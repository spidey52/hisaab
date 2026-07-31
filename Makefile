.PHONY: help up up-db down logs reset migrate api web

COMPOSE := docker compose -f compose.local.yml

help:
	@echo "Local (no Docker)"
	@echo "  make api       Backend on :3001 (needs backend/.env DATABASE_URL)"
	@echo "  make web       React UI on :3000 → http://localhost:3001"
	@echo "  make migrate   Drizzle migrate"
	@echo ""
	@echo "Docker"
	@echo "  make up        API + web containers"
	@echo "  make up-db     API + web + Postgres 18"
	@echo "  make down / logs / reset"

up:
	$(COMPOSE) up --build api web

up-db:
	$(COMPOSE) --profile db up --build

down:
	$(COMPOSE) --profile db down

logs:
	$(COMPOSE) logs -f api

reset:
	$(COMPOSE) --profile db down
	rm -rf backend/data/postgres

migrate:
	cd backend && bun run db:migrate

api:
	cd backend && bun run dev

web:
	cd frontend && VITE_API_BASE_URL=http://localhost:3001 bun run dev
