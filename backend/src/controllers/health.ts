import type { Context } from "hono";
import { sql } from "drizzle-orm";
import { db } from "../db";

export async function check(c: Context) {
  try {
    await db.execute(sql`SELECT 1`);
    return c.json(
      { status: "ok" },
      { headers: { "cache-control": "no-store" } },
    );
  } catch (error) {
    console.error("Health check failed", error);
    return c.json(
      { status: "unavailable" },
      { status: 503, headers: { "cache-control": "no-store" } },
    );
  }
}
