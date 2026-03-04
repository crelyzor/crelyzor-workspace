# Crelyzor — Roadmap

## North Star

Ship a solo product that feels like one unified system — not three features duct-taped together.

---

## Phase 1 — Offline First (Core Product)

**Goal:** A solo user can manage their identity, run meetings offline, and get full AI intelligence from those meetings.

**We are here.**

### Digital Cards
- [x] Card creation and editor
- [x] Public shareable card page
- [x] QR code generation
- [x] vCard download
- [x] Contact exchange (lead capture)
- [x] Card analytics
- [ ] Email signature generator (polish — low priority)
- [ ] Card templates polish (low priority)

### Smart Meeting Recordings

**Infrastructure (done)**
- [x] Meeting creation (CRUD) — SCHEDULED | RECORDED | VOICE_NOTE
- [x] Recording upload to GCS
- [x] Deepgram transcription pipeline
- [x] Speaker diarization (who said what)
- [x] Speaker rename
- [x] OpenAI summary + key points
- [x] Task model — `Task` with `TaskSource` + `TaskPriority` enums, replaces `MeetingActionItem`
- [x] Tasks CRUD API (`GET/POST /meetings/:id/tasks`, `PATCH/DELETE /tasks/:id`)
- [x] Meeting notes CRUD (backend)
- [x] Delete meeting endpoint (`DELETE /meetings/:id`, soft delete)
- [x] 3 distinct MeetingDetail layouts by type
- [x] Voice Notes as separate section

**P0 — Core UX (done ✅)**
- [x] Auth refresh token (no more forced re-login)
- [x] Meeting notes UI
- [x] Tasks UI — CRUD, mark complete, create inline, delete (surfaced as "Tasks")
- [x] Edit meeting modal (SCHEDULED only)
- [x] Delete meeting (VOICE_NOTE + RECORDED, with confirm dialog)

**P1 — AI & Sharing ✅ Done**
- [x] Ask AI — per meeting, streaming chat, pre-loaded suggestions
- [x] Share sheet — copy transcript, copy summary, download audio, share via email
- [x] AI content generation — Meeting report, Main points, Tweet, Blog post, Email
- [x] Regenerate title, Regenerate summary

**P2 — Public Links & Power Features** ← current focus
- [ ] **Migrate `cards-frontend` to Next.js** — prerequisite for all public page work (SSR + SEO)
- [ ] **Public meeting links** — shortId, publish/unpublish toggle in dashboard, selective publish (transcript/summary/tasks), public page at `/m/:id` in cards-frontend
- [ ] Export — Transcript/Summary as PDF or TXT
- [ ] Tags — universal system (meetings + cards, extendable to Tasks)
- [ ] Attachments — file, photo, link on meetings
- [ ] Edit transcript segments + summary inline
- [ ] Regenerate transcript, Change language
- [ ] UI revamp — rethink MeetingDetail layout to fit all new feature surface area

### Home Dashboard
- [x] Recent meetings widget
- [x] Recent voice notes widget
- [x] Quick record CTA (FAB)
- [x] Cards widget
- [ ] Today's meetings widget (filtered to today, not just recent)
- [ ] Pending tasks widget across all meetings

---

## Phase 1.2 — Online Meetings

**Goal:** Same AI intelligence but for online meetings via Recall.ai bot.

**Prerequisite:** Phase 1 P0 + P1 complete.

### Recall.ai Integration
- [ ] Recall.ai API integration (backend)
- [ ] Bot deployment — joins Google Meet / Zoom
- [ ] Stream audio to Deepgram using existing pipeline
- [ ] Same transcription + AI pipeline triggers automatically

### Cal.com Style Scheduling
- [ ] Availability settings (recurring + custom windows) — dashboard in `calendar-frontend`
- [ ] Public booking page — `/schedule/:username` in `cards-frontend` (Next.js, SSR)
- [ ] Google Calendar sync (read + write)
- [ ] Time zone handling
- [ ] Booking confirmation flow

---

## Phase 2 — Big Brain (Global AI)

**Goal:** One AI that knows everything about the user across all of Crelyzor.

**Prerequisite:** Phase 1.2 complete. Enough meeting data to make it useful.

- [ ] Vector embeddings for all transcripts, notes, tasks
- [ ] RAG pipeline over user's full data
- [ ] Global "Ask anything" interface (not per-meeting — this is the Phase 3 evolution of Ask AI)
- [ ] Proactive nudges — missed follow-ups, upcoming meeting prep
- [ ] "Prepare me for my 3pm call" feature
- [ ] Cross-meeting insights: "What do I know about Acme Corp?"

---

## Phase 3 — Standalone Tasks

**Goal:** Todoist-style task management, deeply connected to meetings and AI. Tasks grow up from meeting-linked items to first-class standalone objects.

**Prerequisite:** Phase 2 (AI should drive task generation intelligently).

> Note: The `Task` model (with `TaskSource` + `TaskPriority` enums) was built early in Phase 1 to support meeting-linked tasks. Phase 3 evolves it into a standalone, first-class system.

- [x] `Task` model — `meetingId`, `TaskSource`, `TaskPriority`, CRUD API (built in Phase 1)
- [ ] Standalone tasks — decouple from meetings (optional `meetingId`, add `dueDate`, `status`)
- [ ] Task list page — filter, sort, priority, due date
- [ ] AI task suggestions from meetings (auto-create, not just display)
- [ ] Tags across Tasks (extends the universal Tag system from Phase 1)
- [ ] Link tasks to contacts (cards)

---

## Future — Teams

**Not scoped. Do not build.**

Will be designed after Solo Phases 1-3 are complete.

---

## Naming Decisions (locked)

| Old name | New name | Notes |
|---|---|---|
| Action Items | **Tasks** | Renamed in UI + backend — `Task` model replaced `MeetingActionItem` in Phase 1 |
| Ask AI (per meeting) | **Ask AI** | Phase 1. Global AI = Phase 2 Big Brain. |
| Action Items tab | **Tasks tab** | Rename in all 3 MeetingDetail layouts |
