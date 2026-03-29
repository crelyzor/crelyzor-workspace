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
- [x] AI content generation — Meeting report, Tweet, Blog post, Email
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

## Phase 1.2 — Scheduling & Online Meetings ✅ COMPLETE

**Goal:** Solo professionals can share a booking link, let guests book time, and have meetings auto-transcribed whether online or in-person.

Full design doc: `docs/dev-notes/phase-1.2-scheduling.md`

### P0 — Data Model & Settings Foundation ✅
- [x] `UserSettings` model — schedulingEnabled, minNoticeHours, maxWindowDays, defaultBufferMins, recallEnabled, etc.
- [x] `EventType` model — title, slug, duration, locationType (IN_PERSON | ONLINE), bufferBefore, bufferAfter, meetingLink, isActive
- [x] `AvailabilitySchedule` + `Availability` models — named schedules, dayOfWeek slots, timezone-aware
- [x] `AvailabilityOverride` model — date-based blocks or custom overrides
- [x] `Booking` model — eventTypeId, guestName, guestEmail, guestNote, startTime, endTime, timezone, status (PENDING | CONFIRMED | DECLINED | CANCELLED | NO_SHOW), meetingId FK, googleEventId
- [x] DB migration for all new models
- [x] Settings page UI — Profile, Appearance, Scheduling, Event Types, Availability, Bookings, AI & Transcription, Integrations, Tags, Security, Privacy
- [x] Settings: scheduling on/off, min notice, max window, default buffer

### P1 — Event Types + Availability ✅
- [x] Event types CRUD API (`GET/POST /scheduling/event-types`, `PATCH/DELETE /scheduling/event-types/:id`)
- [x] Event types UI — create, edit, delete, activate/deactivate
- [x] Availability settings API (`GET/PATCH /scheduling/schedules/:id/availability`)
- [x] Availability settings UI — weekly schedule grid (per-day on/off + time range)
- [x] Availability overrides API — mark specific dates as blocked (`GET/POST/DELETE /scheduling/overrides`)
- [x] Slot calculation engine — availability windows MINUS existing meetings MINUS existing bookings MINUS GCal busy time MINUS buffers, timezone-aware
- [x] `GET /public/scheduling/slots/:username/:eventTypeSlug?date=` — returns available slots for a given date

### P2 — Public Booking Pages (`crelyzor-public`) ✅
- [x] `/schedule/:username` — lists all active event types (SSR, SEO, OG)
- [x] `/schedule/:username/:slug` — calendar picker, slot grid, timezone-aware
- [x] Booking form — guest name, email, optional note, timezone picker
- [x] Booking confirmation page — summary + add-to-calendar button
- [x] `POST /public/bookings` — creates Booking + Meeting atomically (no auth), with Serializable transaction for conflict detection
- [x] Booking cancellation — guest can cancel via `PATCH /public/bookings/:id/cancel`

### P3 — Google Calendar Integration ✅
- [x] Settings: connect Google Calendar (OAuth re-auth with calendar scope)
- [x] Settings: disconnect Google Calendar
- [x] Read sync — fetch Google Calendar events for busy-time calculation (injected into slot engine)
- [x] Write sync — create Google Calendar event when booking is confirmed (with guest as attendee)
- [x] Write sync — cancel Google Calendar event when booking is cancelled
- [x] Store `googleEventId` on `Booking`

### P4 — Recall.ai Integration ✅
- [x] Settings: Recall.ai on/off toggle
- [x] Recall.ai service — deploy bot to a meeting URL
- [x] On booking confirmed (ONLINE event type + recallEnabled) → queue Recall bot deployment
- [x] Recall webhook — bot joined, audio stream starts
- [x] Audio stream → existing Deepgram pipeline (reuse `transcribeRecording`)
- [x] Same AI pipeline fires after transcription (reuse `processTranscriptWithAI`)

---

## Phase 1.3 — Google Calendar Deep Integration + Unified Timeline ✅ COMPLETE

**Goal:** Google Calendar is woven into every corner of Crelyzor. Meet links are auto-generated. Your full day (GCal events + Crelyzor meetings) lives in one timeline. Every meeting you create in Crelyzor lands in your Google Calendar automatically.

Full design doc: `docs/dev-notes/phase-1.3-gcal.md`

### P0 — Schema + Meet Link Foundation ✅
- [x] Schema: `meetLink String?` + `googleEventId String?` on `Meeting` model
- [x] DB migration
- [x] `createGCalEventForMeeting()` — creates GCal event with conferenceData, returns `{ googleEventId, meetLink }`
- [x] Auto-generate Meet link in `meetingService.createMeeting()` when `addToCalendar === true` (SCHEDULED only)

### P1 — GCal Write Sync for Meetings ✅
- [x] On `createMeeting` → `createGCalEventForMeeting` → stores `googleEventId` + `meetLink`. Fail-open.
- [x] On `updateMeeting` → `updateGCalEventForMeeting` if `googleEventId` set. Fail-open.
- [x] On `cancelMeeting` / `deleteMeeting` → `deleteCalendarEvent`. Fail-open.

