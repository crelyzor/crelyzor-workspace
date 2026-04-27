# Crelyzor — Master Task List

Last updated: 2026-04-22 (Phase 4.4 complete ✅ — Polish & First-Run Experience shipped)

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

> ⛔ **Payment gateway — NOT DOING NOW.** Razorpay account blocked. Upgrade users manually via Prisma Studio (`user.plan = PRO`). Revisit later.

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

## Phase 4.7 — Razorpay ⛔ BLOCKED

Account blocked. Do not start. Uncomment env vars and build when account is live.

---

## Phase 5 — Big Brain ⛔ BLOCKED

Explicitly blocked. Do not start. Requires separate vector DB infrastructure that is not yet in place.
Requires Phase 4.1 + 4.2 complete first — Big Brain features are paid-only.

- [ ] Vector embeddings pipeline — embed transcripts, notes, tasks on creation/update
- [ ] Global Ask AI — RAG query over all user data ("What do I know about Acme Corp?")
- [ ] Cross-meeting insights — surface patterns across meetings
- [ ] Proactive nudges — missed follow-ups, upcoming meeting prep
- [ ] **Full two-way GCal sync** — GCal push webhooks → GCal edits/cancels reflect in Crelyzor (deferred from 1.3 — requires webhook infra + conflict resolution)
- [x] Model upgrades — Nova-3 Multilingual + gpt-5.4-mini ✅ done in Phase 4

---

## Teams — Future Scope

Not scoped. Do not build.
