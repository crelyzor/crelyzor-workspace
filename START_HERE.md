# Start Here — Crelyzor

---

## First time?

→ Read `SETUP.md` first. Come back here after.

---

## Running the project

```bash
docker compose up
```

| Service | URL |
|---------|-----|
| Backend API | http://localhost:3000 |
| Dashboard | http://localhost:5173 |
| Public site | http://localhost:5174 |

---

## What Is Crelyzor

An all-in-one productivity OS for solo professionals.

Replaces: HiHello + Cal.com + Otter.ai + Todoist — in one product where everything is connected.

- **Digital Cards** — shareable, scannable business card with QR and vCard
- **Smart Meeting AI** — record meetings → AI transcribes, summarizes, extracts tasks
- **Ask AI** — chat with any meeting: "What did John say about the budget?"
- **Scheduling** — availability and booking links
- **Tasks** — linked to meetings, AI-generated

Teams is future scope only. Building solo-first.

---

## Repos

| Folder | What It Is | Port |
|--------|-----------|------|
| `crelyzor-backend` | Node.js + Express API | 3000 |
| `crelyzor-frontend` | React dashboard (auth required) | 5173 |
| `crelyzor-public` | Next.js public pages (SEO) | 5174 |

---

## Key Files

```
crelyzor-workspace/
├── SETUP.md               ← First time setup
├── START_HERE.md          ← You are here
├── TASKS.md               ← Master task list (all phases)
├── CLAUDE.md              ← Project conventions (Claude reads this)
├── docker-compose.yml     ← Dev environment
├── docker-compose.staging.yml
├── docker-compose.prod.yml
├── deploy.sh              ← ./deploy.sh prod | staging
│
├── docs/
│   ├── product.md         ← Full feature spec
│   ├── roadmap.md         ← Phase roadmap
│   ├── architecture.md    ← System design
│   └── ai-brain.md        ← AI design
│
├── crelyzor-backend/
│   ├── CLAUDE.md          ← Backend conventions
│   └── prisma/schema.prisma
│
├── crelyzor-frontend/
│   └── CLAUDE.md          ← UI/design system
│
└── crelyzor-public/
    └── CLAUDE.md          ← Public site conventions
```

---

## Current Phase

**Phase 4.5 — Docker & Deployment** (in progress)

See `TASKS.md` for the full breakdown.

---

## Claude Code Workflow

```bash
/crelyzor-start    # start of every session
/crelyzor          # each subsequent task
```

Skills: `new-endpoint` · `new-page` · `frontend-design` · `review`
