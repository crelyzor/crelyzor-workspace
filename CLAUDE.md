# Crelyzor — Project Intelligence

Read this first. Every session. No exceptions.

---

## What Is Crelyzor

An all-in-one productivity OS for professionals.

**One-liner:** Your identity, schedule, meetings, and work — all connected, all intelligent.

**Replaces:** HiHello (cards) + Cal.com (scheduling) + Otter.ai (meeting AI) + Todoist (tasks)

**The magic:** Everything talks to each other. A card contact becomes a meeting participant. A meeting generates tasks via AI. The AI knows your schedule, your people, your conversations.

**Target:** Solo professionals first. Teams later (future scope — do not build for teams now).

---

## Repos

| Repo | Role | Port |
|------|------|------|
| `calendar-backend` | Node.js + Express API — all business logic | 3000 |
| `calendar-frontend` | React + Vite dashboard — meetings, cards, settings (auth required) | 5173 |
| `cards-frontend` | Next.js — all public-facing pages (no auth, SEO-critical) | 5174 |

**`cards-frontend` is the public frontend** — all public, shareable, SEO-indexed URLs live here:
- `/:username` — public card / profile page
- `/schedule/:username` — availability + booking (Phase 2)
- `/m/:id` — published meeting (transcript, summary, tasks — Phase 1 P2)

`calendar-frontend` is the authenticated dashboard. No public routes live there.
Both repos are **fully independent** — no shared packages, no monorepo. Same design language (Tailwind + shadcn/ui) maintained by convention.

---

## How To Run

```bash
# Backend
cd calendar-backend
pnpm install
pnpm dev              # API server on :3000
pnpm dev:worker       # Bull job processor (separate terminal)
pnpm db:studio        # Prisma Studio (DB GUI)
pnpm db:migrate       # Run migrations
pnpm db:push          # Push schema without migration

# Frontend (dashboard)
cd calendar-frontend
pnpm install
pnpm dev              # Vite on :5173

# Public frontend (Next.js)
cd cards-frontend
pnpm install
pnpm dev              # Next.js on :5174
```

---

## Required Environment Variables

Create `calendar-backend/.env` from `.env.example`:

```bash
PORT=3000
DATABASE_URL="postgresql://..."        # PostgreSQL — NOT MongoDB
BASE_URL_SHORTNER=http://localhost:3000

# Auth
JWT_SECRET=""
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_CALLBACK_URL=""

# AI & Transcription
OPENAI_API_KEY=""                      # Required for AI features
DEEPGRAM_API_KEY=""                    # Required for transcription

# Storage
GCS_BUCKET_NAME=""                     # Google Cloud Storage
GCS_PROJECT_ID=""
GOOGLE_APPLICATION_CREDENTIALS=""

# Queue
UPSTASH_REDIS_REST_URL=""
UPSTASH_REDIS_REST_TOKEN=""

# Recall.ai (optional — enables auto-record for online meetings)
RECALL_API_KEY=""                     # Platform-level Recall.ai key
RECALL_WEBHOOK_SECRET=""              # HMAC signing key for webhook verification

# Optional
HARD_DELETE_ENABLED=false
AUTO_START_CRON=false
```

---

## Current Phase & Focus

**Phase 1.4 — Recall.ai Platform Integration** ✅ Complete

Recall.ai is now a platform-level service. One `RECALL_API_KEY` in `.env`, users get a simple toggle.

**Phase 1 through 1.4 complete ✅. Moving to Phase 2.**

Full roadmap: `docs/roadmap.md`

---

## Architecture

```
calendar-frontend  ──┐
                     ├──► calendar-backend ──► PostgreSQL (Prisma)
cards-frontend     ──┘         │
                               ├──► Google Cloud Storage (recordings)
                               ├──► Deepgram (transcription)
                               ├──► OpenAI (AI summaries, Ask AI)
                               └──► Redis/Bull (job queues)
```

API base: `/api/v1/`

Key route groups:
- `/auth/*` — Google OAuth, JWT
- `/meetings/*` — Meeting CRUD
- `/cards/*` — Card management (auth required)
- `/public/cards/*` — Public card pages (no auth)
- `/public/meetings/:shortId` — Published meeting pages (no auth — Phase 1 P2)
- `/sma/*` — Smart Meeting Assistant (transcription, AI, Ask AI)
- `/users/*` — Profile management

---

## Tech Stack

