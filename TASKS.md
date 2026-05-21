# Crelyzor — Master Task List

Last updated: 2026-05-09 (Phase 7 Teams — spec written, tasks planned across all repos)

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

## Phase 4.5 — Docker & Deployment

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
- [ ] Provision VM (EC2 t3.small or GCE e2-medium)
- [ ] Docker + Certbot installed on VM
- [ ] DNS A records pointing to server IP
- [ ] SSL certs issued via Certbot (`certbot certonly --nginx -d crelyzor.com -d app.crelyzor.com -d api.crelyzor.com`)
- [ ] GCS service account key on server
- [ ] Add GitHub Secrets: `VM_HOST`, `VM_USER`, `VM_SSH_KEY`, `VM_WORKSPACE_PATH`
- [ ] `crelyzor-backend/.env.prod` filled with real values on VM

### P6 — Go Live
- [ ] DB migrations run on prod (`docker compose -f docker-compose.prod.yml exec backend pnpm db:migrate`)
- [ ] Google OAuth callback URL updated in Google Console
- [ ] End-to-end test: sign in → create meeting → upload recording

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

## Phase 4.7 — Security Hardening ← current

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

**Horizontal scaling:** Redis pub/sub handles fan-out across multiple backend instances. Each instance maintains its own `ConnectionRegistry` and a single Redis subscriber that fans out to all local sockets for that user.

**`index.ts` integration:** `app.listen()` returns an `http.Server`. We pass that server instance directly to `createWsServer(server)` — no new port, no new process.

### Notification types

`BOOKING_RECEIVED` · `BOOKING_CONFIRMED` · `BOOKING_CANCELLED` · `BOOKING_REMINDER` · `MEETING_AI_COMPLETE` · `TASK_DUE_SOON`

### Backend (`crelyzor-backend`)

- [ ] **P0 — Schema:** `Notification` model + `NotificationType` enum + index on `[userId, isRead, createdAt]` + `inAppNotificationsEnabled`, `inAppBookingEnabled`, `inAppMeetingReadyEnabled`, `inAppTaskDueEnabled` on `UserSettings` + `pnpm db:migrate && pnpm db:generate`

- [ ] **P1 — WebSocket Foundation** ← replaces the SSE plan; install `ws` + `@types/ws`
  - `src/websocket/types.ts` — `WsServerMessage` + `WsClientMessage` discriminated unions
  - `src/websocket/connectionRegistry.ts` — `Map<userId, Set<WebSocket>>`, `add()`, `remove()`, `broadcast(userId, msg)`, `size()`
  - `src/websocket/wsAuth.ts` — extract `?token=` from upgrade request URL, call `tokenService.verifyAccessToken()`, validate session via `sessionService.validateSession()`, return `TokenPayload` or close with 4001
  - `src/websocket/heartbeat.ts` — 30s `setInterval`, send `{ type: 'PING' }`, mark `ws.isAlive = false`, terminate if no PONG received before next tick
  - `src/websocket/notificationSubscriber.ts` — `Map<userId, IORedis>` subscriber map; `subscribeUser(userId)` calls `redisClient.duplicate()`, `sub.subscribe('notify:${userId}')`, on message parses JSON and calls `registry.broadcast()`; `unsubscribeUser(userId)` when registry removes last connection for that user
  - `src/websocket/wsServer.ts` — `createWsServer(httpServer)`: creates `WebSocketServer({ server, path: '/ws' })`, on `connection`: run `wsAuth` (close 4001 if fail), add to registry, subscribe Redis channel, send `CONNECTED` with unread count, wire heartbeat, on `close` remove from registry + conditionally unsubscribe Redis; export `closeWsServer()`
  - `src/index.ts` — capture `const server = app.listen(...)`, call `createWsServer(server)`, add `closeWsServer()` to both SIGTERM and SIGINT shutdown handlers

