import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from "node:crypto";
import { parsePhoneNumberFromString } from "libphonenumber-js";
import { and, eq, gt, isNull, lt, or, sql } from "drizzle-orm";
import {
  authEvents,
  companies,
  db,
  memberships,
  otpChallenges,
  users,
  userSessions,
  withTransaction,
} from "../db";
import { addDuration, nowDate, subtractDuration } from "../utils/date-utils";
import {
  ApiError,
  authenticationSecret,
  clientIpAddress,
  privateHash,
} from "../utils/security";

const OTP_LIFETIME_MINUTES = 10;
const SESSION_LIFETIME_DAYS = 30;
const PHONE_REQUESTS_PER_HOUR = 5;
const IP_REQUESTS_PER_HOUR = 20;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_OTP_ATTEMPTS = 5;

export type SessionIdentity = {
  userId: string;
  phoneE164: string;
  fullName: string;
};

type ChallengeRow = {
  id: string;
  phone_e164: string;
  provider: "console" | "twilio_verify";
  code_hash: string | null;
  attempts: number;
  max_attempts: number;
};

type RateLimitSnapshot = {
  phoneRequests: number;
  ipRequests: number;
  retryAfterSeconds: number;
};

export class PhoneAuthError extends ApiError {
  constructor(
    message: string,
    status = 400,
    retryAfterSeconds?: number,
  ) {
    super(status, message, {
      headers: retryAfterSeconds != null
        ? { "retry-after": String(retryAfterSeconds) }
        : undefined,
    });
  }
}

export function normalizePhoneNumber(input: unknown) {
  if (typeof input !== "string") {
    throw new PhoneAuthError("Enter a valid mobile number.");
  }
  const value = input.trim();
  const parsed = parsePhoneNumberFromString(value, "IN");
  if (!parsed?.isValid()) {
    throw new PhoneAuthError(
      "Enter a valid mobile number with its country code.",
    );
  }
  return parsed.number;
}

export function maskPhoneNumber(phoneE164: string) {
  const suffix = phoneE164.slice(-4);
  const countryPrefix = phoneE164.slice(0, Math.max(2, phoneE164.length - 10));
  return `${countryPrefix} •••••• ${suffix}`;
}

export async function requestPhoneOtp(phoneInput: unknown, request: Request) {
  const phoneE164 = normalizePhoneNumber(phoneInput);

  const ipHash = privateHash(clientIpAddress(request));
  const phoneHash = privateHash(phoneE164);
  const challengeId = crypto.randomUUID();
  const provider = otpProvider();
  let codeHash: string | null = null;
  let developmentCode: string | undefined;

  if (provider === "console") {
    assertConsoleOtpIsLocalOnly();
    developmentCode = String(randomInt(100_000, 1_000_000));
    codeHash = hashOtp(challengeId, phoneE164, developmentCode);
  }

  let blocked: RateLimitSnapshot | null = null;
  try {
    await withTransaction(async (client) => {
      const lockKeys = [`otp-ip:${ipHash}`, `otp-phone:${phoneHash}`].sort();
      for (const lockKey of lockKeys) {
        await client.execute(
          sql`SELECT pg_advisory_xact_lock(hashtextextended(${lockKey}, 0))`,
        );
      }

      const rate = await client
        .select({
          phone_count: sql<
            number
          >`count(*) filter (where ${otpChallenges.phoneE164} = ${phoneE164})::int`
            .mapWith(
              Number,
            ),
          ip_count: sql<
            number
          >`count(*) filter (where ${otpChallenges.requestedIpHash} = ${ipHash})::int`
            .mapWith(
              Number,
            ),
          seconds_since_latest: sql<
            number | null
          >`extract(epoch from (current_timestamp - max(${otpChallenges.createdAt}) filter (where ${otpChallenges.phoneE164} = ${phoneE164})))::int`
            .mapWith(
              Number,
            ),
        })
        .from(otpChallenges)
        .where(
          gt(
            otpChallenges.createdAt,
            sql`current_timestamp - interval '1 hour'`,
          ),
        );
      const limits = rate[0];
      const cooldown = limits?.seconds_since_latest == null
        ? 0
        : RESEND_COOLDOWN_SECONDS - limits.seconds_since_latest;
      if (
        (limits?.phone_count ?? 0) >= PHONE_REQUESTS_PER_HOUR ||
        (limits?.ip_count ?? 0) >= IP_REQUESTS_PER_HOUR ||
        cooldown > 0
      ) {
        blocked = {
          phoneRequests: limits?.phone_count ?? 0,
          ipRequests: limits?.ip_count ?? 0,
          retryAfterSeconds: cooldown > 0 ? cooldown : 15 * 60,
        };
        throw new PhoneAuthError(
          "Please wait before requesting another code.",
          429,
          blocked.retryAfterSeconds,
        );
      }

      const expiresAt = addDuration(OTP_LIFETIME_MINUTES, "minute");
      await client.insert(otpChallenges).values({
        id: challengeId,
        phoneE164,
        provider,
        providerReference: null,
        codeHash,
        requestedIpHash: ipHash,
        maxAttempts: MAX_OTP_ATTEMPTS,
        expiresAt,
      });
    });
  } catch (error) {
    if (blocked) {
      await logAuthEvent(phoneHash, ipHash, "otp_request_blocked", blocked);
    }
    throw error;
  }

  if (provider === "console") {
    console.info(
      `[Hisaab local OTP] ${
        maskPhoneNumber(phoneE164)
      } code ${developmentCode}`,
    );
  } else {
    try {
      const providerReference = await startTwilioVerification(phoneE164);
      await db
        .update(otpChallenges)
        .set({ providerReference })
        .where(
          and(
            eq(otpChallenges.id, challengeId),
            isNull(otpChallenges.consumedAt),
          ),
        );
    } catch (error) {
      await db
        .delete(otpChallenges)
        .where(eq(otpChallenges.id, challengeId));
      throw error;
    }
  }

  await logAuthEvent(phoneHash, ipHash, "otp_requested", { provider });
  await cleanupExpiredAuthData();

  return {
    challengeId,
    phoneE164,
    maskedPhone: maskPhoneNumber(phoneE164),
    expiresInSeconds: OTP_LIFETIME_MINUTES * 60,
    resendAfterSeconds: RESEND_COOLDOWN_SECONDS,
    developmentCode,
  };
}

