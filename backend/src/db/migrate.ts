import { config } from "dotenv";
import { migrate } from "drizzle-orm/node-postgres/migrator";
import { resolve } from "node:path";

config({ path: resolve(import.meta.dir, "../../.env") });

const { db, pool } = await import("./client");
const migrationsFolder = resolve(import.meta.dir, "../../drizzle");

try {
  await migrate(db, { migrationsFolder });
  console.log("Hisaab PostgreSQL schema is ready (drizzle migrations).");
} finally {
  await pool.end();
}
