import {
  PhoneAuthError,
  setSessionCookie,
  verifyPhoneOtp,
} from "@/lib/phone-auth";
import {
  assertTrustedMutation,
  readJsonBody,
} from "@/lib/request-security";

export async function POST(request: Request) {
  try {
    assertTrustedMutation(request);
    const payload = await readJsonBody<{
      challengeId?: string;
      phone?: string;
      code?: string;
    }>(request, 4_096);
    const session = await verifyPhoneOtp(
      payload.challengeId,
      payload.phone,
      payload.code,
      request,
    );
    await setSessionCookie(session.token);
    return Response.json(
      {
        ok: true,
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
  } catch (error) {
    if (error instanceof Response) return error;
    if (error instanceof PhoneAuthError) {
      return Response.json(
        { error: error.publicMessage },
        { status: error.status },
      );
    }
    console.error("OTP verification failed", error);
    return Response.json(
      { error: "We could not verify that code. Please try again." },
      { status: 500 },
    );
  }
}
