import { createMiddleware } from "hono/factory";
import { ZodError, type ZodType } from "zod";
import type { AppEnv } from "../types/hono";

export function json<T extends ZodType>(schema: T) {
  return createMiddleware<AppEnv>(async (c, next) => {
    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      throw new ZodError([
        {
          code: "custom",
          message: "Send a valid JSON request body.",
          path: [],
        },
      ]);
    }
    c.set("json", schema.parse(raw));
    await next();
  });
}

export function query<T extends ZodType>(schema: T) {
  return createMiddleware<AppEnv>(async (c, next) => {
    c.set("query", schema.parse(c.req.query()));
    await next();
  });
}

export function params<T extends ZodType>(schema: T) {
  return createMiddleware<AppEnv>(async (c, next) => {
    c.set("params", schema.parse(c.req.param()));
    await next();
  });
}
