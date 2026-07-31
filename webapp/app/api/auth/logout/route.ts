import { revokeCurrentSession } from "@/lib/phone-auth";
import { assertTrustedMutation } from "@/lib/request-security";

export async function POST(request: Request) {
  try {
    assertTrustedMutation(request);
    await revokeCurrentSession();
    if (request.headers.get("accept")?.includes("text/html")) {
      return new Response(null, {
        status: 303,
        headers: {
          "cache-control": "no-store",
          "clear-site-data": '"cache", "storage"',
          location: "/",
        },
      });
    }
    return Response.json(
      { ok: true },
      {
        headers: {
          "cache-control": "no-store",
          "clear-site-data": '"cache", "storage"',
        },
      },
    );
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("Sign out failed", error);
    return Response.json({ error: "Could not sign out." }, { status: 500 });
  }
}
