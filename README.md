# Crelyzor

> One workspace. Your identity, your schedule, your meetings, your work — all connected.

Professionals today juggle 5+ disconnected tools. Crelyzor collapses them into one product where everything knows about everything else.

---

## What Crelyzor Is

| Pillar | What It Replaces | Core Value |
|--------|-----------------|------------|
| Digital Cards | HiHello, Blinq | Your identity — shareable, scannable, always live |
| Smart Meetings | Otter.ai, Fireflies | Record offline or online → AI transcribes, summarizes, extracts action items |
| Scheduling | Cal.com, Calendly | Availability, booking links, Google Calendar sync |
| Tasks | Todoist | Tasks linked to meetings, contacts, AI-generated |
| AI Brain | — | One AI that knows your schedule, people, meetings, and work |

---

## The Difference

Everything is connected.

- A card contact becomes a meeting participant
- A meeting generates tasks automatically via AI
- The AI knows your schedule, your people, your conversations
- Ask your meeting "What did John say about the budget?" — it answers

---

## Who It's For

**Phase 1:** Solo professionals — founders, consultants, freelancers, sales reps
**Future:** Teams — shared workspaces, collaborative meeting AI, team cards

---

## Repos

| Repo | Role |
|------|------|
| `crelyzor-backend` | Node.js + Express + PostgreSQL — all API and business logic |
| `crelyzor-frontend` | React app — main dashboard (cards, meetings, settings) |
| `crelyzor-public` | Next.js — public pages (cards, scheduling, SEO) |

## Running Locally

```bash
docker compose up
```

All services start including Postgres. Hot reload enabled. See `CLAUDE.md` for details.

---

## Docs

- [Product Spec](./docs/product.md) — Features, user flows, what's built
- [Roadmap](./docs/roadmap.md) — Phase 1 → Big Brain → Teams
- [Architecture](./docs/architecture.md) — System design, tech stack, integrations
- [AI Brain](./docs/ai-brain.md) — Per-meeting AI, Ask AI, Big Brain