**Backend:** Express 5, TypeScript 5, Prisma 6, PostgreSQL, Bull + Redis, OpenAI, Deepgram, GCS, Zod, Pino

**Dashboard (`calendar-frontend`):** React 19, TypeScript 5, Vite, React Router 7, TanStack Query v5, Zustand, TailwindCSS 4, shadcn/ui, Motion, Sonner, Lucide

**Public (`cards-frontend`):** Next.js (App Router), TypeScript 5, TailwindCSS 4, shadcn/ui — SSR for SEO

**Package manager:** pnpm (always — never npm or yarn)

---

## Backend Conventions

**Pattern:** Controller → Service → Prisma (never skip layers)

```typescript
// Always use AppError for errors
throw new AppError("Meeting not found", 404);

// Always use global response handler
return globalResponseHandler(res, 200, "Meeting created", data);

// Always validate with Zod schemas
const validated = meetingSchema.parse(req.body);

// Always use logger, never console.log
logger.info("Meeting created", { meetingId });
logger.error("Failed", { error });

// Always use transactions for multi-step DB ops
await prisma.$transaction(async (tx) => { ... }, { timeout: 15000 });

// All IDs are UUIDs — never auto-increment
```

**Auth:** All protected routes use `verifyJWT` middleware. Never skip it.

**Validation:** Zod on every route input. Schemas live in `src/validators/`.

---

## Frontend Conventions

```typescript
// Data fetching — always React Query, never useEffect + fetch
const { data } = useQuery({ queryKey: queryKeys.meetings.all(), queryFn: ... });

// Mutations — always useMutation with toast feedback
const mutation = useMutation({ onSuccess: () => toast.success("Done") });

// App state — Zustand stores only (authStore, themeStore, uiStore, toolbarStore)

// Notifications — always Sonner toast, never alert()
toast.success("Meeting created");
toast.error("Something went wrong");

// Animations — Motion (Framer Motion). Wrap pages in <PageMotion>

// Components — shadcn/ui first, then custom. @ alias for src/

// Dark mode — every component must support it (use Tailwind dark: prefix)
```

**Query keys:** Always use `src/lib/queryKeys.ts` — never hardcode strings.

**No mock data in production components.** If data isn't ready, show a skeleton or empty state.

---

## Smart Meeting Assistant (SMA) — How It Works

```
Upload recording → GCS → Deepgram (Nova-2, diarize) → TranscriptSegment[]
                                                              ↓
                                                    OpenAI processing (parallel)
                                                    ├── Summary
                                                    ├── Key points
                                                    └── Action items
```

Transcription status: `NONE → UPLOADED → PROCESSING → COMPLETED`

Frontend polls `/sma/meetings/:id/transcript/status` until `COMPLETED`.

**Ask AI (to build):**
```
POST /sma/meetings/:id/ask
{ question: string }
→ Fetch transcript → Build OpenAI prompt → Stream response
```

Full AI design: `docs/ai-brain.md`

---

## Database

**PostgreSQL only.** Prisma ORM. Schema: `calendar-backend/prisma/schema.prisma`

Key models: `User`, `Meeting`, `MeetingRecording`, `MeetingTranscript`, `TranscriptSegment`, `MeetingAISummary`, `MeetingActionItem`, `MeetingNote`, `Card`, `CardContact`, `CardView`

All soft deletes — never hard delete unless `HARD_DELETE_ENABLED=true`.

---

## What NOT To Do

- Do NOT use MongoDB — the database is PostgreSQL
- Do NOT use npm or yarn — use pnpm
- Do NOT add public-facing routes to `calendar-frontend` — all public URLs live in `cards-frontend`
- Do NOT build Teams features — future scope
- Do NOT skip `verifyJWT` on protected routes
- Do NOT use `console.log` — use `logger`
- Do NOT use `any` in TypeScript — use proper types
- Do NOT hardcode mock data in components — connect to real API
- Do NOT edit `.env` files directly
- Do NOT start Phase 3 (Big Brain) until Phase 2 is complete

---

## Docs

- `README.md` — Product vision and overview
- `docs/product.md` — Full feature spec, what's built vs not
- `docs/roadmap.md` — Phased roadmap with task checklist
- `docs/architecture.md` — System design and data flows
- `docs/ai-brain.md` — AI per-meeting brain + Big Brain design
- `docs/dev-notes/` — Per-task implementation notes, gotchas, and patterns. Read before working on related features.
