import type { Context } from "hono";
import { and, eq, inArray, isNull, ne, sql } from "drizzle-orm";
import { withTransaction, contactDiscoveryUsage, users } from "../db";
import {
  ContactDiscoveryValidationError,
  MAX_DISCOVERY_PHONES_PER_HOUR,
  MAX_DISCOVERY_REQUESTS_PER_HOUR,
  normalizeDiscoveryPhones,
  selectDiscoverableMatches,
} from "../services/contact-discovery";
import {
  handleRouteError,
  requireServerContext,
} from "../services/server-auth";

export async function discover(c: Context) {
  try {
    const request = c.req.raw;
    const context = await requireServerContext(request);
    const payload = c.get("json") as { phones: string[] };
    let phones: string[];
    try {
      phones = normalizeDiscoveryPhones(payload.phones);
    } catch (error) {
      if (error instanceof ContactDiscoveryValidationError) {
        return c.json({ error: error.message }, { status: 400 });
      }
      throw error;
    }
    if (phones.length === 0) {
      return c.json({ matches: [] });
    }

    const matches = await withTransaction(async (client) => {
      await client.execute(
        sql`SELECT pg_advisory_xact_lock(hashtextextended(${`contact-discovery:${context.userId}`}, 0))`,
      );

      const usage = await client
        .select({
          request_count: sql<number>`coalesce(${contactDiscoveryUsage.requestCount}, 0)::int`.mapWith(
            Number,
          ),
          phone_count: sql<number>`coalesce(${contactDiscoveryUsage.phoneCount}, 0)::int`.mapWith(
            Number,
          ),
          retry_after_seconds: sql<number>`greatest(1, extract(epoch from (date_trunc('hour', current_timestamp) + interval '1 hour' - current_timestamp))::int)`.mapWith(
            Number,
          ),
        })
        .from(contactDiscoveryUsage)
        .where(
          and(
            eq(contactDiscoveryUsage.userId, context.userId),
            eq(
              contactDiscoveryUsage.windowStart,
              sql`date_trunc('hour', CURRENT_TIMESTAMP)`,
            ),
          ),
        );

      const current = usage[0] ?? {
        request_count: 0,
        phone_count: 0,
        retry_after_seconds: 3600,
      };
      if (
        current.request_count >= MAX_DISCOVERY_REQUESTS_PER_HOUR ||
        current.phone_count + phones.length > MAX_DISCOVERY_PHONES_PER_HOUR
      ) {
        throw new Response(
          JSON.stringify({
            error: "Contact discovery is temporarily limited. Try again later.",
            code: "RATE_LIMITED",
          }),
          {
            status: 429,
            headers: {
              "content-type": "application/json",
              "retry-after": String(current.retry_after_seconds),
            },
          },
        );
      }
      await client
        .insert(contactDiscoveryUsage)
        .values({
          userId: context.userId,
          windowStart: sql`date_trunc('hour', CURRENT_TIMESTAMP)`,
          requestCount: 1,
          phoneCount: phones.length,
        })
        .onConflictDoUpdate({
          target: [
            contactDiscoveryUsage.userId,
            contactDiscoveryUsage.windowStart,
          ],
          set: {
            requestCount: sql`${contactDiscoveryUsage.requestCount} + 1`,
            phoneCount: sql`${contactDiscoveryUsage.phoneCount} + excluded.phone_count`,
          },
        });

      const found = await client
        .select({
          phone_e164: users.phoneE164,
          contact_discoverable: users.contactDiscoverable,
        })
        .from(users)
        .where(
          and(
            inArray(users.phoneE164, phones),
            eq(users.contactDiscoverable, true),
            isNull(users.deletedAt),
            ne(users.id, context.userId),
          ),
        );

      return selectDiscoverableMatches(
        phones,
        found.map((row) => ({
          phoneE164: row.phone_e164,
          contactDiscoverable: Boolean(row.contact_discoverable),
        })),
      );
    });

    return c.json(
      { matches },
      { headers: { "cache-control": "private, no-store" } },
    );
  } catch (error) {
    if (error instanceof Response) return error;
    // Auth / validation errors should surface as-is; hide DB details.
    const handled = handleRouteError(error);
    if (handled.status !== 500) return handled;
    console.error("Contact discovery failed.");
    return c.json(
      { error: "Contact discovery is temporarily unavailable." },
      { status: 500 },
    );
  }
}
