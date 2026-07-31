import { createHmac } from "node:crypto";

const DEFAULT_JSON_LIMIT_BYTES = 32 * 1024;

export function assertTrustedMutation(request: Request) {
  const fetchSite = request.headers.get("sec-fetch-site");
  if (fetchSite === "cross-site") {
    throw new Response(JSON.stringify({ error: "Request not allowed." }), {
      status: 403,
      headers: { "content-type": "application/json" },
    });
  }

  const origin = request.headers.get("origin");
  if (!origin) return;

  const expectedOrigins = new Set([new URL(request.url).origin]);
  if (process.env.PUBLIC_BASE_URL) {
    expectedOrigins.add(new URL(process.env.PUBLIC_BASE_URL).origin);
  }
  for (const configuredOrigin of (
    process.env.ADDITIONAL_ALLOWED_ORIGINS ?? ""
  ).split(",")) {
    const value = configuredOrigin.trim();
    if (value) expectedOrigins.add(new URL(value).origin);
  }
  if (!expectedOrigins.has(origin)) {
    throw new Response(JSON.stringify({ error: "Request not allowed." }), {
      status: 403,
      headers: { "content-type": "application/json" },
    });
  }
}

export async function readJsonBody<T>(
  request: Request,
  maximumBytes = DEFAULT_JSON_LIMIT_BYTES,
): Promise<T> {
  const contentType = request.headers
    .get("content-type")
    ?.split(";", 1)[0]
    ?.trim()
    .toLowerCase();
  if (contentType !== "application/json") {
    throw jsonError("Send this request as JSON.", 415);
  }

  const declaredLength = Number(request.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw jsonError("That request is too large.", 413);
  }
  if (!request.body) {
    throw jsonError("A JSON request body is required.", 400);
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maximumBytes) {
      await reader.cancel();
      throw jsonError("That request is too large.", 413);
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    return JSON.parse(new TextDecoder().decode(bytes)) as T;
  } catch {
    throw jsonError("Send a valid JSON request body.", 400);
  }
}

export function clientIpAddress(request: Request) {
  if (process.env.TRUST_PROXY === "true") {
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
  const secret = process.env.SESSION_SECRET;
  if (secret && secret.length >= 32) return secret;
  if (process.env.NODE_ENV !== "production") {
    return "hisaab-development-secret-change-before-production";
  }
  throw new Error("SESSION_SECRET must contain at least 32 characters.");
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json",
    },
  });
}