export async function verifyPhoneOtp(
  challengeIdInput: unknown,
  phoneInput: unknown,
  codeInput: unknown,
  request: Request,
) {
  const challengeId = typeof challengeIdInput === "string"
    ? challengeIdInput.trim()
    : "";
  const phoneE164 = normalizePhoneNumber(phoneInput);
  const code = typeof codeInput === "string" ? codeInput.trim() : "";
  if (!challengeId || !/^\d{4,10}$/.test(code)) {
    throw new PhoneAuthError("Enter the verification code sent to your phone.");
  }

  const now = nowDate();
  const attempt = await db
    .update(otpChallenges)
    .set({ attempts: sql`${otpChallenges.attempts} + 1` })
    .where(
      and(
        eq(otpChallenges.id, challengeId),
        eq(otpChallenges.phoneE164, phoneE164),
        isNull(otpChallenges.consumedAt),
        gt(otpChallenges.expiresAt, now),
        lt(otpChallenges.attempts, otpChallenges.maxAttempts),
      ),
    )
    .returning({
      id: otpChallenges.id,
      phone_e164: otpChallenges.phoneE164,
      provider: otpChallenges.provider,
      code_hash: otpChallenges.codeHash,
      attempts: otpChallenges.attempts,
      max_attempts: otpChallenges.maxAttempts,
    });
  const challenge = attempt[0] as ChallengeRow | undefined;
  if (!challenge) {
    throw new PhoneAuthError(
      "This code has expired or was used. Request a new code.",
      400,
    );
  }

  const approved = challenge.provider === "console"
    ? verifyLocalCode(challengeId, phoneE164, code, challenge.code_hash)
    : await checkTwilioVerification(phoneE164, code);
  const ipHash = privateHash(clientIpAddress(request));
  const phoneHash = privateHash(phoneE164);

  if (!approved) {
    await logAuthEvent(phoneHash, ipHash, "otp_failed", {
      attempt: challenge.attempts,
    });
    const attemptsLeft = Math.max(
      0,
      challenge.max_attempts - challenge.attempts,
    );
    throw new PhoneAuthError(
      attemptsLeft > 0
        ? `That code is not correct. ${attemptsLeft} ${
          attemptsLeft === 1 ? "try" : "tries"
        } remaining.`
        : "Too many incorrect attempts. Request a new code.",
      400,
    );
  }

  const consumed = await db
    .update(otpChallenges)
    .set({ consumedAt: nowDate() })
    .where(
      and(
        eq(otpChallenges.id, challengeId),
        isNull(otpChallenges.consumedAt),
      ),
    )
    .returning({ id: otpChallenges.id });
  if (consumed.length !== 1) {
    throw new PhoneAuthError(
      "This code has already been used. Request a new code.",
    );
  }

  const session = await createSessionForPhone(phoneE164, request);
  await logAuthEvent(phoneHash, ipHash, "otp_approved", {});
  return session;
}

