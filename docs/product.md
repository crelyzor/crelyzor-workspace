# Crelyzor — Product Spec

## Vision

A productivity OS for professionals. Not another tool — a platform where your identity, calendar, meetings, and tasks are one unified system with AI as the connective tissue.

---

## User Types

### Phase 1 — Solo
A single professional using Crelyzor for themselves.

- Creates their digital card(s)
- Manages their own meetings
- Records and gets AI insights from meetings
- Tracks tasks generated from meetings
- Books others via their scheduling link

### Future — Teams
A workspace shared between multiple users.

- Shared meeting rooms
- Team cards
- Collaborative AI summaries
- Assigned action items across team
- Role-based access (Owner, Admin, Member)

---

## Core Features

### 1. Digital Cards

**What it is:** A shareable, live digital business card with a unique URL and QR code.

**Key capabilities:**
- Create and customize cards (name, title, bio, avatar, links, contact fields)
- Multiple cards per user (personal, professional, event-specific)
- QR code generation for in-person sharing
- vCard download (saves to phone contacts)
- Public card page at `/:username` or `/:username/:slug`
- Contact exchange — scanner submits their info, user captures a lead
- Card analytics — views, link clicks, geo data, referrers
- Email signature generator

**Card templates:** Executive, Minimal, Bold, Creative

**Status:** Built (backend + frontend + public page)

---

### 2. Smart Meetings — Offline

**What it is:** Record any in-person or offline meeting, upload the audio/video, and get a full AI-powered breakdown.

**Flow:**
1. Create a meeting in Crelyzor
2. Record it on your phone or any device
3. Upload the recording file
4. Deepgram transcribes it (speaker diarization — who said what)
5. AI processes the transcript and generates:
   - Full transcript (timestamped, speaker-labeled)
   - Summary (paragraph form)
   - Key points (bullet list)
   - Action items (categorized, assigned, with suggested dates)
   - Meeting notes
6. User can then **Ask AI** anything about the meeting

**Supported formats:** Audio and video files

**Status:**
- Backend pipeline: Built (upload → GCS → Deepgram → OpenAI)
- Frontend: Partially built (mock data, needs API integration)
- Ask AI: Not built

---

### 3. Smart Meetings — Online (Phase 1.2)

**What it is:** Join your online meetings (Google Meet, Zoom) with an AI bot that records and transcribes in real time.

**Flow:**
1. Create a meeting or connect your Google Calendar
2. Before the meeting, activate the Recall.ai bot
3. Bot joins the call, records audio, streams to Deepgram (using your creds)
4. Same AI pipeline runs after the meeting ends
5. Full transcript + summary + action items available immediately

**Key integrations:**
- Recall.ai — bot that joins calls
- Deepgram — transcription (same pipeline as offline)
- Google Calendar — auto-detect upcoming meetings
- Same AI processing as offline meetings

**Status:** Not built

---

### 4. AI Brain — Per Meeting

**What it is:** An AI that deeply understands every meeting and can answer questions about it.

**Two modes:**

**Pre-generated insights** (auto, runs after transcription):
- Summary
- Key points
- Decisions made
- Action items with owners and dates
- Key moments (timestamps)
- Follow-ups required

**Ask AI (custom Q&A):**
- Chat interface within the meeting detail
- Ask anything: "What did Sarah say about the timeline?" / "What were the blockers mentioned?" / "Summarize the first 10 minutes"
- Full transcript used as context
- Conversation history preserved per meeting

**Status:** Pre-generated — backend built, frontend needs integration. Ask AI — not built.

---

### 5. AI Big Brain (Phase 2)

**What it is:** An AI that knows everything across Crelyzor — all your meetings, all your contacts, your schedule, your tasks.

**Capabilities:**
- "What am I supposed to do this week?" — pulls from tasks + action items across all meetings
- "What do I know about Acme Corp?" — surfaces meeting notes, contacts, history
- "Prepare me for my 3pm call with John" — pulls context from past meetings with John
- Proactive nudges: "You haven't followed up on the action item from Monday's meeting"

**Architecture:** RAG (Retrieval Augmented Generation) over all user data

**Status:** Not built

---

### 6. Scheduling (Phase 1.2)

**What it is:** Cal.com-style availability and booking for solo users.

**Key capabilities:**
- Set your availability (recurring + custom overrides)
- Share a booking link — others book slots directly
- Google Calendar sync (reads existing events, writes new bookings)
- Meeting confirmation and reminders
- Time zone handling

**Status:** Partially built

---

### 7. Tasks (Phase 3)

**What it is:** Todoist-style task management, deeply integrated with meetings and AI.

**Key capabilities:**
- Create tasks manually
- Tasks auto-generated from meeting action items
- Link tasks to meetings, contacts, or projects
- Due dates, priorities, status
- AI can assign tasks from meeting summaries

**Status:** Not built

---

## What's Built vs Not Built

| Feature | Backend | Frontend |
|---------|---------|----------|
| Digital Cards | ✅ | ✅ |
| Public Card Page | ✅ | ✅ |
| Card Analytics | ✅ | ✅ |
| Card Contacts | ✅ | ✅ |
| Meetings CRUD | ✅ | ✅ |
| Meeting List | ✅ | ✅ |
| Offline Recording Upload | ✅ | Needs wiring |
| Deepgram Transcription | ✅ | Needs wiring |
| AI Summary + Key Points | ✅ | Needs wiring |
| Action Items | ✅ | Needs wiring |
| Meeting Notes | ✅ | Needs wiring |
| Transcription Status Polling | ✅ | Missing |
| Ask AI (per meeting) | ❌ | ❌ |
| Recall.ai Integration | ❌ | ❌ |
| Cal.com Scheduling | Partial | Partial |
| AI Big Brain | ❌ | ❌ |
| Tasks | ❌ | ❌ |
| Teams | ❌ | ❌ |
