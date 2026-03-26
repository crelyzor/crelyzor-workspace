# Crelyzor — Master Task List

Last updated: 2026-03-08 (Phase 1 complete ✅)

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

## Phase 1.2 — Scheduling & Online Meetings ← current

Full design doc: `docs/dev-notes/phase-1.2-scheduling.md`
Per-repo task breakdowns: each repo's `TASKS.md`

**Build order (each is independently shippable):**

| # | What | Repo |
|---|------|------|
| 1 | Schema: UserSettings, EventType, Availability, AvailabilityOverride, Booking | backend |
| 2 | DB migration | backend |
| 3 | UserSettings auto-create on sign-up + `GET/PATCH /settings/user` API | backend |
| 4 | Settings page skeleton (all tabs) | frontend |
| 5 | Scheduling settings UI section | frontend |
| 6 | AI & Transcription settings UI section | frontend |
| 7 | Event types CRUD API | backend |
| 8 | Event types UI (list + form) | frontend |
| 9 | Availability API (weekly + overrides) | backend |
| 10 | Availability UI (weekly grid + overrides) | frontend |
| 11 | Slot calculation engine | backend |
| 12 | Slots API + public profile API | backend |
| 13 | Public booking pages (`/schedule/:username`, `/:slug`, `/confirmed`) | public |
| 14 | Booking creation API (`POST /public/bookings`) | backend |
| 15 | Booking management API (host cancel, guest cancel) | backend |
| 16 | Google Calendar re-auth + read sync (busy times in slot engine) | backend |
| 17 | Google Calendar write sync (create/cancel events) | backend |
| 18 | Google Calendar settings UI | frontend |
| 19 | Recall.ai service + bot job + webhook | backend |
| 20 | Recall.ai settings UI | frontend |

Stop at #15 for a complete, working booking system without integrations.

---

## Phase 2 — Standalone Tasks

- [ ] Task list (Todoist-style — filter by status, priority, due date, meeting source)
- [ ] Standalone tasks API — `GET /tasks` (all tasks, not scoped to a meeting)
- [ ] Tags on Tasks (`TaskTag` junction — extends universal Tag system)
- [ ] Due date + priority support (model already has the fields, just needs API + UI)

---

## Phase 3 — Big Brain

- [ ] Global Ask AI (RAG over all user data — transcripts, notes, tasks)
- [ ] Cross-meeting insights ("What do I know about Acme Corp?")
- [ ] Proactive nudges (missed follow-ups, upcoming meeting prep)
- [ ] Vector embeddings pipeline

---

## Teams — Future Scope

Not scoped. Do not build.