export async function getIdentityFromBearerToken(
  token: string | null | undefined,
): Promise<SessionIdentity | null> {
  if (!token || token.length < 32) return null;

  const result = await db
    .select({
      user_id: users.id,
      phone_e164: users.phoneE164,
      full_name: users.fullName,
    })
    .from(userSessions)
    .innerJoin(users, eq(users.id, userSessions.userId))
    .where(
      and(
        eq(userSessions.tokenHash, hashSessionToken(token)),
        isNull(userSessions.revokedAt),
        gt(userSessions.expiresAt, sql`current_timestamp`),
        isNull(users.deletedAt),
      ),
    )
    .limit(1);
  const user = result[0];
  if (!user) return null;

  return {
    userId: user.user_id,
    phoneE164: user.phone_e164,
    fullName: user.full_name?.trim() || `User ${user.phone_e164.slice(-4)}`,
  };
}

export function extractBearerToken(request: Request): string | null {
  const header = request.headers.get("authorization");
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match?.[1]?.trim() || null;
}

export async function revokeBearerSession(token: string | null | undefined) {
  if (!token) return;
  const result = await db
    .update(userSessions)
    .set({ revokedAt: nowDate() })
    .where(
      and(
        eq(userSessions.tokenHash, hashSessionToken(token)),
        isNull(userSessions.revokedAt),
      ),
    )
    .returning({ user_id: userSessions.userId });
  if (result[0]) {
    await logAuthEvent("", "", "session_revoked", {
      userId: result[0].user_id,
    });
  }
}

async function createSessionForPhone(phoneE164: string, request: Request) {
  const now = nowDate();
  const rawToken = randomBytes(32).toString("base64url");
  const tokenHash = hashSessionToken(rawToken);
  const ipHash = privateHash(clientIpAddress(request));
  const userAgent = (request.headers.get("user-agent") ?? "").slice(0, 500);
  const sessionExpiresAt = addDuration(SESSION_LIFETIME_DAYS, "day", now);

  const identity = await withTransaction(async (client) => {
    const userId = crypto.randomUUID();
    const userResult = await client
      .insert(users)
      .values({
        id: userId,
        phoneE164,
        phoneVerifiedAt: now,
        fullName: null,
        createdAt: now,
        updatedAt: now,
      })
      .onConflictDoUpdate({
        target: users.phoneE164,
        set: {
          phoneVerifiedAt: now,
          updatedAt: now,
          deletedAt: null,
        },
      })
      .returning({ id: users.id, full_name: users.fullName });
    const user = userResult[0]!;

    const membership = await client
      .select({ id: memberships.id })
      .from(memberships)
      .where(eq(memberships.userId, user.id))
      .limit(1);
    if (membership.length === 0) {
      const companyId = crypto.randomUUID();
      await client.insert(companies).values({
        id: companyId,
        name: "My Hisaab",
        currency: "INR",
        timezone: "Asia/Kolkata",
        nextEntryNumber: 1,
        createdAt: now,
        updatedAt: now,
      });
      await client.insert(memberships).values({
        id: crypto.randomUUID(),
        userId: user.id,
        companyId,
        role: "owner",
        tutorialCompleted: false,
        createdAt: now,
      });
    }

    await client.insert(userSessions).values({
      id: crypto.randomUUID(),
      userId: user.id,
      tokenHash,
      userAgent,
      ipHash,
      createdAt: now,
      lastSeenAt: now,
      expiresAt: sessionExpiresAt,
    });

    return {
      userId: user.id,
      phoneE164,
      fullName: user.full_name?.trim() || `User ${phoneE164.slice(-4)}`,
    };
  });

  await logAuthEvent(privateHash(phoneE164), ipHash, "session_created", {
    userId: identity.userId,
  });
  return { ...identity, token: rawToken };
}

function otpProvider(): "console" | "twilio_verify" {
  return process.env.OTP_PROVIDER === "console" ? "console" : "twilio_verify";
}

