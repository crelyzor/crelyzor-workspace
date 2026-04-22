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
- [x] Email signature generator (done in Phase 3.2)
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

## Phase 3 — Todoist-Level Tasks + Calendar View ✅ COMPLETE

**Goal:** Tasks become a first-class Todoist-quality system — with views, drag-and-drop, a detail panel, board view, and Crelyzor-exclusive integrations (meeting context, contact linking, AI extraction, calendar blocking). The `/calendar` page ties it all together.

**Prerequisite:** Phase 2 complete ✅

Full design doc: `docs/dev-notes/phase-3-tasks-calendar.md`

---

### P0 — Schema + API Upgrades (`crelyzor-backend`) ✅ Complete

- [x] `sortOrder Int @default(0)` on `Task`
- [x] `status TaskStatus` enum — `TODO | IN_PROGRESS | DONE`, synced with `isCompleted`
- [x] `parentTaskId UUID?` on `Task` — subtasks (self-referential FK)
- [x] `cardId UUID?` on `Task` — link task to a Card contact
- [x] `transcriptContext String?` — transcript sentence for AI-extracted tasks
- [x] DB push + Prisma client regenerated
- [x] `PATCH /sma/tasks/reorder` — userId-scoped transaction
- [x] `GET /sma/tasks?view=` — inbox / today / upcoming / all / from_meetings. Upcoming returns pre-grouped `{ date, tasks[] }[]`
- [x] `cardId`, `status`, `transcriptContext` on create + update endpoints
- [x] Subtask endpoints: `GET /sma/tasks/:id/subtasks`, `POST /sma/tasks/:id/subtasks`
- [x] `updateTask`: bidirectional status↔isCompleted sync
- [x] `deleteTask`: cascades soft-delete to subtasks in transaction

---

### P1 — Task Detail Panel + Row Redesign (`crelyzor-frontend`) ✅ Complete

- [x] **Task detail slide panel** — right-side slide-over, auto-save on blur
  - Inline-editable title + description
  - Due date picker
  - Priority selector (HIGH / MEDIUM / LOW)
  - Status pill (TODO / IN PROGRESS / DONE)
  - Tags multi-select (attach/detach)
  - Linked meeting chip (click → navigate)
  - Subtasks list with inline add
- [x] **Task row redesign**
  - Left priority border (red HIGH, amber MEDIUM)
  - "Overdue" indicator (midnight boundary, not current time)
  - Meeting chip
  - Click row → opens detail panel

---

### P2 — Sidebar Navigation + Views (`crelyzor-frontend`) ✅ Complete

- [x] **Sidebar nav within `/tasks`**: Inbox · Today · Upcoming · All Tasks · From Meetings (URL: `?view=`)
- [x] **Inbox view** — tasks with no due date + no scheduled time
- [x] **Today view** — "Overdue" section + "Due today" section, split at midnight
- [x] **Upcoming view** — 7 days, grouped by date with human-friendly headers (Tomorrow, Wed Apr 2, etc.)
- [x] **All Tasks view** — full filter bar (status/priority/source/sort)
- [x] **From Meetings view** — tasks grouped by meeting name (client-side grouping)

---

### P3 — Board View + Drag and Drop (`crelyzor-frontend`) ✅

- [x] **View toggle** — List / Board / Grouped (by date) switcher in header
- [x] **Board view** — 3 Kanban columns: Todo · In Progress · Done. Drag task between columns → updates `status`
- [x] **List drag-to-reorder** — drag handle on task rows, persists `sortOrder` via `PATCH /tasks/reorder`
- [x] **Grouped view** — tasks grouped under: Overdue / Today / Tomorrow / This Week / Later

---

### P4 — Global Quick-Add + Integrations (`crelyzor-frontend` + `crelyzor-backend`) ✅

- [x] **Global quick-add** — `Cmd+K` from anywhere in app → input with natural language parsing
- [x] **Contact-linked tasks on Card detail** — Card detail page shows open tasks linked to that contact via `cardId`

