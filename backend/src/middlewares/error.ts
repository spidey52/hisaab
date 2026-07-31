import type { ErrorHandler } from "hono";
import { ZodError } from "zod";
import { ApiError } from "../utils/security";

export const onError: ErrorHandler = (error, c) => {
  if (error instanceof ApiError) {
    return c.json(
      {
        error: error.publicMessage,
        ...(error.options.code ? { code: error.options.code } : {}),
        ...error.options.context,
      },
      {
        status: error.status as 400,
        headers: {
          "cache-control": "no-store",
          ...error.options.headers,
        },
      },
    );
  }

  if (error instanceof ZodError) {
    return c.json(
      { error: error.issues[0]?.message ?? "Invalid request." },
      {
        status: 400,
        headers: { "cache-control": "no-store" },
      },
    );
  }

  if (error instanceof SyntaxError) {
    return c.json(
      { error: "Send a valid JSON request body." },
      { status: 400, headers: { "cache-control": "no-store" } },
    );
  }

  if (c.req.path === "/api/health") {
    console.error("Health check failed", error);
    return c.json(
      { status: "unavailable" },
      { status: 503, headers: { "cache-control": "no-store" } },
    );
  }

  const message = error instanceof Error
    ? error.message
    : "Something went wrong.";
  console.error("Hisaab route error", error);
  return c.json(
    {
      error: message.includes("connect") ||
          message.includes("PostgreSQL") ||
          message.includes("database")
        ? "Your account data is temporarily unavailable. Please try again."
        : "We could not complete that action. Please try again.",
    },
    { status: 500, headers: { "cache-control": "no-store" } },
  );
};
