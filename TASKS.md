# Crelyzor — Master Task List

Last updated: 2026-05-23 (Phase 6 Teams — spec revised with per-team DEK + full UX, tasks restructured across all repos)

> **Rule:** When you complete a task, change `- [ ]` to `- [x]` and move it to the Done section.
> **Legend:** `[ ]` Not started · `[~]` Has code but broken/incomplete · `[x]` Done and working

See per-repo tasks for implementation details:

- [crelyzor-backend/TASKS.md](./crelyzor-backend/TASKS.md)
- [crelyzor-frontend/TASKS.md](./crelyzor-frontend/TASKS.md)
- [crelyzor-public/TASKS.md](./crelyzor-public/TASKS.md)

---

## Naming Decisions

- **"Tasks"** — the feature is called Tasks everywhere, always. Not "action items", not "todo".
  The DB model is `Task` from day one (see below). `MeetingActionItem` is being dropped.
- **"Ask AI"** — meeting-level for Phase 1. Global AI = Phase 2 Big Brain (separate).
- **"Tags"** — universal system. Hits meetings + cards in Phase 1. Tasks + everything else in Phase 3.

## Task Model Decision

We are building the `Task` model **now** (P0 backend), not in Phase 3.

Rationale: `MeetingActionItem` was always a placeholder. Migrating it later (when there's real user data)
means a painful data migration + API breaking changes. Doing it now costs one schema migration and one
service update — before any frontend is built.

```
Task {
  id, userId, meetingId (nullable), title, description,
  isCompleted, completedAt, dueDate, priority, source (AI_EXTRACTED | MANUAL),
  createdAt, updatedAt, isDeleted, deletedAt
}
```

- Meeting-linked task: `meetingId` set, `source: AI_EXTRACTED` (from AI pipeline) or `MANUAL`
- Standalone task (Phase 3): `meetingId: null`
- `MeetingActionItem` model will be dropped after migration

---

## Phase 1 — Current State

### Working ✅

- Cards (create, edit, public page, QR, vCard, contacts, analytics)
- Google OAuth sign-in
- Meeting CRUD (create, update, cancel, complete)
- Meetings list — type toggle, skeleton, context menu actions
- Recording upload → GCS → Deepgram transcription → OpenAI AI processing
- Live recording via browser microphone (FAB)
- MeetingDetail — 3 distinct layouts (VoiceNoteDetail / RecordedDetail / ScheduledDetail)
- MeetingDetail — wired to real API (transcript, summary, tasks display, recording player, all action buttons)
- AI title generation, Retry AI button
- MeetingType system (SCHEDULED | RECORDED | VOICE_NOTE)
- MeetingSpeaker — auto-created after transcription, rename, get endpoints
- Voice Notes — separate page, sidebar nav, home widget
- Home dashboard — recent meetings, recent voice notes, widgets, skeleton
- Settings — theme, profile, URL-based tabs
- Cmd+K command palette
- Skeleton loading on all pages
- Theme flash eliminated, light mode softened
- Auth refresh token (backend + frontend interceptor)
- Meeting notes UI — create, delete, timestamp, all 3 layouts
- Tasks UI — CRUD, optimistic toggle, inline create, ⋯ copy menu, all 3 layouts
- Edit meeting modal (SCHEDULED — title, description, time, location, conflict detection)
- Delete meeting (VoiceNote + Recorded — confirm dialog, nav back)
- Ask AI — streaming SSE endpoint + chat panel in all 3 layouts (suggestion chips, session history)
- Button/modal theming fixed — Tailwind v4 CSS variable utilities now resolve correctly
- Share sheet — Copy transcript/summary, Download audio, Share via email (all 3 layouts)
- Regenerate title + summary (quick-action buttons, all 3 layouts)
- AI content generation — Meeting Report, Tweet, Blog Post, Follow-up Email (cached in DB, all 3 layouts)

---

### P1 — AI & Sharing ✅ Done

1. ~~**Frontend:** Share sheet — Copy transcript, Copy summary, Download Audio (all types)~~ ✅
2. ~~**Backend + Frontend:** Regenerate — title, summary (quick-action buttons, simple re-trigger endpoints)~~ ✅
3. ~~**Backend + Frontend:** AI content generation — Meeting Report, Tweet, Blog Post, Follow-up Email~~ ✅
4. ~~**Backend + Frontend:** Ask AI — streaming SSE + chat panel (suggestion chips, session history)~~ ✅

---

### P2 — Public Links & Power Features ← current focus

1. ~~**`cards-frontend`:** Migrate to Next.js App Router — mobile-first, PWA setup, SSR + SEO + OG previews~~ ✅
2. ~~**Backend + Frontend + Public:** Public meeting links~~ ✅
3. ~~**Backend + Frontend:** Export — Transcript as PDF/TXT, Summary as PDF/TXT~~ ✅
4. ~~**Backend + Frontend:** Tags — universal system (meetings + cards backend + meetings UI)~~ ✅ (tags on voice notes + cards UI still needed — see below)
5. ~~**Backend + Frontend:** Attachments — file/photo/link on meetings~~ ✅
6. ~~**Backend + Frontend:** Edit transcript segments + summary content inline~~ ✅
7. ~~**Backend + Frontend:** Regenerate transcript, Change language (re-run Deepgram)~~ ✅
8. ~~**Frontend (`calendar-frontend`):** Mobile responsiveness + UI revamp~~ ✅

---

### UX & Polish (discovered during P2) ✅ Done

1. ~~**Tags truly universal** — tags on Voice Notes listing + Cards listing + tag editor on Cards dashboard~~ ✅
2. ~~**Meeting list click UX** — single click navigates to detail, context menu handles actions~~ ✅
3. ~~**RECORDED meeting status badge** — hidden for RECORDED, shown only for SCHEDULED~~ ✅
4. ~~**Hover jitter on meeting list** — scoped to `border-color` + `box-shadow` only~~ ✅
5. ~~**Ask AI persistence** — per-meeting conversation history persisted in PostgreSQL, seeded on mount, rolling 6-message context window, clear chat~~ ✅ (Phase 4.2)

---

### Not Built Yet ❌

- Nothing. Phase 1 P2 is complete. ✅

---

## Phase 1.2 — Scheduling & Online Meetings ✅ Complete

Full design doc: `docs/dev-notes/phase-1.2-scheduling.md`

All 20 tasks complete — scheduling engine, booking pages, GCal integration (booking-scoped), Recall.ai.

---

## Phase 1.3 — Google Calendar Deep Integration ✅ Complete

Full design doc: `docs/dev-notes/phase-1.3-gcal.md`
Per-repo task breakdowns: each repo's `TASKS.md`

All 13 tasks complete — schema migration, GCal write sync (create/update/cancel/delete), events endpoint, unified TodayTimeline, meet link UX in all layouts, Settings > Integrations fully wired.

---

## Phase 1.4 — Recall.ai Platform Integration ✅ Complete

Full design doc: `docs/dev-notes/phase-1.4-recall-platform.md`

Move Recall.ai from per-user BYO-key to platform-level service. One `RECALL_API_KEY` in `.env`, users get a simple toggle.

### Backend

- [x] Schema: drop `recallApiKey` from UserSettings, keep `recallEnabled`
- [x] Env: add `RECALL_API_KEY`, remove `RECALL_ENCRYPTION_KEY`
- [x] Remove `PUT /settings/recall-api-key` endpoint + encryption utilities
- [x] Refactor `recallService.ts` — read key from env, add `join_at` + `automatic_leave` config
- [x] Refactor worker — remove per-user key fetch + decrypt
- [x] Refactor booking confirm — simplified recallEnabled check (was already clean)
- [x] Update `GET /settings/user` — `recallAvailable` flag replaces `hasRecallApiKey`
- [x] Expand bot deploy: manual SCHEDULED meetings with video links (not just bookings)
- [x] URL allowlist validation (`isVideoMeetingUrl`) — only known video platforms passed to Recall

### Frontend

- [x] Remove API key input + save from Settings > Integrations
- [x] Toggle shown only when `recallAvailable === true`
- [x] Copy: "Auto-record online meetings" (don't expose vendor name)
- [x] Remove dead types, services, hooks

### Cleanup

- [x] Remove dead code (encryption.ts, recallApiKeySchema, useSaveRecallApiKey)
- [x] Update `.env.example`

---

## Phase 2 — Standalone Tasks ✅ Complete

- [x] Task list page (Todoist-style — filter by status, priority, due date, meeting source)
- [x] Standalone tasks API — `GET /tasks` (all tasks, not scoped to a meeting) + `POST /tasks` (standalone create)
- [x] Tags on Tasks (`TaskTag` junction — extends universal Tag system)
- [x] `scheduledTime` field on Task (for calendar placement in Phase 3)

---

## Phase 3 — Calendar View + Tasks on Calendar ← current focus

- [x] Tasks with `scheduledTime` appear on `TodayTimeline` as timed items
- [x] Tasks with only `dueDate` appear as "Due today" section on `TodayTimeline`
- [x] Full `/calendar` page — week/day view (GCal events + Crelyzor meetings + Tasks)
- [x] Tasks with `scheduledTime` appear as time blocks on calendar
- [x] Tasks with `dueDate` appear as all-day markers
- [x] Drag task to time slot → sets `scheduledTime`
- [x] Click empty slot → quick-create (Meeting | Task)

---

## Phase 3.2 — Polish, Enhancements & Power Features ← current focus

Full breakdown per repo:

- [crelyzor-backend/TASKS.md](./crelyzor-backend/TASKS.md)
- [crelyzor-frontend/TASKS.md](./crelyzor-frontend/TASKS.md)

### P0 — Bugs & Embarrassing Gaps (fix first)

- [x] **Frontend:** Fix "Reschedule meeting" button — remove "coming soon" toast, implement rescheduling
- [x] **Frontend:** Privacy Settings tab — removed (was empty placeholder)

### P1 — Quick Wins (high value, low effort)

- [x] **Frontend:** Task count badges on sidebar nav items (Inbox · Today · Upcoming)
- [x] **Frontend:** Overdue tasks section on home dashboard (above the timeline)
- [x] **Frontend:** NL parsing in inline task create form (same parser as Cmd+K)
- [x] **Backend + Frontend:** Task duration field — `durationMinutes` on Task schema + detail panel picker + calendar renders correct block height
- [x] **Frontend:** Jump-to-date on calendar — clicking the week label opens a date picker
- [x] **Frontend:** Email signature generator for cards

### P2 — Meaningful Features

- [x] **Backend:** Auto-create "Prepare for [meeting]" task on booking confirmed
- [x] **Frontend:** "New tasks from meeting" badge on home dashboard after AI processes
- [x] **Frontend:** Task bulk actions — select multiple, bulk complete / delete / set priority
- [x] **Frontend:** Card analytics — views trend chart + link click breakdown
- [x] **Frontend:** Onboarding flow for new users (empty state → guided first actions)

### P3 — Bigger Features

- [x] **Backend + Frontend:** Global search — across meetings, tasks, cards, contacts
- [x] **Frontend:** Calendar month view
- [x] **Frontend:** Keyboard shortcuts — J/K navigation, E edit, D due date, P priority, Enter open panel
- [x] **Backend + Frontend:** Schedule task → create GCal block (when scheduledTime is set)
- [x] **Backend + Frontend:** Meeting ↔ Card contact auto-linking (match participant email to card contact)

### P4 — Major Feature

- [x] **Backend + Frontend:** Recurring tasks — `recurringRule` (RRULE) on Task schema + UI picker + auto-generate next occurrence on complete

---

---

## Phase 3.3 — Close the Product Gaps

> Identified via full user-perspective product review (2026-04-04).
> Each gap below is something a real user would hit on their first week.

Full breakdown per repo:

- [crelyzor-backend/TASKS.md](./crelyzor-backend/TASKS.md)
- [crelyzor-frontend/TASKS.md](./crelyzor-frontend/TASKS.md)
- [crelyzor-public/TASKS.md](./crelyzor-public/TASKS.md)

### P0 — Fix the Front Door (public card page)

The public card page is what you hand to strangers. It currently has broken/missing states.

- [x] **Public:** Avatar fallback — show initials on gold background when no photo
- [x] **Public:** Loading skeleton — match card shape and dark bg while fetching
- [x] **Public:** Proper 404 — nice error page when card not found (not broken layout)
- [x] **Public:** Contact form validation — name required + email or phone required
- [x] **Public:** Contact form states — success state after submit, error state on fail, loading spinner during submit
- [x] **Public:** Smooth avatar image load — fade in, no layout shift
- [x] **Public:** Verify vCard download works on iOS and Android

### P1 — Email Notifications (the product is silent right now)

Not a single email is sent proactively. Productivity apps push value to you.

- [x] **Backend:** Transactional email service — integrate Resend (simple API, free tier, great DX)
- [x] **Backend:** Booking received — email to host when guest books (`bookingManagementService.ts`)
- [x] **Backend:** Booking confirmation — email to guest with details + calendar links (currently only stored in sessionStorage)
- [x] **Backend:** Booking reminder — email to both host + guest 24h before meeting
- [x] **Backend:** Meeting AI complete — email to user when transcript + summary are ready ("Your meeting '[title]' has been processed")
- [x] **Backend:** Daily task digest — 8am email with today's tasks + overdue items (Bull cron job, opt-in)
- [x] **Frontend:** Notification preferences in Settings — toggles for each email type

### P2 — Scheduling Completeness (can't replace Cal.com with these gaps)

- [x] **Backend + Frontend:** Guest cancellation link — include a cancel URL in the booking confirmation email. `PATCH /public/bookings/:id/cancel` already exists, just needs to be surfaced.
  - Frontend: New page `cards-frontend/src/app/bookings/[id]/cancel/page.tsx` — shows booking details (need to fetch `GET /public/bookings/:id` first) + "Cancel this booking" button + reason text area.
  - Backend: Add `GET /api/v1/public/bookings/:id` — returns public booking details.
- [x] **Backend + Frontend:** Guest reschedule — "Need to reschedule?" link in confirmation email → takes guest back to the date picker with the booking pre-loaded
- [x] **Frontend:** Minimum notice UI — expose `minNoticeHours` field on EventType editor (backend already supports it)
- [x] **Frontend:** Buffer time UI — expose `bufferBefore` / `bufferAfter` fields on EventType editor (backend already supports it)
- [x] **Frontend:** Max bookings per day UI — expose `maxPerDay` on EventType editor (backend already supports it)
- [x] **Backend + Frontend:** Booking cancelled notification — email to both parties when a booking is cancelled (host or guest)

### P3 — Connection Features (deliver the "everything talks" promise)

- [x] **Backend + Frontend:** Meeting ↔ Card contact auto-linking (already in P3.2 backlog — bump priority)
- [x] **Frontend:** Ask AI discovery — surface "Ask AI" as a prominent action on the meeting list row and home dashboard (not buried at the bottom of meeting detail)
- [x] **Backend:** Speaker memory — when user renames "Speaker 0" → "John Smith" in one meeting, remember the mapping so future meetings from the same voice are pre-labeled (requires voice fingerprint from Deepgram)

### P4 — Recurring Tasks (table stakes for task management)

- [x] **Backend + Frontend:** Recurring tasks — `recurringRule` (RRULE) on Task schema + UI picker + auto-generate next occurrence on complete

### P5 — Data Import (how people switch tools)

- [x] **Backend + Frontend:** Contact CSV import — upload a CSV, map columns (name, email, phone, company), bulk-create CardContacts on a chosen card
- [x] **Backend + Frontend:** Calendar import — import .ics file → create Meeting records for past meetings (gives AI something to process)

---

## Phase 3.4 — Global Tags ✅ Complete

> Tags already exist on meetings, cards, and tasks. This phase makes them truly global — adding contacts, adding a tags index page, and a tag detail page that shows everything tagged with a given tag across all entity types.

Full breakdown per repo:

- [crelyzor-backend/TASKS.md](./crelyzor-backend/TASKS.md)
- [crelyzor-frontend/TASKS.md](./crelyzor-frontend/TASKS.md)

### What's being built

**Tag universe after this phase:**

```
#any-tag
├── Meetings  (incl. voice notes)  — MeetingTag  ✅ exists
├── Cards                          — CardTag      ✅ exists
├── Tasks                          — TaskTag      ✅ exists
└── Contacts                       — ContactTag   ← new (ContactTag junction)
```

**New surfaces:**

- `/tags` — index page: all your tags with item counts per type
- `/tags/:tagId` — detail page: everything tagged with this tag, grouped by type
- Tag chips on contacts + tag editor on contact rows
- Tag chip anywhere in the app navigates to its tag detail page

### P0 — Schema (do first — everything depends on it)

- [x] **Backend:** `ContactTag` junction model + migrate `Tag` + `CardContact` relations
- [x] **Backend:** Add `contactTags` cleanup to `deleteTag` transaction

### P1 — Backend APIs

- [x] **Backend:** Contact tag endpoints (`GET/POST/DELETE /cards/:cardId/contacts/:contactId/tags/:tagId`)
- [x] **Backend:** `GET /tags/:tagId/items` — returns `{ tag, meetings[], cards[], tasks[], contacts[], counts }`
- [x] **Backend:** `listTags` updated to include counts per type

### P2 — Frontend: Tags Index + Detail Pages

- [x] **Frontend:** `/tags` index page — tag grid with counts, inline create, rename, delete
- [x] **Frontend:** `/tags/:tagId` detail page — 4 sections (Meetings / Cards / Tasks / Contacts)
- [x] **Frontend:** Register routes + add "Tags" to sidebar nav

### P3 — Frontend: Tags on Contacts

- [x] **Frontend:** Tag chips on contact rows in Cards contacts view
- [x] **Frontend:** Tag editor popover on contacts (same pattern as meetings/cards)
- [x] **Frontend:** Tag filter bar on contacts list

### P4 — Tag Chip Navigation

- [x] **Frontend:** Clicking any tag chip anywhere navigates to `/tags/:tagId`

---

## Phase 4.1 — Billing & Monetization ✅ Complete

Full design doc: `docs/pricing-and-costs.md`
Per-repo task breakdowns: each repo's `TASKS.md`

### Plans

- **Free** — 120 min transcription, 50 AI Credits, no Recall.ai
- **Pro ($19/mo)** — 600 min transcription, 1,000 AI Credits, 5 hrs Recall.ai
- **Business** — custom pricing, negotiated per deal

### P0 — Backend: Schema + Usage Service

- [x] `plan` enum on `User` — `FREE | PRO | BUSINESS`
- [x] `UserUsage` model — transcription minutes, Recall hours, AI credits, storage, reset date
- [x] `Subscription` model — Razorpay customer/subscription IDs, plan, status, period end
- [x] Migration
- [x] `usageService.ts` — check + deduct for each resource type
  - [x] Wire into transcription, Recall, AI services
  - [x] Monthly reset cron job

### P1 — Backend: Billing Endpoints + Enforcement ✅ Done

- [x] `GET /billing/usage`, `POST /billing/checkout` (stub), `POST /billing/portal` (stub)
- [x] Enforcement layer — 402 responses with error codes + upgrade context
- [x] Monthly reset cron

> ⛔ **Payment gateway — deferred to Phase 7.** Payment processing not yet implemented. See roadmap.

### P2 — Frontend: Billing UI

- [x] Settings > Billing tab — plan badge, usage meters, upgrade CTA
- [x] `<UpgradeModal />` — shows on 402 or upgrade click
- [x] 402 interceptor in `apiClient.ts`
- [x] `billingService.ts`, `useBillingUsage()` hook, `queryKeys.billing`
- [x] `<UsageWarningBanner />` — soft warning at 80% on any limit
- [x] In-context indicators — credits in Ask AI, minutes on upload/FAB, hours on Recall toggle
- [x] Dashboard `/pricing` page
- [x] Free users trying content gen → `UpgradeModal` with `reason="feature_gate"`
- [x] Content gen buttons — credit cost badge (~Ncr on each type card)

### P3 — Public: Pricing Page

- [x] `/pricing` in `crelyzor-public` — SSR, plan comparison table, CTAs, FAQ

---

## Phase 4.2 — Ask AI Persistence ✅ Complete

> Ask AI conversations are now persisted in PostgreSQL and survive page refreshes and device switches.
> The last 6 messages (3 exchanges) are included as context in each OpenAI call for follow-up awareness.

### What was built

- **Schema:** `AskAIConversation` (one per user × meeting, `@@unique([meetingId, userId])`) + `AskAIMessage` (`@db.Text` content, composite index on `[conversationId, createdAt]`). Tables created via `pnpm db:push`.
- **Service:** `src/services/ai/askAIConversationService.ts` — `getOrCreateConversation`, `getMessages`, `appendMessage`, `clearMessages`
- **Endpoints:**
  - `GET /sma/meetings/:meetingId/ask/history` — fetch persisted conversation
  - `DELETE /sma/meetings/:meetingId/ask/history` — clear conversation
  - `POST /sma/meetings/:meetingId/ask` — now persists user message before streaming, assistant message after; injects last 6 messages as OpenAI context
- **Frontend:**
  - `queryKeys.sma.askHistory(meetingId)` in `queryKeys.ts`
  - `useAskAIHistory` + `useClearAskAIHistory` hooks in `useSMAQueries.ts`
  - `AskAITab` seeds from DB history on first mount (skeleton while loading), ref-based seeding guard prevents re-seeding on background refetches
  - Clear button (`Trash2`) in Ask AI header — only visible when messages exist, optimistically clears local + cache
  - Suggestion chips only shown on empty conversation

---

## Phase 4.3 — Two-way GCal Push Webhooks ✅ Complete

> GCal edits/cancels now reflect in Crelyzor in real-time via Google Calendar push webhooks.
> Pull-based sync (on dashboard load) still runs as fallback. All push operations fail-open.

Full breakdown: per-repo `TASKS.md` files.

---

## Phase 4.4 — Polish & First-Run Experience ✅ Complete

> **Goal:** Fix the gaps a real user hits in their first week. Based on full product audit (2026-04-19).

### Backend
- [x] `CardContact` soft delete — schema + `db:push` + update `cardService.ts` (currently hard-deletes, violates convention)

### Frontend
- [x] **Setup page** — explain why username is required upfront
- [x] **Onboarding** — re-trigger mechanism (getting started link); fix trigger condition to check actual step completion
- [x] **Cards page** — Retry button on error state
- [x] **Voice notes** — Retry + Delete actions on failed transcription items
- [x] **Meetings** — "Clear filters" CTA when filter combo produces empty state
- [x] **Meeting detail → Generate tab** — explicit "transcript required" message instead of vague error
- [x] **Meeting creation** — show link warning upfront, not post-submit
- [x] **Bookings** — show timezone on all booking times
- [x] **Pricing page** — add Upgrade CTA for free users
- [x] **Home widgets** — "No meetings today" / "No recent meetings" link to /meetings
- [x] **Ask AI** — visually distinct low-credits warning (amber) so user notices before hitting the wall

Full breakdown: per-repo `TASKS.md` files.

---

## Phase 4.5 — Docker & Deployment ✅ Complete

> Full design doc: `docs/dev-notes/phase-4.5-docker-deployment.md`

### Prerequisites
- [x] Docker basics — images, containers, Dockerfile, Compose (learn before building)

### P0 — Dockerfiles
- [x] `crelyzor-backend/Dockerfile` — multi-stage, Node 20 alpine
- [x] `crelyzor-frontend/Dockerfile` — multi-stage, Vite build → nginx static
- [x] `crelyzor-public/Dockerfile` — multi-stage, Next.js server

### P1 — Docker Compose
- [x] `docker-compose.prod.yml` — backend, worker, frontend, public, postgres, nginx
- [x] `docker-compose.yml` — local dev version (hot reload, no SSL, direct ports)
- [x] `docker-compose.staging.yml` — staging server (full build, nginx, SSL)

### P2 — Nginx Config
- [x] `nginx/nginx.conf` — prod: 3 domains, SSE support, 500MB upload limit
- [x] `nginx/nginx.staging.conf` — staging: same pattern for staging.* subdomains

### P3 — Environment Files
- [x] `.env.prod` — workspace-level Compose build args (gitignored)
- [x] `.env.staging` — workspace-level Compose build args (gitignored)
- [x] `deploy.sh` — `./deploy.sh prod` or `./deploy.sh staging`

### P4 — CI/CD
- [x] `.github/workflows/deploy.yml` — typecheck all 3 repos in parallel, then SSH deploy
  - push to `main` → production
  - push to `dev` → staging
  - deploy blocked if any typecheck fails

### P5 — VM Setup
- [x] Provision VM (EC2 t3.small or GCE e2-medium)
- [x] Docker + Certbot installed on VM
- [x] DNS A records pointing to server IP
- [x] SSL certs issued via Certbot (`certbot certonly --nginx -d crelyzor.com -d app.crelyzor.com -d api.crelyzor.com`)
- [x] GCS service account key on server
- [x] Add GitHub Secrets: `VM_HOST`, `VM_USER`, `VM_SSH_KEY`, `VM_WORKSPACE_PATH`
- [x] `crelyzor-backend/.env.prod` filled with real values on VM

### P6 — Go Live
- [x] DB migrations run on prod (`docker compose -f docker-compose.prod.yml exec backend pnpm db:migrate`)
- [x] Google OAuth callback URL updated in Google Console
- [x] End-to-end test: sign in → create meeting → upload recording

---

## Phase 4.6 — Infrastructure Optimization ✅ COMPLETE

Local Redis, queue consolidation, Docker resource limits, slim images, selective deploys.
Design: `docs/superpowers/specs/2026-04-26-phase-4.6-infra-optimization-design.md`

- [x] Replace Upstash REST client with ioredis singleton
- [x] Remove `@upstash/redis` dependency
- [x] Consolidate 5 Bull queues → 1 queue ("crelyzor")
- [x] Producer-only mode for API server (1 connection vs 15)
- [x] Add local Redis container (redis:7-alpine) to Docker Compose
- [x] Add resource limits (memory + CPU) to all containers
- [x] Backend Dockerfile: prune devDependencies from prod image
- [x] Public Dockerfile: Next.js standalone output, remove pnpm
- [x] Selective service rebuild in deploy.sh
- [x] Remove worker from staging Docker Compose
- [x] Update env vars on VMs (REDIS_URL=redis://redis:6379, remove UPSTASH_*)
- [x] Deploy to staging + prod
---

## Phase 4.7 — Security Hardening ✅ Complete

> Full security audit completed 2026-05-09 across all 4 repos.
> Issues ordered by severity. Fix critical + high before any public launch.

### CRITICAL — Fix immediately

- [x] **[crelyzor-public]** Stored XSS via `dangerouslySetInnerHTML` in JSON-LD blocks — user-supplied `displayName`, `bio`, `links` are injected raw via `JSON.stringify` which does not escape HTML. A crafted name like `</script><script>alert(1)</script>` executes JS on every visitor's browser.
  - `src/app/[username]/page.tsx:103`
  - `src/app/[username]/[slug]/page.tsx:101`
  - Fix: escape `<`, `>`, `&` as `<`, `>`, `&` in a `safeJsonLd()` helper

### HIGH — Fix before production traffic

- [x] **[crelyzor-backend]** Recall webhook accepts unauthenticated requests when `RECALL_WEBHOOK_SECRET` is unset — the entire HMAC block is inside `if (webhookSecret)`, so a missing env var means any caller can trigger meeting status changes and recording jobs
  - `src/controllers/recallWebhookController.ts:22`
  - Fix: in production, return 503 if secret is unset — never fall through

- [x] **[crelyzor-backend]** `ADMIN_JWT_SECRET` not validated at startup — user JWT secrets throw and kill the process if missing, but `ADMIN_JWT_SECRET` is only checked at request time (returns 500). A misconfigured deploy silently starts with admin auth broken.
  - `src/index.ts`
  - Fix: add startup check alongside existing JWT_ACCESS_SECRET validation — `process.exit(1)` if unset

- [x] **[crelyzor-admin]** Admin JWT stored in `localStorage` — readable by any JS on the page (third-party scripts, extensions, future XSS). For the highest-privilege token in the system this is unacceptable.
  - `src/lib/apiClient.ts:9`, `src/pages/LoginPage.tsx:21`, `src/components/AdminRoute.tsx:4`, `src/App.tsx:35`, `src/pages/AcceptInvitePage.tsx:37`
  - Fix: switch to `httpOnly; Secure; SameSite=Strict` cookie — backend sets cookie on login, frontend adds `withCredentials: true`, `AdminRoute` verifies via `GET /admin/auth/me` instead of checking localStorage

- [x] **[crelyzor-admin]** No Content Security Policy — without a CSP, any injected script runs unrestricted. Critical for an admin portal.
  - `nginx.conf`
  - Fix: add `Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff` headers

- [x] **[crelyzor-public]** Booking reschedule leaks any guest's email — `?reschedule=<bookingId>` fetches and renders `guestEmail` with no ownership check against the host/event type in the URL. Any booking UUID can be probed to expose guest emails.
  - `src/app/schedule/[username]/[slug]/page.tsx:46`
  - Fix: backend must validate that booking belongs to the `username`/`slug` pair before returning guest data

- [x] **[crelyzor-public]** SSRF — OG image route fetches user-supplied `avatarUrl` server-side with no allowlist — a user can set their avatarUrl to an internal cloud metadata endpoint and the edge worker will fetch it
  - `src/app/api/og/[username]/route.tsx:32`
  - Fix: validate `avatarUrl` against an allowlist of known-safe hostnames (`storage.googleapis.com`, `lh3.googleusercontent.com`) before fetching

- [x] **[crelyzor-public]** SSRF — `next.config.ts` allows Next.js Image Optimization to proxy images from any HTTP/HTTPS host (`hostname: '**'`) — enables open image proxy and internal IP fetching
  - `next.config.ts:9`
  - Fix: restrict to `storage.googleapis.com` and any actual CDN hostname used

### MEDIUM — Fix before scale

- [x] **[crelyzor-backend]** No rate limit on `POST /admin/auth/login` — brute-force is unrestricted. All user auth endpoints have rate limits; admin login has none.
  - `src/routes/adminRoutes.ts:20`
  - Fix: add `rateLimit({ windowMs: 15 * 60 * 1000, max: 5, skipSuccessfulRequests: true })`

- [x] **[crelyzor-backend]** `getNotes` query missing `author: userId` scope — meeting ownership is checked but the notes `findMany` doesn't include `author: userId`, creating a defence-in-depth gap
  - `src/controllers/aiController.ts:158`
  - Fix: add `author: userId` to both `findMany` and `count` where clauses

- [x] **[crelyzor-backend]** `ALLOWED_ORIGINS` not validated at startup in production — if unset or empty, the server starts silently; should hard-fail in production
  - `src/utils/security/corsOptions.ts`, `src/index.ts`
  - Fix: `if (NODE_ENV === 'production' && !ALLOWED_ORIGINS) { logger.error(...); process.exit(1); }`

- [x] **[crelyzor-backend]** Recall webhook signature check silently skipped in dev when secret IS configured but signature header is absent — should at least warn loudly
  - `src/controllers/recallWebhookController.ts:65`

- [x] **[crelyzor-admin]** Raw backend error messages shown verbatim to users — `AcceptInvitePage` and `TeamPage` surface `err.response.data.message` directly; could expose internal field names or Prisma errors
  - `src/pages/AcceptInvitePage.tsx:42`, `src/pages/TeamPage.tsx:26,93`
  - Fix: replace with a safe static fallback string; only pass through known-safe messages

- [x] **[crelyzor-admin]** No session idle timeout — admin tab left open keeps token valid until the 24h JWT expiry with no warning or auto-logout
  - `src/App.tsx`
  - Fix: 30-minute idle timer using `mousemove` + `keydown` events, warn at 5 minutes, redirect on expiry

- [x] **[crelyzor-admin]** Logout does not explicitly clear React Query cache — safe now (full page reload) but fragile if logout is ever refactored to SPA navigation
  - `src/App.tsx:35`
  - Fix: call `queryClient.clear()` before redirect

- [x] **[crelyzor-frontend]** Refresh token stored in `localStorage` — access token is correctly in-memory (Zustand), but the refresh token persists to localStorage and is readable by JS
  - `src/lib/apiClient.ts:54`, `src/components/AppInitializer.tsx:27`, `src/pages/auth-callback/AuthCallback.tsx:27`
  - Fix: move refresh token to `httpOnly` cookie on the backend (larger auth refactor — coordinate with backend change)

- [x] **[crelyzor-public]** No frontend rate limiting on contact form, booking form, or waitlist — UI-level throttle already in place via `submitting` state (button disabled during and after submission); waitlist has no active form UI
  - `src/components/ContactForm.tsx`, booking flow, `src/app/api/waitlist/route.ts`

### LOW — Polish

- [x] **[crelyzor-backend]** No rate limit on `POST /admin/auth/accept-invite` — token entropy makes guessing infeasible but rate limiting is cheap defence-in-depth
  - `src/routes/adminRoutes.ts:22`

- [x] **[crelyzor-backend]** Admin JWT has no revocation — stolen token valid 24h with no way to invalidate without rotating the secret
  - `src/services/adminService.ts:31`
  - Fixed: shortened expiry to 2h (server-side revocation deferred to future session table)

- [x] **[crelyzor-backend]** Admin password minimum is 8 characters — raise to 12 for admin accounts
  - `src/validators/adminSchema.ts:25`

- [x] **[crelyzor-backend]** `notesQuerySchema` defined inline in controller instead of `src/validators/`
  - `src/controllers/aiController.ts:13`

- [x] **[crelyzor-public]** Waitlist email field has no maximum length check — add `email.length > 254` guard
  - `src/app/api/waitlist/route.ts`

- [x] **[crelyzor-frontend]** Raw `error.message` shown in non-PROD toast — staging environments with real user data would expose internal error strings
  - `src/lib/queryClient.ts:26`

- [x] **[crelyzor-frontend]** OAuth `error` query param interpolated verbatim into toast — map known OAuth error codes to user-friendly messages instead
  - `src/pages/auth-callback/AuthCallback.tsx:34`

- [x] **[crelyzor-frontend]** Google login `redirectUrl` accepted as any string — backend already validates via `isAllowedRedirectUrl()` in `googleController.ts` against `ALLOWED_ORIGINS`
  - `src/services/authService.ts:9`

---

## Phase 4.8 — Embeddable Booking Widget ✅ Complete

> Cal.com-style iframe embed for Crelyzor scheduling pages.
> Anyone can drop a `<script>` tag on their site and get a fully functional booking widget.
> All 5 changes are frontend-only in `crelyzor-public` — no backend changes needed.
> Design analysis: conversation 2026-05-11.

### How it works
Host site loads `crelyzor.app/embed.js` → script creates an `<iframe>` pointing to `/schedule/:username/:slug?embed=1` → iframe strips chrome and fires `postMessage` events (resize, booking-confirmed) back to the parent page.

### P0 — Allow iframing (unblock the embed)

- [x] **[crelyzor-public]** `next.config.ts` — add custom headers for `/schedule/**` routes: `X-Frame-Options: ALLOWALL` + `Content-Security-Policy: frame-ancestors *` (Next.js sets `SAMEORIGIN` by default, which blocks all cross-origin iframes)

### P1 — Embed mode UI (strip chrome inside iframe)

- [x] **[crelyzor-public]** `schedule/[username]/[slug]/page.tsx` — read `searchParams.embed` and pass `isEmbed: boolean` prop to `<BookingFlow />`
- [x] **[crelyzor-public]** `schedule/[username]/[slug]/BookingFlow.tsx` — when `isEmbed`: hide outer nav/header, remove top padding, set `bg-transparent`
- [x] **[crelyzor-public]** `schedule/[username]/[slug]/confirmed/ConfirmedClient.tsx` — read `?embed=1` from `useSearchParams`, strip chrome when present

### P2 — postMessage bridge

- [x] **[crelyzor-public]** `BookingFlow.tsx` — after `createBooking()` succeeds, fire `window.parent.postMessage({ type: 'CRELYZOR:booking-confirmed', data: booking }, '*')` when in embed mode
- [x] **[crelyzor-public]** `BookingFlow.tsx` — fire `window.parent.postMessage({ type: 'CRELYZOR:resize', height: document.documentElement.scrollHeight }, '*')` on content height changes (use `ResizeObserver`)
- [x] **[crelyzor-public]** Pass `?embed=1` through to the confirmed redirect URL so `confirmed` page also strips chrome: `/schedule/:u/:s/confirmed?bookingId=X&embed=1`

### P3 — embed.js script

- [x] **[crelyzor-public]** New file `public/embed.js` — vanilla JS, no dependencies, served statically at `crelyzor.app/embed.js`
  - Exposes `window.Crelyzor('init', { link, container, onBooking })` API
  - Creates `<iframe src="/schedule/${link}?embed=1">`, appends to `config.container`
  - Listens for `CRELYZOR:resize` → sets `iframe.style.height`
  - Listens for `CRELYZOR:booking-confirmed` → calls `config.onBooking?.(data)`

---

## Phase 4.9 — In-App Notifications + WebSocket Foundation

> Real-time in-app notification system built on a WebSocket foundation designed to scale to Phase 6 Teams (presence, workspace events) and beyond. SSE was the original plan but is replaced by WebSocket: Phase 6 Teams definitively needs bidirectional real-time, so building the infrastructure now avoids a guaranteed migration later. One WS connection per tab carries all real-time events — notifications today, team presence and Ask AI streaming in future phases.

### Architecture

```
Browser Tab
    │
    │  ws://<host>/ws?token=<jwt>        ← native WebSocket, no Socket.io
    ▼
Express HTTP server (same port, no new process)
    │  HTTP upgrade → WebSocket
    ▼
WebSocketServer (ws library)  ←  src/websocket/wsServer.ts
    │
    ├── wsAuth.ts           verify JWT from ?token= query param on upgrade
    ├── connectionRegistry.ts   Map<userId, Set<WebSocket>>  (multiple tabs)
    ├── heartbeat.ts        30s ping/pong, terminate dead connections
    └── notificationSubscriber.ts
            │  redisClient.duplicate() → dedicated sub connection per instance
            │  SUB notify:${userId}  when first tab connects
            │  UNSUB notify:${userId} when last tab disconnects
            ▼
        Redis pub/sub  ←── notificationService.create() publishes after DB insert
```

**Typed message envelope** — all WS traffic uses a discriminated union so adding new event types in future phases requires zero infrastructure changes:

```typescript
// Server → Client
type WsServerMessage =
  | { type: 'CONNECTED'; unreadCount: number }
  | { type: 'NOTIFICATION'; data: Notification }
  | { type: 'PING' }
  // Phase 6 additions (no infrastructure changes needed):
  // | { type: 'TEAM_MEMBER_JOINED'; teamId: string; member: TeamMember }
  // | { type: 'MEMBER_PRESENCE_UPDATED'; teamId: string; userId: string; status: 'online' | 'away' }
  // Ask AI migration (drop SSE, reuse this connection):
  // | { type: 'ASK_AI_CHUNK'; meetingId: string; chunk: string }
  // | { type: 'ASK_AI_DONE'; meetingId: string }

// Client → Server
type WsClientMessage =
  | { type: 'PONG' }
  | { type: 'PING' }
```

**Architectural constraints (non-negotiable):**
- **Worker = publisher only.** The worker process (`jobProcessor`) never holds WebSocket connections and never touches the `ConnectionRegistry`. It only calls `redisClient.publish('notify:${userId}', payload)` after completing a job. This is enforced by the fact that the ConnectionRegistry lives in the API server's memory — a separate Node.js process cannot access it.
- **API server = sole WebSocket owner.** All WebSocket connections live in the API server process. It is the only process that holds open sockets and fans out messages to clients.
- This boundary means: worker triggers a notification → publishes to Redis → API server's subscriber picks it up → fans out to all open tabs for that user via ConnectionRegistry. Never short-circuit this path.

**Horizontal scaling:** Redis pub/sub handles fan-out across multiple backend instances automatically. When a user has tab 1 on instance A and tab 2 on instance B, both instances subscribe to `notify:${userId}` on Redis — so both tabs receive the notification. No coordination between instances is needed.

**Redis subscriber — one per instance, not one per user:** Each backend instance runs a single shared `IORedis` subscriber connection (not one per user). When a user's first tab connects, call `sharedSub.subscribe('notify:${userId}')` on the shared connection. When their last tab disconnects, call `sharedSub.unsubscribe('notify:${userId}')`. The single `sharedSub.on('message', (channel, message) => {...})` handler parses the userId from the channel name and routes to `registry.broadcast()`. This keeps Redis connections at O(instances) not O(users).

**`index.ts` integration:** `app.listen()` returns an `http.Server`. We pass that server instance directly to `createWsServer(server)` — no new port, no new process.

### Notification types

`BOOKING_RECEIVED` · `BOOKING_CONFIRMED` · `BOOKING_CANCELLED` · `BOOKING_REMINDER` · `MEETING_AI_COMPLETE` · `TASK_DUE_SOON`

### Backend (`crelyzor-backend`)

- [x] **P0 — Schema:** `Notification` model + `NotificationType` enum + index on `[userId, isRead, createdAt]` + `inAppNotificationsEnabled`, `inAppBookingEnabled`, `inAppMeetingReadyEnabled`, `inAppTaskDueEnabled` on `UserSettings` + `pnpm db:migrate && pnpm db:generate`

- [x] **P1 — WebSocket Foundation** ← replaces the SSE plan; install `ws` + `@types/ws`
  - `src/websocket/types.ts` — `WsServerMessage` + `WsClientMessage` discriminated unions
  - `src/websocket/connectionRegistry.ts` — `Map<userId, Set<WebSocket>>`, `add()`, `remove()`, `broadcast(userId, msg)`, `size()`
  - `src/websocket/wsAuth.ts` — extract `?token=` from upgrade request URL, call `tokenService.verifyAccessToken()`, validate session via `sessionService.validateSession()`, return `TokenPayload` or close with 4001
  - `src/websocket/heartbeat.ts` — 30s `setInterval`, send `{ type: 'PING' }`, mark `ws.isAlive = false`, terminate if no PONG received before next tick
  - `src/websocket/notificationSubscriber.ts` — ONE shared `IORedis` subscriber instance (created once via `redisClient.duplicate()`), never recreated; `subscribeUser(userId)` calls `sharedSub.subscribe('notify:${userId}')` only when `registry.size(userId) === 1` (first tab for that user); `unsubscribeUser(userId)` calls `sharedSub.unsubscribe('notify:${userId}')` only when `registry.size(userId) === 0` (last tab closed); single `sharedSub.on('message', (channel, msg) => { const userId = channel.replace('notify:', ''); registry.broadcast(userId, JSON.parse(msg)); })` handler routes all messages — O(instances) Redis connections, not O(users)
  - `src/websocket/wsServer.ts` — `createWsServer(httpServer)`: creates `WebSocketServer({ server, path: '/ws' })`, on `connection`: run `wsAuth` (close 4001 if fail), add to registry, subscribe Redis channel, send `CONNECTED` with unread count, wire heartbeat, on `close` remove from registry + conditionally unsubscribe Redis; export `closeWsServer()`
  - `src/index.ts` — capture `const server = app.listen(...)`, call `createWsServer(server)`, add `closeWsServer()` to both SIGTERM and SIGINT shutdown handlers

- [x] **P2 — Notification Service + REST Endpoints:** `src/services/notificationService.ts` (create with Redis publish, list paginated, markRead, markAllRead, delete, unreadCount) + `src/validators/notificationSchema.ts` + `src/controllers/notificationController.ts` + `src/routes/notificationRoutes.ts` registered under `/api/v1/notifications`. Endpoints: `GET /notifications` (paginated, filter by isRead), `GET /notifications/unread-count`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all`, `DELETE /notifications/:id`

- [x] **P3 — Wire Triggers** — call `notificationService.create()` fail-open (try/catch, log on error, never throw) alongside existing email sends:
  - `bookingManagementService.ts` → `BOOKING_RECEIVED` to host on new booking, `BOOKING_CANCELLED` to host on cancellation
  - `bookingService.ts` reminder job → `BOOKING_REMINDER` to host + guest
  - `jobProcessor.ts` AI complete handler → `MEETING_AI_COMPLETE` after `aiService.processTranscriptWithAI()` succeeds
  - New daily 8am cron job (`TASK_DUE_SOON`) → query tasks where `dueDate = today AND isCompleted = false` per user, create one notification per user if any exist

- [x] **P4 — Settings:** add `inApp*` fields to `settingsService.ts` `getUserSettings()` + `updateUserSettings()` + `settingsController.ts` response shape + `src/validators/settingsSchema.ts`

### Frontend (`crelyzor-frontend`)

- [x] **P0 — WebSocket Client Hook**
  - `src/hooks/useWebSocket.ts` — singleton pattern (one connection per app lifetime, not per component); reads JWT from `authStore`; connects to `ws://<API_HOST>/ws?token=<jwt>`; typed `WsServerMessage` handler registry (`Map<string, Set<handler>>`); exponential backoff reconnect (3s → 6s → 12s → 24s → max 60s, reset on successful open); cleanup on unmount; disconnect on logout
  - `src/hooks/useNotificationStream.ts` — wraps `useWebSocket`, registers handler for `NOTIFICATION` message type; on event: `queryClient.invalidateQueries(queryKeys.notifications.all())` + show Sonner toast with notification title; mount this in `AppInitializer` so it runs for the entire authenticated session

- [x] **P1 — Notification Service + Query Layer:** `src/services/notificationService.ts` (REST API calls for all 5 endpoints) + add `notifications` namespace to `src/lib/queryKeys.ts` + hooks: `useNotifications(filter?)`, `useUnreadCount()`, `useMarkRead()`, `useMarkAllRead()`, `useDeleteNotification()`

- [x] **P2 — Notification Bell:** `<NotificationBell />` in app header — `Bell` icon (Lucide), red badge with unread count capped at "99+", badge hidden when count is 0, opens `<NotificationPanel />` on click, uses `useUnreadCount()` (60s polling fallback) + WS for instant update

- [x] **P3 — Notification Panel:** `<NotificationPanel />` popover — skeleton while loading; empty state "You're all caught up" with muted bell icon; notification rows (type icon + title + body + relative time + unread dot); click row → `markRead` + navigate to entity (`/meetings/:id`, `/scheduling/bookings`, `/tasks`); "Mark all as read" button (hidden when all read); "Clear all" button; rows grouped into Today / Earlier sections

- [x] **P4 — Settings:** expand Settings > Notifications tab — add "In-App" column alongside existing "Email" column; master `inAppNotificationsEnabled` toggle disables all per-type toggles below it; per-type: Bookings, Meeting AI ready, Task due soon

### Public (`crelyzor-public`)

No changes — notifications are authenticated dashboard-only.

### Future phases — zero infrastructure changes needed

| Phase | Addition |
|---|---|
| Phase 6 Teams | Add `TEAM_MEMBER_JOINED`, `MEMBER_PRESENCE_UPDATED` to `WsServerMessage`; publish to `notify:${userId}` from team service |
| Ask AI migration | Handled in Phase 8 P6 — migrate SSE → WebSocket alongside agent launch |
| Live collaborative notes | Add `NOTE_UPDATED` type; publish from `meetingNoteService` |

---

## Phase 5 — Encryption at Rest

**Goal:** every sensitive user-facing string and every recording object is encrypted at rest. Server holds keys (envelope encryption via Google Cloud KMS), AI features and all existing searches keep working unchanged. Not E2EE — Crelyzor can still decrypt to power AI; an explicit non-goal.

**Implementation plan:** `docs/superpowers/plans/2026-05-22-encryption-at-rest.md`

**Key model:**
- One KEK per environment in Google Cloud KMS — never leaves the HSM. Same GCP region as app server (latency requirement).
- One DEK per user, AES-256-GCM, stored as `User.wrappedDek Bytes` (wrapped by KEK). Also tracks `User.dekVersion Int` for rotation.
- DEK history kept in `UserDekHistory` — enables rotation without re-encrypting all records at once.
- DEK cached in an **in-process LRU cache** (200 entries, 60s TTL) — works identically in HTTP handlers AND Bull workers.
- AES-256-GCM via Node's built-in `crypto`. No third-party crypto libs.
- Per-record ciphertext: `version(1) ‖ iv(12 random) ‖ ciphertext ‖ authTag(16)` — version byte enables DEK rotation without re-encrypting old records.
- Blind indexes (HMAC-SHA256) for all searchable PII fields — exact-match queries preserved.

**KMS provider:** toggled by `KMS_PROVIDER=local|gcp`. `LocalKmsProvider` uses `LOCAL_KMS_KEY` from `.env` — same code path as GCP, no bypass, no plaintext passthrough. Dev behaves exactly like prod.

**Decisions made (2026-05-22):**

| # | Decision | What | Why |
|---|----------|------|-----|
| 1 | KMS provider for dev | `KMS_PROVIDER=local` — `LocalKmsProvider` wraps/unwraps the DEK using `LOCAL_KMS_KEY` (32-byte hex in `.env`). Same AES-256-GCM code path as GCP, no plaintext bypass. | Avoids requiring GCP credentials just to start the dev server. Prod always uses `KMS_PROVIDER=gcp`. |
| 2 | Crypto algorithm | AES-256-GCM via Node.js built-in `crypto` module. No third-party crypto libs. | Industry standard authenticated encryption — confidentiality + integrity in one pass. Built-in means zero supply-chain risk. |
| 3 | Migration strategy | **Single-step — no dual-write.** In-scope columns change from `String` to `Bytes?` in one migration. Existing rows set to `NULL` (4-5 users — acceptable to nuke). Backfill generates DEKs and re-encrypts any surviving rows. | Dual-write only pays off at 1,000+ users who need zero-downtime rollout windows. At 4-5 users, nuke-and-restart is free and removes two extra phases of complexity. |
| 4 | No feature flags | No `_encrypted` shadow columns. No `ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN` env flag. All writes go directly to the `Bytes` column; all reads decrypt from the same column. | Feature flags add complexity, test surface, and maintenance burden. Current scale makes them pure overhead with no benefit. |
| 5 | Task.title plaintext, Task.description encrypted | `Task.title` stays `String` — needed for full-text search and future Big Brain indexing. `Task.description` becomes `Bytes?`. | Title is always user-typed, always shown in lists, always searched. Description is AI-generated with richer PII (participant names, topics, details). |
| 6 | Blind index implementation | `HMAC-SHA256(normalize(value), HMAC_BLIND_INDEX_KEY)` stored in `*_bidx Bytes` column. Separate `HMAC_BLIND_INDEX_KEY` (32-byte hex). Normalise = lowercase + trim before hashing. | Industry standard for exact-match search on encrypted fields. Normalisation ensures "Jane@Acme.com" and "jane@acme.com" produce the same blind index and match correctly. |
| 7 | No backups infrastructure yet | No automated backup system. If DB restore needed: SSH into VM, restore from filesystem snapshot manually. | Pre-PMF at 4-5 users. Invest in backup infra when user count justifies it. Revisit at Phase 6 / first paying customer. |
| 8 | OAuthAccount tokens in scope | `OAuthAccount.accessToken` and `refreshToken` are encrypted. Looked up only by `userId + provider` — no blind index needed. | Highest-value encryption target: compromising these gives full Google account access. Zero query-pattern impact from encrypting since they're never searched or matched by value. |

**Known breakages naive encryption would cause (and how they're resolved):**

| # | Breakage | File | What breaks | Resolution |
|---|----------|------|-------------|------------|
| 1 | Meeting↔card auto-linking | `meetingService.ts:216` — `email: { in: participantEmails }` on `CardContact.email` | Encrypted `Bytes` never equals a plaintext email string — auto-linking silently breaks | Compute blind index of each participant email, query `CardContact.email_bidx: { in: [...blindIndexes] }` instead |
| 2 | Global search on contact email | `searchService.ts:95` — `ILIKE '%query%'` on `CardContact.email` | ILIKE on `Bytes` column = zero matches always | Drop `email` from the ILIKE OR clause; when query looks like an email (contains `@`), add exact blind-index match |
| 3 | Card contact search by email | `cardService.ts:634, 729` — `ILIKE` on `CardContact.email` | Same as above | Same fix: blind-index exact match |
| 4 | Public write with no req.user | `cardService.ts:524` — `submitContact()` — guest submits contact to a card owner | No `req.user` → no `userId` to call `getDek()` | Pass `card.userId` (the card owner's ID) explicitly: `getDek(card.userId)` |

**In scope (encrypted columns):**

| Model | Column(s) | Blind index? |
|---|---|---|
| `MeetingTranscript` | `fullText` | No |
| `TranscriptSegment` | `text` | No |
| `MeetingNote` | `content` | No |
| `MeetingAISummary` | `summary`, `keyPoints` (each element encrypted individually, stored as `Bytes[]`) | No |
| `MeetingAIContent` | `content` | No |
| `AskAIMessage` | `content` | No |
| `Task` | `description` only — `title` stays `String` for search + Big Brain | No |
| `CardContact` | `name`, `email`, `phone`, `company`, `note` | `email_bidx`, `phone_bidx` |
| `Booking` | `guestName`, `guestEmail`, `guestNote` | `guestEmail_bidx` |
| `MeetingParticipant` | `guestEmail` | `guestEmail_bidx` |
| `OAuthAccount` | `accessToken`, `refreshToken` | No — looked up by `userId + provider` only |

**In scope (storage):**
- GCS recordings bucket → CMEK via the same KMS key. No app code changes.

**Out of scope (stays plaintext):**
- All IDs, FKs, timestamps, soft-delete flags
- `Meeting.title`, `Task.title`, `Tag.name`, indexed fields (`speaker`, `startTime`)
- `Card.*` (public profile rendered to open web — must be readable without a user session)
- `CardContact.name`, `CardContact.company` — ILIKE search in global search + card search; lower PII sensitivity than email
- `EventType.*`, `UserSettings`, `Task.status`, `Task.dueDate`
- Blind index columns (`*_bidx`) — HMAC output, not reversible to plaintext

**Out of scope (explicitly not building):**
- End-to-end encryption — kills AI features and Big Brain.
- Full-text search on encrypted columns — Phase 8 (Big Brain embeddings) handles semantic search.
- Per-meeting "Private Mode" — deferred until users ask for it.

**Worker / background job DEK access:** Bull workers call `getDek(userId)` — hits the shared LRU cache first, falls back to KMS on miss. No AsyncLocalStorage, no manual seeding. Same function as HTTP handlers. No special worker code required.

**Crypto-shredding:** destroying `User.wrappedDek` + all `UserDekHistory` rows makes every ciphertext for that user permanently unrecoverable — even in old DB backups. GDPR delete solved as a free side effect.

### P0 — cryptoService foundations

- [x] Install `@google-cloud/kms` and `vitest`
- [x] Build `src/utils/security/dekCache.ts` — LRU wrapper around `node-cache`, keyed by `userId:version`
- [x] Build `src/utils/security/kmsProviders.ts` — `GcpKmsProvider` + `LocalKmsProvider`, toggled by `KMS_PROVIDER`
- [x] Build `src/utils/security/crypto.ts` — `encrypt`, `decrypt`, `blindIndex`, `initDekForNewUser`, `encryptWithKey`, `decryptWithKey`
- [x] Add env vars: `KMS_PROVIDER`, `LOCAL_KMS_KEY`, `HMAC_BLIND_INDEX_KEY`, `GCP_KMS_KEY_NAME`
- [x] Unit tests (vitest): round-trip, version byte, random IV, tampered ciphertext throws, blind index normalises, LocalKmsProvider wrap/unwrap, dekCache eviction

### P1 — Schema migration (single-step)

- [x] `User.wrappedDek Bytes?`, `User.dekVersion Int @default(1)`
- [x] `UserDekHistory` model with `@@unique([userId, version])`
- [x] All in-scope `String` columns → `Bytes?` (single-step, no shadow columns)
- [x] `MeetingAISummary.keyPoints Bytes?` (encrypted JSON array)
- [x] Blind index columns: `emailBidx`, `phoneBidx` on `CardContact`; `guestEmailBidx` on `Booking` + `MeetingParticipant`
- [x] `pnpm db:migrate` + `pnpm db:generate`

### P2 — Registration hook

- [x] `initDekForNewUser(userId, tx)` called inside the `isNewUser` block in `src/controllers/googleController.ts`

### P3 — Service-layer encryption (direct — no dual-write)

- [x] `transcriptionService.ts` — encrypt `fullText` + `TranscriptSegment.text`
- [x] `aiService.ts` — encrypt `MeetingAISummary.summary` + `keyPoints`
- [x] `askAIConversationService.ts` — encrypt `AskAIMessage.content`
- [x] `smaEditService.ts` — encrypt `MeetingNote.content`, `MeetingAIContent.content`, segment edits
- [x] `tasksService` / `taskController` — encrypt `Task.description`
- [x] `cardService.ts` — encrypt `CardContact` PII + blind-index search; `submitContact()` uses `getDek(card.userId)` (Breakage #4)
- [x] `bookingService.ts` — encrypt `Booking` PII + `guestEmail_bidx`
- [x] `meetingService.ts` — encrypt `MeetingParticipant.guestEmail`; auto-linking uses `blindIndex` (Breakage #1)
- [x] `googleCalendarService.ts` / `googleService.ts` — encrypt `OAuthAccount.accessToken` + `refreshToken`
- [x] `searchService.ts` — blind-index exact match for email queries (Breakages #2 + #3)
- [x] `shareService.ts` + `exportService.ts` — decrypt transcript + summary for public/export reads
- [x] Logger PII denylist: `redactPii()` in `logFormatter.ts` strips denylisted fields from structured log output

### P4 — Backfill

- [x] `src/scripts/phase5Backfill.ts` — idempotent, batched, `--dry-run` flag, verification sample
- [x] Dry-run passed clean
- [x] Real run passed: spot-checks green on local DB

### P5 — GCS CMEK + crypto-shredding + observability

- [x] GCS CMEK: KMS keyrings + keys provisioned for dev/staging/prod; GCS service agent granted access; CMEK set on all three buckets; existing objects re-encrypted
- [x] Crypto-shredding: `authService.deactivateAccount` destroys `UserDekHistory` + nulls `User.wrappedDek` in transaction, then `evictDek(userId)`
- [x] Cloud Monitoring alert created (policy `8638838345955756167`): KMS API requests > 100/hour
- [x] KMS DR runbook in `docs/dev-notes/encryption.md` (key destruction protection, IAM hygiene checklist, regional failover)

---

## Phase 6 — Teams

> Full design spec: `docs/internal/superpowers/specs/2026-05-09-teams-design.md`
> Per-repo breakdowns: each repo's `TASKS.md`

**The model:** Pro+ users (PRO or BUSINESS plan) can create teams (≤3 for Pro, ≤10 for Business — both configurable via SystemConfig). The team owner pays for all consumption — transcription, storage, AI tokens — across all their teams. Members and admins consume the owner's quota. Members can join on any plan including Free.

**Encryption:** Per-team DEK (additive to Phase 5's per-user DEK). Team-scoped content encrypts under the team DEK; member removal and ownership transfer require zero re-encryption. Team deletion = crypto-shred via cascade.

**Workspace switching:** Top-left replaces `UserMenu` with a workspace switcher. Soft switch (no hard reload) — Zustand store + broad query invalidation + 250ms cross-fade.

**Roles:** Owner (full control, billing) / Admin (manage, no billing) / Member (own content only).

**Cards:** Team gets a public card at `crelyzor.app/t/:slug`. Members get auto-created team cards on join.

**Scheduling:** Each member sets their own availability within the team. External visitors book a specific member via `/schedule/t/:slug/:username`. Team members book each other internally from the dashboard (4-step modal).

**Config:** All limits live in a `SystemConfig` table — editable from admin portal. Nothing hardcoded.

**Pro gate (interim):** Until Razorpay unblocks, admins flip `user.plan` manually via the admin portal.

### P0 — Backend: Schema (do first — everything depends on this)

- [ ] `SystemConfig` model — key/value store + `updatedAt`, `updatedBy`. Seed defaults: `max_teams_per_pro_user=3`, `max_teams_per_business_user=10`, `max_members_per_team=50`, `team_invite_expiry_days=7`.
- [ ] `Team` model — id (UUID), name, slug (unique), description (String? max 500), ownerId, logoUrl, **wrappedDek (Bytes)**, **dekVersion (Int @default 1)**, isDeleted, deletedAt, createdAt, updatedAt.
- [ ] `TeamMember` model — id, teamId, userId, role (OWNER | ADMIN | MEMBER), joinedAt, isDeleted, deletedAt. (No `leftAt` — soft-delete semantics handle "left" via `isDeleted`.)
- [ ] `TeamInvite` model — id, teamId, email, userId?, role, token (unique), invitedById, expiresAt, acceptedAt?, declinedAt?, cancelledAt?, isDeleted, deletedAt.
- [ ] `TeamDekHistory` model — mirrors `UserDekHistory`. Hard cascade on Team delete (crypto-shred). No isDeleted/deletedAt.
- [ ] Add `teamId UUID?` + index `@@index([teamId, isDeleted])` to: `Meeting`, `Card`, `Task`, `EventType`, `Booking`, `UserUsage`.
- [ ] Migration: `pnpm db:migrate && pnpm db:generate`.

### P1 — Backend: Team CRUD + Member Management

- [ ] `POST /teams` — create team. Plan gate (`user.plan IN ('PRO','BUSINESS')`). SystemConfig max-teams check by plan. Transaction: create Team + generate team DEK (Cloud KMS) + create OWNER TeamMember + auto-create team Card with `userId = ownerId`.
- [ ] `GET /teams` — list teams the user is active in. Include role.
- [ ] `PATCH /teams/:teamId` — update name (Admin), slug (Owner only), logo (Admin), description (Admin).
- [ ] `DELETE /teams/:teamId` — soft delete (Owner only). Sets all member rows `isDeleted: true` in transaction. Schedules hard delete + crypto-shred after retention window.
- [ ] `POST /teams/:teamId/transfer-ownership` — Owner only. Requires typing team name to confirm. Transaction: flip `Team.ownerId`, swap roles (old Owner → ADMIN, new Owner → OWNER), reassign team Cards' `userId`.

### P2 — Backend: Team Member + Invite Management

- [ ] `GET /teams/:teamId/members` — active members + role + last-active (from WS presence) + per-member usage summary.
- [ ] `POST /teams/:teamId/members/invite` — body: `{ mode: 'user'|'email', userId?, emails?[], role, message? }`. Admin/Owner only. Member count check. Returns invites created.
- [ ] `GET /teams/:teamId/invites` — list pending invites. Admin/Owner.
- [ ] `POST /teams/:teamId/invites/:inviteId/resend` — Admin/Owner.
- [ ] `DELETE /teams/:teamId/invites/:inviteId` — Admin/Owner (cancels invite).
- [ ] `GET /invites/:token` — public, validate token + return team info (no auth).
- [ ] `POST /invites/:token/accept` — accept email invite (requires JWT; if no account, signup flow runs first then calls this).
- [ ] `POST /invites/:token/decline` — decline.
- [ ] `POST /teams/:teamId/invites/accept` — accept in-app invite (existing user).
- [ ] `POST /teams/:teamId/invites/decline` — decline in-app.
- [ ] `PATCH /teams/:teamId/members/:userId` — change role. Owner only. Cannot change own role.
- [ ] `DELETE /teams/:teamId/members/:userId` — remove member. Admin/Owner. Cannot remove Owner. Soft-deletes their team Card.
- [ ] `DELETE /teams/:teamId/leave` — leave team. Blocked if caller is Owner.

### P3 — Backend: Encryption — per-team DEK

- [ ] Extend `cryptoService.getDek()` to accept `Principal = { type: 'user'|'team', id }`. Backward-compatible overload.
- [ ] DEK cache key becomes `${type}:${id}` — same LRU capacity, shared across user + team.
- [ ] Encrypt/decrypt helpers pick principal from `row.teamId` (set → team, null → user).
- [ ] Bull job payloads carry `{ userId, teamId? }`. Workers call correct `getDek()`.
- [ ] Crypto unit tests cover team principal path + cache eviction across principals.

### P4 — Backend: Context Middleware + Quota Resolver

- [ ] `resolveTeamContext` middleware — reads `X-Team-Id` header, runs `verifyTeamMember` inline, populates `req.teamContext = { teamId, role } | null`.
- [ ] `verifyTeamRole('ADMIN' | 'OWNER')` factory — runs after `resolveTeamContext`, throws 403 if role insufficient.
- [ ] `getQuotaOwner({ userId, teamId })` — returns userId of the principal whose pool gets debited (team.ownerId or self).
- [ ] Wire `getQuotaOwner` into every metering call site (transcription start, OpenAI calls, GCS write, Recall webhook minute attribution).
- [ ] `UserUsage` writes carry `teamId` for attribution.

### P5 — Backend: Team-scoped Content (split per service)

- [ ] **P5.1** Meetings service — list/get/create/update/delete + attachments + participants + recordings respect `req.teamContext`. Member visibility: filter by `participants.userId = req.user.id` when role=MEMBER.
- [ ] **P5.2** Cards service — list/get/create/update/delete + contacts respect team context.
- [ ] **P5.3** Tasks service — list/get/create/update/complete respect team context. Reassign blocked for MEMBER.
- [ ] **P5.4** Scheduling — event types CRUD, availability, bookings (private endpoints) respect team context.
- [ ] **P5.5** Tags service — universal tags (meeting/card/task/contact) scope to team context.
- [ ] **P5.6** SMA + AI — Ask AI sessions, content generation cache (`MeetingAIContent`) scope by `meeting.teamId`.
- [ ] **P5.7** Recall webhooks — match meeting → use `meeting.teamId` for quota attribution.
- [ ] **P5.8** Usage endpoint `GET /teams/:teamId/usage?period=...` — per-member breakdown. Owner/Admin only.

### P6 — Backend: Public Team Endpoints

- [ ] `GET /public/teams/:slug` — no auth. Team profile + active member roster (name, username, avatar, role) for the `/t/:slug` page.
- [ ] `GET /public/scheduling/team/:slug/profile` — team scheduling profile.
- [ ] `GET /public/scheduling/team/:slug/:username` — specific member's team-scoped event types.
- [ ] Slot engine respects team-scoped EventTypes (`eventType.teamId = team.id`).

### P7 — Backend: WebSocket Events

- [ ] Extend `WsServerMessage` with: `TEAM_INVITE_RECEIVED`, `TEAM_MEMBER_JOINED`, `TEAM_MEMBER_LEFT`, `TEAM_MEMBER_ROLE_CHANGED`, `TEAM_MEETING_BOOKED`.
- [ ] Publish each on the relevant service mutation.

### P8 — Backend: Admin API

- [ ] `GET /admin/config` — list all SystemConfig entries grouped by category.
- [ ] `PATCH /admin/config/:key` — update value. Records `updatedBy`.
- [ ] `GET /admin/teams?include_deleted=false&search=` — list all teams with owner email + member count + status. Pagination.
- [ ] `GET /admin/teams/:teamId` — full team detail incl. members + activity log.
- [ ] `DELETE /admin/teams/:teamId` — soft-delete (admin override).
- [ ] `PATCH /admin/users/:userId/plan` — set `user.plan` to FREE/PRO/BUSINESS. Records audit row.

### P9 — Frontend: Workspace Switcher + Team Store

- [ ] `teamStore` (Zustand, sessionStorage-persisted) — `activeTeamId`, `setActiveTeam()`.
- [ ] `apiClient` injects `X-Team-Id` header when `activeTeamId` set.
- [ ] `teamService.ts` + `useTeamQueries.ts` + `queryKeys.teams.*` additions.
- [ ] Workspace switcher component replaces `UserMenu` trigger. Dropdown panel: pending invites surface + workspaces list + Create team + account actions.
- [ ] On switch: `queryClient.invalidateQueries()` + `<motion.div key={activeTeamId}>` cross-fade wrapper around route outlet.
- [ ] Command palette: "Switch workspace" section. `Cmd+1..9` keybinds.

### P10 — Frontend: Team Creation + Plan Gate

- [ ] `<CreateTeamModal />` — name + slug (debounced availability check) + description (collapsed) + logo dropzone. Single-page, no wizard.
- [ ] `<UpgradeToProModal />` — shown when Free user clicks Create team or Pro user hits team limit.

### P11 — Frontend: Team Settings Page

Route: `/teams/:teamId/settings`. Vertical tab nav (left) + content (right).

- [ ] **General tab** — name/slug/description/logo. Save on dirty.
- [ ] **Members tab** — table + Invite button + role dropdown (Owner only) + remove kebab.
- [ ] **Invite member modal** — Search users / By email (chip input) tabs.
- [ ] **Invites tab** — pending invites table + Resend + Cancel.
- [ ] **Usage tab** — 4 summary cards + period selector + per-member breakdown + CSV export.
- [ ] **Billing tab** — Owner-only message + link to personal billing.
- [ ] **Danger zone** — Leave team (members) / Transfer ownership / Delete team (Owner).

### P12 — Frontend: Team-aware Content + Internal Booking

- [ ] All pages scope to `activeTeamId` via the injected header (no per-page code change needed beyond removing client-side `userId` filters).
- [ ] Sidebar header swaps to team identity block when in team context.
- [ ] `<BookTeamMemberModal />` — 4-step (pick member → pick slot → details with pre-filled subject → confirm). Trigger from Meetings page.
- [ ] Card editor public URL preview: `crelyzor.app/t/[team-slug]/[card-slug]` when team context.

### P13 — Frontend: In-app Invite Surfaces

- [ ] Workspace switcher shows pending invites count + expandable section.
- [ ] Notifications panel renders invite items with inline Accept/Decline.
- [ ] WS handlers for `TEAM_INVITE_RECEIVED`, `TEAM_MEMBER_*` events → invalidate relevant queries.

### P14 — Public (crelyzor-public)

- [ ] `/invite/:token` — SSR; accept/decline flow; Google OAuth signup if needed; expired/invalid token states.
- [ ] `/t/:slug` — SSR team public page (logo, name, description, members roster, OG meta).
- [ ] `/schedule/t/:slug/:username` — team-branded booking page (team identity header + member booking flow).

### P15 — Admin Portal

- [ ] `/config` page — SystemConfig editor with grouped sections + autosave + audit trail.
- [ ] `/teams` page — table + search + filter + drawer with full team detail.
- [ ] User detail drawer — plan select (FREE/PRO/BUSINESS) → `PATCH /admin/users/:id/plan`.

---

## Phase 7 — Razorpay ⛔ BLOCKED

Account blocked. Do not start. Uncomment env vars and build when account is live.

---

## Phase 8 — Big Brain Agent ⛔ BLOCKED

**Blocked until:** Phase 5 (Encryption at Rest) ships + pgvector extension enabled on Postgres instance.

**The vision:** A fully autonomous AI agent that knows everything about the user across Crelyzor and connected external platforms. It doesn't just answer questions — it takes actions. It can schedule a meeting, create a task, reply to a booking request, fetch your unread Slack messages, draft a Gmail reply, and tell you what to focus on today — all from a single chat interface or triggered automatically.

---

### What this is NOT

Not a chatbot that wraps GPT. Not another RAG Q&A. This is an **agentic loop** — the LLM reasons, picks a tool, executes it, sees the result, reasons again, and repeats until the job is done. The user gives intent; the agent figures out the steps.

---

### Architecture

```
User message / scheduled trigger
        ↓
   Agent Core (LLM with tool use)
        ↓  reasons: "I need to check their calendar first"
        ↓  calls tool: get_upcoming_meetings({ days: 7 })
        ↓  gets result back
        ↓  reasons: "3pm slot is free, create the booking"
        ↓  calls tool: create_booking({ ... })
        ↓  gets confirmation
        ↓
  Final response streamed to user
```

**Key model:** Gemini 2.5 Flash (already integrated) with function calling / tool use. Falls back to structured OpenAI function calling if needed.

**Memory layers:**
- Short-term: conversation history (already exists via AskAIConversation)
- Semantic: vector embeddings of all user data in pgvector — transcripts, notes, tasks, contacts, bookings
- Structured: live Crelyzor DB + external platform APIs via tool calls

---

### Crelyzor-native tools (agent can call these)

| Tool | What it does |
|---|---|
| `get_meetings(filter)` | List meetings by date range, participant, tag |
| `get_meeting_detail(id)` | Full transcript + summary + tasks for one meeting |
| `create_task(title, due, priority)` | Create a task |
| `update_task(id, fields)` | Update status, due date, assignee |
| `get_tasks(filter)` | List tasks by status, due date, source |
| `create_booking(eventTypeId, slot, guestEmail)` | Schedule a booking on behalf of user |
| `cancel_booking(id, reason)` | Cancel an existing booking |
| `get_availability(date_range)` | Check free slots across event types |
| `get_contacts(query)` | Search card contacts by name / company / email |
| `get_contact_history(contactId)` | All meetings + tasks linked to a contact |
| `search_memory(query)` | Semantic RAG search over all user data |
| `send_notification(message)` | Push an in-app notification to the user |

---

### External platform integrations (Phase 8 adds these)

Each integration requires OAuth connection per user (stored as encrypted tokens). Agent can read AND write.

| Platform | Read | Write |
|---|---|---|
| **Gmail** | Unread emails, thread content, search | Draft reply, send email, label/archive |
| **Google Calendar** | Events, free/busy, attendees | Create event, update, cancel, add Meet link |
| **Slack** | Channel messages, DMs, mentions, search | Send message, reply in thread, set status |
| **Linear** | Issues, projects, assigned to user | Create issue, update status, add comment |
| **Notion** | Pages, databases, linked content | Create page, append block, update property |

OAuth tokens stored in new `UserIntegration` model — encrypted at rest (Phase 5 prerequisite).

---

### Proactive agent modes (runs on schedule, no user prompt needed)

| Mode | Trigger | What it does |
|---|---|---|
| **Morning briefing** | 8am daily | Summarizes: today's meetings, overdue tasks, unread Slack mentions, priority emails |
| **Meeting prep** | 30min before any scheduled meeting | Pulls: past meetings with these people, open action items, last decisions made, their company context from contacts |
| **Follow-up nudge** | 24h after meeting ends | Checks if AI-extracted tasks are still open, drafts follow-up email if requested |
| **Weekly digest** | Monday 8am | What you did last week, what's coming, what's overdue |
| **Booking manager** | On new booking received | Optionally sends a pre-call prep email to guest, creates prep task for host |

---

### P0 — Vector store foundation (prerequisite for everything)

- [ ] Enable `pgvector` extension on Postgres: `CREATE EXTENSION IF NOT EXISTS vector`
- [ ] Add `embedding vector(1536)` column to: `MeetingTranscript`, `MeetingNote`, `MeetingAISummary`, `Task`, `CardContact` (Prisma `Unsupported("vector(1536)")`)
- [ ] `embeddingService.ts` — `embedText(text): Promise<number[]>` via OpenAI `text-embedding-3-small`
- [ ] Embedding pipeline: after AI processing completes on a meeting, embed transcript + summary + notes + tasks and store vectors
- [ ] `searchMemory(userId, query, topK): Promise<Chunk[]>` — pgvector cosine similarity search across all tables, filtered by userId
- [ ] Bull job: `EMBED_CONTENT` — triggered after transcription completes, embeds all new/updated content for a meeting
- [ ] Backfill: embed all existing user content on Phase 8 launch

### P1 — Agent core

- [ ] `agentService.ts` — the agent loop:
  - Accepts `{ userId, message, conversationId? }`
  - Builds system prompt with: user profile, today's date, available tools list
  - Calls Gemini with function calling enabled (tool definitions passed as `tools` array)
  - On tool call response: execute the tool, append result to messages, loop
  - Max 10 tool call iterations per turn (prevent runaway loops)
  - Streams responses via the **existing WebSocket connection** (not SSE) — reuses the notification WS, no new connection needed
- [ ] WS message types added to the existing WS server (Phase 4.9):

  ```
  Client → Server:
    { type: 'AGENT_MESSAGE', conversationId, text }
    { type: 'AGENT_CANCEL', conversationId }          ← cancels mid-run loop

  Server → Client:
    { type: 'AGENT_CHUNK', conversationId, text }          ← streaming text token
    { type: 'AGENT_TOOL_CALL', conversationId, tool, input }    ← "Checking calendar..."
    { type: 'AGENT_TOOL_RESULT', conversationId, tool, summary } ← "Found 3 events"
    { type: 'AGENT_DONE', conversationId }
    { type: 'AGENT_ERROR', conversationId, message }
  ```

  Why WS over SSE: bidirectional mid-stream (user can cancel, agent can ask clarifying questions), reuses authenticated connection already open, one connection carries notifications + agent events together.

- [ ] Tool registry: `src/agent/tools/` — one file per tool, each exports `{ definition, execute }`. Definition is the JSON schema Gemini expects. Execute calls service layer directly (never HTTP).
- [ ] `GET /agent/conversations` — list conversation history (REST, not WS)
- [ ] `AskAIConversation` already exists — reuse it for agent conversations (new `isAgentConversation: Boolean` flag)

### P2 — Crelyzor tool implementations

- [ ] Implement all tools listed in the Crelyzor-native tools table above
- [ ] Each tool: Zod input schema + TypeScript execute function that calls internal services (never goes to HTTP — calls service layer directly)
- [ ] Tool results are truncated / summarised if too large (transcripts → summary only unless agent explicitly asks for full text)
- [ ] Error handling: tool failures return `{ error: string }` — agent sees the error and can retry or tell the user

### P3 — External platform integrations

- [ ] `UserIntegration` Prisma model: `{ userId, platform, accessToken (Bytes — encrypted), refreshToken (Bytes), expiresAt, scopes, createdAt }`
- [ ] OAuth connection flow per platform: `GET /integrations/:platform/connect` → OAuth → `GET /integrations/:platform/callback` → store tokens
- [ ] Token refresh middleware: before each tool call, check expiry and refresh if needed
- [ ] Gmail tools: `gmail_get_unread`, `gmail_search`, `gmail_send`, `gmail_reply` — via Google Gmail API v1
- [ ] Google Calendar tools: already partially built (Phase 1.3) — extend with write tools (`gcal_create_event`, `gcal_update_event`, `gcal_cancel_event`)
- [ ] Slack tools: `slack_get_mentions`, `slack_search`, `slack_send_message`, `slack_reply` — via Slack Web API (Bot Token OAuth)
- [ ] Linear tools: `linear_get_issues`, `linear_create_issue`, `linear_update_issue` — via Linear GraphQL API
- [ ] Notion tools: `notion_search`, `notion_create_page`, `notion_append_block` — via Notion API v1
- [ ] Settings > Integrations section extended: show connected platforms, connect/disconnect per platform, scopes granted

### P4 — Proactive agent (scheduled, no user prompt)

- [ ] Bull jobs for each proactive mode (morning briefing, meeting prep, follow-up nudge, weekly digest, booking manager) — see table above
- [ ] Each proactive job: runs the agent loop with a system-constructed prompt (no user message), sends result as in-app notification + optional email
- [ ] User can toggle each proactive mode on/off in Settings > AI Agent section (new sub-section)
- [ ] `UserAgentPreferences` — new model or extend `UserSettings`: `morningBriefingEnabled`, `meetingPrepEnabled`, `followUpNudgeEnabled`, `weeklyDigestEnabled`, `bookingManagerEnabled`

### P5 — Frontend: Agent chat interface

- [ ] `/agent` route — full-page chat interface, different from per-meeting Ask AI
- [ ] Conversation sidebar: list past agent conversations, new conversation button
- [ ] Message composer: text input + optional voice input (Web Speech API → transcript → send as text)
- [ ] Streaming response rendering via existing `useNotificationSocket` hook — extend it to handle `AGENT_CHUNK`, `AGENT_TOOL_CALL`, `AGENT_TOOL_RESULT`, `AGENT_DONE`, `AGENT_ERROR` message types. No new WS connection — agent events ride the same authenticated connection as notifications.
- [ ] Tool call visibility: show what the agent did between messages (collapsible "Agent used 4 tools" row)
- [ ] Connected platforms panel in sidebar: green dot = connected, grey = not connected, click = connect/disconnect
- [ ] Proactive notifications from agent appear as regular in-app notifications (Phase 4.9 already built)

### P6 — Migrate Ask AI from SSE → WebSocket

Ask AI currently streams via SSE (one HTTP request per question → one response stream). With the agent WS channel live, Ask AI moves to the same connection — consistent transport, cancellable mid-stream, and one less SSE infrastructure path to maintain.

**Backend changes:**
- [ ] Add WS message types to existing WS server:
  ```
  Client → Server:
    { type: 'ASK_AI_MESSAGE', meetingId, conversationId, text }
    { type: 'ASK_AI_CANCEL', conversationId }

  Server → Client:
    { type: 'ASK_AI_CHUNK', conversationId, text }
    { type: 'ASK_AI_DONE', conversationId }
    { type: 'ASK_AI_ERROR', conversationId, message }
  ```
- [ ] `aiService.askAI()` — replace `res.write(SSE chunk)` with `registry.broadcast(userId, { type: 'ASK_AI_CHUNK', ... })` using the existing WS client registry from Phase 4.9
- [ ] Keep `POST /sma/meetings/:meetingId/ask` route but change it to: validate + authenticate, then kick off the stream via WS and return `202 { conversationId }` immediately (fire-and-forget HTTP trigger)
- [ ] Remove SSE headers (`Content-Type: text/event-stream`, `Connection: keep-alive`) from the ask endpoint

**Frontend changes:**
- [ ] Extend `useNotificationSocket` hook to handle `ASK_AI_CHUNK`, `ASK_AI_DONE`, `ASK_AI_ERROR` — append chunks to a per-conversationId buffer in a ref or Zustand slice
- [ ] `useAskAI(meetingId)` hook — sends `ASK_AI_MESSAGE` over WS instead of opening a `fetch` ReadableStream; listens to the WS buffer for chunks
- [ ] Remove the `ReadableStream` / `getReader()` logic from the existing Ask AI hook
- [ ] Cancel button in Ask AI chat panel now sends `ASK_AI_CANCEL` over WS instead of `controller.abort()`
- [ ] All 3 meeting detail layouts (VoiceNoteDetail, RecordedDetail, ScheduledDetail) pick up the change automatically — they use the hook, not raw fetch

**Why this is in Phase 8 and not sooner:** Ask AI SSE works fine today. The migration is low-risk but requires the WS registry infrastructure from Phase 4.9 to be solid in prod first, and it makes most sense to do alongside the agent launch so both use the same transport from day one.

---

**Effort estimate:** 4–6 weeks total. P0 + P1 are the foundation. P2 is mechanical find-replace. P3 is one week per new platform integration. P4 + P5 build on everything. P6 (Ask AI migration) is ~1 day once the WS message types are defined.

**Model choice at build time:** Re-evaluate Gemini 2.5 Flash vs Claude 3.5 Sonnet vs GPT-4o for the agent loop. Tool use quality varies significantly across models and the field moves fast. Pick whichever has the best function-calling benchmark at the time Phase 8 starts.

---

## Admin Portal ✅ COMPLETE

Founder ops dashboard — user management, plan upgrades, platform stats.
Design: `docs/superpowers/specs/2026-05-08-admin-portal-design.md`
Repo: `github.com/crelyzor/crelyzor-admin` (port 5175, separate git)
Run with: `make admin-up` | Stop with: `make admin-down`

- [x] Backend: verifyAdmin middleware + /api/v1/admin/* route group
- [x] Backend: adminService — login, listUsers, getUserDetail, updateUserPlan, resetUserUsage, getPlatformStats
- [x] Frontend: Login page (env-based credentials → JWT)
- [x] Frontend: Dashboard (platform stats — total users, plan breakdown, usage totals)
- [x] Frontend: Users table with search, pagination, plan management, usage reset
- [x] Docker Compose profile (make admin-up / admin-down / admin-logs)
- [x] crelyzor-start skill updated to include crelyzor-admin as 4th repo

**Phase 2 (future):**
- [ ] Audit log — record every plan change
- [ ] User suspend / soft-delete from admin
- [ ] System health dashboard
- [ ] Team member access (AdminUser table)
- [ ] Production deploy