---

### P5 — Calendar View (`crelyzor-frontend`) ✅

- [x] `/calendar` page — dedicated week/day view (separate route, not just home TodayTimeline)
- [x] GCal events + Crelyzor meetings + Tasks with `scheduledTime` — unified in one calendar grid
- [x] Tasks with only `dueDate` appear as all-day markers at top of day column
- [x] Drag a task to a time slot → sets `scheduledTime`
- [x] Click empty time slot → quick-create (Task | Meeting)

---

## Phase 3.2 — Polish, Enhancements & Power Features ✅ COMPLETE

**Goal:** Make everything already built feel production-quality. Fix embarrassing gaps, add quick wins, and ship the power features that turn casual users into daily users.

**No new infrastructure required.** All work is within existing stack.

### P0 — Bugs & Embarrassing Gaps ✅
- [x] Fix "Reschedule meeting" button — `RescheduleMeetingModal` implemented
- [x] Privacy Settings tab — removed (empty placeholder)

### P1 — Quick Wins ✅
- [x] Task count badges on sidebar nav (Inbox · Today · Upcoming)
- [x] Overdue tasks section on home dashboard
- [x] NL parsing in inline task create (same parser as Cmd+K)
- [x] Task duration field — `durationMinutes` on Task + detail panel picker + calendar block height
- [x] Jump-to-date on calendar header
- [x] Email signature generator for cards

### P2 — Meaningful Features ✅
- [x] Auto-create "Prepare for [meeting]" task on booking confirmed (backend)
- [x] "New AI tasks from meeting" badge on home dashboard
- [x] Task bulk actions (select multiple → complete / delete / priority)
- [x] Card analytics improvement (views trend chart + link clicks)
- [x] Onboarding flow for new users (3-step, skippable)

### P3 — Bigger Features ✅ (mostly done)
- [x] Global search — `GET /search?q=` endpoint + results page UI
- [x] Calendar month view
- [x] Keyboard shortcuts on tasks page (J/K/E/D/P/Space/Escape)
- [x] Schedule task → create GCal block (opt-in toggle in task detail)
- [x] Meeting ↔ Card contact auto-linking — backend + frontend done

### P4 — Major Feature
- [x] Recurring tasks — `recurringRule` (RRULE) on Task + UI picker + auto-generate next on complete

---

## Phase 3.3 — Close the Product Gaps ✅ COMPLETE

**Goal:** Fix things a real user would hit in their first week. Public card page, email notifications, scheduling completeness.

Full breakdown: per-repo TASKS.md files.

### P0 — Fix the Front Door (public card page) ✅
- [x] Avatar fallback — initials on gold background when no photo
- [x] Loading skeleton — match card shape + dark bg while fetching
- [x] Proper 404 — on-brand error page when card not found
- [x] Contact form validation — name required + email or phone required
- [x] Contact form states — success / error / loading
- [x] Smooth avatar image load — fade in, no layout shift
- [x] Verify vCard download works on iOS and Android (mobile testing)

### P1 — Email Notifications ✅
- [x] Resend integration — `emailService.ts` with fail-open wrapper
- [x] Booking received email → host
- [x] Booking confirmation email → guest (with calendar links + cancel link)
- [x] Booking reminder — Bull delayed job at 24h before
- [x] Booking cancelled — both parties notified
- [x] Meeting AI complete — email when transcript + summary are ready
- [x] Daily task digest — 8am Bull cron job, opt-in per user
- [x] Email notification preferences in Settings → Notifications tab

### P2 — Scheduling Completeness ✅
- [x] Guest cancellation page — `/bookings/[id]/cancel` in `crelyzor-public`
- [x] `GET /public/bookings/:id` — public booking details endpoint
- [x] Guest reschedule — "Need to reschedule?" link in email → back to date picker
- [x] EventType editor: min notice, buffer time, max per day fields exposed in UI
- [x] Cancelled bookings shown in bookings list (strikethrough + badge)

