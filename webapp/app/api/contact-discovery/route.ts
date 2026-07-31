import { withTransaction } from "@/db";
import {
  ContactDiscoveryValidationError,
  MAX_DISCOVERY_PHONES_PER_HOUR,
  MAX_DISCOVERY_REQUESTS_PER_HOUR,
  normalizeDiscoveryPhones,
  selectDiscoverableMatches,
} from "@/lib/contact-discovery";
import { readJsonBody } from "@/lib/request-security";
import { requireMutationContext } from "@/lib/server-auth";

export async function POST(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<{ phones?: unknown }>(request, 64 * 1024);
    let phones: string[];
    try {
      phones = normalizeDiscoveryPhones(payload.phones);
    } catch (error) {
      if (error instanceof ContactDiscoveryValidationError) {
        return Response.json({ error: error.message }, { status: 400 });
      }
      throw error;
    }
    if (phones.length === 0) {
      return Response.json({ matches: [] });
    }

    const matches = await withTransaction(async (client) => {
      await client.query(
        "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
        [`contact-discovery:${context.userId}`],
      );
      const usage = await client.query<{
        request_count: number;
        phone_count: number;
        retry_after_seconds: number;
      }>(
        `SELECT
           COALESCE(request_count, 0)::int AS request_count,
           COALESCE(phone_count, 0)::int AS phone_count,
           GREATEST(
             1,
             EXTRACT(EPOCH FROM (
               date_trunc('hour', CURRENT_TIMESTAMP) + INTERVAL '1 hour'
               - CURRENT_TIMESTAMP
             ))::int
           ) AS retry_after_seconds
         FROM contact_discovery_usage
         WHERE user_id = $1
           AND window_start = date_trunc('hour', CURRENT_TIMESTAMP)`,
        [context.userId],
      );
      const current = usage.rows[0] ?? {
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
      await client.query(
        `INSERT INTO contact_discovery_usage (
           user_id, window_start, request_count, phone_count
         ) VALUES (
           $1, date_trunc('hour', CURRENT_TIMESTAMP), 1, $2
         )
         ON CONFLICT (user_id, window_start)
         DO UPDATE SET
           request_count = contact_discovery_usage.request_count + 1,
           phone_count = contact_discovery_usage.phone_count + EXCLUDED.phone_count`,
        [context.userId, phones.length],
      );
      const found = await client.query<{
        phone_e164: string;
        contact_discoverable: boolean;
      }>(
        `SELECT phone_e164, contact_discoverable
         FROM users
         WHERE phone_e164 = ANY($1::text[])
           AND contact_discoverable = TRUE
           AND deleted_at IS NULL
           AND id <> $2`,
        [phones, context.userId],
      );
      return selectDiscoverableMatches(
        phones,
        found.rows.map((row) => ({
          phoneE164: row.phone_e164,
          contactDiscoverable: Boolean(row.contact_discoverable),
        })),
      );
    });

    return Response.json(
      { matches },
      { headers: { "cache-control": "private, no-store" } },
    );
  } catch (error) {
    if (error instanceof Response) return error;
    // Never log request values or database error details on this endpoint:
    // either could expose a submitted address-book number.
    console.error("Contact discovery failed.");
    return Response.json(
      { error: "Contact discovery is temporarily unavailable." },
      { status: 500 },
    );
  }
}
