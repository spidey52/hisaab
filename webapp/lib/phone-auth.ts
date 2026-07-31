import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from "node:crypto";
import { cookies } from "next/headers";
import { parsePhoneNumberFromString } from "libphonenumber-js";
import { ensureDatabase } from "@/db/ensure";
import { pool, withTransaction } from "@/db";
import {
  authenticationSecret,
  clientIpAddress,
  privateHash,
} from "./request-security";

const OTP_LIFETIME_MINUTES = 10;
const SESSION_LIFETIME_DAYS = 30;
const PHONE_REQUESTS_PER_HOUR = 5;
const IP_REQUESTS_PER_HOUR = 20;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_OTP_ATTEMPTS = 5;

type SessionIdentity = {
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

export class PhoneAuthError extends Error {
  constructor(
    readonly publicMessage: string,
    readonly status = 400,
    readonly retryAfterSeconds?: number,
  ) {
    super(publicMessage);
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
  await ensureDatabase();

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
        await client.query(
          "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
          [lockKey],
        );
      }

      const rate = await client.query<{
        phone_count: number;
        ip_count: number;
        seconds_since_latest: number | null;
      }>(
        `SELECT
          COUNT(*) FILTER (WHERE phone_e164 = $1)::int AS phone_count,
          COUNT(*) FILTER (WHERE requested_ip_hash = $2)::int AS ip_count,
          EXTRACT(EPOCH FROM (
            CURRENT_TIMESTAMP - MAX(created_at) FILTER (WHERE phone_e164 = $1)
          ))::int AS seconds_since_latest
        FROM otp_challenges
        WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '1 hour'`,
        [phoneE164, ipHash],
      );
      const limits = rate.rows[0];
      const cooldown =
        limits?.seconds_since_latest == null
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

      await client.query(
        `INSERT INTO otp_challenges (
          id, phone_e164, provider, provider_reference, code_hash,
          requested_ip_hash, max_attempts, expires_at
        ) VALUES (
          $1, $2, $3, NULL, $4, $5, $6,
          CURRENT_TIMESTAMP + INTERVAL '${OTP_LIFETIME_MINUTES} minutes'
        )`,
        [
          challengeId,
          phoneE164,
          provider,
          codeHash,
          ipHash,
          MAX_OTP_ATTEMPTS,
        ],
      );
    });
  } catch (error) {
    if (blocked) {
      await logAuthEvent(phoneHash, ipHash, "otp_request_blocked", blocked);
    }
    throw error;
  }

  if (provider === "console") {
    console.info(
      `[Hisaab local OTP] ${maskPhoneNumber(phoneE164)} code ${developmentCode}`,
    );
  } else {
    try {
      const providerReference = await startTwilioVerification(phoneE164);
      await pool.query(
        `UPDATE otp_challenges
         SET provider_reference = $1
         WHERE id = $2 AND consumed_at IS NULL`,
        [providerReference, challengeId],
      );
    } catch (error) {
      await pool.query("DELETE FROM otp_challenges WHERE id = $1", [
        challengeId,
      ]);
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
  const challengeId =
    typeof challengeIdInput === "string" ? challengeIdInput.trim() : "";
  const phoneE164 = normalizePhoneNumber(phoneInput);
  const code = typeof codeInput === "string" ? codeInput.trim() : "";
  if (!challengeId || !/^\d{4,10}$/.test(code)) {
    throw new PhoneAuthError("Enter the verification code sent to your phone.");
  }

  await ensureDatabase();
  const attempt = await pool.query<ChallengeRow>(
    `UPDATE otp_challenges
     SET attempts = attempts + 1
     WHERE id = $1
       AND phone_e164 = $2
       AND consumed_at IS NULL
       AND expires_at > CURRENT_TIMESTAMP
       AND attempts < max_attempts
     RETURNING id, phone_e164, provider, code_hash, attempts, max_attempts`,
    [challengeId, phoneE164],
  );
  const challenge = attempt.rows[0];
  if (!challenge) {
    throw new PhoneAuthError(
      "This code has expired or was used. Request a new code.",
      400,
    );
  }

  const approved =
    challenge.provider === "console"
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

  const consumed = await pool.query(
    `UPDATE otp_challenges
     SET consumed_at = CURRENT_TIMESTAMP
     WHERE id = $1 AND consumed_at IS NULL
     RETURNING id`,
    [challengeId],
  );
  if (consumed.rowCount !== 1) {
    throw new PhoneAuthError(
      "This code has already been used. Request a new code.",
    );
  }

  const session = await createSessionForPhone(phoneE164, request);
  await logAuthEvent(phoneHash, ipHash, "otp_approved", {});
  return session;
}

export async function getPhoneSessionIdentity(): Promise<SessionIdentity | null> {
  const cookieStore = await cookies();
  const token =
    cookieStore.get(productionCookieName())?.value ??
    cookieStore.get("hisaab_session")?.value;
  if (!token || token.length < 32) return null;

  await ensureDatabase();
  const result = await pool.query<{
    user_id: string;
    phone_e164: string;
    full_name: string | null;
  }>(
    `SELECT
      u.id AS user_id,
      u.phone_e164,
      u.full_name
    FROM user_sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token_hash = $1
      AND s.revoked_at IS NULL
      AND s.expires_at > CURRENT_TIMESTAMP
      AND u.deleted_at IS NULL
    LIMIT 1`,
    [hashSessionToken(token)],
  );
  const user = result.rows[0];
  if (!user) return null;

  return {
    userId: user.user_id,
    phoneE164: user.phone_e164,
    fullName: user.full_name?.trim() || `User ${user.phone_e164.slice(-4)}`,
  };
}

export async function setSessionCookie(token: string) {
  const cookieStore = await cookies();
  cookieStore.set(sessionCookieName(), token, {
    httpOnly: true,
    secure: secureCookies(),
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_LIFETIME_DAYS * 24 * 60 * 60,
    priority: "high",
  });
}

export async function revokeCurrentSession() {
  const cookieStore = await cookies();
  const names = [productionCookieName(), "hisaab_session"];
  const token = names
    .map((name) => cookieStore.get(name)?.value)
    .find(Boolean);

  if (token) {
    await ensureDatabase();
    const result = await pool.query<{ user_id: string }>(
      `UPDATE user_sessions
       SET revoked_at = CURRENT_TIMESTAMP
       WHERE token_hash = $1 AND revoked_at IS NULL
       RETURNING user_id`,
      [hashSessionToken(token)],
    );
    if (result.rows[0]) {
      await logAuthEvent("", "", "session_revoked", {
        userId: result.rows[0].user_id,
      });
    }
  }

  for (const name of names) {
    cookieStore.set(name, "", {
      httpOnly: true,
      secure: name.startsWith("__Host-"),
      sameSite: "lax",
      path: "/",
      expires: new Date(0),
    });
  }
}

export async function clearSessionCookies() {
  const cookieStore = await cookies();
  for (const name of [productionCookieName(), "hisaab_session"]) {
    cookieStore.set(name, "", {
      httpOnly: true,
      secure: name.startsWith("__Host-"),
      sameSite: "lax",
      path: "/",
      expires: new Date(0),
    });
  }
}

async function createSessionForPhone(phoneE164: string, request: Request) {
  const now = new Date();
  const rawToken = randomBytes(32).toString("base64url");
  const tokenHash = hashSessionToken(rawToken);
  const ipHash = privateHash(clientIpAddress(request));
  const userAgent = (request.headers.get("user-agent") ?? "").slice(0, 500);

  const identity = await withTransaction(async (client) => {
    const userId = crypto.randomUUID();
    const userResult = await client.query<{
      id: string;
      full_name: string | null;
    }>(
      `INSERT INTO users (
        id, phone_e164, phone_verified_at, full_name, created_at, updated_at
      ) VALUES ($1, $2, $3, NULL, $3, $3)
      ON CONFLICT (phone_e164) DO UPDATE SET
        phone_verified_at = EXCLUDED.phone_verified_at,
        updated_at = EXCLUDED.updated_at,
        deleted_at = NULL
      RETURNING id, full_name`,
      [userId, phoneE164, now],
    );
    const user = userResult.rows[0]!;

    const membership = await client.query(
      `SELECT id FROM memberships WHERE user_id = $1 LIMIT 1`,
      [user.id],
    );
    if (membership.rowCount === 0) {
      const companyId = crypto.randomUUID();
      await client.query(
        `INSERT INTO companies (
          id, name, currency, timezone, next_entry_number, created_at, updated_at
        ) VALUES ($1, 'My Hisaab', 'INR', 'Asia/Kolkata', 1, $2, $2)`,
        [companyId, now],
      );
      await client.query(
        `INSERT INTO memberships (
          id, user_id, company_id, role, tutorial_completed, created_at
        ) VALUES ($1, $2, $3, 'owner', FALSE, $4)`,
        [crypto.randomUUID(), user.id, companyId, now],
      );
    }

    await client.query(
      `INSERT INTO user_sessions (
        id, user_id, token_hash, user_agent, ip_hash, created_at,
        last_seen_at, expires_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6::timestamptz, $6::timestamptz,
        $6::timestamptz + INTERVAL '${SESSION_LIFETIME_DAYS} days'
      )`,
      [
        crypto.randomUUID(),
        user.id,
        tokenHash,
        userAgent,
        ipHash,
        now,
      ],
    );

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
  const baseUrl = new URL(process.env.PUBLIC_BASE_URL ?? "http://localhost:3000");
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

function secureCookies() {
  if (process.env.COOKIE_SECURE === "false") return false;
  if (process.env.COOKIE_SECURE === "true") return true;
  return process.env.NODE_ENV === "production";
}

function productionCookieName() {
  return "__Host-hisaab_session";
}

function sessionCookieName() {
  return secureCookies() ? productionCookieName() : "hisaab_session";
}

async function startTwilioVerification(phoneE164: string) {
  const credentials = twilioCredentials();
  const body = new URLSearchParams({ To: phoneE164, Channel: "sms" });
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${encodeURIComponent(
      credentials.serviceSid,
    )}/Verifications`,
    {
      method: "POST",
      headers: {
        authorization: `Basic ${Buffer.from(
          `${credentials.accountSid}:${credentials.authToken}`,
        ).toString("base64")}`,
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
    `https://verify.twilio.com/v2/Services/${encodeURIComponent(
      credentials.serviceSid,
    )}/VerificationCheck`,
    {
      method: "POST",
      headers: {
        authorization: `Basic ${Buffer.from(
          `${credentials.accountSid}:${credentials.authToken}`,
        ).toString("base64")}`,
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
  await pool.query(
    `INSERT INTO auth_events (
      id, phone_hash, ip_hash, event_type, metadata
    ) VALUES ($1, $2, $3, $4, $5::jsonb)`,
    [
      crypto.randomUUID(),
      phoneHash,
      ipHash,
      eventType,
      JSON.stringify(metadata),
    ],
  );
}

async function cleanupExpiredAuthData() {
  await Promise.all([
    pool.query(
      `DELETE FROM otp_challenges
       WHERE expires_at < CURRENT_TIMESTAMP - INTERVAL '1 day'`,
    ),
    pool.query(
      `DELETE FROM user_sessions
       WHERE expires_at < CURRENT_TIMESTAMP - INTERVAL '30 days'
          OR revoked_at < CURRENT_TIMESTAMP - INTERVAL '30 days'`,
    ),
    pool.query(
      `DELETE FROM auth_events
       WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days'`,
    ),
  ]);
}
