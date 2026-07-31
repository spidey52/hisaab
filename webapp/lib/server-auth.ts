import { ensureDatabase } from "@/db/ensure";
import { getRawDb } from "@/db";
import { getPhoneSessionIdentity } from "./phone-auth";
import { assertTrustedMutation } from "./request-security";

export type ServerContext = {
  userId: string;
  phoneE164: string;
  fullName: string;
  language: "en" | "hi";
  accessibilityMode: boolean;
  contactDiscoverable: boolean;
  userVersion: number;
  companyId: string;
  companyName: string;
  currency: "INR";
  timezone: string;
  companyVersion: number;
  companyUpdatedAt: string;
  role: "owner" | "member";
};

export async function getAuthenticatedIdentity() {
  return getPhoneSessionIdentity();
}

export async function requireServerContext(): Promise<ServerContext> {
  const identity = await getAuthenticatedIdentity();
  if (!identity) {
    throw new Response(
      JSON.stringify({ error: "Verify your phone number to continue." }),
      {
        status: 401,
        headers: { "content-type": "application/json" },
      },
    );
  }

  await ensureDatabase();
  const database = getRawDb();
  const membership = await database
    .prepare(
      `SELECT
        u.id AS user_id,
        u.phone_e164,
        COALESCE(u.full_name, 'User ' || right(u.phone_e164, 4)) AS full_name,
        u.language,
        u.accessibility_mode,
        u.contact_discoverable,
        u.version AS user_version,
        c.id AS company_id,
        c.name AS company_name,
        c.currency,
        c.timezone,
        c.version AS company_version,
        c.updated_at AS company_updated_at,
        m.role
      FROM users u
      JOIN memberships m ON m.user_id = u.id
      JOIN companies c ON c.id = m.company_id
      WHERE u.id = ? AND u.deleted_at IS NULL
      ORDER BY m.created_at ASC
      LIMIT 1`,
    )
    .bind(identity.userId)
    .first<Record<string, unknown>>();

  if (!membership) {
    throw new Response(
      JSON.stringify({ error: "Your Hisaab account could not be found." }),
      {
        status: 403,
        headers: { "content-type": "application/json" },
      },
    );
  }

  return rowToContext(membership);
}

export async function requireMutationContext(request: Request) {
  assertTrustedMutation(request);
  return requireServerContext();
}

function rowToContext(row: Record<string, unknown>): ServerContext {
  return {
    userId: String(row.user_id),
    phoneE164: String(row.phone_e164),
    fullName: String(row.full_name),
    language: row.language === "hi" ? "hi" : "en",
    accessibilityMode: Boolean(row.accessibility_mode),
    contactDiscoverable: Boolean(row.contact_discoverable),
    userVersion: Number(row.user_version ?? 1),
    companyId: String(row.company_id),
    companyName: String(row.company_name),
    currency: "INR",
    timezone: String(row.timezone),
    companyVersion: Number(row.company_version ?? 1),
    companyUpdatedAt: String(row.company_updated_at),
    role: row.role === "member" ? "member" : "owner",
  };
}

export function handleRouteError(error: unknown) {
  if (error instanceof Response) return error;
  const message =
    error instanceof Error ? error.message : "Something went wrong.";
  console.error("Hisaab route error", error);
  return Response.json(
    {
      error:
        message.includes("connect") ||
        message.includes("PostgreSQL") ||
        message.includes("database")
          ? "Your account data is temporarily unavailable. Please try again."
          : "We could not complete that action. Please try again.",
    },
    { status: 500 },
  );
}
