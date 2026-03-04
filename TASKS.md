# Crelyzor — Master Task List

Last updated: 2026-03-04

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

1. **`cards-frontend`:** Migrate to Next.js App Router — prerequisite for all public page work (SSR + SEO + OG previews)
2. **Backend + Frontend + Public:** Public meeting links
   - Backend: `shortId` on Meeting, `publishedFields` (transcript/summary/tasks flags), `POST /sma/meetings/:id/publish`, `GET /public/meetings/:shortId`
   - Dashboard (`calendar-frontend`): Publish toggle + field checkboxes + "Copy link" button on MeetingDetail
   - Public page (`cards-frontend`): `/m/:id` — SSR page showing selected content
3. **Backend + Frontend:** Export — Transcript as PDF/TXT, Summary as PDF/TXT
4. **Backend + Frontend:** Tags — universal system (meetings first, then cards)
5. **Backend + Frontend:** Attachments — file/photo/link on meetings
6. **Backend + Frontend:** Edit transcript segments + summary content inline
7. **Backend:** Regenerate transcript, Change language (re-run Deepgram)
8. **Frontend:** UI revamp — new layout to accommodate all the new feature surface area

---

### Not Built Yet ❌
- `cards-frontend` Next.js migration
- Public meeting links (backend publish model + dashboard toggle + `/m/:id` public page)
- Export (PDF/TXT)
- Tags
- Attachments
- Inline editing (transcript, summary)

---

## Phase 1.2 — Online Meetings (Do not start until Phase 1 done)

- [ ] Cal.com style scheduling + availability settings
- [ ] Public booking page
- [ ] Google Calendar sync (read + write)
- [ ] Recall.ai bot — joins Google Meet / Zoom, same pipeline triggers automatically

---

## Phase 2 — Big Brain

- [ ] Global Ask AI (RAG over all user data — transcripts, notes, tasks)
- [ ] Cross-meeting insights ("What do I know about Acme Corp?")
- [ ] Proactive nudges (missed follow-ups, upcoming meeting prep)
- [ ] Vector embeddings pipeline

---

## Phase 3 — Standalone Tasks + Tags Everywhere

- [ ] Task model — standalone with optional `meetingId` (meeting-linked tasks become proper tasks)
- [ ] Task list (Todoist-style — filter, priority, due date)
- [ ] AI task suggestions from meetings
- [ ] Tags — extend to Tasks, Cards, everything

---

## Teams — Future Scope

Not scoped. Do not build.
