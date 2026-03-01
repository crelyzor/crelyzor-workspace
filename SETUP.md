# Crelyzor — Setup Guide

Complete setup from zero to running. Follow in order.

---

## Prerequisites

Install these before anything else:

| Tool | Version | Install |
|------|---------|---------|
| Node.js | >= 20 | https://nodejs.org or `nvm install 20` |
| pnpm | >= 9 | `npm install -g pnpm` |
| Git | any | https://git-scm.com |
| Claude Code | latest | `npm install -g @anthropic/claude-code` |

---

## Step 1 — Clone All Repos

Create a `Calendar` folder and clone everything inside it:

```bash
mkdir Calendar && cd Calendar
```

Clone the workspace (this repo):
```bash
git clone <this-repo-url> .
```

Clone the 3 code repos into the same folder:
```bash
git clone <calendar-backend-url>   calendar-backend
git clone <calendar-frontend-url>  calendar-frontend
git clone <cards-frontend-url>     cards-frontend
```

Your folder should look like this:
```
Calendar/
├── calendar-backend/
├── calendar-frontend/
├── cards-frontend/
├── CLAUDE.md
├── TASKS.md
├── START_HERE.md
└── ...
```

---

## Step 2 — Environment Variables

The backend needs a `.env` file. Ask the team for the values.

```bash
cp calendar-backend/.env.example calendar-backend/.env
```

Open `calendar-backend/.env` and fill in:

```bash
# Database (Neon PostgreSQL — get connection string from team)
DATABASE_URL=""

# Auth
JWT_SECRET=""
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_CALLBACK_URL="http://localhost:3000/api/v1/auth/google/login/callback"

# AI & Transcription
OPENAI_API_KEY=""       # Get from platform.openai.com
DEEPGRAM_API_KEY=""     # Get from console.deepgram.com

# Storage (Google Cloud Storage)
GCS_BUCKET_NAME=""
GCS_PROJECT_ID=""
GOOGLE_APPLICATION_CREDENTIALS=""   # Path to service account JSON

# Queue (Upstash Redis)
UPSTASH_REDIS_REST_URL=""
UPSTASH_REDIS_REST_TOKEN=""

# Config
PORT=3000
BASE_URL_SHORTNER=http://localhost:3000
HARD_DELETE_ENABLED=false
AUTO_START_CRON=false
```

Frontends have no `.env` files — they point to the backend at `localhost:3000`.

---

## Step 3 — Install Dependencies

From the root `Calendar/` folder:

```bash
pnpm install          # installs root (concurrently)
pnpm install:all      # installs all 3 repos
```

---

## Step 4 — Database

Generate the Prisma client:

```bash
pnpm db:generate    # runs prisma generate in calendar-backend
```

If you have a fresh database:
```bash
pnpm db:migrate     # runs migrations
```

If the schema is already deployed (most cases):
```bash
# Nothing to do — DATABASE_URL connects to Neon which already has the schema
```

To browse the database:
```bash
pnpm db:studio      # opens Prisma Studio at localhost:5555
```

---

## Step 5 — Run Everything

```bash
# Start all 3 services
pnpm dev

# Or start everything including the job worker (required for transcription)
pnpm dev:full
```

| Service | URL |
|---------|-----|
| API | http://localhost:3000 |
| Dashboard | http://localhost:5173 |
| Public Cards | http://localhost:5174 |

The job worker is required for recording transcription and AI processing to work. Use `pnpm dev:full` if you're working on meeting features.

---

## Step 6 — Claude Code Setup

Open Claude Code from the `Calendar/` root:

```bash
claude
```

### Add MCP Servers

First, export the DB URL as a named env var (add this to your `~/.zshrc` or `~/.zprofile`):

```bash
# Local Testing — Crelyzor DB URL (Neon PostgreSQL)
export CRELYZOR_TEST_DB_URL="<your DATABASE_URL from calendar-backend/.env>"
```

Then reload your shell:

```bash
source ~/.zshrc
```

Now add the MCP servers:

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres "$CRELYZOR_TEST_DB_URL"
```

### Verify Setup

Type `/crelyzor` in Claude Code — it should read the task lists and tell you what to work on next.

---

## Step 7 — Verify Everything Works

1. **Auth** — go to `http://localhost:5173`, sign in with Google
2. **Cards** — create a card, visit the public URL at `http://localhost:5174/:username`
3. **Meetings** — create a meeting, check it appears in the list

---

## Troubleshooting

**Port already in use:**
```bash
lsof -ti:3000 | xargs kill    # kill process on port 3000
lsof -ti:5173 | xargs kill    # kill process on port 5173
```

**Prisma client out of sync:**
```bash
cd calendar-backend && pnpm db:generate
```

**pnpm not found:**
```bash
npm install -g pnpm
```

**Node version too old:**
```bash
nvm install 20 && nvm use 20
```

**Transcription not working:**
- Make sure you ran `pnpm dev:full` (not just `pnpm dev`) — the worker process is required
- Check `DEEPGRAM_API_KEY` is set in `.env`

---

## Project Structure

```
Calendar/               ← Workspace root (this repo)
├── calendar-backend/   ← Express API (port 3000)
├── calendar-frontend/  ← React dashboard (port 5173)
├── cards-frontend/     ← Public cards (port 5174)
├── CLAUDE.md           ← Claude reads this every session
├── TASKS.md            ← What's done and what's next
├── START_HERE.md       ← Quick start after setup
├── DECISIONS.md        ← Why things were built the way they were
├── docs/               ← Full product and architecture docs
└── .claude/            ← Claude Code skills, agents, and hooks
```

Once set up, read `START_HERE.md` for the development workflow.
