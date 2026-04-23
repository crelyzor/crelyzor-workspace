.PHONY: local-up local-up-build local-down local-down-v local-restart local-ps local-logs local-logs-backend local-logs-frontend local-logs-public migrate studio

# ── Local ─────────────────────────────────────────────────────────────────────

local-up:
	docker compose -f docker-compose.local.yml --env-file .env.local up

local-up-build:
	docker compose -f docker-compose.local.yml --env-file .env.local up --build

local-down:
	docker compose -f docker-compose.local.yml --env-file .env.local down

local-down-v:
	docker compose -f docker-compose.local.yml --env-file .env.local down -v

local-restart:
	docker compose -f docker-compose.local.yml --env-file .env.local restart

local-ps:
	docker compose -f docker-compose.local.yml --env-file .env.local ps

local-logs:
	docker compose -f docker-compose.local.yml --env-file .env.local logs -f

local-logs-backend:
	docker compose -f docker-compose.local.yml --env-file .env.local logs -f backend

local-logs-frontend:
	docker compose -f docker-compose.local.yml --env-file .env.local logs -f frontend

local-logs-public:
	docker compose -f docker-compose.local.yml --env-file .env.local logs -f public

# ── Database ──────────────────────────────────────────────────────────────────

migrate:
	docker compose -f docker-compose.local.yml --env-file .env.local exec backend pnpm db:migrate

studio:
	docker compose -f docker-compose.local.yml --env-file .env.local exec backend pnpm db:studio

# ── Staging / Prod ────────────────────────────────────────────────────────────

staging-up:
	docker compose -f docker-compose.staging.yml --env-file .env.staging up -d --build

staging-down:
	docker compose -f docker-compose.staging.yml --env-file .env.staging down

prod-up:
	docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

prod-down:
	docker compose -f docker-compose.prod.yml --env-file .env.prod down
