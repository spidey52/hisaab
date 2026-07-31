CREATE TABLE "audit_events" (
	"id" text PRIMARY KEY NOT NULL,
	"company_id" text NOT NULL,
	"actor_user_id" text NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" text NOT NULL,
	"action" text NOT NULL,
	"details" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "auth_events" (
	"id" text PRIMARY KEY NOT NULL,
	"phone_hash" text NOT NULL,
	"ip_hash" text NOT NULL,
	"event_type" text NOT NULL,
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "companies" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"currency" text DEFAULT 'INR' NOT NULL,
	"timezone" text DEFAULT 'Asia/Kolkata' NOT NULL,
	"next_entry_number" bigint DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "companies_currency_check" CHECK ("companies"."currency" = 'INR'),
	CONSTRAINT "companies_next_entry_number_check" CHECK ("companies"."next_entry_number" > 0)
);
--> statement-breakpoint
CREATE TABLE "entries" (
	"id" text PRIMARY KEY NOT NULL,
	"company_id" text NOT NULL,
	"party_id" text NOT NULL,
	"sequence" bigint NOT NULL,
	"action" text NOT NULL,
	"amount_paise" bigint NOT NULL,
	"balance_effect_paise" bigint NOT NULL,
	"narration" text NOT NULL,
	"entry_date" date NOT NULL,
	"payment_account" text,
	"status" text DEFAULT 'posted' NOT NULL,
	"idempotency_key" text NOT NULL,
	"created_by" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"edited_by" text,
	"edited_at" timestamp with time zone,
	"cancelled_by" text,
	"cancelled_at" timestamp with time zone,
	CONSTRAINT "entries_action_check" CHECK ("entries"."action" in ('gave', 'received', 'opening_balance')),
	CONSTRAINT "entries_status_check" CHECK ("entries"."status" in ('posted', 'cancelled')),
	CONSTRAINT "entries_payment_account_check" CHECK ("entries"."payment_account" is null or "entries"."payment_account" in ('cash', 'bank'))
);
--> statement-breakpoint
CREATE TABLE "entry_revisions" (
	"id" text PRIMARY KEY NOT NULL,
	"entry_id" text NOT NULL,
	"previous_values" jsonb NOT NULL,
	"changed_by" text NOT NULL,
	"changed_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "memberships" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"company_id" text NOT NULL,
	"role" text DEFAULT 'owner' NOT NULL,
	"tutorial_completed" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "memberships_role_check" CHECK ("memberships"."role" in ('owner', 'member'))
);
--> statement-breakpoint
CREATE TABLE "otp_challenges" (
	"id" text PRIMARY KEY NOT NULL,
	"phone_e164" text NOT NULL,
	"provider" text NOT NULL,
	"provider_reference" text,
	"code_hash" text,
	"requested_ip_hash" text NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"max_attempts" integer DEFAULT 5 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"consumed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "parties" (
	"id" text PRIMARY KEY NOT NULL,
	"company_id" text NOT NULL,
	"reference" text NOT NULL,
	"name" text NOT NULL,
	"short_name" text DEFAULT '' NOT NULL,
	"phone" text DEFAULT '' NOT NULL,
	"notes" text DEFAULT '' NOT NULL,
	"group_id" text,
	"created_by" text NOT NULL,
	"updated_by" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"archived_at" timestamp with time zone,
	"merged_into_id" text
);
--> statement-breakpoint
CREATE TABLE "party_groups" (
	"id" text PRIMARY KEY NOT NULL,
	"company_id" text NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_sessions" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"token_hash" text NOT NULL,
	"user_agent" text DEFAULT '' NOT NULL,
	"ip_hash" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" text PRIMARY KEY NOT NULL,
	"phone_e164" text NOT NULL,
	"phone_verified_at" timestamp with time zone NOT NULL,
	"full_name" text,
	"language" text DEFAULT 'en' NOT NULL,
	"accessibility_mode" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "users_language_check" CHECK ("users"."language" in ('en', 'hi'))
);
--> statement-breakpoint
ALTER TABLE "audit_events" ADD CONSTRAINT "audit_events_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "audit_events" ADD CONSTRAINT "audit_events_actor_user_id_users_id_fk" FOREIGN KEY ("actor_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_party_id_parties_id_fk" FOREIGN KEY ("party_id") REFERENCES "public"."parties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_edited_by_users_id_fk" FOREIGN KEY ("edited_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_cancelled_by_users_id_fk" FOREIGN KEY ("cancelled_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_revisions" ADD CONSTRAINT "entry_revisions_entry_id_entries_id_fk" FOREIGN KEY ("entry_id") REFERENCES "public"."entries"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_revisions" ADD CONSTRAINT "entry_revisions_changed_by_users_id_fk" FOREIGN KEY ("changed_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "parties" ADD CONSTRAINT "parties_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "parties" ADD CONSTRAINT "parties_group_id_party_groups_id_fk" FOREIGN KEY ("group_id") REFERENCES "public"."party_groups"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "parties" ADD CONSTRAINT "parties_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "parties" ADD CONSTRAINT "parties_updated_by_users_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "party_groups" ADD CONSTRAINT "party_groups_company_id_companies_id_fk" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_sessions" ADD CONSTRAINT "user_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audit_company_created_idx" ON "audit_events" USING btree ("company_id","created_at");--> statement-breakpoint
CREATE INDEX "audit_entity_idx" ON "audit_events" USING btree ("entity_type","entity_id");--> statement-breakpoint
CREATE INDEX "auth_events_created_idx" ON "auth_events" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "auth_events_phone_idx" ON "auth_events" USING btree ("phone_hash","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "entries_company_sequence_uq" ON "entries" USING btree ("company_id","sequence");--> statement-breakpoint
CREATE UNIQUE INDEX "entries_company_idempotency_uq" ON "entries" USING btree ("company_id","idempotency_key");--> statement-breakpoint
CREATE INDEX "entries_company_party_date_idx" ON "entries" USING btree ("company_id","party_id","entry_date","sequence");--> statement-breakpoint
CREATE INDEX "entries_company_created_idx" ON "entries" USING btree ("company_id","created_at");--> statement-breakpoint
CREATE INDEX "entries_party_idx" ON "entries" USING btree ("party_id");--> statement-breakpoint
CREATE INDEX "entry_revisions_entry_idx" ON "entry_revisions" USING btree ("entry_id");--> statement-breakpoint
CREATE UNIQUE INDEX "memberships_user_company_uq" ON "memberships" USING btree ("user_id","company_id");--> statement-breakpoint
CREATE INDEX "memberships_company_idx" ON "memberships" USING btree ("company_id");--> statement-breakpoint
CREATE INDEX "memberships_user_idx" ON "memberships" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "otp_phone_recent_idx" ON "otp_challenges" USING btree ("phone_e164","created_at");--> statement-breakpoint
CREATE INDEX "otp_ip_recent_idx" ON "otp_challenges" USING btree ("requested_ip_hash","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "parties_company_reference_uq" ON "parties" USING btree ("company_id","reference");--> statement-breakpoint
CREATE INDEX "parties_company_name_idx" ON "parties" USING btree ("company_id","name");--> statement-breakpoint
CREATE INDEX "parties_company_phone_idx" ON "parties" USING btree ("company_id","phone");--> statement-breakpoint
CREATE INDEX "parties_group_idx" ON "parties" USING btree ("group_id");--> statement-breakpoint
CREATE UNIQUE INDEX "party_groups_company_name_uq" ON "party_groups" USING btree ("company_id","name");--> statement-breakpoint
CREATE UNIQUE INDEX "user_sessions_token_hash_uq" ON "user_sessions" USING btree ("token_hash");--> statement-breakpoint
CREATE INDEX "sessions_user_active_idx" ON "user_sessions" USING btree ("user_id","expires_at") WHERE "user_sessions"."revoked_at" is null;--> statement-breakpoint
CREATE INDEX "sessions_expiry_idx" ON "user_sessions" USING btree ("expires_at") WHERE "user_sessions"."revoked_at" is null;--> statement-breakpoint
CREATE UNIQUE INDEX "users_phone_e164_uq" ON "users" USING btree ("phone_e164");