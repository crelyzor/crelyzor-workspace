# Crelyzor — Architectural Decisions

When you ask "why did we build it this way?" — the answer is here.

---

## Database

### PostgreSQL over MongoDB
**Date:** Project start
**Decision:** PostgreSQL + Prisma ORM
**Why:**
- Meeting data is relational — meetings have participants, participants have roles, recordings have transcripts, transcripts have segments. Document DB would require constant denormalization.
- Prisma gives type-safe queries with zero boilerplate
- Neon (serverless Postgres) works perfectly with Vercel-style deployments
- MongoDB was considered but rejected — the relational nature of the data made it the wrong fit

---

## AI & Transcription

### Deepgram over OpenAI Whisper
**Date:** Phase 1
**Decision:** Deepgram Nova-2 for transcription
**Why:**
- Deepgram has native speaker diarization (who said what) — Whisper does not
- Deepgram is faster and cheaper at scale
- Same Deepgram credentials work with Recall.ai for Phase 1.2 (online meetings)
- Whisper considered but rejected due to no diarization support

### GPT-4o-mini over GPT-4o for Meeting Processing
**Date:** Phase 1
**Decision:** GPT-4o-mini for summary, key points, action items
**Why:**
- Meeting transcripts fit comfortably in 4o-mini's context window
- 10x cheaper than GPT-4o with acceptable quality for structured extraction
- GPT-4o reserved for Big Brain (Phase 2) where reasoning quality matters more
- Upgrade path clear: swap model string when needed

### Recall.ai for Online Meeting Bot (Phase 1.2)
**Date:** Roadmap decision
**Decision:** Recall.ai over building our own bot
**Why:**
- Building a Zoom/Google Meet bot requires maintaining separate OAuth apps, bot infrastructure, recording pipelines
- Recall.ai handles all of this and supports streaming audio to Deepgram with our own credentials
- Same AI pipeline from Phase 1 works unchanged
- Cost is justified vs. engineering time to build custom bot

---

## Architecture

### Monorepo (3 repos in one folder) over Full Monorepo
**Date:** Project start
**Decision:** 3 independent repos under `/Calendar/` root, not pnpm workspaces
**Why:**
- `cards-frontend` needs to be deployed independently (different URL, no auth)
- `calendar-frontend` and `calendar-backend` have completely different deployment needs
- Keeping them independent avoids shared dependency conflicts
- Root `package.json` provides `pnpm dev` convenience without full workspace complexity

### Separate `cards-frontend` repo
**Date:** Project start
**Decision:** Public card pages live in their own repo, not inside `calendar-frontend`
**Why:**
- Public cards are served from a different domain (`card.yourdomain.com` vs `app.yourdomain.com`)
- Zero auth requirements — completely different security posture
- Should be ultra-fast and minimal — no dashboard bundle weight
- SEO requirements differ (public pages need proper meta tags, dashboard doesn't)

### Bull + Redis for Job Queue
**Date:** Phase 1
**Decision:** Bull (with Upstash Redis) for async job processing
**Why:**
- Transcription takes 30-120 seconds — can't hold an HTTP connection open
- Bull provides retry logic, job status, and failure handling out of the box
- Upstash Redis = serverless Redis, no infrastructure to manage
- Worker runs as separate process (`pnpm dev:worker`)

---

## Frontend

### Zustand over Redux / Context
**Date:** Project start
**Decision:** Zustand for global state
**Why:**
- Redux is overkill for this app's state complexity
- Context causes unnecessary re-renders at scale
- Zustand is minimal, TypeScript-native, and has built-in persistence middleware
- Used only for: auth state, theme, UI state, toolbar pins

### TanStack Query over SWR / raw useEffect
**Date:** Project start
**Decision:** React Query for all server state
**Why:**
- Caching, background refetching, optimistic updates, and pagination built-in
- Eliminates all `useEffect` + `useState` data fetching patterns
- Query invalidation model is clean and predictable
- SWR considered but React Query has better TypeScript support

### shadcn/ui over MUI / Ant Design / Chakra
**Date:** Project start
**Decision:** shadcn/ui as component foundation
**Why:**
- shadcn components are copy-owned — no dependency lock-in
- Radix UI primitives provide accessibility without visual opinions
- TailwindCSS integration is native — no style conflicts
- Full design control over every pixel (critical for Crelyzor's aesthetic)
- MUI/Ant rejected — too opinionated, hard to customize to our neutral palette

### Neutral-Only Color Palette
**Date:** Design decision
**Decision:** Zero hue/saturation in color system. Pure neutrals + one gold accent (cards only).
**Why:**
- Timeless — won't look dated in 2 years
- Forces clarity — meaning comes from layout and typography, not color
- Premium feel — luxury brands use minimal color
- Accessibility — contrast ratios are easier to maintain with neutrals

---

## Auth

### Google OAuth Only (Phase 1)
**Date:** Project start
**Decision:** Google OAuth as the only auth method
**Why:**
- Solo professionals all have Google accounts
- Google Calendar integration requires Google OAuth anyway
- Reduces attack surface (no password storage, no reset flows)
- Email/password can be added later if demand exists

---

## Deployment (Future Reference)

### Backend on Vercel (original plan)
- `vercel.json` exists in `calendar-backend`
- Can deploy as serverless functions
- Note: Bull/Redis worker cannot run on Vercel — needs separate process

### Neon PostgreSQL
- Serverless Postgres — scales to zero, no infra management
- Connection pooling via `?sslmode=require`
- Region: ap-southeast-1 (Singapore)