- [ ] **P2 — Notification Service + REST Endpoints:** `src/services/notificationService.ts` (create with Redis publish, list paginated, markRead, markAllRead, delete, unreadCount) + `src/validators/notificationSchema.ts` + `src/controllers/notificationController.ts` + `src/routes/notificationRoutes.ts` registered under `/api/v1/notifications`. Endpoints: `GET /notifications` (paginated, filter by isRead), `GET /notifications/unread-count`, `PATCH /notifications/:id/read`, `PATCH /notifications/read-all`, `DELETE /notifications/:id`

- [ ] **P3 — Wire Triggers** — call `notificationService.create()` fail-open (try/catch, log on error, never throw) alongside existing email sends:
  - `bookingManagementService.ts` → `BOOKING_RECEIVED` to host on new booking, `BOOKING_CANCELLED` to host on cancellation
  - `bookingService.ts` reminder job → `BOOKING_REMINDER` to host + guest
  - `jobProcessor.ts` AI complete handler → `MEETING_AI_COMPLETE` after `aiService.processTranscriptWithAI()` succeeds
  - New daily 8am cron job (`TASK_DUE_SOON`) → query tasks where `dueDate = today AND isCompleted = false` per user, create one notification per user if any exist

- [ ] **P4 — Settings:** add `inApp*` fields to `settingsService.ts` `getUserSettings()` + `updateUserSettings()` + `settingsController.ts` response shape + `src/validators/settingsSchema.ts`

### Frontend (`crelyzor-frontend`)

- [ ] **P0 — WebSocket Client Hook**
  - `src/hooks/useWebSocket.ts` — singleton pattern (one connection per app lifetime, not per component); reads JWT from `authStore`; connects to `ws://<API_HOST>/ws?token=<jwt>`; typed `WsServerMessage` handler registry (`Map<string, Set<handler>>`); exponential backoff reconnect (3s → 6s → 12s → 24s → max 60s, reset on successful open); cleanup on unmount; disconnect on logout
  - `src/hooks/useNotificationStream.ts` — wraps `useWebSocket`, registers handler for `NOTIFICATION` message type; on event: `queryClient.invalidateQueries(queryKeys.notifications.all())` + show Sonner toast with notification title; mount this in `AppInitializer` so it runs for the entire authenticated session

- [ ] **P1 — Notification Service + Query Layer:** `src/services/notificationService.ts` (REST API calls for all 5 endpoints) + add `notifications` namespace to `src/lib/queryKeys.ts` + hooks: `useNotifications(filter?)`, `useUnreadCount()`, `useMarkRead()`, `useMarkAllRead()`, `useDeleteNotification()`

- [ ] **P2 — Notification Bell:** `<NotificationBell />` in app header — `Bell` icon (Lucide), red badge with unread count capped at "99+", badge hidden when count is 0, opens `<NotificationPanel />` on click, uses `useUnreadCount()` (60s polling fallback) + WS for instant update

- [ ] **P3 — Notification Panel:** `<NotificationPanel />` popover — skeleton while loading; empty state "You're all caught up" with muted bell icon; notification rows (type icon + title + body + relative time + unread dot); click row → `markRead` + navigate to entity (`/meetings/:id`, `/scheduling/bookings`, `/tasks`); "Mark all as read" button (hidden when all read); "Clear all" button; rows grouped into Today / Earlier sections

- [ ] **P4 — Settings:** expand Settings > Notifications tab — add "In-App" column alongside existing "Email" column; master `inAppNotificationsEnabled` toggle disables all per-type toggles below it; per-type: Bookings, Meeting AI ready, Task due soon

### Public (`crelyzor-public`)

No changes — notifications are authenticated dashboard-only.

### Future phases — zero infrastructure changes needed

| Phase | Addition |
|---|---|
| Phase 6 Teams | Add `TEAM_MEMBER_JOINED`, `MEMBER_PRESENCE_UPDATED` to `WsServerMessage`; publish to `notify:${userId}` from team service |
| Ask AI migration | Add `ASK_AI_CHUNK` / `ASK_AI_DONE` types; migrate `aiService.askAI()` to use `registry.broadcast()` instead of SSE; update frontend hook |
| Live collaborative notes | Add `NOTE_UPDATED` type; publish from `meetingNoteService` |

