import { z } from "zod";

export const deleteAccountSchema = z.object({
  confirmation: z.literal("DELETE MY ACCOUNT", {
    errorMap: () => ({ message: 'Type "DELETE MY ACCOUNT" to confirm.' }),
  }),
});
