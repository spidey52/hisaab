import { env } from "../config/env";

export type OtpDeliveryChannel = "console" | "notify";

export class OtpDeliveryError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OtpDeliveryError";
  }
}

/**
 * Delivers a one-time code to the user's phone.
 *
 * - `console`: no external call; the caller logs the code (local development).
 * - `notify`: posts to the notify service (https://notify.mgdh.in) `POST /otp/send`,
 *   which forwards the code as an SMS. Because we pass `otp`, notify uses our
 *   code verbatim instead of generating its own.
 */
export async function deliverOtp(
  phoneE164: string,
  code: string,
): Promise<{ channel: OtpDeliveryChannel }> {
  if (env.OTP_DELIVERY === "console") {
    return { channel: "console" };
  }
  await sendViaNotify(phoneE164, code);
  return { channel: "notify" };
}

async function sendViaNotify(phoneE164: string, code: string) {
  const endpoint = new URL("/otp/send", env.OTP_NOTIFY_BASE_URL);
  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({
        phone: phoneE164,
        otp: code,
        length: code.length,
        service: env.OTP_NOTIFY_SERVICE,
      }),
      signal: AbortSignal.timeout(env.OTP_NOTIFY_TIMEOUT_MS),
    });
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    throw new OtpDeliveryError(`notify request failed: ${reason}`);
  }

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new OtpDeliveryError(
      `notify responded ${response.status}: ${body.slice(0, 300)}`,
    );
  }
}
