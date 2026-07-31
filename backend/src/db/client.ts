import { drizzle } from "drizzle-orm/node-postgres";
import { sql } from "drizzle-orm";
import { Pool, types } from "pg";
import * as schema from "./schema";

types.setTypeParser(20, (value) => Number(value));
types.setTypeParser(1700, (value) => Number(value));
types.setTypeParser(1082, (value) => value);
types.setTypeParser(1184, (value) => value);

function numberFromEnvironment(
  key: string,
  fallback: number,
  minimum: number,
  maximum: number,
) {
  const value = Number(process.env[key]);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.trunc(value)));
}

function getDatabaseUrl() {
  if (process.env.DATABASE_URL?.trim()) {
    return process.env.DATABASE_URL.trim();
  }
  const host = process.env.PGHOST ?? "127.0.0.1";
  const port = numberFromEnvironment("PGPORT", 5432, 1, 65_535);
  const database = process.env.PGDATABASE ?? "hisaab";
  const user = encodeURIComponent(process.env.PGUSER ?? "hisaab");
  const password = encodeURIComponent(process.env.PGPASSWORD ?? "hisaab");
  return `postgresql://${user}:${password}@${host}:${port}/${database}`;
}

export const pool = new Pool({
  connectionString: getDatabaseUrl(),
  max: numberFromEnvironment("DATABASE_POOL_SIZE", 10, 1, 50),
  idleTimeoutMillis: numberFromEnvironment(
    "DATABASE_IDLE_TIMEOUT_MS",
    30_000,
    1_000,
    600_000,
  ),
  connectionTimeoutMillis: numberFromEnvironment(
    "DATABASE_CONNECT_TIMEOUT_MS",
    5_000,
    500,
    60_000,
  ),
  ssl:
    process.env.DATABASE_SSL === "true"
      ? {
          rejectUnauthorized:
            process.env.DATABASE_SSL_REJECT_UNAUTHORIZED !== "false",
        }
      : undefined,
});

pool.on("error", (error) => {
  console.error("Unexpected PostgreSQL pool error", error);
});

export const db = drizzle(pool, { schema });

export type Db = typeof db;
export type Transaction = Parameters<Parameters<Db["transaction"]>[0]>[0];
export type DbExecutor = Db | Transaction;

export async function withTransaction<T>(
  callback: (tx: Transaction) => Promise<T>,
  options: { statementTimeoutMs?: number } = {},
): Promise<T> {
  return db.transaction(async (tx) => {
    const statementTimeoutMs = Math.min(
      300_000,
      Math.max(1_000, Math.trunc(options.statementTimeoutMs ?? 10_000)),
    );
    await tx.execute(
      sql`SELECT set_config('statement_timeout', ${`${statementTimeoutMs}ms`}, true)`,
    );
    await tx.execute(
      sql`SET LOCAL idle_in_transaction_session_timeout = '10s'`,
    );
    return callback(tx);
  });
}

export async function withReadTransaction<T>(
  callback: (tx: Transaction) => Promise<T>,
): Promise<T> {
  return db.transaction(async (tx) => {
    await tx.execute(
      sql`SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY`,
    );
    await tx.execute(sql`SET LOCAL statement_timeout = '15s'`);
    await tx.execute(
      sql`SET LOCAL idle_in_transaction_session_timeout = '15s'`,
    );
    return callback(tx);
  });
}
