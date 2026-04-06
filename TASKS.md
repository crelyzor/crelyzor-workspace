# Crelyzor — Master Task List

Last updated: 2026-04-06 (Phase 3.4 planned + Phase 3.2/3.3 audit)

> **Rule:** When you complete a task, change `- [ ]` to `- [x]` and move it to the Done section.
> **Legend:** `[ ]` Not started · `[~]` Has code but broken/incomplete · `[x]` Done and working

See per-repo tasks for implementation details:
- [calendar-backend/TASKS.md](./calendar-backend/TASKS.md)
- [calendar-frontend/TASKS.md](./calendar-frontend/TASKS.md)
- [cards-frontend/TASKS.md](./cards-frontend/TASKS.md)

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
5. **Ask AI persistence** — deferred to Phase 2 Big Brain.

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
- [ ] **Backend + Frontend:** Meeting ↔ Card contact auto-linking (match participant email to card contact)

### P4 — Major Feature
- [ ] **Backend + Frontend:** Recurring tasks — `recurringRule` (RRULE) on Task schema + UI picker + auto-generate next occurrence on complete

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
- [ ] **Public:** Verify vCard download works on iOS and Android

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
- [ ] **Backend + Frontend:** Meeting ↔ Card contact auto-linking (already in P3.2 backlog — bump priority)
- [ ] **Frontend:** Ask AI discovery — surface "Ask AI" as a prominent action on the meeting list row and home dashboard (not buried at the bottom of meeting detail)
- [ ] **Backend:** Speaker memory — when user renames "Speaker 0" → "John Smith" in one meeting, remember the mapping so future meetings from the same voice are pre-labeled (requires voice fingerprint from Deepgram)

### P4 — Recurring Tasks (table stakes for task management)
- [ ] **Backend + Frontend:** Recurring tasks — `recurringRule` (RRULE) on Task schema + UI picker + auto-generate next occurrence on complete (already in 3.2 P4 — carry forward)

### P5 — Data Import (how people switch tools)
- [ ] **Backend + Frontend:** Contact CSV import — upload a CSV, map columns (name, email, phone, company), bulk-create CardContacts on a chosen card
- [ ] **Backend + Frontend:** Calendar import — import .ics file → create Meeting records for past meetings (gives AI something to process)

---

## Phase 3.4 — Global Tags ← next

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
- [ ] **Backend:** `ContactTag` junction model + migrate `Tag` + `CardContact` relations
- [ ] **Backend:** Add `contactTags` cleanup to `deleteTag` transaction

### P1 — Backend APIs
- [ ] **Backend:** Contact tag endpoints (`GET/POST/DELETE /cards/:cardId/contacts/:contactId/tags/:tagId`)
- [ ] **Backend:** `GET /tags/:tagId/items` — returns `{ tag, meetings[], cards[], tasks[], contacts[], counts }`
- [ ] **Backend:** `listTags` updated to include counts per type

### P2 — Frontend: Tags Index + Detail Pages
- [ ] **Frontend:** `/tags` index page — tag grid with counts, inline create, rename, delete
- [ ] **Frontend:** `/tags/:tagId` detail page — 4 sections (Meetings / Cards / Tasks / Contacts)
- [ ] **Frontend:** Register routes + add "Tags" to sidebar nav

### P3 — Frontend: Tags on Contacts
- [ ] **Frontend:** Tag chips on contact rows in Cards contacts view
- [ ] **Frontend:** Tag editor popover on contacts (same pattern as meetings/cards)
- [ ] **Frontend:** Tag filter bar on contacts list

### P4 — Tag Chip Navigation
- [ ] **Frontend:** Clicking any tag chip anywhere navigates to `/tags/:tagId`

---

## Phase 4 — Big Brain ⛔ BLOCKED

Explicitly blocked. Do not start. Requires separate vector DB infrastructure that is not yet in place.

- [ ] Vector embeddings pipeline — embed transcripts, notes, tasks on creation/update
- [ ] Global Ask AI — RAG query over all user data ("What do I know about Acme Corp?")
- [ ] Cross-meeting insights — surface patterns across meetings
- [ ] Proactive nudges — missed follow-ups, upcoming meeting prep
- [ ] **Full two-way GCal sync** — GCal push webhooks → GCal edits/cancels reflect in Crelyzor (deferred from 1.3 — requires webhook infra + conflict resolution)

---

## Teams — Future Scope

Not scoped. Do not build.
