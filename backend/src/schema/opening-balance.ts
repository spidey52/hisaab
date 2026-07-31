import { z } from "zod";
import {
  dateOnlySchema,
  nonNegativeAmountPaiseSchema,
  operationIdSchema,
  uuidSchema,
  versionSchema,
} from "./common";

export const openingBalanceSchema = z.object({
  clientId: uuidSchema.optional(),
  partyId: z.string().min(1, "Enter a valid opening balance."),
  amountPaise: nonNegativeAmountPaiseSchema,
  direction: z.enum(["receive", "pay"], {
    errorMap: () => ({ message: "Enter a valid opening balance." }),
  }),
  entryDate: dateOnlySchema,
  idempotencyKey: operationIdSchema.optional(),
  baseVersion: versionSchema.optional(),
});
