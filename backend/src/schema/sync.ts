import { z } from "zod";

const DEFAULT_LIMIT = 200;
const MAX_LIMIT = 500;

export const syncPullQuerySchema = z.object({
  cursor: z
    .string()
    .regex(/^\d{1,19}$/, "This sync cursor is invalid.")
    .optional()
    .default("0")
    .transform((value) => value.replace(/^0+(?=\d)/, ""))
    .superRefine((value, ctx) => {
      try {
        const parsed = BigInt(value);
        if (parsed < 0n || parsed > 9_223_372_036_854_775_807n) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "This sync cursor is invalid.",
          });
        }
      } catch {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "This sync cursor is invalid.",
        });
      }
    }),
  limit: z
    .string()
    .regex(/^\d+$/, "Choose a valid sync page size.")
    .optional()
    .transform((value) => (value === undefined ? DEFAULT_LIMIT : Number(value)))
    .refine(
      (value) =>
        Number.isSafeInteger(value) && value >= 1 && value <= MAX_LIMIT,
      `Sync page size must be between 1 and ${MAX_LIMIT}.`,
    ),
});
