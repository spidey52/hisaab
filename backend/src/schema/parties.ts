import { z } from "zod";
import {
  dateOnlySchema,
  operationIdSchema,
  uuidSchema,
  versionSchema,
} from "./common";

function optionalClean(max: number) {
  return z
    .string()
    .optional()
    .transform((value) => (value === undefined ? undefined : value.trim().slice(0, max)));
}

export const createPartySchema = z.object({
  clientId: uuidSchema.optional(),
  idempotencyKey: operationIdSchema.optional(),
  name: z
    .string()
    .transform((value) => value.trim().slice(0, 100))
    .refine(
      (value) => value.length >= 2,
      "Enter a name with at least 2 characters.",
    ),
  phone: optionalClean(40),
  shortName: optionalClean(100),
  notes: optionalClean(500),
  groupId: z
    .union([z.string(), z.null()])
    .optional()
    .transform((value) => {
      if (value === undefined) return undefined;
      if (value === null) return null;
      const cleaned = value.trim().slice(0, 80);
      return cleaned || null;
    }),
  confirmDuplicate: z.boolean().optional(),
});

export const updatePartySchema = z.object({
  name: optionalClean(100),
  phone: optionalClean(40),
  shortName: optionalClean(100),
  notes: optionalClean(500),
  groupId: z
    .union([z.string(), z.null()])
    .optional()
    .transform((value) => {
      if (value === undefined) return undefined;
      if (value === null) return null;
      const cleaned = value.trim().slice(0, 80);
      return cleaned || null;
    }),
  archived: z.boolean().optional(),
  idempotencyKey: operationIdSchema.optional(),
  baseVersion: versionSchema.optional(),
});

export const mergePartiesSchema = z
  .object({
    sourcePartyId: z.string().min(1, "Choose two different people to merge."),
    targetPartyId: z.string().min(1, "Choose two different people to merge."),
    idempotencyKey: operationIdSchema.optional(),
    baseSourceVersion: versionSchema.optional(),
    baseTargetVersion: versionSchema.optional(),
  })
  .refine((value) => value.sourcePartyId !== value.targetPartyId, {
    message: "Choose two different people to merge.",
  });

export const statementQuerySchema = z
  .object({
    from: dateOnlySchema.optional(),
    to: dateOnlySchema.optional(),
    limit: z
      .string()
      .regex(/^\d+$/, "Choose a valid statement page size.")
      .optional()
      .transform((value) => (value === undefined ? 100 : Number(value)))
      .refine(
        (value) => Number.isSafeInteger(value) && value >= 1 && value <= 200,
        "Statement page size must be between 1 and 200.",
      ),
    cursor: z.string().optional(),
  })
  .superRefine((value, ctx) => {
    if (value.from && value.to && value.from > value.to) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Choose a valid statement date range.",
        path: ["from"],
      });
    }
  });

export type UpdatePartyBody = z.infer<typeof updatePartySchema>;
export type StatementQuery = z.infer<typeof statementQuerySchema>;
