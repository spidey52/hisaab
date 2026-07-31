import { createHmac } from "node:crypto";
import { env } from "../config/env";

export function clientIpAddress(request: Request) {
  if (env.TRUST_PROXY) {
    const realIp = request.headers.get("x-real-ip");
    if (realIp) return realIp.trim();
    const forwarded = request.headers.get("x-forwarded-for");
    if (forwarded) return forwarded.split(",")[0]?.trim() || "unknown";
  }
  return "direct-client";
}

export function privateHash(value: string) {
  return createHmac("sha256", authenticationSecret())
    .update(value)
    .digest("hex");
}

export function authenticationSecret() {
  return env.SESSION_SECRET;
}

export type ApiErrorOptions = {
  code?: string;
  context?: Record<string, unknown>;
  headers?: Record<string, string>;
};

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly publicMessage: string,
    readonly options: ApiErrorOptions = {},
  ) {
    super(publicMessage);
    this.name = "ApiError";
  }
}

/** Throws a public API error that the root Hono error handler serializes. */
export function throwApiError(
  status: number,
  message: string,
  options?: ApiErrorOptions,
): never {
  throw new ApiError(status, message, options);
}
