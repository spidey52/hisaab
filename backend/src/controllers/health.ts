import type { Context } from "hono";
import { sql } from "drizzle-orm";
import { db } from "../db";

export async function check(c: Context) {
  await db.execute(sql`SELECT 1`);
  return c.json(
    { status: "ok" },
    { headers: { "cache-control": "no-store" } },
  );
}
