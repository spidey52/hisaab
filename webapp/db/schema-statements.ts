export const schemaStatements = [
  `CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    phone_e164 TEXT NOT NULL UNIQUE,
    phone_verified_at TIMESTAMPTZ NOT NULL,
    full_name TEXT,
    language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'hi')),
    accessibility_mode BOOLEAN NOT NULL DEFAULT FALSE,
    contact_discoverable BOOLEAN NOT NULL DEFAULT FALSE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
  )`,
  `CREATE TABLE IF NOT EXISTS companies (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    next_entry_number BIGINT NOT NULL DEFAULT 1 CHECK (next_entry_number > 0),
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS memberships (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'member')),
    tutorial_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, company_id)
  )`,
  `CREATE TABLE IF NOT EXISTS party_groups (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 1,
    UNIQUE(company_id, name)
  )`,
  `CREATE TABLE IF NOT EXISTS parties (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    reference TEXT NOT NULL,
    name TEXT NOT NULL,
    short_name TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    phone_e164 TEXT,
    notes TEXT NOT NULL DEFAULT '',
    group_id TEXT REFERENCES party_groups(id) ON DELETE SET NULL,
    created_by TEXT NOT NULL REFERENCES users(id),
    updated_by TEXT REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    archived_at TIMESTAMPTZ,
    merged_into_id TEXT,
    version BIGINT NOT NULL DEFAULT 1,
    UNIQUE(company_id, reference)
  )`,
  `CREATE TABLE IF NOT EXISTS entries (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    party_id TEXT NOT NULL REFERENCES parties(id),
    sequence BIGINT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('gave','received','opening_balance')),
    amount_paise BIGINT NOT NULL CHECK(amount_paise >= 0 AND amount_paise <= 99999999900),
    balance_effect_paise BIGINT NOT NULL CHECK(abs(balance_effect_paise) <= 99999999900),
    narration TEXT NOT NULL,
    entry_date DATE NOT NULL,
    payment_account TEXT CHECK(payment_account IN ('cash', 'bank')),
    status TEXT NOT NULL DEFAULT 'posted' CHECK(status IN ('posted','cancelled')),
    idempotency_key TEXT NOT NULL,
    created_by TEXT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 1,
    edited_by TEXT REFERENCES users(id),
    edited_at TIMESTAMPTZ,
    cancelled_by TEXT REFERENCES users(id),
    cancelled_at TIMESTAMPTZ,
    UNIQUE(company_id, sequence),
    UNIQUE(company_id, idempotency_key)
  )`,
  `CREATE TABLE IF NOT EXISTS entry_revisions (
    id TEXT PRIMARY KEY,
    entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    previous_values JSONB NOT NULL,
    changed_by TEXT NOT NULL REFERENCES users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS audit_events (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    actor_user_id TEXT NOT NULL REFERENCES users(id),
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS user_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    user_agent TEXT NOT NULL DEFAULT '',
    ip_hash TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
  )`,
  `CREATE TABLE IF NOT EXISTS otp_challenges (
    id TEXT PRIMARY KEY,
    phone_e164 TEXT NOT NULL,
    provider TEXT NOT NULL CHECK(provider IN ('console', 'twilio_verify')),
    provider_reference TEXT,
    code_hash TEXT,
    requested_ip_hash TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 5 CHECK(max_attempts BETWEEN 1 AND 10),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
  )`,
  `CREATE TABLE IF NOT EXISTS auth_events (
    id TEXT PRIMARY KEY,
    phone_hash TEXT NOT NULL,
    ip_hash TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK(event_type IN (
      'otp_requested',
      'otp_request_blocked',
      'otp_failed',
      'otp_approved',
      'session_created',
      'session_revoked'
    )),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS operation_receipts (
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    operation_id TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    request_hash TEXT NOT NULL,
    response_body JSONB NOT NULL,
    status_code INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(company_id, operation_id)
  )`,
  `CREATE TABLE IF NOT EXISTS sync_changes (
    id BIGSERIAL PRIMARY KEY,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    change_type TEXT NOT NULL CHECK(change_type IN ('upsert', 'tombstone')),
    entity_version BIGINT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS contact_discovery_usage (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    window_start TIMESTAMPTZ NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    phone_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(user_id, window_start)
  )`,
  `CREATE INDEX IF NOT EXISTS memberships_company_idx ON memberships(company_id)`,
  `CREATE INDEX IF NOT EXISTS memberships_user_idx ON memberships(user_id)`,
  `CREATE INDEX IF NOT EXISTS parties_company_name_idx ON parties(company_id, name)`,
  `CREATE INDEX IF NOT EXISTS parties_company_phone_idx ON parties(company_id, phone)`,
  `CREATE INDEX IF NOT EXISTS parties_group_idx ON parties(group_id)`,
  `CREATE INDEX IF NOT EXISTS entries_company_party_date_idx ON entries(company_id, party_id, entry_date, sequence)`,
  `CREATE INDEX IF NOT EXISTS entries_company_created_idx ON entries(company_id, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS entries_party_idx ON entries(party_id)`,
  `CREATE INDEX IF NOT EXISTS entry_revisions_entry_idx ON entry_revisions(entry_id)`,
  `CREATE INDEX IF NOT EXISTS audit_company_created_idx ON audit_events(company_id, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS audit_entity_idx ON audit_events(entity_type, entity_id)`,
  `CREATE INDEX IF NOT EXISTS sessions_user_active_idx
    ON user_sessions(user_id, expires_at)
    WHERE revoked_at IS NULL`,
  `CREATE INDEX IF NOT EXISTS sessions_expiry_idx
    ON user_sessions(expires_at)
    WHERE revoked_at IS NULL`,
  `CREATE INDEX IF NOT EXISTS otp_phone_recent_idx
    ON otp_challenges(phone_e164, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS otp_ip_recent_idx
    ON otp_challenges(requested_ip_hash, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS auth_events_created_idx
    ON auth_events(created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS auth_events_phone_idx
    ON auth_events(phone_hash, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS operation_receipts_created_idx
    ON operation_receipts(created_at)`,
  `CREATE INDEX IF NOT EXISTS sync_changes_company_id_idx
    ON sync_changes(company_id, id)`,
  `CREATE INDEX IF NOT EXISTS sync_changes_entity_idx
    ON sync_changes(company_id, entity_type, entity_id, id)`,
  `CREATE INDEX IF NOT EXISTS contact_discovery_usage_window_idx
    ON contact_discovery_usage(window_start)`,
] as const;

// These indexes depend on columns/cleanup introduced by numbered migrations.
// Keeping them in a post-migration phase makes upgrades from legacy databases
// safe while still declaring the complete current schema here.
export const postMigrationSchemaStatements = [
  `CREATE INDEX IF NOT EXISTS parties_company_phone_e164_idx
    ON parties(company_id, phone_e164) WHERE phone_e164 IS NOT NULL`,
  `CREATE UNIQUE INDEX IF NOT EXISTS entries_one_active_opening_balance_uq
    ON entries(company_id, party_id)
    WHERE action = 'opening_balance' AND status = 'posted'`,
] as const;
