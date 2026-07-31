import type { Context } from "hono";
import type { ZodType, ZodTypeDef } from "zod";
import { readJsonBody } from "./request-body";
import { HttpError } from "./security";

export function parseSchema<T>(
  schema: ZodType<T, ZodTypeDef, unknown>,
  data: unknown,
  fallbackMessage = "Invalid request.",
): T {
  const parsed = schema.safeParse(data);
  if (!parsed.success) {
    throw new HttpError(
      parsed.error.issues[0]?.message ?? fallbackMessage,
      400,
    );
  }
  return parsed.data;
}

export async function parseJsonBody<T>(
  request: Request,
  schema: ZodType<T, ZodTypeDef, unknown>,
  maximumBytes?: number,
  fallbackMessage?: string,
): Promise<T> {
  const raw = await readJsonBody<unknown>(request, maximumBytes);
  return parseSchema(schema, raw, fallbackMessage);
}

export function parseQuery<T>(
  c: Context,
  schema: ZodType<T, ZodTypeDef, unknown>,
  fallbackMessage = "Invalid query.",
): T {
  return parseSchema(schema, c.req.query(), fallbackMessage);
}

export function parseParams<T>(
  c: Context,
  schema: ZodType<T, ZodTypeDef, unknown>,
  fallbackMessage = "Invalid path.",
): T {
  return parseSchema(schema, c.req.param(), fallbackMessage);
}