### P3 — Connection Features ✅
- [x] Ask AI discovery — prominent action on meeting list row + home dashboard
- [x] Meeting ↔ Card contact chips — participant → card chip (requires backend P3 complete)
- [x] Speaker memory — voice fingerprint → pre-label future meetings (Deepgram)

### P4 — Recurring Tasks ✅
- [x] Recurring tasks — `recurringRule` (RRULE) on Task + UI picker + auto-generate next on complete

### P5 — Data Import ✅
- [x] Contact CSV import — `POST /cards/:cardId/contacts/import` + UI file picker
- [x] Calendar .ics import — `POST /meetings/import/ics` + UI file picker

---

## Phase 3.4 — Global Tags ✅ COMPLETE

**Goal:** Tags are already on meetings, cards, and tasks. This phase makes them truly global — adding contacts, a tags index page, and a tag detail page that shows everything tagged with a given tag across all entity types.

Full breakdown: per-repo TASKS.md files.

### Tag universe after this phase
```
#any-tag
├── Meetings  (incl. voice notes)  — MeetingTag  ✅ exists
├── Cards                          — CardTag      ✅ exists
├── Tasks                          — TaskTag      ✅ exists
└── Contacts                       — ContactTag   ← new (ContactTag junction)
```

### P0 — Schema (backend)
- [x] `ContactTag` junction model + migrate relations on `Tag` + `CardContact`
- [x] `deleteTag` transaction updated to cascade `contactTags`

### P1 — Backend APIs
- [x] Contact tag endpoints (`GET/POST/DELETE /cards/:cardId/contacts/:contactId/tags/:tagId`)
- [x] `GET /tags/:tagId/items` — returns `{ tag, meetings[], cards[], tasks[], contacts[], counts }`
- [x] `listTags` updated to include counts per type

### P2 — Tags Index + Detail Pages (frontend)
- [x] `/tags` index page — tag grid with counts, inline create, rename, delete
- [x] `/tags/:tagId` detail page — 4 sections (Meetings / Cards / Tasks / Contacts)
- [x] Route registration + sidebar nav "Tags" item

### P3 — Tags on Contacts (frontend)
- [x] Tag chips on contact rows in Cards contacts view
- [x] Tag editor popover on contacts
- [x] Tag filter bar on contacts list

### P4 — Tag Chip Navigation (frontend)
- [x] Every tag chip in the app navigates to `/tags/:tagId`

---

## Phase 4 — Billing & Monetization

**Goal:** Monetize the product. Gate AI features behind usage limits. Integrate Stripe. Make limits visible and intuitive in the UI.

**Prerequisite:** Phase 3.4 complete ✅

Full design: `docs/pricing-and-costs.md`

### Plans
- **Free** — 120 min transcription/mo, 50 AI Credits/mo, no Recall.ai
- **Pro ($19/mo)** — 600 min/mo, 1,000 AI Credits/mo, 5 hrs Recall.ai/mo
- **Business** — custom pricing per deal

### Backend
- [x] Schema: `plan` on User, `UserUsage` model, `Subscription` model
- [x] `usageService.ts` — check + deduct transcription, Recall, AI credits
- [x] Wire into transcription, Recall, AI services
- [x] Monthly usage reset cron job
- [ ] Billing endpoints: `GET /billing/usage`, `POST /billing/checkout` (stub), `POST /billing/portal` (stub)
- [ ] Enforcement layer — 402 responses with upgrade context
- ⛔ Payment gateway (Razorpay) — **NOT DOING NOW.** Account blocked. Early users upgraded manually via Prisma Studio. Revisit later.

### Frontend
- [ ] Settings > Billing tab — plan badge, usage meters, upgrade CTA
- [ ] `<UpgradeModal />` — reusable, context-aware
- [ ] Soft warning banner at 80% usage
- [ ] In-context indicators — credits in Ask AI, minutes on upload, hours on Recall toggle
- [ ] Hard wall: 402 interceptor → UpgradeModal
- [ ] `/pricing` route in dashboard

