import { sql } from "drizzle-orm";
import {
  bigint,
  bigserial,
  boolean,
  check,
  date,
  index,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
} from "drizzle-orm/pg-core";

const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
};

export const users = pgTable(
  "users",
  {
    id: text("id").primaryKey(),
    phoneE164: text("phone_e164").notNull(),
    phoneVerifiedAt: timestamp("phone_verified_at", {
      withTimezone: true,
    }).notNull(),
    fullName: text("full_name"),
    language: text("language").notNull().default("en"),
    accessibilityMode: boolean("accessibility_mode").notNull().default(false),
    contactDiscoverable: boolean("contact_discoverable")
      .notNull()
      .default(false),
    version: bigint("version", { mode: "number" }).notNull().default(1),
    ...timestamps,
    deletedAt: timestamp("deleted_at", { withTimezone: true }),
  },
  (table) => [
    uniqueIndex("users_phone_e164_uq").on(table.phoneE164),
    check("users_language_check", sql`${table.language} in ('en', 'hi')`),
  ],
);

export const companies = pgTable(
  "companies",
  {
    id: text("id").primaryKey(),
    name: text("name").notNull(),
    currency: text("currency").notNull().default("INR"),
    timezone: text("timezone").notNull().default("Asia/Kolkata"),
    nextEntryNumber: bigint("next_entry_number", { mode: "number" })
      .notNull()
      .default(1),
    version: bigint("version", { mode: "number" }).notNull().default(1),
    ...timestamps,
  },
  (table) => [
    check("companies_currency_check", sql`${table.currency} = 'INR'`),
    check(
      "companies_next_entry_number_check",
      sql`${table.nextEntryNumber} > 0`,
    ),
  ],
);

export const memberships = pgTable(
  "memberships",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    companyId: text("company_id")
      .notNull()
      .references(() => companies.id, { onDelete: "cascade" }),
    role: text("role").notNull().default("owner"),
    tutorialCompleted: boolean("tutorial_completed").notNull().default(false),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    version: bigint("version", { mode: "number" }).notNull().default(1),
  },
  (table) => [
    uniqueIndex("memberships_user_company_uq").on(
      table.userId,
      table.companyId,
    ),
    index("memberships_company_idx").on(table.companyId),
    index("memberships_user_idx").on(table.userId),
    check("memberships_role_check", sql`${table.role} in ('owner', 'member')`),
  ],
);

