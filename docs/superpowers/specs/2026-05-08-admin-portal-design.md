# Admin Portal — Design Spec

**Date:** 2026-05-08
**Phase:** Post-4.6 (independent of main roadmap phases)
**Status:** Approved — ready for implementation planning

---

## Problem

No admin tooling exists. Plan upgrades happen manually via Prisma Studio. There is no visibility into user signups, usage across the platform, or any operational controls. As Razorpay is blocked, manual plan management is the only path to monetization right now.

---

## Decision

Build a separate `crelyzor-admin` repo — a standalone React + Vite admin portal that talks to a new `/api/v1/admin/*` route group on the backend. It does not share code with `crelyzor-frontend` or `crelyzor-public`. It is not started by default — it has its own `make admin-up` command via Docker Compose profiles.

---

## Architecture

```
crelyzor-admin (React + Vite, port 5175)
        │
        │  POST /api/v1/admin/auth/login  → own JWT
        │  GET/PATCH /api/v1/admin/*      → verifyAdmin middleware
        ▼
crelyzor-backend
        │
        └──► PostgreSQL (same DB, same Prisma client)
```

Admin frontend talks only to the backend API. No direct DB access. Same architectural pattern as `crelyzor-frontend`.

---

## Auth

Not Google OAuth. Not user accounts.

- Two env vars: `ADMIN_EMAIL` and `ADMIN_PASSWORD` in `crelyzor-backend/.env.local`
- `POST /api/v1/admin/auth/login` validates credentials against env vars, returns a signed JWT with `{ role: 'admin' }` claim
- `verifyAdmin` middleware on all `/admin/*` routes verifies this JWT
- Admin frontend stores token in `localStorage`, attaches as `Authorization: Bearer <token>` on all requests
- When Razorpay or team member access is needed later: swap to a proper `AdminUser` table with no disruption to the rest of the system

---

## Backend Changes

### New middleware
`src/middleware/verifyAdmin.ts` — verifies admin JWT, rejects with 401 if missing or invalid

### New route group
`src/routes/adminRoutes.ts` — all routes under `/api/v1/admin/`

### Endpoints (v1)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/admin/auth/login` | Validate credentials → return JWT |
| `GET` | `/admin/users` | List all users — id, name, email, plan, createdAt, usage totals |
| `GET` | `/admin/users/:id` | Single user detail + full usage breakdown |
| `PATCH` | `/admin/users/:id/plan` | Upgrade or downgrade plan (`FREE \| PRO \| BUSINESS`) |
| `PATCH` | `/admin/users/:id/usage/reset` | Manually reset usage counters for a user |
| `GET` | `/admin/stats` | Platform totals — total users, plan breakdown, monthly usage aggregates |

### New service
`src/services/adminService.ts` — all admin-specific queries. Never shares logic with user-facing services.

---

## Frontend (crelyzor-admin)

### Stack
React 19, TypeScript 5, Vite, TanStack Query v5, TailwindCSS 4, shadcn/ui, React Router, Sonner, Lucide. pnpm. Same versions as `crelyzor-frontend`.

### Pages (v1)

**`/login`**
Email + password form. On success stores JWT, redirects to `/`. On invalid credentials shows inline error. No "forgot password" — env-based credentials.

**`/` — Dashboard**
Platform stats cards:
- Total users
- Users by plan (Free / Pro / Business)
- Transcription minutes consumed this month (platform total)
- AI credits consumed this month (platform total)
- Recall hours consumed this month (platform total)

**`/users` — Users Table**
Paginated table. Columns: Avatar + Name, Email, Plan badge (color-coded), Transcription used/limit, AI Credits used/limit, Recall hrs used/limit, Joined date.

Click a row → right-side panel slides open:
- Full user detail
- Plan selector dropdown (FREE / PRO / BUSINESS) → `PATCH /admin/users/:id/plan`
- "Reset usage" button → `PATCH /admin/users/:id/usage/reset` with confirmation dialog
- Usage bars for each resource type

### Auth guard
`<AdminRoute />` wrapper — checks for valid JWT in localStorage. Redirects to `/login` if missing. No public routes except `/login`.

### No mock data
All data from API. Skeleton loaders while fetching.

---

## Infrastructure

### Docker Compose profile

New service added to `docker-compose.local.yml`:

```yaml
admin:
  profiles: ["admin"]
  build:
    context: ./crelyzor-admin
    target: deps
  command: pnpm dev --host 0.0.0.0
  ports:
    - "5175:5175"
  volumes:
    - ./crelyzor-admin:/app
    - /app/node_modules
```

`profiles: ["admin"]` means `make local-up` never starts it. Completely invisible to the normal dev flow.

### Makefile additions

```makefile
admin-up:
    docker compose -f docker-compose.local.yml --env-file .env.local --profile admin up -d

admin-down:
    docker compose -f docker-compose.local.yml --env-file .env.local --profile admin down

admin-logs:
    docker compose -f docker-compose.local.yml --env-file .env.local --profile admin logs -f admin
```

### Port allocation
- 4000 — backend
- 5173 — crelyzor-frontend
- 5174 — crelyzor-public
- **5175 — crelyzor-admin** ← new

### Production / staging
Admin portal is included in `docker-compose.prod.yml` and wired to `admin.crelyzor.app` via nginx. It is **not** in `docker-compose.staging.yml` — staging uses local-only access.

**Prerequisites before first prod deploy:**
1. Clone `crelyzor-admin` on the VM alongside the other repos
2. Provision the SSL cert: `certbot certonly --nginx -d admin.crelyzor.app`

---

## Skill Updates

`crelyzor-start` skill updated to:
- Read `crelyzor-admin/TASKS.md` on session start
- Include `crelyzor-admin` git status in session briefing
- Show admin tasks in `IN PROGRESS` and `NOT STARTED` sections

---

## What Is NOT in v1

- Content moderation / flagging
- System health graphs (queue depth, error rates)
- Email-based admin invites / team member access
- Audit log of admin actions
- Production deploy of admin portal
- Razorpay subscription management UI

These are explicitly deferred. Do not build.

---

## Repo Structure (crelyzor-admin)

```
crelyzor-admin/
├── src/
│   ├── components/
│   │   ├── ui/               # shadcn/ui components
│   │   └── AdminRoute.tsx    # auth guard
│   ├── pages/
│   │   ├── LoginPage.tsx
│   │   ├── DashboardPage.tsx
│   │   └── UsersPage.tsx
│   ├── services/
│   │   └── adminService.ts   # all API calls
│   ├── lib/
│   │   ├── queryKeys.ts
│   │   └── apiClient.ts      # axios instance with admin JWT interceptor
│   ├── App.tsx
│   └── main.tsx
├── Dockerfile
├── .env.local
├── package.json
├── vite.config.ts
└── TASKS.md
```