---

## Phase 5 — Encryption at Rest

> Full design spec: `docs/superpowers/specs/2026-05-16-encryption-at-rest-design.md`

**Goal:** every sensitive user-facing string and every recording object is encrypted at rest. Server holds keys (envelope encryption via Google Cloud KMS), AI features keep working unchanged. Not E2EE — Crelyzor can still decrypt to power AI; an explicit non-goal documented in the spec.

**Key model:**
- One KEK per environment in Google Cloud KMS — never leaves the HSM.
- One DEK per user, AES-256, stored as `User.wrappedDek` (wrapped by KEK).
- Unwrapped to plaintext only in backend memory, only for the duration of a single request (AsyncLocalStorage), discarded on request end.
- AES-256-GCM via Node's built-in `crypto`. No third-party crypto libs.
- Per-record ciphertext: `iv(12) ‖ ciphertext ‖ authTag(16)` in a single `Bytes` column.

**In scope (encrypted columns):**

| Model | Column(s) |
|---|---|
| `MeetingTranscript` | `fullText` |
| `TranscriptSegment` | `text` |
| `MeetingNote` | `content` |
| `MeetingAISummary` | `summary`, `keyPoints[]` |
| `MeetingAIContent` | `content` |
| `AskAIConversation` | message contents |
| `Task` | `title`, `description` |
| `CardContact` | `name`, `email`, `phone`, `notes` |
| `Booking` | `guestEmail`, `guestNotes` |

**In scope (storage):**
- GCS recordings bucket → bucket-level CMEK using the same KMS key (no app code changes; one `gsutil kms encryption -k ...` config).

**Out of scope (stays plaintext):**
- All IDs, FKs, timestamps, soft-delete flags
- `Meeting.title`, `Tag.name`, indexed fields (`speaker`, `startTime`)
- `Card.*` (public profile rendered to open web)
- `EventType.*`, `UserSettings`, `Task.status`, `Task.dueDate`

**Out of scope (explicitly not building):**
- End-to-end encryption — evaluated and rejected (kills AI features, breaks Phase 8 Big Brain, lost-passphrase = permanent data loss).
- Per-meeting "Private Mode" Hybrid opt-in — deferred until users actually ask for it.
- Searchable encryption / blind indexes — defer.

### P0 — Foundations (do first)

- [ ] Provision Google Cloud KMS keyring + KEK per environment (dev / staging / prod)
- [ ] IAM bind backend service account: `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the KEK only
- [ ] Build `src/utils/security/crypto.ts` — `encrypt(text, userId)`, `decrypt(bytes, userId)`, internal `getDek(userId)` with AsyncLocalStorage cache
- [ ] Unit tests: round-trip encrypt/decrypt, wrong-DEK fails, tampered ciphertext fails GCM auth check
- [ ] Add `cryptoMiddleware` that unwraps DEK once per request and caches in AsyncLocalStorage

### P1 — Schema changes

- [ ] Migration 1 (`add_wrapped_dek_and_bytes_columns`): add `User.wrappedDek Bytes?` + `<column>_encrypted Bytes?` shadow column for every in-scope column. Both old + new live side-by-side during backfill.
- [ ] Update Prisma schema accordingly. `pnpm db:migrate && pnpm db:generate`

### P2 — Backfill

- [ ] Script `src/scripts/backfill-encryption.ts` — generate DEKs for users missing one, then encrypt all in-scope rows. Idempotent, resumable, batched (1000/txn), dry-run mode.
- [ ] Run dry-run against staging DB snapshot — assert decrypt-roundtrip matches plaintext for 1000-row random sample
- [ ] Run against staging
- [ ] Run against prod (off-hours)

### P3 — Service-layer cutover

- [ ] Patch all in-scope service writes: encrypt before insert. ~30–50 call sites total.
- [ ] Patch all in-scope service reads: decrypt after fetch. Same call sites mostly.
- [ ] Feature flag `ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN` defaults `false`. When `true`, reads come from `_encrypted` column; when `false`, from plaintext column.
- [ ] Writes dual-write to both columns during the rollout window (~7 days), gated by same flag.
- [ ] Add logger denylist for encrypted fields — `logger.info({ transcript })`-style passes never log plaintext content.

### P4 — GCS CMEK

- [ ] Grant Cloud Storage service agent `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the KEK
- [ ] `gsutil kms encryption -k <key-resource-name> gs://<recordings-bucket>` — all new uploads encrypted
- [ ] Background `gsutil rewrite -k` for existing recording objects

