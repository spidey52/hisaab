import { ensureDatabase } from "@/db/ensure";
import { pool } from "@/db";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await ensureDatabase();
    await pool.query("SELECT 1");
    return Response.json(
      { status: "ok" },
      { headers: { "cache-control": "no-store" } },
    );
  } catch (error) {
    console.error("Health check failed", error);
    return Response.json(
      { status: "unavailable" },
      { status: 503, headers: { "cache-control": "no-store" } },
    );
  }
}
