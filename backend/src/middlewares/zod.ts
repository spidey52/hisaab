import { createMiddleware } from "hono/factory";
import type { ZodType } from "zod";
import type { AppEnv } from "../types/hono";

export function json<T extends ZodType>(schema: T) {
  return createMiddleware<AppEnv>(async (c, next) => {
    c.set("json", schema.parse(await c.req.json()));
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
