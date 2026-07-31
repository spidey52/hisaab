import { and, asc, eq, isNull } from "drizzle-orm";
import { companies, db, memberships, users } from "../db";
import { extractBearerToken, getIdentityFromBearerToken } from "./phone-auth";
import { throwApiError } from "../utils/security";

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
    throwApiError(401, "Verify your phone number to continue.");
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
    throwApiError(403, "Your Hisaab account could not be found.");
  }

  return {
    userId: membership.userId,
    phoneE164: membership.phoneE164,
    fullName: membership.fullName?.trim() ||
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
