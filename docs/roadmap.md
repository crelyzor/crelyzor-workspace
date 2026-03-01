# Crelyzor — Roadmap

## North Star

Ship a solo product that feels like one unified system — not three features duct-taped together.

---

## Phase 1 — Offline First (Core Product)

**Goal:** A solo user can manage their identity, run meetings offline, and get full AI intelligence from those meetings.

### Deliverables

**Digital Cards**
- [x] Card creation and editor
- [x] Public shareable card page
- [x] QR code generation
- [x] vCard download
- [x] Contact exchange (lead capture)
- [x] Card analytics
- [ ] Email signature generator (polish)
- [ ] Card templates polish

**Offline Smart Meetings**
- [x] Meeting creation (CRUD)
- [x] Meetings list with filters
- [x] Recording upload to GCS
- [x] Deepgram transcription pipeline
- [x] Speaker diarization (who said what)
- [x] OpenAI summary + key points
- [x] Action items extraction
- [x] Meeting notes
- [ ] Wire MeetingDetail frontend to real API (transcript, summary, action items)
- [ ] Recording upload UI connected to backend
- [ ] Real-time transcription status polling
- [ ] Action items UI (mark complete, edit, create manually)
- [ ] Notes UI (create, delete)
- [ ] Edit meeting functionality

**Ask AI (Per Meeting)**
- [ ] Backend: POST /sma/meetings/:meetingId/ask
- [ ] Context: Full transcript injected into OpenAI prompt
- [ ] Frontend: Chat interface in meeting detail
- [ ] Pre-generated: Auto-surface decisions, key moments, follow-ups

**Home Dashboard**
- [ ] Command center feel
- [ ] Today's meetings widget
- [ ] Recent action items widget
- [ ] Quick record a meeting CTA
- [ ] Cards widget

---

## Phase 1.2 — Online Meetings

**Goal:** Same AI intelligence but for online meetings via Recall.ai bot.

**Prerequisite:** Phase 1 complete.

### Deliverables

**Recall.ai Integration**
- [ ] Recall.ai API integration (backend)
- [ ] Bot deployment — joins Google Meet / Zoom
- [ ] Stream audio to Deepgram using existing credentials
- [ ] Same transcription + AI pipeline triggers automatically

**Cal.com Style Scheduling**
- [ ] Availability settings UI (recurring + custom)
- [ ] Public booking page
- [ ] Google Calendar sync (read + write)
- [ ] Time zone handling
- [ ] Booking confirmation flow

---

## Phase 2 — Big Brain

**Goal:** One AI that knows everything about the user across all of Crelyzor.

**Prerequisite:** Phase 1.2 complete. Enough meeting data to make it useful.

### Deliverables

- [ ] Vector embeddings for all transcripts, notes, action items
- [ ] RAG pipeline over user's full data
- [ ] "Ask anything" interface at the app level (not per meeting)
- [ ] Proactive nudges: missed follow-ups, upcoming meeting context
- [ ] "Prepare me for my 3pm call" feature
- [ ] Cross-meeting insights: "What do I know about Acme Corp?"

---

## Phase 3 — Tasks

**Goal:** Todoist-style task management, deeply connected to meetings and AI.

**Prerequisite:** Phase 2 complete (AI generates and manages tasks intelligently).

### Deliverables

- [ ] Task creation (manual)
- [ ] Task list with filters, priorities, due dates
- [ ] Auto-generate tasks from meeting action items
- [ ] Link tasks to meetings and contacts
- [ ] AI task suggestions based on meeting content
- [ ] Task completion tracking

---

## Future — Teams

**Goal:** Everything in Phase 1-3 but shared across a team workspace.

**Not scoped yet. Will be designed after Solo is complete.**

Topics to design:
- Workspace and roles (Owner, Admin, Member)
- Shared meeting rooms
- Collaborative AI summaries
- Assigned action items across team members
- Team digital cards
- Billing and seat management

---

## Current Focus

**We are here:** Phase 1 — wiring the frontend to real data + building Ask AI.

Next immediate tasks (in order):
1. Wire MeetingDetail to real API
2. Build Ask AI backend endpoint
3. Build Ask AI frontend chat interface
4. Home Dashboard polish
