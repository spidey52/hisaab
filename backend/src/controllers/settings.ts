import type { Context } from "hono";
import { and, eq, sql } from "drizzle-orm";
import { companies, users, withTransaction } from "../db";
import { requireServerContext } from "../services/server-auth";
import { nowDate } from "../utils/date-utils";
import { throwApiError } from "../utils/security";
import {
  appendSyncChange,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "../services/sync-server";

const operationType = "settings.update";

export async function updateSettings(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  const payload = c.get("json") as {
    companyName?: string;
    timezone?: "Asia/Kolkata" | "Asia/Kathmandu" | "Asia/Dubai" | "UTC";
    language?: "en" | "hi";
    accessibilityMode?: boolean;
    contactDiscoverable?: boolean;
    idempotencyKey?: string;
    baseCompanyVersion?: number;
    baseUserVersion?: number;
  };
  const updatesCompany = payload.companyName !== undefined ||
    payload.timezone !== undefined;
  const updatesUser = payload.language !== undefined ||
    payload.accessibilityMode !== undefined ||
    payload.contactDiscoverable !== undefined;
  const intent = {
    companyName: payload.companyName,
    timezone: payload.timezone,
    language: payload.language,
    accessibilityMode: payload.accessibilityMode,
    contactDiscoverable: payload.contactDiscoverable,
  };
  const requestHash = operationRequestHash(operationType, intent);

  const result = await withTransaction(async (client) => {
    if (payload.idempotencyKey) {
      await lockOperation(
        client,
        context.companyId,
        payload.idempotencyKey,
      );
      const receipt = await readOperationReceipt(
        client,
        context.companyId,
        payload.idempotencyKey,
      );
      if (receipt) {
        return replayReceipt(receipt, operationType, requestHash);
      }
    }

    const now = nowDate();
    let changeCursor = "0";
    let company:
      | {
        id: string;
        name: string;
        currency: "INR";
        timezone: string;
        version: number;
        updatedAt: string;
      }
      | undefined;
    let userSettings:
      | {
        language: "en" | "hi";
        accessibilityMode: boolean;
        contactDiscoverable: boolean;
        version: number;
      }
      | undefined;

    if (updatesCompany) {
      const companyName = payload.companyName ?? context.companyName;
      const timezone = payload.timezone ?? context.timezone;
      const updated = await client
        .update(companies)
        .set({
          name: companyName,
          timezone,
          updatedAt: now,
          version: sql`${companies.version} + 1`,
        })
        .where(
          and(
            eq(companies.id, context.companyId),
            payload.baseCompanyVersion != null
              ? eq(companies.version, payload.baseCompanyVersion)
              : undefined,
          ),
        )
        .returning({
          id: companies.id,
          name: companies.name,
          timezone: companies.timezone,
          version: companies.version,
          updatedAt: companies.updatedAt,
        });
      const row = updated[0];
      if (!row) {
        versionConflict("company", context.companyVersion);
      }
      company = {
        id: row.id,
        name: row.name,
        currency: "INR",
        timezone: row.timezone,
        version: Number(row.version),
        updatedAt: String(row.updatedAt),
      };
      changeCursor = await appendSyncChange(client, {
        companyId: context.companyId,
        entityType: "company",
        entityId: context.companyId,
        version: company.version,
        payload: { company },
      });
    }

    if (updatesUser) {
      const language = payload.language === "hi" || payload.language === "en"
        ? payload.language
        : context.language;
      const accessibilityMode = payload.accessibilityMode ??
        context.accessibilityMode;
      const contactDiscoverable = payload.contactDiscoverable ??
        context.contactDiscoverable;
      const updated = await client
        .update(users)
        .set({
          language,
          accessibilityMode,
          contactDiscoverable,
          updatedAt: now,
          version: sql`${users.version} + 1`,
        })
        .where(
          and(
            eq(users.id, context.userId),
            payload.baseUserVersion != null
              ? eq(users.version, payload.baseUserVersion)
              : undefined,
          ),
        )
        .returning({
          language: users.language,
          accessibilityMode: users.accessibilityMode,
          contactDiscoverable: users.contactDiscoverable,
          version: users.version,
        });
      const row = updated[0];
      if (!row) {
        versionConflict("user settings", context.userVersion);
      }
      userSettings = {
        language: row.language === "hi" ? "hi" : "en",
        accessibilityMode: Boolean(row.accessibilityMode),
        contactDiscoverable: Boolean(row.contactDiscoverable),
        version: Number(row.version),
      };
      changeCursor = await appendSyncChange(client, {
        companyId: context.companyId,
        entityType: "user_settings",
        entityId: context.userId,
        version: userSettings.version,
        payload: { userSettings },
      });
    }

    const body = {
      ok: true,
      replayed: false,
      company,
      userSettings,
      changeCursor,
    };
    if (payload.idempotencyKey) {
      await storeOperationReceipt(client, {
        companyId: context.companyId,
        operationId: payload.idempotencyKey,
        operationType,
        requestHash,
        responseBody: body,
        statusCode: 200,
      });
    }
    return body;
  });
  return c.json(result);
}

function versionConflict(entity: string, currentVersion: number) {
  throwApiError(409, `These ${entity} changed on another device.`, {
    code: "VERSION_CONFLICT",
    context: { currentVersion },
  });
}