export const partyGroups = pgTable(
  "party_groups",
  {
    id: text("id").primaryKey(),
    companyId: text("company_id")
      .notNull()
      .references(() => companies.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    version: bigint("version", { mode: "number" }).notNull().default(1),
  },
  (table) => [
    uniqueIndex("party_groups_company_name_uq").on(
      table.companyId,
      table.name,
    ),
  ],
);

export const parties = pgTable(
  "parties",
  {
    id: text("id").primaryKey(),
    companyId: text("company_id")
      .notNull()
      .references(() => companies.id, { onDelete: "cascade" }),
    reference: text("reference").notNull(),
    name: text("name").notNull(),
    shortName: text("short_name").notNull().default(""),
    phone: text("phone").notNull().default(""),
    phoneE164: text("phone_e164"),
    notes: text("notes").notNull().default(""),
    groupId: text("group_id").references(() => partyGroups.id, {
      onDelete: "set null",
    }),
    createdBy: text("created_by")
      .notNull()
      .references(() => users.id),
    updatedBy: text("updated_by").references(() => users.id),
    ...timestamps,
    archivedAt: timestamp("archived_at", { withTimezone: true }),
    mergedIntoId: text("merged_into_id"),
    version: bigint("version", { mode: "number" }).notNull().default(1),
  },
  (table) => [
    uniqueIndex("parties_company_reference_uq").on(
      table.companyId,
      table.reference,
    ),
    index("parties_company_name_idx").on(table.companyId, table.name),
    index("parties_company_phone_idx").on(table.companyId, table.phone),
    index("parties_company_phone_e164_idx")
      .on(table.companyId, table.phoneE164)
      .where(sql`${table.phoneE164} is not null`),
    index("parties_group_idx").on(table.groupId),
  ],
);

export const entries = pgTable(
  "entries",
  {
    id: text("id").primaryKey(),
    companyId: text("company_id")
      .notNull()
      .references(() => companies.id, { onDelete: "cascade" }),
    partyId: text("party_id")
      .notNull()
      .references(() => parties.id),
    sequence: bigint("sequence", { mode: "number" }).notNull(),
    action: text("action").notNull(),
    amountPaise: bigint("amount_paise", { mode: "number" }).notNull(),
    balanceEffectPaise: bigint("balance_effect_paise", {
      mode: "number",
    }).notNull(),
    narration: text("narration").notNull(),
    entryDate: date("entry_date").notNull(),
    paymentAccount: text("payment_account"),
    status: text("status").notNull().default("posted"),
    idempotencyKey: text("idempotency_key").notNull(),
    createdBy: text("created_by")
      .notNull()
      .references(() => users.id),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    version: bigint("version", { mode: "number" }).notNull().default(1),
    editedBy: text("edited_by").references(() => users.id),
    editedAt: timestamp("edited_at", { withTimezone: true }),
    cancelledBy: text("cancelled_by").references(() => users.id),
    cancelledAt: timestamp("cancelled_at", { withTimezone: true }),
  },
  (table) => [
    uniqueIndex("entries_company_sequence_uq").on(
      table.companyId,
      table.sequence,
    ),
    uniqueIndex("entries_company_idempotency_uq").on(
      table.companyId,
      table.idempotencyKey,
    ),
    index("entries_company_party_date_idx").on(
      table.companyId,
      table.partyId,
      table.entryDate,
      table.sequence,
    ),
    index("entries_company_created_idx").on(
      table.companyId,
      table.createdAt,
    ),
    index("entries_party_idx").on(table.partyId),
    uniqueIndex("entries_one_active_opening_balance_uq")
      .on(table.companyId, table.partyId)
      .where(
        sql`${table.action} = 'opening_balance' and ${table.status} = 'posted'`,
      ),
    check(
      "entries_action_check",
      sql`${table.action} in ('gave', 'received', 'opening_balance')`,
    ),
    check(
      "entries_status_check",
      sql`${table.status} in ('posted', 'cancelled')`,
    ),
    check(
      "entries_payment_account_check",
      sql`${table.paymentAccount} is null or ${table.paymentAccount} in ('cash', 'bank')`,
    ),
  ],
);

export const entryRevisions = pgTable(
  "entry_revisions",
  {
    id: text("id").primaryKey(),
    entryId: text("entry_id")
      .notNull()
      .references(() => entries.id, { onDelete: "cascade" }),
    previousValues: jsonb("previous_values").notNull(),
    changedBy: text("changed_by")
      .notNull()
      .references(() => users.id),
    changedAt: timestamp("changed_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [index("entry_revisions_entry_idx").on(table.entryId)],
);

export const auditEvents = pgTable(
  "audit_events",
  {
    id: text("id").primaryKey(),
    companyId: text("company_id")
      .notNull()
      .references(() => companies.id, { onDelete: "cascade" }),
    actorUserId: text("actor_user_id")
      .notNull()
      .references(() => users.id),
    entityType: text("entity_type").notNull(),
    entityId: text("entity_id").notNull(),
    action: text("action").notNull(),
    details: jsonb("details").notNull().default({}),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    index("audit_company_created_idx").on(
      table.companyId,
      table.createdAt,
    ),
    index("audit_entity_idx").on(table.entityType, table.entityId),
  ],
);

export const userSessions = pgTable(
  "user_sessions",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    tokenHash: text("token_hash").notNull(),
    userAgent: text("user_agent").notNull().default(""),
    ipHash: text("ip_hash").notNull().default(""),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
  },
  (table) => [
    uniqueIndex("user_sessions_token_hash_uq").on(table.tokenHash),
    index("sessions_user_active_idx")
      .on(table.userId, table.expiresAt)
      .where(sql`${table.revokedAt} is null`),
    index("sessions_expiry_idx")
      .on(table.expiresAt)
      .where(sql`${table.revokedAt} is null`),
  ],
);

export const otpChallenges = pgTable(
  "otp_challenges",
  {
    id: text("id").primaryKey(),
    phoneE164: text("phone_e164").notNull(),
    provider: text("provider").notNull(),
    providerReference: text("provider_reference"),
    codeHash: text("code_hash"),
    requestedIpHash: text("requested_ip_hash").notNull(),
    attempts: integer("attempts").notNull().default(0),
    maxAttempts: integer("max_attempts").notNull().default(5),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    consumedAt: timestamp("consumed_at", { withTimezone: true }),
  },
  (table) => [
    index("otp_phone_recent_idx").on(table.phoneE164, table.createdAt),
    index("otp_ip_recent_idx").on(table.requestedIpHash, table.createdAt),
  ],
);

export const authEvents = pgTable(
  "auth_events",
  {
    id: text("id").primaryKey(),
    phoneHash: text("phone_hash").notNull(),
    ipHash: text("ip_hash").notNull(),
    eventType: text("event_type").notNull(),
    metadata: jsonb("metadata").notNull().default({}),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    index("auth_events_created_idx").on(table.createdAt),
    index("auth_events_phone_idx").on(table.phoneHash, table.createdAt),
  ],
);

export const operationReceipts = pgTable(
  "operation_receipts",
  {
    companyId: text("company_id")
      .notNull()
      .references(() => companies.id, { onDelete: "cascade" }),
    operationId: text("operation_id").notNull(),
    operationType: text("operation_type").notNull(),
    requestHash: text("request_hash").notNull(),
    responseBody: jsonb("response_body").notNull(),
    statusCode: integer("status_code").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    primaryKey({ columns: [table.companyId, table.operationId] }),
    index("operation_receipts_created_idx").on(table.createdAt),
  ],
);

export const syncChanges = pgTable(
  "sync_changes",
  {
    id: bigserial("id", { mode: "number" }).primaryKey(),
    companyId: text("company_id")
      .notNull()
      .references(() => companies.id, { onDelete: "cascade" }),
    entityType: text("entity_type").notNull(),
    entityId: text("entity_id").notNull(),
    changeType: text("change_type").notNull(),
    entityVersion: bigint("entity_version", { mode: "number" }).notNull(),
    payload: jsonb("payload").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .notNull()
      .defaultNow(),
  },
  (table) => [
    index("sync_changes_company_id_idx").on(table.companyId, table.id),
    index("sync_changes_entity_idx").on(
      table.companyId,
      table.entityType,
      table.entityId,
      table.id,
    ),
    check(
      "sync_changes_change_type_check",
      sql`${table.changeType} in ('upsert', 'tombstone')`,
    ),
  ],
);

export const contactDiscoveryUsage = pgTable(
  "contact_discovery_usage",
  {
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    windowStart: timestamp("window_start", { withTimezone: true }).notNull(),
    requestCount: integer("request_count").notNull().default(0),
    phoneCount: integer("phone_count").notNull().default(0),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.windowStart] }),
    index("contact_discovery_usage_window_idx").on(table.windowStart),
  ],
);
