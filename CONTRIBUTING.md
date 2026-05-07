# Contributing to Crelyzor

Thanks for taking the time to contribute. Crelyzor is an open-source productivity OS for professionals — your contributions directly improve the product for everyone.

---

## Table of Contents

- [Before You Start](#before-you-start)
- [How to Contribute](#how-to-contribute)
- [Local Setup](#local-setup)
- [Branch Naming](#branch-naming)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [Code Standards](#code-standards)
- [Issue Triage](#issue-triage)

---

## Before You Start

- Check [open issues](https://github.com/crelyzor/crelyzor-workspace/issues) — your idea or bug may already be tracked
- For large changes, open an issue first to discuss before writing code
- Look for issues labelled [`good first issue`](https://github.com/crelyzor/crelyzor-workspace/issues?q=label%3A%22good+first+issue%22) if you're new here
- Read the [Code of Conduct](CODE_OF_CONDUCT.md) — we hold everyone to it

---

## How to Contribute

| Type | What to do |
|------|-----------|
| Bug | Open a **Bug Report** issue, then submit a PR referencing it |
| Feature | Open a **Feature Request** issue first — get it `approved` before building |
| Enhancement | Open an **Enhancement** issue or comment on an existing one |
| Docs | PRs welcome directly, no issue needed |
| Refactor | Comment on an existing issue or open one before large refactors |

---

## Local Setup

**Requirements:** Node 20+, pnpm 10+, Docker

```bash
# Clone the workspace
git clone https://github.com/crelyzor/crelyzor-workspace.git
cd crelyzor-workspace

# Start everything (Postgres + Redis included)
docker compose up

# First time only — run migrations after Postgres is up
docker compose exec backend pnpm db:migrate

# Services
# Backend API      → http://localhost:4000
# Dashboard        → http://localhost:5173
# Public site      → http://localhost:5174
```

Copy `crelyzor-backend/.env.example` to `crelyzor-backend/.env` and fill in the required values. Most features work without external API keys — transcription (Deepgram) and AI (OpenAI) require keys to function.

---

## Branch Naming

Branch off `dev`. Use this convention:

```
<type>/<short-description>
```

| Type | When |
|------|------|
| `feat/` | New feature |
| `fix/` | Bug fix |
| `chore/` | Maintenance, deps |
| `refactor/` | Code restructure, no behavior change |
| `docs/` | Documentation only |

Examples: `feat/task-recurring-rules`, `fix/calendar-tz-drift`, `docs/setup-guide`

---

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>
```

```bash
feat(tasks): add recurring rule UI picker
fix(calendar): correct timezone offset for DST
chore(deps): bump pnpm to 10.2
docs(contributing): add local setup steps
```

Scopes mirror the area labels: `backend`, `frontend`, `public`, `infra`, `billing`.

---

## Pull Request Process

1. Fork the repo and branch off `dev`
2. Make your changes — keep the PR focused (one thing per PR)
3. Run `pnpm tsc --noEmit` and `pnpm lint` — both must pass
4. Open a PR against `dev` using the PR template
5. A maintainer will review within a few days
6. Once approved and CI passes, a maintainer merges it

**PRs that touch `staging` or `main` directly are not accepted.** Everything goes through `dev` first.

---

## Code Standards

**Backend (`crelyzor-backend`)**
- Always use `AppError` — never throw plain `Error`
- Always use `globalResponseHandler` — never `res.json()` directly
- Always use `logger` — never `console.log`
- Always validate with Zod on every route input
- Always use `verifyJWT` on protected routes
- No `any` types

**Frontend (`crelyzor-frontend`, `crelyzor-public`)**
- Data fetching via React Query — never bare `useEffect + fetch`
- Toasts via Sonner — never `alert()`
- Every component must support dark mode (`dark:` prefix)
- No hardcoded hex values — use CSS variables via Tailwind classes

Full conventions in each repo's `CLAUDE.md`.

---

## Issue Triage

Issues go through this lifecycle:

```
opened (triage) → approved → in progress → closed
```

- **`triage`** — needs maintainer review. Don't start work on these.
- **`approved`** — safe to pick up and build. Comment to claim it.
- **`blocked`** — waiting on something. Don't pick up.
- **`wontfix`** — won't be built. Closed with explanation.

If you want to work on an `approved` issue, leave a comment saying so. We'll assign it to you so there's no duplicate work.
