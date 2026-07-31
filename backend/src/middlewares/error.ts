import type { ErrorHandler } from "hono";
import { ZodError } from "zod";
import { PhoneAuthError } from "../services/phone-auth";
import { HttpError } from "../utils/security";

export const onError: ErrorHandler = (error, c) => {
  if (error instanceof Response) return error;

  if (error instanceof ZodError) {
    return c.json(
      { error: error.issues[0]?.message ?? "Invalid request." },
      {
        status: 400,
        headers: { "cache-control": "no-store" },
      },
    );
  }

  if (error instanceof HttpError || error instanceof PhoneAuthError) {
    return c.json(
      { error: error.publicMessage },
      {
        status: error.status as 400,
        headers: {
          "cache-control": "no-store",
          ...(error.retryAfterSeconds != null
            ? { "retry-after": String(error.retryAfterSeconds) }
            : {}),
        },
      },
    );
  }

  const message =
    error instanceof Error ? error.message : "Something went wrong.";
  console.error("Hisaab route error", error);
  return c.json(
    {
      error:
        message.includes("connect") ||
        message.includes("PostgreSQL") ||
        message.includes("database")
          ? "Your account data is temporarily unavailable. Please try again."
          : "We could not complete that action. Please try again.",
    },
    { status: 500, headers: { "cache-control": "no-store" } },
  );
};
