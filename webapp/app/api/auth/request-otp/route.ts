import {
  PhoneAuthError,
  requestPhoneOtp,
} from "@/lib/phone-auth";
import {
  assertTrustedMutation,
  readJsonBody,
} from "@/lib/request-security";

export async function POST(request: Request) {
  try {
    assertTrustedMutation(request);
    const payload = await readJsonBody<{ phone?: string }>(request, 2_048);
    const result = await requestPhoneOtp(payload.phone, request);
    return Response.json(result, {
      status: 202,
      headers: {
        "cache-control": "no-store",
        "retry-after": String(result.resendAfterSeconds),
      },
    });
  } catch (error) {
    return authErrorResponse(error);
  }
}

function authErrorResponse(error: unknown) {
  if (error instanceof Response) return error;
  if (error instanceof PhoneAuthError) {
    return Response.json(
      { error: error.publicMessage },
      {
        status: error.status,
        headers: error.retryAfterSeconds
          ? { "retry-after": String(error.retryAfterSeconds) }
          : undefined,
      },
    );
  }
  console.error("OTP request failed", error);
  return Response.json(
    { error: "We could not send a code. Please try again." },
    { status: 500 },
  );
}
