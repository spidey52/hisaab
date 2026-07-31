import { Hono } from "hono";
import { deleteAccount } from "../controllers/account";
import { logout, requestOtp, verifyOtp } from "../controllers/auth";
import { getBootstrap } from "../controllers/bootstrap";
import { discover } from "../controllers/contact-discovery";
import { createEntry, updateEntry } from "../controllers/entries";
import { exportData } from "../controllers/export";
import { createGroup } from "../controllers/groups";
import { check } from "../controllers/health";
import { upsertOpeningBalance } from "../controllers/opening-balance";
import {
  createParty,
  getStatement,
  mergeParties,
  updateParty,
} from "../controllers/parties";
import { updateSettings } from "../controllers/settings";
import { pull } from "../controllers/sync";
import { onError } from "../middlewares/error";
import { json, params, query } from "../middlewares/zod";
import { deleteAccountSchema } from "../schema/account";
import { requestOtpSchema, verifyOtpSchema } from "../schema/auth";
import { idParamSchema } from "../schema/common";
import { contactDiscoverySchema } from "../schema/contact-discovery";
import { createEntrySchema, updateEntrySchema } from "../schema/entries";
import { exportQuerySchema } from "../schema/export";
import { createGroupSchema } from "../schema/groups";
import { openingBalanceSchema } from "../schema/opening-balance";
import {
  createPartySchema,
  mergePartiesSchema,
  statementQuerySchema,
  updatePartySchema,
} from "../schema/parties";
import { settingsSchema } from "../schema/settings";
import { syncPullQuerySchema } from "../schema/sync";
import type { AppEnv } from "../types/hono";

export const apiRoutes = new Hono<AppEnv>();
apiRoutes.onError(onError);

// Health
apiRoutes.get("/health", check);

// Auth
apiRoutes.post("/auth/request-otp", json(requestOtpSchema), requestOtp);
apiRoutes.post("/auth/verify-otp", json(verifyOtpSchema), verifyOtp);
apiRoutes.post("/auth/logout", logout);

// Session
apiRoutes.get("/bootstrap", getBootstrap);
apiRoutes.get("/sync/pull", query(syncPullQuerySchema), pull);

// Account
apiRoutes.delete("/account", json(deleteAccountSchema), deleteAccount);
apiRoutes.patch("/settings", json(settingsSchema), updateSettings);
apiRoutes.get("/export", query(exportQuerySchema), exportData);
apiRoutes.post(
  "/contact-discovery",
  json(contactDiscoverySchema),
  discover,
);

// Parties
apiRoutes.post("/parties", json(createPartySchema), createParty);
apiRoutes.post("/parties/merge", json(mergePartiesSchema), mergeParties);
apiRoutes.patch(
  "/parties/:id",
  params(idParamSchema),
  json(updatePartySchema),
  updateParty,
);
apiRoutes.get(
  "/parties/:id/statement",
  params(idParamSchema),
  query(statementQuerySchema),
  getStatement,
);
apiRoutes.post("/groups", json(createGroupSchema), createGroup);

// Ledger
apiRoutes.post("/entries", json(createEntrySchema), createEntry);
apiRoutes.patch(
  "/entries/:id",
  params(idParamSchema),
  json(updateEntrySchema),
  updateEntry,
);
apiRoutes.post(
  "/opening-balance",
  json(openingBalanceSchema),
  upsertOpeningBalance,
);
