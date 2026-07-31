import { Pool, types, type PoolClient, type QueryResultRow } from "pg";

types.setTypeParser(20, (value) => Number(value));
types.setTypeParser(1700, (value) => Number(value));
types.setTypeParser(1082, (value) => value);
types.setTypeParser(1184, (value) => value);

const databaseConnection = process.env.DATABASE_URL
  ? { connectionString: process.env.DATABASE_URL }
  : {
      host: process.env.PGHOST ?? "127.0.0.1",
      port: numberFromEnvironment("PGPORT", 5432, 1, 65_535),
      database: process.env.PGDATABASE ?? "hisaab",
      user: process.env.PGUSER ?? "hisaab",
      password: process.env.PGPASSWORD ?? "hisaab",
    };

const globalDatabase = globalThis as typeof globalThis & {
  hisaabPostgresPool?: Pool;
};

export const pool =
  globalDatabase.hisaabPostgresPool ??
  new Pool({
    ...databaseConnection,
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
        ? { rejectUnauthorized: process.env.DATABASE_SSL_REJECT_UNAUTHORIZED !== "false" }
        : undefined,
  });

if (process.env.NODE_ENV !== "production") {
  globalDatabase.hisaabPostgresPool = pool;
}

pool.on("error", (error) => {
  console.error("Unexpected PostgreSQL pool error", error);
});

type Queryable = Pick<Pool, "query"> | Pick<PoolClient, "query">;

class PreparedQuery {
  readonly text: string;
  private values: unknown[] = [];

  constructor(text: string) {
    this.text = toPostgresPlaceholders(text);
  }

  bind(...values: unknown[]) {
    this.values = values;
    return this;
  }

  first<T extends QueryResultRow = QueryResultRow>(): Promise<T | null>;
  first<
    T extends QueryResultRow = QueryResultRow,
    K extends keyof T = keyof T,
  >(column: K): Promise<T[K] | null>;
  async first<T extends QueryResultRow = QueryResultRow>(
    column?: keyof T,
  ): Promise<T | T[keyof T] | null> {
    const result = await this.execute<T>(pool);
    const first = result.rows[0] ?? null;
    if (first === null || !column) return first;
    return first[column] ?? null;
  }

  async all<T extends QueryResultRow = QueryResultRow>() {
    const result = await this.execute<T>(pool);
    return { results: result.rows };
  }

  async run() {
    const result = await this.execute(pool);
    return {
      success: true,
      results: result.rows,
      meta: { changes: result.rowCount ?? 0 },
    };
  }

  execute<T extends QueryResultRow = QueryResultRow>(client: Queryable) {
    return client.query<T>(this.text, this.values);
  }
}

class PostgresCompatibilityDatabase {
  prepare(text: string) {
    return new PreparedQuery(text);
  }

  async batch(statements: PreparedQuery[]) {
    return withTransaction(async (client) => {
      const results = [];
      for (const statement of statements) {
        const result = await statement.execute(client);
        results.push({
          success: true,
          results: result.rows,
          meta: { changes: result.rowCount ?? 0 },
        });
      }
      return results;
    });
  }
}

const database = new PostgresCompatibilityDatabase();

export function getRawDb() {
  return database;
}

export function getDb() {
  return database;
}

export async function withTransaction<T>(
  callback: (client: PoolClient) => Promise<T>,
  options: { statementTimeoutMs?: number } = {},
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const statementTimeoutMs = Math.min(
      300_000,
      Math.max(1_000, Math.trunc(options.statementTimeoutMs ?? 10_000)),
    );
    await client.query("SELECT set_config('statement_timeout', $1, true)", [
      `${statementTimeoutMs}ms`,
    ]);
    await client.query("SET LOCAL idle_in_transaction_session_timeout = '10s'");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function withReadTransaction<T>(
  callback: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query(
      "BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY",
    );
    await client.query("SET LOCAL statement_timeout = '15s'");
    await client.query("SET LOCAL idle_in_transaction_session_timeout = '15s'");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

function toPostgresPlaceholders(sql: string) {
  let result = "";
  let parameter = 0;
  let quote: "'" | '"' | null = null;

  for (let index = 0; index < sql.length; index += 1) {
    const character = sql[index];
    const next = sql[index + 1];

    if (quote) {
      result += character;
      if (character === quote) {
        if (next === quote) {
          result += next;
          index += 1;
        } else {
          quote = null;
        }
      }
      continue;
    }

    if (character === "'" || character === '"') {
      quote = character;
      result += character;
      continue;
    }

    if (character === "?") {
      parameter += 1;
      result += `$${parameter}`;
      continue;
    }

    result += character;
  }

  return result;
}

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
