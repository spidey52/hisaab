import { z } from "zod";
import { operationIdSchema, versionSchema } from "./common";

const timezoneSchema = z.enum([
  "Asia/Kolkata",
  "Asia/Kathmandu",
  "Asia/Dubai",
  "UTC",
]);

export const settingsSchema = z
  .object({
    companyName: z
      .string()
      .transform((value) => value.trim().slice(0, 100))
      .optional(),
    timezone: timezoneSchema.optional(),
    language: z.enum(["en", "hi"]).optional(),
    accessibilityMode: z.boolean().optional(),
    contactDiscoverable: z.boolean().optional(),
    idempotencyKey: operationIdSchema.optional(),
    baseCompanyVersion: versionSchema.optional(),
    baseUserVersion: versionSchema.optional(),
  })
  .superRefine((value, ctx) => {
    const updatesCompany =
      value.companyName !== undefined || value.timezone !== undefined;
    const updatesUser =
      value.language !== undefined ||
      value.accessibilityMode !== undefined ||
      value.contactDiscoverable !== undefined;
    if (!updatesCompany && !updatesUser) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Nothing to update.",
      });
    }
  });
