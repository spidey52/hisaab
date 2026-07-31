import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { z } from "zod";
import { throwApiError } from "../utils/security";
import { onError } from "./error";
import { json } from "./zod";

function testApp() {
  const app = new Hono();
  const routes = new Hono();
  app.onError(onError);
  routes.post(
    "/validated",
    json(z.object({ name: z.string().min(2) })),
    (c) => c.json({ ok: true }),
  );
  routes.get("/unauthorized", () => {
    throwApiError(401, "Sign in first.");
  });
  routes.get("/conflict", () => {
    throwApiError(409, "Already changed.", {
      code: "VERSION_CONFLICT",
      context: { currentVersion: 3 },
      headers: { "retry-after": "5" },
    });
  });
  app.route("/api", routes);
  return app;
}

describe("root error handler", () => {
  test("formats Zod validation errors", async () => {
    const response = await testApp().request("/api/validated", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: "x" }),
    });

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({
      error: "String must contain at least 2 character(s)",
    });
  });

  test("formats malformed JSON errors", async () => {
    const response = await testApp().request("/api/validated", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{",
    });

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({
      error: "Send a valid JSON request body.",
    });
  });

  test("formats application HTTP errors", async () => {
    const response = await testApp().request("/api/unauthorized");

    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "Sign in first." });
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  test("passes expected response errors through nested routes", async () => {
    const response = await testApp().request("/api/conflict");

    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({
      error: "Already changed.",
      code: "VERSION_CONFLICT",
      currentVersion: 3,
    });
    expect(response.headers.get("retry-after")).toBe("5");
  });
});
