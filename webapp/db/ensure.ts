import { getRawDb } from ".";
import { runNumberedMigrations } from "./migrations";
import {
  postMigrationSchemaStatements,
  schemaStatements,
} from "./schema-statements";

let schemaPromise: Promise<void> | null = null;

export function ensureDatabase(): Promise<void> {
  if (schemaPromise) return schemaPromise;

  const database = getRawDb();
  schemaPromise = database
    .batch(schemaStatements.map((statement) => database.prepare(statement)))
    .then(runNumberedMigrations)
    .then(() =>
      database.batch(
        postMigrationSchemaStatements.map((statement) =>
          database.prepare(statement),
        ),
      ),
    )
    .then(() => undefined)
    .catch((error) => {
      schemaPromise = null;
      throw error;
    });

  return schemaPromise;
}