### P2 — GCal Read Sync for Dashboard Timeline ✅
- [x] `GET /integrations/google/events?start=&end=` — normalized events, 5-min Redis cache, rate-limited
- [x] `GET /integrations/google/status` — `{ connected, email, syncEnabled }`
- [x] `TodayTimeline` component — unified Crelyzor meetings + GCal events, chronologically sorted

### P3 — Meet Link UX + Settings Integrations ✅
- [x] Meeting creation form: "Add to Google Calendar" switch
- [x] ScheduledDetail: "Join Meeting" button (primary) + copy icon
- [x] Settings > Integrations: live connection status, email badge, Disconnect button, sync toggle

---

## Phase 1.4 — Recall.ai Platform Integration ✅ COMPLETE

**Goal:** Recall.ai is a platform-level service. One API key in `.env`, managed by us. Users get a simple on/off toggle — no BYO-key friction.

Full design doc: `docs/dev-notes/phase-1.4-recall-platform.md`

### P0 — Backend Refactor ✅
- [x] Schema: `recallApiKey` removed from `UserSettings` (only `recallEnabled` remains)
- [x] `RECALL_API_KEY` + `RECALL_BASE_URL` + `RECALL_WEBHOOK_SECRET` in `.env`
- [x] `PUT /settings/recall-api-key` endpoint removed
- [x] Encryption utilities removed (were only used for per-user Recall key)
- [x] `recallService.ts` reads `RECALL_API_KEY` from env — no per-user key parameter
- [x] `recallService.ts` reads `RECALL_BASE_URL` from env (regional endpoint support)
- [x] Bot config: `join_at`, `automatic_leave` (waiting_room_timeout: 600, noone_joined_timeout: 180)
- [x] `jobProcessor.ts` — no per-user key fetch
- [x] `bookingManagementService.ts` — checks `recallEnabled` + `!!env.RECALL_API_KEY`
- [x] `GET /settings/user` response includes `recallAvailable: boolean` (derived from `!!env.RECALL_API_KEY`)

### P1 — Expand bot deployment scope ✅
- [x] Deploy bot on manual meeting creation (SCHEDULED + has meetingLink + recallEnabled)
- [x] Deploy bot on GCal-synced meetings with Meet links

### P2 — Frontend simplification ✅
- [x] API key input removed from Settings > Integrations
- [x] Toggle shown only when `recallAvailable === true` from backend
- [x] `hasRecallApiKey` removed from types, `saveRecallApiKey` removed from service + hooks

---

## Phase 2 — Standalone Tasks ✅ COMPLETE

**Goal:** Tasks grow from meeting-linked items into first-class standalone objects.

- [x] `Task` model — optional `meetingId`, `dueDate`, `scheduledTime`, `isCompleted`, `TaskSource`, `TaskPriority`
- [x] Task list page — filter, sort, priority, due date
- [x] Tasks appear on `TodayTimeline` (home page) as time blocks when `scheduledTime` is set
- [x] Tags across Tasks (universal Tag system)

---

## Phase 3 — Calendar View ← current

**Goal:** A full `/calendar` page — week/day view with GCal events + Crelyzor meetings + Tasks unified in one place. The daily planning command center.

**Prerequisite:** Phase 2 complete ✅

- [ ] `/calendar` page — week/day view (dedicated route, not just the home timeline)
- [ ] GCal events + Crelyzor meetings + Tasks — unified in one calendar view
- [ ] Tasks with `scheduledTime` appear as time blocks on calendar
- [ ] Tasks with only `dueDate` appear as all-day markers
- [ ] Drag a task to a time slot → sets `scheduledTime`
- [ ] Link tasks to contacts (cards) — `cardId` on Task model

---

## Phase 4 — Big Brain (Global AI)

**Goal:** One AI that knows everything about the user across all of Crelyzor.

**Prerequisite:** Phase 3 complete.

- [ ] Vector embeddings for all transcripts, notes, tasks
- [ ] RAG pipeline over user's full data
- [ ] Global "Ask anything" interface (not per-meeting — evolution of Ask AI)
- [ ] Proactive nudges — missed follow-ups, upcoming meeting prep
- [ ] "Prepare me for my 3pm call" feature
- [ ] Cross-meeting insights: "What do I know about Acme Corp?"
- [ ] **Full two-way GCal sync** — GCal edits/cancels reflect back in Crelyzor (requires Google Calendar push webhook subscription + conflict resolution). Deferred from 1.3.

---

## Future — Teams

**Not scoped. Do not build.**

Will be designed after Solo Phases 1–4 are complete.

---

## Naming Decisions (locked)

| Old name | New name | Notes |
|---|---|---|
| Action Items | **Tasks** | Renamed in UI + backend — `Task` model replaced `MeetingActionItem` in Phase 1 |
| Ask AI (per meeting) | **Ask AI** | Phase 1. Global AI = Phase 4 Big Brain. |
| Action Items tab | **Tasks tab** | Rename in all 3 MeetingDetail layouts |
