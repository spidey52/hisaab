import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from "node:crypto";
import { parsePhoneNumberFromString } from "libphonenumber-js";
import { and, eq, gt, isNull, lt, or, sql } from "drizzle-orm";
import { env } from "../config/env";
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
import { deliverOtp } from "./otp-delivery";

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
  code_hash: string;
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
  const code = String(randomInt(100_000, 1_000_000));
  const codeHash = hashOtp(challengeId, phoneE164, code);

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

  let delivery: Awaited<ReturnType<typeof deliverOtp>>;
  try {
    delivery = await deliverOtp(phoneE164, code);
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    console.error(
      `[Hisaab OTP] delivery failed for ${maskPhoneNumber(phoneE164)}: ${reason}`,
    );
    // Drop the challenge so the failed attempt does not count against the
    // resend cooldown and the user can retry right away.
    await db.delete(otpChallenges).where(eq(otpChallenges.id, challengeId));
    await logAuthEvent(phoneHash, ipHash, "otp_delivery_failed", {
      delivery: env.OTP_DELIVERY,
      reason: reason.slice(0, 500),
    });
    throw new PhoneAuthError(
      "We could not send the code right now. Please try again.",
      502,
    );
  }

  if (delivery.channel === "console" || env.OTP_IN_RESPONSE) {
    console.info(
      `[Hisaab local OTP] ${maskPhoneNumber(phoneE164)} code ${code}`,
    );
  }

  await logAuthEvent(phoneHash, ipHash, "otp_requested", {
    delivery: delivery.channel,
  });
  await cleanupExpiredAuthData();

  return {
    challengeId,
    phoneE164,
    maskedPhone: maskPhoneNumber(phoneE164),
    expiresInSeconds: OTP_LIFETIME_MINUTES * 60,
    resendAfterSeconds: RESEND_COOLDOWN_SECONDS,
    ...(env.OTP_IN_RESPONSE ? { developmentCode: code } : {}),
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

  const approved = verifyLocalCode(
    challengeId,
    phoneE164,
    code,
    challenge.code_hash,
  );
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

async function logAuthEvent(
  phoneHash: string,
  ipHash: string,
  eventType:
    | "otp_requested"
    | "otp_request_blocked"
    | "otp_delivery_failed"
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
