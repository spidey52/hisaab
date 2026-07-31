import { z } from "zod";

export const exportQuerySchema = z.object({
  format: z.enum(["json", "csv"]).optional().default("json"),
});