### P5 — Cutover + cleanup

- [ ] Flip `ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN` → `true` in prod
- [ ] Monitor 7 days — KMS audit logs healthy, no decrypt failures, no plaintext leaks in app logs
- [ ] Migration 2 (`drop_plaintext_columns`): drop old String columns, rename `_encrypted` → original name
- [ ] Wire account-delete flow to destroy `wrappedDek` (crypto-shredding for GDPR)

### P6 — Hardening (post-cutover)

- [ ] Spot-check prod DB dump for any remaining plaintext content (`grep -c` on common transcript words against a redacted dump)
- [ ] Document the KMS disaster-recovery runbook (key destruction protection, regional failover, IAM hygiene)
- [ ] Cloud Logging alert on anomalous KMS unwrap volume
- [ ] Pre-encryption backups: inventory all Cloud SQL backups + manual snapshots, then delete or re-import-and-re-encrypt every pre-encryption backup — otherwise crypto-shredding has a plaintext escape hatch

**Effort estimate:** ~1.5 weeks for one focused engineer. Most of the time is in P2 (backfill correctness) and P3 (mechanical but wide find-and-replace + tests).

---

## Phase 6 — Teams

> Full design spec: `docs/superpowers/specs/2026-05-09-teams-design.md`
> Per-repo breakdowns: each repo's `TASKS.md`

**The model:** Pro users can create up to 3 teams (configurable via SystemConfig). The team owner pays for all consumption — transcription, storage, AI credits — for all members across all their teams. Members and admins consume the owner's Pro quota. Members join free.

**Workspace switching:** Top-left dropdown (where user name is today) switches between Personal and each team. Full context switch — all surfaces (meetings, cards, tasks, scheduling) scope to selection. Zero overlap.

**Roles:** Owner (full control, billing) / Admin (manage, no billing) / Member (own content only).

**Cards:** Team gets a public card at `crelyzor.app/t/:slug`. Members get auto-created team cards on join.

**Scheduling:** Each member sets their own availability within the team. External visitors book a specific member via `/schedule/t/:slug/:username`. Team members can book each other internally from the dashboard.

**Config:** All limits live in a `SystemConfig` table — editable from admin portal. Nothing hardcoded.

### P0 — Backend: Schema (do first — everything depends on this)

- [ ] `SystemConfig` model — key/value store for all limits and feature flags
- [ ] `Team` model — id (UUID), name, slug (unique), ownerId, logoUrl, createdAt, deletedAt
- [ ] `TeamMember` model — id, teamId, userId, role (OWNER | ADMIN | MEMBER), joinedAt, leftAt (nullable)
- [ ] Add `teamId UUID?` to: Meeting, Card, Task, EventType, Booking (null = personal context)
- [ ] Migration: `pnpm db:migrate && pnpm db:generate`

### P1 — Backend: Team CRUD + Member Management

- [ ] `POST /teams` — create team (Pro gate, SystemConfig max-teams check, auto-create team Card)
- [ ] `GET /teams` — list teams the user belongs to
- [ ] `PATCH /teams/:teamId` — update name/logo (Owner/Admin)
- [ ] `DELETE /teams/:teamId` — soft delete (Owner only)
- [ ] `GET /teams/:teamId/members` — list members with role + usage
- [ ] `POST /teams/:teamId/members/invite` — invite by userId or email
- [ ] `PATCH /teams/:teamId/members/:userId` — change role (Owner only)
- [ ] `DELETE /teams/:teamId/members/:userId` — remove member (Owner/Admin)
- [ ] `POST /teams/invites/:token/accept` — accept email invite
- [ ] `DELETE /teams/:teamId/leave` — leave team (blocked if Owner)

