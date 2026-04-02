# Crelyzor — Master Task List

Last updated: 2026-04-02 (Phase 3 complete)

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
- [ ] **Frontend:** Fix "Reschedule meeting" button — remove "coming soon" toast, implement rescheduling
- [ ] **Frontend:** Privacy Settings tab — either build (data export + delete account) or remove the tab

### P1 — Quick Wins (high value, low effort)
- [ ] **Frontend:** Task count badges on sidebar nav items (Inbox · Today · Upcoming)
- [ ] **Frontend:** Overdue tasks section on home dashboard (above the timeline)
- [ ] **Frontend:** NL parsing in inline task create form (same parser as Cmd+K)
- [ ] **Backend + Frontend:** Task duration field — `durationMinutes` on Task schema + detail panel picker + calendar renders correct block height
- [ ] **Frontend:** Jump-to-date on calendar — clicking the week label opens a date picker
- [ ] **Frontend:** Email signature generator for cards

### P2 — Meaningful Features
- [ ] **Backend:** Auto-create "Prepare for [meeting]" task on booking confirmed
- [ ] **Frontend:** "New tasks from meeting" badge on home dashboard after AI processes
- [ ] **Frontend:** Task bulk actions — select multiple, bulk complete / delete / set priority
- [ ] **Frontend:** Card analytics — views trend chart + link click breakdown
- [ ] **Frontend:** Onboarding flow for new users (empty state → guided first actions)

### P3 — Bigger Features
- [ ] **Backend + Frontend:** Global search — across meetings, tasks, cards, contacts
- [ ] **Frontend:** Calendar month view
- [ ] **Frontend:** Keyboard shortcuts — J/K navigation, E edit, D due date, P priority, Enter open panel
- [ ] **Backend + Frontend:** Schedule task → create GCal block (when scheduledTime is set)
- [ ] **Backend + Frontend:** Meeting ↔ Card contact auto-linking (match participant email to card contact)

### P4 — Major Feature
- [ ] **Backend + Frontend:** Recurring tasks — `recurringRule` (RRULE) on Task schema + UI picker + auto-generate next occurrence on complete

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
