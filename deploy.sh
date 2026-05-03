#!/bin/bash
# deploy.sh — pull latest code and redeploy a specific environment
#
# Usage:
#   ./deploy.sh prod       → production
#   ./deploy.sh staging    → staging
#
# Run this on the VM from the workspace root.

set -e
export DOCKER_BUILDKIT=1

# Only one deploy can run at a time — other deploys wait for the lock
LOCKFILE="/tmp/crelyzor-deploy.lock"
exec 200>"$LOCKFILE"
flock 200
echo "Lock acquired (PID $$)"

ENV=${1:-prod}
if [[ "$ENV" != "prod" && "$ENV" != "staging" ]]; then
  echo "Usage: ./deploy.sh [prod|staging]"
  exit 1
fi

if [[ "$ENV" == "prod" ]]; then
  BRANCH="main"
  COMPOSE_FILE="docker-compose.prod.yml"
  ENV_FILE="crelyzor-backend/.env.prod"
else
  BRANCH="staging"
  COMPOSE_FILE="docker-compose.staging.yml"
  ENV_FILE="crelyzor-backend/.env.staging"
fi

echo "──────────────────────────────────────────"
echo "  Deploying: $ENV"
echo "──────────────────────────────────────────"

# ── 1. Pull latest code ──────────────────────────────────────────────────────
echo "[1/5] Pulling latest code..."

PREV_WORKSPACE=$(git rev-parse HEAD 2>/dev/null || echo "none")
PREV_BACKEND=$(git -C ./crelyzor-backend rev-parse HEAD 2>/dev/null || echo "none")
PREV_FRONTEND=$(git -C ./crelyzor-frontend rev-parse HEAD 2>/dev/null || echo "none")
PREV_PUBLIC=$(git -C ./crelyzor-public rev-parse HEAD 2>/dev/null || echo "none")

sync_repo() {
  git -C "$1" fetch origin $BRANCH
  git -C "$1" reset --hard origin/$BRANCH
}
sync_repo .
sync_repo ./crelyzor-backend
sync_repo ./crelyzor-frontend
sync_repo ./crelyzor-public

# ── 2. Pull env from Secret Manager ─────────────────────────────────────────
echo "[2/5] Pulling env from Secret Manager..."
SECRET_NAME="crelyzor-${ENV}-env"
gcloud secrets versions access latest --secret="$SECRET_NAME" > "$ENV_FILE" || {
  echo "ERROR: Failed to pull secret $SECRET_NAME — aborting"
  exit 1
}
set -a; source "$ENV_FILE"; set +a

# ── 3. Detect changes and build new images ───────────────────────────────────
echo "[3/5] Detecting changes..."

WORKSPACE_CHANGED=false
BACKEND_CHANGED=false
FRONTEND_CHANGED=false
PUBLIC_CHANGED=false

[ "$(git rev-parse HEAD)" != "$PREV_WORKSPACE" ]                        && WORKSPACE_CHANGED=true
[ "$(git -C ./crelyzor-backend  rev-parse HEAD)" != "$PREV_BACKEND"  ] && BACKEND_CHANGED=true
[ "$(git -C ./crelyzor-frontend rev-parse HEAD)" != "$PREV_FRONTEND" ] && FRONTEND_CHANGED=true
[ "$(git -C ./crelyzor-public   rev-parse HEAD)" != "$PREV_PUBLIC"   ] && PUBLIC_CHANGED=true

COMPOSE_SERVICES=$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null)

BUILD_TARGETS=""
$BACKEND_CHANGED  && BUILD_TARGETS="$BUILD_TARGETS backend worker"
$FRONTEND_CHANGED && BUILD_TARGETS="$BUILD_TARGETS frontend"
$PUBLIC_CHANGED   && BUILD_TARGETS="$BUILD_TARGETS public"

# Filter to services that exist in this compose file
VALID_BUILD=""
for svc in $BUILD_TARGETS; do
  echo "$COMPOSE_SERVICES" | grep -qx "$svc" && VALID_BUILD="$VALID_BUILD $svc"
done

if [ -n "$VALID_BUILD" ]; then
  echo "        Building:$VALID_BUILD"
  docker compose -f "$COMPOSE_FILE" build $VALID_BUILD
  docker image prune -f
elif ! $WORKSPACE_CHANGED; then
  echo ""
  echo "✓ Nothing changed — skipping deploy."
  exit 0
fi

# ── 4. Run migrations before swapping containers ─────────────────────────────
# Runs in a one-off container from the new backend image while old containers
# are still serving traffic. If this fails, old containers stay up untouched.
echo "[4/5] Running database migrations..."
if $BACKEND_CHANGED; then
  docker compose -f "$COMPOSE_FILE" run --rm -T backend pnpm db:deploy || {
    echo "ERROR: Migrations failed — aborting. Old containers are still running."
    exit 1
  }
else
  echo "        No backend changes — skipping migrations."
fi

# ── 5. Start new containers and reload nginx ──────────────────────────────────
echo "[5/5] Starting services..."
docker compose -f "$COMPOSE_FILE" up -d

# Wait for backend to accept connections before reloading nginx
if $BACKEND_CHANGED && echo "$COMPOSE_SERVICES" | grep -qx "backend"; then
  echo "        Waiting for backend to be ready..."
  TRIES=0
  until docker compose -f "$COMPOSE_FILE" exec -T backend \
    node -e "require('http').get('http://localhost:4000/',r=>process.exit(0)).on('error',()=>process.exit(1))" \
    2>/dev/null; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge 30 ]; then
      echo "ERROR: Backend did not become ready within 60s — check container logs."
      docker compose -f "$COMPOSE_FILE" logs --tail=50 backend
      exit 1
    fi
    sleep 2
  done
  echo "        Backend is ready."
fi

# Reload nginx gracefully — no dropped connections, no downtime
docker compose -f "$COMPOSE_FILE" exec -T nginx nginx -s reload

echo ""
echo "✓ Deployed to $ENV successfully."
echo ""
docker compose -f "$COMPOSE_FILE" ps