### P2 — Backend: Team-scoped Content + Middleware

- [ ] `verifyTeamMember` middleware — verifies user is active member (`leftAt IS NULL`)
- [ ] `verifyTeamRole('ADMIN' | 'OWNER')` middleware — role check on top of membership
- [ ] All meeting/card/task/scheduling endpoints respect `teamId` context header
- [ ] Meeting visibility: Members see own meetings only; Owner/Admin see all team meetings
- [ ] `GET /teams/:teamId/usage` — per-member consumption breakdown (Owner/Admin only)

### P3 — Backend: Team Scheduling (public endpoints)

- [ ] `GET /public/scheduling/team/:slug/profile` — team profile + active member list
- [ ] `GET /public/scheduling/team/:slug/:username` — specific member's scheduling profile (team context)
- [ ] Slot engine respects team-scoped EventTypes

### P4 — Backend: Admin Portal Config API

- [ ] `GET /admin/config` — list all SystemConfig entries
- [ ] `PATCH /admin/config/:key` — update a config value
- [ ] `GET /admin/teams` — list all teams with owner + member count

### P5 — Frontend: Workspace Switcher + Team Store

- [ ] `teamStore` (Zustand) — `activeTeamId`, `teams[]`, `setActiveTeam()`
- [ ] Top-left workspace switcher dropdown — Personal + team list + "Create team"
- [ ] All API calls in team context include `X-Team-Id` header
- [ ] `useTeams()` query hook, `teamService.ts`

### P6 — Frontend: Team Creation + Settings

- [ ] Team creation modal (name, slug, logo upload)
- [ ] `/teams/:teamId/settings` — General (name/logo) + Members + Usage tabs
- [ ] Invite modal — search existing users OR enter email
- [ ] Pending invites list in settings
- [ ] Per-member usage breakdown table

### P7 — Frontend: Team-aware Content Pages

- [ ] All pages (Meetings, Cards, Tasks, Calendar) scope to activeTeamId when in team context
- [ ] Meeting visibility enforced — Members can't see other members' meetings
- [ ] Team context indicator in header/sidebar
- [ ] Internal booking: pick team member → see availability → book (from meetings/scheduling page)

### P8 — Public: Team Public Card Page

- [ ] `/t/:slug` — SSR team public page (name, logo, description, member roster)
- [ ] OG meta + structured data
- [ ] 404 when team not found or deleted

### P9 — Public: Team Member Booking Page

- [ ] `/schedule/t/:slug/:username` — book specific team member (team-branded)
- [ ] Same UX as personal booking; member's team EventTypes shown

### P10 — Admin Portal: SystemConfig + Teams Pages

- [ ] System Config page — list all config keys, inline edit values
- [ ] Teams page — list all teams, owner, member count, creation date, soft-delete

---

## Phase 7 — Razorpay ⛔ BLOCKED

Account blocked. Do not start. Uncomment env vars and build when account is live.

---

## Phase 8 — Big Brain ⛔ BLOCKED

Explicitly blocked. Do not start. Requires separate vector DB infrastructure that is not yet in place.
Requires Phase 4.1 + 4.2 complete first — Big Brain features are paid-only.

- [ ] Vector embeddings pipeline — embed transcripts, notes, tasks on creation/update
- [ ] Global Ask AI — RAG query over all user data ("What do I know about Acme Corp?")
- [ ] Cross-meeting insights — surface patterns across meetings
- [ ] Proactive nudges — missed follow-ups, upcoming meeting prep
- [ ] **Full two-way GCal sync** — GCal push webhooks → GCal edits/cancels reflect in Crelyzor (deferred from 1.3 — requires webhook infra + conflict resolution)
- [x] Model upgrades — Nova-3 Multilingual + gpt-5.4-mini ✅ done in Phase 4

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
