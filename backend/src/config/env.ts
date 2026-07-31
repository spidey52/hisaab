import { resolve } from "node:path";
import { createEnv } from "@t3-oss/env-core";
import { config } from "dotenv";
import { z } from "zod";

config({ path: resolve(import.meta.dir, "../../.env"), quiet: true });

const LOCAL_DATABASE_URL = "postgresql://hisaab:hisaab@127.0.0.1:5432/hisaab";
const DEVELOPMENT_SESSION_SECRET =
  "hisaab-development-secret-change-before-production";

const booleanString = z
  .enum(["true", "false"])
  .transform((value) => value === "true");

export const env = createEnv({
  server: {
    NODE_ENV: z.enum(["development", "test", "production"]).default(
      "development",
    ),
    PORT: z.coerce.number().int().min(1).max(65_535).default(3001),
    DATABASE_URL: z.string().url().default(LOCAL_DATABASE_URL),
    DATABASE_POOL_SIZE: z.coerce.number().int().min(1).max(50).default(10),
    DATABASE_IDLE_TIMEOUT_MS: z.coerce
      .number()
      .int()
      .min(1_000)
      .max(600_000)
      .default(30_000),
    DATABASE_CONNECT_TIMEOUT_MS: z.coerce
      .number()
      .int()
      .min(500)
      .max(60_000)
      .default(5_000),
    SESSION_SECRET: z.string().min(32).default(DEVELOPMENT_SESSION_SECRET),
    TRUST_PROXY: booleanString.default("false"),
    OTP_IN_RESPONSE: booleanString.default("false"),
  },
  runtimeEnv: process.env,
  emptyStringAsUndefined: true,
});

if (env.NODE_ENV === "production") {
  if (env.DATABASE_URL === LOCAL_DATABASE_URL) {
    throw new Error("DATABASE_URL must be configured for production.");
  }
  if (env.SESSION_SECRET === DEVELOPMENT_SESSION_SECRET) {
    throw new Error("SESSION_SECRET must be configured for production.");
  }
}
