# Hisaab

A self-hosted web ledger for Indian shops and small businesses. Hisaab records
customer and supplier activity in integer paise, calculates running balances,
and keeps financial corrections auditable.

## What is included

- Next.js 16 application and Node.js 22 server
- PostgreSQL 17 database with pooled connections, constraints, and indexes
- Phone-number authentication using one-time SMS codes
- Twilio Verify integration for public deployments
- Opaque, revocable, server-side sessions in HttpOnly cookies
- Per-phone and per-IP OTP limits, resend cooldown, expiry, one-use challenges,
  and maximum-attempt enforcement
- Docker images and Compose definitions for local and production use
- Caddy reverse proxy with automatic HTTPS
- Health checks, persistent volumes, migration startup, and backup instructions
- Company-scoped API authorization, audit history, offline entry queue, exports,
  and permanent account deletion

There is no dependency on ChatGPT Sites, Cloudflare Workers, D1, or ChatGPT
authentication.

## Run locally

Prerequisites: Docker Desktop (or Docker Engine with Compose).

```bash
docker compose -f compose.local.yml up --build
```

Open [http://localhost:3000](http://localhost:3000). Enter a real-looking phone
number such as `+91 98765 43210`. Local mode displays the generated test OTP in
the browser; it never sends an SMS.

The app and database keep running in containers. PostgreSQL data persists in the
`hisaab_local_postgres` Docker volume. From the host, PostgreSQL is available at
`postgresql://hisaab:hisaab_local_password@127.0.0.1:5434/hisaab`. From another
device on the same tailnet, use
`postgresql://hisaab:hisaab_local_password@100.77.37.100:5434/hisaab`.

```bash
# Follow logs
docker compose -f compose.local.yml logs -f app

# Stop without deleting data
docker compose -f compose.local.yml down

# Stop and intentionally erase local database data
docker compose -f compose.local.yml down --volumes
```

Console OTP is guarded by both `ALLOW_INSECURE_LOCAL_OTP=true` and a localhost
`PUBLIC_BASE_URL`. The production Compose file does not enable it.

When exposing the local app through a private Tailscale Serve URL, put that
origin in `ADDITIONAL_ALLOWED_ORIGINS` before starting Compose. Local test codes
are returned to and prefilled by the login form; production SMS codes are never
prefilled.

## Deploy on your server

Prerequisites:

- A Linux server with Docker Engine and the Docker Compose plugin
- A domain whose DNS `A`/`AAAA` record points to that server
- Inbound ports 80 and 443 open
- A Twilio account and a Verify Service configured for SMS

Copy the repository to the server, then:

```bash
cp .env.production.example .env.production
openssl rand -hex 32
openssl rand -hex 32
```

Put the two generated values into `POSTGRES_PASSWORD` and `SESSION_SECRET`.
Set `DOMAIN`, `SUPPORT_EMAIL`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`,
and `TWILIO_VERIFY_SERVICE_SID`. The support address is shown on the public
privacy and terms pages. Never commit `.env.production`.

```bash
docker compose \
  --env-file .env.production \
  -f compose.production.yml \
  up -d --build
```

Caddy obtains and renews the TLS certificate automatically. Only Caddy exposes
public ports; PostgreSQL is reachable solely through the internal Docker
network. Check deployment health with:

```bash
docker compose --env-file .env.production -f compose.production.yml ps
curl --fail https://YOUR_DOMAIN/api/health
```

The response should be `{"status":"ok"}`.

## Production operations

### Backup

```bash
docker compose --env-file .env.production -f compose.production.yml \
  exec -T db pg_dump -U hisaab -d hisaab -Fc > hisaab-backup.dump
```

Copy backups off the server and test restoration periodically. To restore into
an empty database:

```bash
docker compose --env-file .env.production -f compose.production.yml \
  exec -T db pg_restore -U hisaab -d hisaab --clean --if-exists \
  < hisaab-backup.dump
```

### Update

```bash
git pull --ff-only
docker compose --env-file .env.production -f compose.production.yml \
  up -d --build
```

The app applies idempotent schema migrations before accepting traffic.

### Logs

```bash
docker compose --env-file .env.production -f compose.production.yml \
  logs --tail=200 -f app caddy db
```

Do not log raw OTPs in production. The console provider logs codes only in the
explicit localhost configuration.

## Application workflows

- Add, edit, archive, search, group, and safely merge customer/supplier records
- Warn about likely duplicate names and phone numbers
- Create backend-numbered entries with idempotency protection
- Edit entries with retained revisions; cancel rather than delete them
- Undo newly saved entries while keeping their immutable number in history
- Create and edit auditable opening-balance records
- Share or print date-filtered statements with running and final balances
- Queue new entries offline and upload them after reconnection
- Export complete JSON or entry CSV data
- Update company/user preferences and permanently delete an account

Cash and Bank labels describe recorded customer-linked movement only. They are
not represented as guaranteed real-world account balances.

## Development without Docker

Requires Node.js 22.13+, pnpm, and PostgreSQL.

```bash
pnpm install
export DATABASE_URL=postgresql://hisaab:hisaab@127.0.0.1:5432/hisaab
export SESSION_SECRET=local-only-secret-with-at-least-32-characters
export OTP_PROVIDER=console
export ALLOW_INSECURE_LOCAL_OTP=true
export PUBLIC_BASE_URL=http://localhost:3000
export COOKIE_SECURE=false
pnpm db:migrate
pnpm dev
```

## Verification

```bash
pnpm exec tsc --noEmit
pnpm lint
pnpm test
docker compose -f compose.local.yml config --quiet
docker compose --env-file .env.production -f compose.production.yml config --quiet
```

`pnpm test` creates a production build and checks the rendered landing page,
login boundary, API authorization, cross-site mutation rejection, and expected
self-hosted production configuration.

## Account recovery

Signing in with the same verified phone number on another device restores the
authorised company data from PostgreSQL. Losing control of that number currently
requires an administrator-assisted identity check and database update; there is
deliberately no insecure self-service phone-number change. Users should export
their records regularly.
