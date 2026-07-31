import { withTransaction } from "@/db";
import { readJsonBody } from "@/lib/request-security";
import {
  handleRouteError,
  requireMutationContext,
} from "@/lib/server-auth";
import {
  appendSyncChange,
  isValidOperationId,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "@/lib/sync-server";

type SettingsPayload = {
  companyName?: string;
  timezone?: string;
  language?: "en" | "hi";
  accessibilityMode?: boolean;
  contactDiscoverable?: boolean;
  idempotencyKey?: string;
  baseCompanyVersion?: number;
  baseUserVersion?: number;
};

const operationType = "settings.update";

export async function PATCH(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<SettingsPayload>(request);
    if (
      payload.idempotencyKey !== undefined &&
      !isValidOperationId(payload.idempotencyKey)
    ) {
      return Response.json(
        { error: "This settings change has an invalid operation identifier." },
        { status: 400 },
      );
    }
    for (const version of [
      payload.baseCompanyVersion,
      payload.baseUserVersion,
    ]) {
      if (
        version !== undefined &&
        (!Number.isSafeInteger(version) || version < 1)
      ) {
        return Response.json(
          { error: "This settings version is invalid." },
          { status: 400 },
        );
      }
    }
    if (
      payload.contactDiscoverable !== undefined &&
      typeof payload.contactDiscoverable !== "boolean"
    ) {
      return Response.json(
        { error: "Choose a valid contact discovery setting." },
        { status: 400 },
      );
    }
    if (
      payload.accessibilityMode !== undefined &&
      typeof payload.accessibilityMode !== "boolean"
    ) {
      return Response.json(
        { error: "Choose a valid accessibility setting." },
        { status: 400 },
      );
    }
    const updatesCompany =
      payload.companyName !== undefined || payload.timezone !== undefined;
    const updatesUser =
      payload.language !== undefined ||
      payload.accessibilityMode !== undefined ||
      payload.contactDiscoverable !== undefined;
    if (!updatesCompany && !updatesUser) {
      return Response.json({ error: "Nothing to update." }, { status: 400 });
    }
    const intent = {
      companyName:
        payload.companyName === undefined
          ? undefined
          : payload.companyName.trim().slice(0, 100),
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

      const now = new Date().toISOString();
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
        const companyName =
          payload.companyName?.trim().slice(0, 100) || context.companyName;
        const timezone = isSupportedTimezone(payload.timezone)
          ? payload.timezone!
          : context.timezone;
        const updated = await client.query<{
          id: string;
          name: string;
          timezone: string;
          version: number;
          updated_at: string;
        }>(
          `UPDATE companies
           SET name = $1, timezone = $2, updated_at = $3,
               version = version + 1
           WHERE id = $4
             AND ($5::bigint IS NULL OR version = $5::bigint)
           RETURNING id, name, timezone, version, updated_at`,
          [
            companyName,
            timezone,
            now,
            context.companyId,
            payload.baseCompanyVersion ?? null,
          ],
        );
        const row = updated.rows[0];
        if (!row) {
          throw versionConflict("company", context.companyVersion);
        }
        company = {
          id: row.id,
          name: row.name,
          currency: "INR",
          timezone: row.timezone,
          version: Number(row.version),
          updatedAt: String(row.updated_at),
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
        const language =
          payload.language === "hi" || payload.language === "en"
            ? payload.language
            : context.language;
        const accessibilityMode =
          payload.accessibilityMode ?? context.accessibilityMode;
        const contactDiscoverable =
          payload.contactDiscoverable ?? context.contactDiscoverable;
        const updated = await client.query<{
          language: "en" | "hi";
          accessibility_mode: boolean;
          contact_discoverable: boolean;
          version: number;
        }>(
          `UPDATE users
           SET language = $1, accessibility_mode = $2,
               contact_discoverable = $3, updated_at = $4,
               version = version + 1
           WHERE id = $5
             AND ($6::bigint IS NULL OR version = $6::bigint)
           RETURNING language, accessibility_mode, contact_discoverable, version`,
          [
            language,
            accessibilityMode,
            contactDiscoverable,
            now,
            context.userId,
            payload.baseUserVersion ?? null,
          ],
        );
        const row = updated.rows[0];
        if (!row) {
          throw versionConflict("user settings", context.userVersion);
        }
        userSettings = {
          language: row.language === "hi" ? "hi" : "en",
          accessibilityMode: Boolean(row.accessibility_mode),
          contactDiscoverable: Boolean(row.contact_discoverable),
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
    return Response.json(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

function isSupportedTimezone(value: unknown) {
  return (
    typeof value === "string" &&
    ["Asia/Kolkata", "Asia/Kathmandu", "Asia/Dubai", "UTC"].includes(value)
  );
}

function versionConflict(entity: string, currentVersion: number) {
  return new Response(
    JSON.stringify({
      error: `These ${entity} changed on another device.`,
      code: "VERSION_CONFLICT",
      currentVersion,
    }),
    { status: 409, headers: { "content-type": "application/json" } },
  );
}
