import { drizzle } from "drizzle-orm/node-postgres";
import { sql } from "drizzle-orm";
import { Pool, types } from "pg";
import { env } from "../config/env";
import * as schema from "./schema";

types.setTypeParser(20, (value) => Number(value));
types.setTypeParser(1700, (value) => Number(value));
types.setTypeParser(1082, (value) => value);
types.setTypeParser(1184, (value) => value);

export const pool = new Pool({
  connectionString: env.DATABASE_URL,
  max: env.DATABASE_POOL_SIZE,
  idleTimeoutMillis: env.DATABASE_IDLE_TIMEOUT_MS,
  connectionTimeoutMillis: env.DATABASE_CONNECT_TIMEOUT_MS,
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
