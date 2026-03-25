# Crelyzor — Roadmap

## North Star

Ship a solo product that feels like one unified system — not three features duct-taped together.

---

## Phase 1 — Offline First (Core Product) ✅ COMPLETE

**Goal:** A solo user can manage their identity, run meetings offline, and get full AI intelligence from those meetings.

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

**P2 — Public Links & Power Features** ✅ Done
- [x] **Migrate `cards-frontend` to Next.js** — mobile-first, PWA (dynamic manifest per username), SSR + SEO + OG previews
- [x] **Public meeting links** — shortId, publish/unpublish toggle in dashboard, selective publish (transcript/summary/tasks), public page at `/m/:id` in cards-frontend
- [x] Export — Transcript/Summary as PDF or TXT
- [x] Tags — universal system (meetings + cards, extendable to Tasks)
- [x] Attachments — file, photo, link on meetings
- [x] Edit transcript segments + summary inline
- [x] Regenerate transcript, Change language
- [x] Mobile responsiveness + UI revamp — bottom tab bar on mobile (`calendar-frontend`)

### Home Dashboard
- [x] Recent meetings widget
- [x] Recent voice notes widget
- [x] Quick record CTA (FAB)
- [x] Cards widget
- [x] Today's meetings widget (filtered to today, not just recent)
- [x] Pending tasks widget across all meetings

---

## Phase 1.2 — Scheduling & Online Meetings

**Goal:** Solo professionals can share a booking link, let guests book time, and have meetings auto-transcribed whether online or in-person.

**Prerequisite:** Phase 1 complete ✅

**We are here.**

Full design doc: `docs/dev-notes/phase-1.2-scheduling.md`

---

### P0 — Data Model & Settings Foundation

> Must be done first. Everything else depends on it.

- [ ] `UserSettings` model — one-to-one with User, stores all feature flags + scheduling config
- [ ] `EventType` model — title, slug, duration, locationType (IN_PERSON | ONLINE), bufferBefore, bufferAfter, meetingLink, isActive
- [ ] `Availability` model — userId, dayOfWeek (0-6), startTime, endTime
- [ ] `AvailabilityOverride` model — userId, date, isBlocked (specific day off)
- [ ] `Booking` model — eventTypeId, guestName, guestEmail, guestNote, startTime, endTime, timezone, status (PENDING | CONFIRMED | CANCELLED | NO_SHOW), meetingId FK, googleEventId
- [ ] DB migration for all new models
- [ ] Settings page UI — skeleton with all sections (Scheduling, Integrations, AI, Privacy)
- [ ] Settings: scheduling on/off, min notice, max window, default buffer
- [ ] Settings: auto-transcribe on/off, auto-AI on/off, default transcription language

---

### P1 — Event Types + Availability (the scheduling engine)

- [ ] Event types CRUD API (`GET/POST /scheduling/event-types`, `PATCH/DELETE /scheduling/event-types/:id`)
- [ ] Event types UI — create, edit, delete, activate/deactivate
- [ ] Availability settings API (`GET/PATCH /scheduling/availability`)
- [ ] Availability settings UI — weekly schedule grid (per-day on/off + time range)
- [ ] Availability overrides API — mark specific dates as blocked
- [ ] Slot calculation engine (backend service) — availability windows MINUS existing meetings MINUS existing bookings MINUS buffers
- [ ] `GET /scheduling/slots?eventTypeId=&date=` — returns available slots for a given date

---

### P2 — Public Booking Pages (`cards-frontend`)

- [ ] `/schedule/:username` — lists all active event types (SSR, SEO, OG)
- [ ] `/schedule/:username/:slug` — calendar picker, slot grid, timezone-aware
- [ ] Booking form — guest name, email, optional note, timezone picker
- [ ] Booking confirmation page — summary + add-to-calendar button
- [ ] `POST /public/bookings` — creates Booking + Meeting atomically (no auth)
- [ ] `GET /public/bookings/:id` — confirmation page data
- [ ] Booking cancellation — guest can cancel via link in email (future: email; now: confirmation page)

---

### P3 — Google Calendar Integration

- [ ] Settings: connect Google Calendar (OAuth re-auth with calendar scope)
- [ ] Settings: disconnect Google Calendar
- [ ] Read sync — fetch Google Calendar events for busy-time calculation (injected into slot engine)
- [ ] Write sync — create Google Calendar event when booking is confirmed (with guest as attendee)
- [ ] Write sync — cancel/update Google Calendar event when booking is cancelled/rescheduled
- [ ] Store `googleEventId` on `Booking`
- [ ] Settings: show sync status (last synced, connected account)

---

### P4 — Recall.ai Integration

- [ ] Settings: Recall.ai on/off toggle + API key input (stored encrypted)
- [ ] Recall.ai service — deploy bot to a meeting URL
- [ ] On booking confirmed (ONLINE event type + recallEnabled) → queue Recall bot deployment
- [ ] Recall webhook — bot joined, audio stream starts
- [ ] Audio stream → existing Deepgram pipeline (reuse `transcribeRecording`)
- [ ] Same AI pipeline fires after transcription (reuse `processTranscriptWithAI`)
- [ ] Recall bot for manually-triggered online meetings (future: user pastes Meet/Zoom link in dashboard)

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
