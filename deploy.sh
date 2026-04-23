#!/bin/bash
# deploy.sh — pull latest code and redeploy a specific environment
#
# Usage:
#   ./deploy.sh prod       → production
#   ./deploy.sh staging    → staging
#
# Run this on the VM from the workspace root.

set -e  # stop on any error

ENV=${1:-prod}

if [[ "$ENV" != "prod" && "$ENV" != "staging" ]]; then
  echo "Usage: ./deploy.sh [prod|staging]"
  exit 1
fi

echo "──────────────────────────────────────────"
echo "  Deploying: $ENV"
echo "──────────────────────────────────────────"

# ── 1. Pull latest code ──────────────────────────────────────────────────────
echo "[1/5] Pulling latest code from git..."
if [[ "$ENV" == "prod" ]]; then
  BRANCH="main"
else
  BRANCH="staging"
fi

# Pull all 4 repos — fetch + reset to handle any diverged state on VM
sync_repo() {
  local dir=$1
  git -C "$dir" fetch origin $BRANCH
  git -C "$dir" reset --hard origin/$BRANCH
}

sync_repo .
sync_repo ./crelyzor-backend
sync_repo ./crelyzor-frontend
sync_repo ./crelyzor-public

# ── 2. Pick the right compose file ──────────────────────────────────────────
if [[ "$ENV" == "prod" ]]; then
  COMPOSE_FILE="docker-compose.prod.yml"
  ENV_FILE=".env.prod"
else
  COMPOSE_FILE="docker-compose.staging.yml"
  ENV_FILE=".env.staging"
fi

echo "[2/5] Using compose file: $COMPOSE_FILE"

# ── 3. Check env file exists ────────────────────────────────────────────────
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Create it from .env.example first."
  exit 1
fi

# Source the env file so compose can read the variables
set -a
source "$ENV_FILE"
set +a

# ── 4. Build and restart services ────────────────────────────────────────────
echo "[3/5] Building images..."
docker compose -f "$COMPOSE_FILE" build

echo "[4/5] Restarting services..."
docker compose -f "$COMPOSE_FILE" up -d

# ── 5. Run database migrations ───────────────────────────────────────────────
echo "[5/5] Running database migrations..."
docker compose -f "$COMPOSE_FILE" exec -T backend pnpm db:deploy

echo ""
echo "✓ Deployed to $ENV successfully."
echo ""
echo "Running containers:"
docker compose -f "$COMPOSE_FILE" ps
