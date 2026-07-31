import { z } from "zod";
import { operationIdSchema, uuidSchema } from "./common";

export const createGroupSchema = z.object({
  name: z
    .string()
    .transform((value) => value.trim().slice(0, 60))
    .refine((value) => value.length >= 2, "Enter a group name."),
  clientId: uuidSchema.optional(),
  idempotencyKey: operationIdSchema.optional(),
});
