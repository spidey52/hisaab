import { and, eq, isNull, asc } from "drizzle-orm";
import { db, memberships, users, companies } from "../db";
import {
  extractBearerToken,
  getIdentityFromBearerToken,
} from "./phone-auth";
import { HttpError } from "../utils/security";

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

export async function requireServerContext(
  request: Request,
): Promise<ServerContext> {
  const identity = await getIdentityFromBearerToken(
    extractBearerToken(request),
  );
  if (!identity) {
    throw new HttpError("Verify your phone number to continue.", 401);
  }

  const rows = await db
    .select({
      userId: users.id,
      phoneE164: users.phoneE164,
      fullName: users.fullName,
      language: users.language,
      accessibilityMode: users.accessibilityMode,
      contactDiscoverable: users.contactDiscoverable,
      userVersion: users.version,
      companyId: companies.id,
      companyName: companies.name,
      currency: companies.currency,
      timezone: companies.timezone,
      companyVersion: companies.version,
      companyUpdatedAt: companies.updatedAt,
      role: memberships.role,
      membershipCreatedAt: memberships.createdAt,
    })
    .from(users)
    .innerJoin(memberships, eq(memberships.userId, users.id))
    .innerJoin(companies, eq(companies.id, memberships.companyId))
    .where(and(eq(users.id, identity.userId), isNull(users.deletedAt)))
    .orderBy(asc(memberships.createdAt))
    .limit(1);

  const membership = rows[0];
  if (!membership) {
    throw new HttpError("Your Hisaab account could not be found.", 403);
  }

  return {
    userId: membership.userId,
    phoneE164: membership.phoneE164,
    fullName:
      membership.fullName?.trim() ||
      `User ${membership.phoneE164.slice(-4)}`,
    language: membership.language === "hi" ? "hi" : "en",
    accessibilityMode: Boolean(membership.accessibilityMode),
    contactDiscoverable: Boolean(membership.contactDiscoverable),
    userVersion: Number(membership.userVersion ?? 1),
    companyId: membership.companyId,
    companyName: membership.companyName,
    currency: "INR",
    timezone: String(membership.timezone),
    companyVersion: Number(membership.companyVersion ?? 1),
    companyUpdatedAt: String(membership.companyUpdatedAt),
    role: membership.role === "member" ? "member" : "owner",
  };
}

export function handleRouteError(error: unknown) {
  if (error instanceof Response) return error;
  if (error instanceof HttpError) {
    return new Response(JSON.stringify({ error: error.publicMessage }), {
      status: error.status,
      headers: {
        "content-type": "application/json",
        "cache-control": "no-store",
        ...(error.retryAfterSeconds != null
          ? { "retry-after": String(error.retryAfterSeconds) }
          : {}),
      },
    });
  }
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
