#!/bin/bash
# deploy.sh — pull latest code and redeploy a specific environment
#
# Usage:
#   ./deploy.sh prod       → production
#   ./deploy.sh staging    → staging
#
# Run this on the VM from the workspace root.

set -e  # stop on any error

# Only one deploy can run at a time — other deploys wait for the lock
LOCKFILE="/tmp/crelyzor-deploy.lock"
exec 200>"$LOCKFILE"
flock 200 || { echo "ERROR: Could not acquire deploy lock"; exit 1; }
echo "Lock acquired (PID $$)"

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

# Save current HEADs before pulling — used for selective rebuild
PREV_BACKEND=$(git -C ./crelyzor-backend rev-parse HEAD 2>/dev/null || echo "none")
PREV_FRONTEND=$(git -C ./crelyzor-frontend rev-parse HEAD 2>/dev/null || echo "none")
PREV_PUBLIC=$(git -C ./crelyzor-public rev-parse HEAD 2>/dev/null || echo "none")

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
# Determine which services need rebuilding
CANDIDATES=""
[ "$(git -C ./crelyzor-backend rev-parse HEAD)" != "$PREV_BACKEND" ] && CANDIDATES="$CANDIDATES backend worker"
[ "$(git -C ./crelyzor-frontend rev-parse HEAD)" != "$PREV_FRONTEND" ] && CANDIDATES="$CANDIDATES frontend"
[ "$(git -C ./crelyzor-public rev-parse HEAD)" != "$PREV_PUBLIC" ] && CANDIDATES="$CANDIDATES public"

# Filter to only services that exist in this compose file (e.g. staging has no worker)
COMPOSE_SERVICES=$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null)
CHANGED=""
for svc in $CANDIDATES; do
  echo "$COMPOSE_SERVICES" | grep -qx "$svc" && CHANGED="$CHANGED $svc"
done

if [ -n "$CHANGED" ]; then
  echo "[3/5] Building changed services:$CHANGED"
  docker compose -f "$COMPOSE_FILE" build $CHANGED
else
  echo "[3/5] No service changes detected — rebuilding all"
  docker compose -f "$COMPOSE_FILE" build
fi

echo "[4/5] Restarting services..."
docker compose -f "$COMPOSE_FILE" up -d
# Restart nginx so it re-resolves container IPs (containers get new IPs after rebuild)
docker compose -f "$COMPOSE_FILE" restart nginx

# ── 5. Run database migrations ───────────────────────────────────────────────
echo "[5/5] Running database migrations..."
docker compose -f "$COMPOSE_FILE" exec -T backend pnpm db:deploy

echo ""
echo "✓ Deployed to $ENV successfully."
echo ""
echo "Running containers:"
docker compose -f "$COMPOSE_FILE" ps
