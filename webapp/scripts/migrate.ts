import { ensureDatabase } from "../db/ensure";
import { pool } from "../db";

try {
  await ensureDatabase();
  console.log("Hisaab PostgreSQL schema is ready.");
} finally {
  await pool.end();
}
