import { z } from "zod";
import {
  amountPaiseSchema,
  dateOnlySchema,
  operationIdSchema,
  paymentAccountSchema,
  uuidSchema,
  versionSchema,
} from "./common";

export const createEntrySchema = z.object({
  clientId: uuidSchema.optional(),
  partyId: z.string().trim().min(1, "Choose a customer or supplier."),
  action: z.enum(["gave", "received"], {
    errorMap: () => ({ message: "Choose whether you gave or got money." }),
  }),
  amountPaise: amountPaiseSchema,
  narration: z.string().optional(),
  entryDate: dateOnlySchema,
  paymentAccount: paymentAccountSchema,
  idempotencyKey: operationIdSchema,
});

const entryEditFields = {
  partyId: z.string().trim().min(1, "Choose a customer or supplier."),
  action: z.enum(["gave", "received"], {
    errorMap: () => ({ message: "Choose a valid action." }),
  }),
  amountPaise: amountPaiseSchema,
  narration: z.string().optional(),
  entryDate: dateOnlySchema,
  paymentAccount: paymentAccountSchema,
};

export const updateEntrySchema = z.discriminatedUnion("operation", [
  z.object({
    operation: z.literal("cancel"),
    idempotencyKey: operationIdSchema.optional(),
    baseVersion: versionSchema.optional(),
  }),
  z.object({
    operation: z.literal("edit"),
    idempotencyKey: operationIdSchema.optional(),
    baseVersion: versionSchema.optional(),
    ...entryEditFields,
  }),
]);

export type UpdateEntryBody = z.infer<typeof updateEntrySchema>;
