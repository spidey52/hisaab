import { z } from "zod";
import { isValidDateOnly } from "../utils/date-utils";

export const uuidSchema = z
  .string()
  .regex(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    "Invalid client identifier.",
  );

export const operationIdSchema = z
  .string()
  .min(12)
  .max(100)
  .regex(/^[A-Za-z0-9._:-]+$/, "Invalid operation identifier.");

export const versionSchema = z
  .number()
  .int()
  .safe()
  .min(1, "This version is invalid.");

export const dateOnlySchema = z
  .string()
  .refine(isValidDateOnly, "Choose a valid date.");

export const amountPaiseSchema = z
  .number()
  .int()
  .safe()
  .min(1, "Enter a valid amount.")
  .max(99_99_99_99_900, "Enter a valid amount.");

export const nonNegativeAmountPaiseSchema = z
  .number()
  .int()
  .safe()
  .min(0, "Enter a valid amount.")
  .max(99_99_99_99_900, "Enter a valid amount.");

export const paymentAccountSchema = z
  .enum(["cash", "bank"])
  .nullable()
  .optional();

export const idParamSchema = z.object({
  id: z.string().min(1, "Missing identifier."),
});