function assertConsoleOtpIsLocalOnly() {
  if (process.env.ALLOW_INSECURE_LOCAL_OTP !== "true") {
    throw new Error(
      "Console OTP is disabled. Configure Twilio Verify or explicitly enable local OTP.",
    );
  }
  const baseUrl = new URL(
    process.env.PUBLIC_BASE_URL ?? "http://localhost:3000",
  );
  if (!["localhost", "127.0.0.1", "::1"].includes(baseUrl.hostname)) {
    throw new Error("Console OTP can only be used with a localhost base URL.");
  }
}

function hashOtp(challengeId: string, phoneE164: string, code: string) {
  return createHmac("sha256", authenticationSecret())
    .update(`${challengeId}:${phoneE164}:${code}`)
    .digest("hex");
}

function verifyLocalCode(
  challengeId: string,
  phoneE164: string,
  code: string,
  expectedHash: string | null,
) {
  if (!expectedHash) return false;
  const actual = Buffer.from(hashOtp(challengeId, phoneE164, code), "hex");
  const expected = Buffer.from(expectedHash, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function hashSessionToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

async function startTwilioVerification(phoneE164: string) {
  const credentials = twilioCredentials();
  const body = new URLSearchParams({ To: phoneE164, Channel: "sms" });
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${
      encodeURIComponent(
        credentials.serviceSid,
      )
    }/Verifications`,
    {
      method: "POST",
      headers: {
        authorization: `Basic ${
          Buffer.from(
            `${credentials.accountSid}:${credentials.authToken}`,
          ).toString("base64")
        }`,
        "content-type": "application/x-www-form-urlencoded",
      },
      body,
      cache: "no-store",
      signal: AbortSignal.timeout(10_000),
    },
  );
  const result = (await response.json()) as {
    sid?: string;
    status?: string;
    message?: string;
  };
  if (!response.ok || result.status !== "pending" || !result.sid) {
    console.error("Twilio Verify start failed", {
      status: response.status,
      providerMessage: result.message?.slice(0, 200),
    });
    throw new PhoneAuthError(
      "We could not send a code right now. Please try again shortly.",
      502,
    );
  }
  return result.sid;
}

async function checkTwilioVerification(phoneE164: string, code: string) {
  const credentials = twilioCredentials();
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${
      encodeURIComponent(
        credentials.serviceSid,
      )
    }/VerificationCheck`,
    {
      method: "POST",
      headers: {
        authorization: `Basic ${
          Buffer.from(
            `${credentials.accountSid}:${credentials.authToken}`,
          ).toString("base64")
        }`,
        "content-type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: phoneE164, Code: code }),
      cache: "no-store",
      signal: AbortSignal.timeout(10_000),
    },
  );
  const result = (await response.json()) as {
    status?: string;
    message?: string;
  };
  if (response.ok) return result.status === "approved";
  if (response.status >= 500) {
    console.error("Twilio Verify check failed", {
      status: response.status,
      providerMessage: result.message?.slice(0, 200),
    });
    throw new PhoneAuthError(
      "Verification is temporarily unavailable. Please try again.",
      502,
    );
  }
  return false;
}

function twilioCredentials() {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const serviceSid = process.env.TWILIO_VERIFY_SERVICE_SID;
  if (!accountSid || !authToken || !serviceSid) {
    throw new Error(
      "Twilio Verify credentials are required when OTP_PROVIDER is twilio_verify.",
    );
  }
  return { accountSid, authToken, serviceSid };
}

async function logAuthEvent(
  phoneHash: string,
  ipHash: string,
  eventType:
    | "otp_requested"
    | "otp_request_blocked"
    | "otp_failed"
    | "otp_approved"
    | "session_created"
    | "session_revoked",
  metadata: Record<string, unknown>,
) {
  await db.insert(authEvents).values({
    id: crypto.randomUUID(),
    phoneHash,
    ipHash,
    eventType,
    metadata,
  });
}

async function cleanupExpiredAuthData() {
  const oneDayAgo = subtractDuration(1, "day");
  const thirtyDaysAgo = subtractDuration(30, "day");
  const ninetyDaysAgo = subtractDuration(90, "day");

  await Promise.all([
    db
      .delete(otpChallenges)
      .where(lt(otpChallenges.expiresAt, oneDayAgo)),
    db.delete(userSessions).where(
      or(
        lt(userSessions.expiresAt, thirtyDaysAgo),
        lt(userSessions.revokedAt, thirtyDaysAgo),
      ),
    ),
    db.delete(authEvents).where(lt(authEvents.createdAt, ninetyDaysAgo)),
  ]);
}
