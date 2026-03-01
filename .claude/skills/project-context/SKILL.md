---
name: project-context
description: Load full Crelyzor project context. Use this automatically at the start of any session to understand the product, phase, conventions, and what needs to be built.
user-invocable: false
---

Load this context before doing any work on Crelyzor:

## Product

Crelyzor is an all-in-one productivity OS for solo professionals.
Pillars: Digital Cards + Smart Meeting AI + Scheduling (Phase 1.2) + Tasks (Phase 3) + Big Brain AI (Phase 2)
Teams is future scope — do not build.

## Current Phase

Phase 1 — Offline First.

Focus: Make the meeting experience complete end-to-end:
1. Wire MeetingDetail frontend to real backend data
2. Build Ask AI (per-meeting chat with transcript as context)
3. Polish home dashboard
4. Polish cards

Do not start Phase 1.2 (Recall.ai, Cal.com scheduling) until Phase 1 tasks are done.

## Repos

| Repo | Role | Port |
|------|------|------|
| `calendar-backend` | Express API — all business logic | 3000 |
| `calendar-frontend` | React dashboard | 5173 |
| `cards-frontend` | Public card pages only | 5174 |

## Co-CEO Mindset

You are both the developer AND the strategic partner. When you see something that:
- Could cause a bug → fix it
- Violates conventions → fix it
- Is a better approach → suggest it

But always stay focused on the current phase task. Do not rabbit-hole into refactoring.

## Before Writing Any Code

Always read:
1. The relevant repo's `CLAUDE.md` for conventions
2. The existing file you're modifying
3. Any related service/type files

## Key Conventions (Quick Reference)

**Backend:** Controller → Service → Prisma. AppError, globalResponseHandler, Zod, logger, verifyJWT, transactions.

**Frontend:** React Query for data, Zustand for state, shadcn/ui for components, Motion for animation, Sonner for toasts. Dark mode on everything. PageMotion on every page.

**Database:** PostgreSQL + Prisma. All IDs are UUIDs. Soft deletes only.

**Package manager:** pnpm always.

## Task Lists

- Root: `TASKS.md`
- Backend: `calendar-backend/TASKS.md`
- Frontend: `calendar-frontend/TASKS.md`
- Cards: `cards-frontend/TASKS.md`
