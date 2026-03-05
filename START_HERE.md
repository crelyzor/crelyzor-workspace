# Start Here — Crelyzor

Welcome. This doc gets you from zero to productive in one read.

---

## What Is Crelyzor

An all-in-one productivity OS for solo professionals.

Replaces: HiHello + Cal.com + Otter.ai + Todoist — in one product where everything is connected.

- **Digital Cards** — shareable, scannable, live business card with QR and vCard
- **Smart Meeting AI** — record offline meetings → AI transcribes, summarizes, extracts action items
- **Ask AI** — chat with any meeting: "What did John say about the budget?"
- **Scheduling** — Cal.com style availability and booking *(Phase 1.2)*
- **Tasks** — Todoist style, AI-generated from meetings *(Phase 3)*
- **Big Brain** — AI that knows all your meetings, people, and work *(Phase 2)*

Teams is **future scope only**. We are building Solo first.

**Full context:** `README.md` · `docs/product.md` · `docs/roadmap.md`

---

## Repos

| Folder | What It Is | Port |
|--------|-----------|------|
| `calendar-backend` | Node.js + Express API — all business logic | 3000 |
| `calendar-frontend` | React dashboard — meetings, cards, settings | 5173 |
| `cards-frontend` | React — public card pages only (`/:username`) | 5174 |

---

## Step 1 — Environment Setup

Copy and fill in the backend env file:

```bash
cp calendar-backend/.env.example calendar-backend/.env
```

Required keys:

```bash
DATABASE_URL=""          # PostgreSQL (Neon) — ask for the connection string
OPENAI_API_KEY=""        # OpenAI — required for AI features
DEEPGRAM_API_KEY=""      # Deepgram — required for transcription
GOOGLE_CLIENT_ID=""      # Google OAuth
GOOGLE_CLIENT_SECRET=""
GCS_BUCKET_NAME=""       # Google Cloud Storage (recordings)
UPSTASH_REDIS_REST_URL=""
UPSTASH_REDIS_REST_TOKEN=""
```

Frontends have no env files — they talk to the backend.

---

## Step 2 — Install Dependencies

```bash
# From root (installs all 3 repos)
pnpm install:all
```

---

## Step 3 — Run Everything

```bash
# From root — starts all 3 services simultaneously
pnpm dev

# Or start everything including the job worker (required for transcription)
pnpm dev:full
```

Individual services:
```bash
pnpm dev:backend   # API only
pnpm dev:frontend  # Dashboard only
pnpm dev:cards     # Public cards only
pnpm dev:worker    # Job worker only (Deepgram/AI queue)
```

Database tools:
```bash
pnpm db:studio    # Prisma Studio — visual DB browser
pnpm db:migrate   # Run new migrations
```

---

## Step 4 — Claude Code Setup

This project is fully configured for Claude Code. Here's what's set up and how to use it.

### Session Commands

| Command | When to use |
|---------|-------------|
| `/crelyzor-start` | **Start of every session.** Shows git status across all repos, what's in progress, picks next task, plans, reviews, executes. |
| `/crelyzor` | **Each subsequent task.** Same as above but skips the session briefing. |

### Utility Commands (run when needed)

| Command | What It Does |
|---------|-------------|
| `/techdebt` | Scan all 3 repos for `any` types, `console.log`, convention violations |
| `/db-check` | Scan backend for queries missing `isDeleted: false` filter |
| `/debug` | Paste an error — traces route → controller → service → DB and fixes it |
| `/migrate` | Guided Prisma migration with schema review before running |
| `/commit` | Create a git commit |
| `/commit-push-pr` | Commit + push + open PR |

### Skills (auto-invoked by `/crelyzor` and `/crelyzor-start`)

| Skill | Invoked when |
|-------|-------------|
| `new-endpoint` | Building a backend endpoint |
| `new-page` | Building a frontend page |
| `frontend-design` | Building any UI / visual work |
| `review` | After writing code |

### Agents (auto-invoked during plan review)

