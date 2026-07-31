import { z } from "zod";

export const contactDiscoverySchema = z.object({
  phones: z.array(z.string().max(64)).max(500).optional().default([]),
});