### Public
- [ ] `/pricing` page — SSR, SEO, plan comparison, CTAs

---

## Phase 4.3 — Two-way GCal Push Webhooks

**Goal:** GCal edits and cancellations reflect in Crelyzor in real-time, not just when the user opens the dashboard.

**Status:** Planned. Starting next.

**What already works:** Pull-based sync (`syncLinkedMeetingsFromGoogle`) runs on every dashboard load — already handles updates and cancellations for linked meetings. This phase adds Google Calendar push webhooks for real-time delivery.

### P0 — Schema
- [ ] `GCalSyncState` model — `channelId`, `resourceId`, `expiration`, `syncToken` per user

### P1 — Push Channel Service
- [ ] `registerWatchChannel(userId)` — call `calendar.events.watch()`, store in DB
- [ ] `stopWatchChannel(userId)` — call `calendar.channels.stop()`, remove from DB
- [ ] `processIncomingNotification(channelId)` — fetch changed events via syncToken, run sync logic
- [ ] `renewExpiringChannels()` — cron target for daily renewal check

### P2 — Webhook Endpoint
- [ ] `POST /webhooks/google/calendar` — receive ping, validate token, queue Bull job, return 200
- [ ] `gcal-push-sync` Bull job — calls `processIncomingNotification`

### P3 — Wiring
- [ ] Register channel after GCal connect callback
- [ ] Stop channel on GCal disconnect
- [ ] Daily cron at 02:00 UTC — renew expiring channels
- [ ] Backfill endpoint for existing connected users: `POST /integrations/google/calendar/push/register`

### P4 — Frontend
- [ ] `pushEnabled` field on integration status response
- [ ] "Real-time sync" badge in Settings > Integrations when channel is active
- [ ] Auto-register push channel after GCal connect success

---

## Phase 4.4 — Polish & First-Run Experience

**Goal:** Fix anything a real new user hits in their first week.

**Status:** In progress.

### First-run polish
- [x] Home getting-started checklist driven by real setup state
- [x] Checklist actions for card, meeting/voice note, Google Calendar, and first task
- [x] Per-user checklist dismissal
- [x] Setup page branding/url copy aligned with Crelyzor public card URLs
- [ ] Fresh new-user walkthrough QA
- [ ] Empty-state copy audit across core pages

---

## Phase 4.5 — Razorpay ⛔ BLOCKED

Account blocked. Env vars in `.env.example` (commented). Do not start.

---

## Phase 5 — Big Brain (Global AI) ⛔ BLOCKED

**Goal:** One AI that knows everything about the user across all of Crelyzor.

**Status:** Explicitly blocked. Do not start. Requires separate vector DB infrastructure not yet in place.

**Prerequisite:** All Phase 4.x complete.

- [ ] Vector embeddings for all transcripts, notes, tasks
- [ ] RAG pipeline over user's full data
- [ ] Global "Ask anything" interface (not per-meeting — evolution of Ask AI)
- [ ] Proactive nudges — missed follow-ups, upcoming meeting prep
- [ ] "Prepare me for my 3pm call" feature
- [ ] Cross-meeting insights: "What do I know about Acme Corp?"

---

### Model Upgrades ✅ Done (Phase 4 start)

**Deepgram:** `nova-2` → `nova-3` (multilingual) ✅
- File: `crelyzor-backend/src/services/transcription/transcriptionService.ts`
- `const DEEPGRAM_MODEL = "nova-3"` — live
- Cost impact: $0.26/hr → $0.31/hr (+19%).

**OpenAI:** `gpt-4o-mini` → `gpt-5.4-mini` ✅
- File: `crelyzor-backend/src/services/ai/aiService.ts`
- `const OPENAI_MODEL = "gpt-5.4-mini"` — live
- Cost impact: input 5x, output 7.5x. Net ~$1.30/Pro user/month increase.

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