| Agent | Invoked when |
|-------|-------------|
| `crelyzor-reviewer` | Every task — reviews plan + code |
| `schema-reviewer` | Task has DB/schema changes |
| `security-reviewer` | Task has backend changes |

### MCP Servers (active in every session)

| MCP | What It Gives Claude |
|-----|---------------------|
| `context7` | Live docs for Prisma, OpenAI, Deepgram, React Router, TanStack Query |
| `postgres` | Direct access to the Neon database — Claude can query it live |

### Hooks (run automatically)

| Hook | When | What It Does |
|------|------|-------------|
| Prettier | After every file write | Auto-formats all `.ts` / `.tsx` files |
| TypeScript check | After every file write | Runs `tsc --noEmit` in the affected repo |
| `.env` guard | Before any file write | Blocks edits to `.env` files |

---

## Step 5 — Start Working

Open Claude Code in this folder and type:

```
/crelyzor-start
```

Claude will:
1. Show git status across all 3 repos
2. Show what's in progress and what's next
3. Pick the highest priority task and announce it
4. Write a detailed plan — reviewed by 2-3 agents
5. Wait for your "go"
6. Execute using the right skills
7. Ask you to test
8. Write dev notes + update CLAUDE.md if needed
9. Mark task done and announce the next one

For each subsequent task in the same session, type `/crelyzor`.

---

## Key Files to Know

```
/
├── START_HERE.md          ← You are here
├── README.md              ← Product vision
├── CLAUDE.md              ← Claude reads this every session (product + conventions)
├── TASKS.md               ← Master task list (all phases)
├── DECISIONS.md           ← Why things were built the way they were
│
├── docs/
│   ├── product.md         ← Full feature spec (what's built vs not)
│   ├── roadmap.md         ← Phase roadmap with task checklist
│   ├── architecture.md    ← System design, data flows, integrations
│   └── ai-brain.md        ← AI per-meeting brain + Big Brain design
│
├── .claude/
│   ├── settings.json      ← Hooks (prettier, tsc, .env guard)
│   ├── skills/            ← /continue, /new-endpoint, /new-page, /review
│   └── agents/            ← crelyzor-reviewer
│
├── calendar-backend/
│   ├── CLAUDE.md          ← Backend patterns (read before writing backend code)
│   ├── TASKS.md           ← Backend task list
│   └── prisma/schema.prisma
│
├── calendar-frontend/
│   ├── CLAUDE.md          ← UI/design system (read before writing any UI)
│   └── TASKS.md           ← Frontend task list
│
└── cards-frontend/
    ├── CLAUDE.md          ← Card design (dark #0a0a0a, gold #d4af61)
    └── TASKS.md           ← Cards task list
```

---

## Current Phase

**Phase 1 — Offline First**

What's left to build (in priority order):

1. **Ask AI endpoint** — `POST /sma/meetings/:id/ask` (backend)
2. **Wire MeetingDetail** — replace mock data with real API (frontend)
3. **Ask AI chat UI** — chat interface in meeting detail (frontend)
4. **Recording upload UI** — connected to backend with status polling
5. **Action items + notes UI** — complete the meeting detail page

Type `/crelyzor` and Claude picks up from here.

---

## Tech Stack (Quick Reference)

**Backend:** Express 5 · TypeScript · Prisma · PostgreSQL (Neon) · OpenAI · Deepgram · Bull + Redis · Google OAuth

**Frontend:** React 19 · Vite · React Router 7 · TanStack Query · Zustand · TailwindCSS 4 · shadcn/ui · Motion

**Package manager:** `pnpm` always — never npm or yarn

---

## Conventions (The Short Version)

**Backend pattern:** Controller → Service → Prisma. Always use `AppError`, `globalResponseHandler`, `logger`, `Zod` validation, `verifyJWT`.

**Frontend pattern:** React Query for data. Zustand for state. shadcn/ui for components. `PageMotion` on every page. Dark mode on everything. No colors outside neutrals.

**Full conventions:** each repo's `CLAUDE.md` has complete rules.
