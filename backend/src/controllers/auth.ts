import type { Context } from "hono";
import type { z } from "zod";
import type { requestOtpSchema, verifyOtpSchema } from "../schema/auth";
import {
  extractBearerToken,
  requestPhoneOtp,
  revokeBearerSession,
  verifyPhoneOtp,
} from "../services/phone-auth";

export async function requestOtp(c: Context) {
  const payload = c.get("json") as z.infer<typeof requestOtpSchema>;
  const result = await requestPhoneOtp(payload.phone, c.req.raw);
  return c.json(result, {
    status: 202,
    headers: {
      "cache-control": "no-store",
      "retry-after": String(result.resendAfterSeconds),
    },
  });
}

export async function verifyOtp(c: Context) {
  const payload = c.get("json") as z.infer<typeof verifyOtpSchema>;
  const session = await verifyPhoneOtp(
    payload.challengeId,
    payload.phone,
    payload.code,
    c.req.raw,
  );
  return c.json(
    {
      ok: true,
      token: session.token,
      user: {
        phoneE164: session.phoneE164,
        fullName: session.fullName,
      },
    },
    {
      headers: {
        "cache-control": "no-store",
      },
    },
  );
}

export async function logout(c: Context) {
  await revokeBearerSession(extractBearerToken(c.req.raw));
  return c.json(
    { ok: true },
    {
      headers: {
        "cache-control": "no-store",
        "clear-site-data": '"cache", "storage"',
      },
    },
  );
}
