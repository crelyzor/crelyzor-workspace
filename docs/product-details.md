# Crelyzor — Full Product Details

> Last updated: 2026-05-02
> Current phase: Phase 4 (Billing & Monetization)

---

## What Is Crelyzor

Crelyzor is a **productivity OS for solo professionals** — founders, consultants, freelancers, and sales reps.

Most professionals juggle 5+ disconnected tools for their daily work. Crelyzor collapses them into one product where everything knows about everything else.

**One-liner:** Your identity, schedule, meetings, and work — all connected, all intelligent.

### What It Replaces

| Tool Category | What professionals use today | Crelyzor replaces it with |
|--------------|------------------------------|--------------------------|
| Digital identity | HiHello, Blinq | Digital Cards |
| Meeting AI | Otter.ai, Fireflies | Smart Meetings + AI Brain |
| Scheduling | Cal.com, Calendly | Scheduling |
| Task management | Todoist, Things | Tasks |
| Calendar | Google Calendar (standalone) | Unified Calendar View |

### The Key Difference

Everything is **connected**:
- A card contact becomes a meeting participant
- A meeting generates tasks automatically via AI
- A booked meeting auto-deploys a recording bot
- Your calendar shows meetings, GCal events, and tasks in one view
- Ask AI knows the full context of every conversation you've had

---

## Who It's For

**Today (Phase 1–4):** Solo professionals
- Founders running investor and customer calls
- Consultants billing by the hour
- Freelancers managing multiple clients
- Sales reps juggling 20+ prospects

**Future (Phase 5+):** Teams
- Shared meeting rooms and AI summaries
- Team cards and collaborative workspaces
- Role-based access (Owner, Admin, Member)

---

## Current Build Status

All core phases are complete. Currently in Phase 4 (billing UI and infrastructure).

| Phase | What | Status |
|-------|------|--------|
| Phase 1 | Core product — Cards, Offline Meetings, AI | ✅ Complete |
| Phase 1.2 | Scheduling + Online Meetings (Recall.ai) | ✅ Complete |
| Phase 1.3 | Google Calendar deep integration | ✅ Complete |
| Phase 1.4 | Recall.ai platform integration | ✅ Complete |
| Phase 2 | Standalone Tasks | ✅ Complete |
| Phase 3 | Todoist-level Tasks + Calendar View | ✅ Complete |
| Phase 3.2 | Polish + power features | ✅ Complete |
| Phase 3.3 | Product gaps + email notifications | ✅ Complete |
| Phase 3.4 | Global Tags across all entities | ✅ Complete |
| Phase 4 | Billing, monetization, infrastructure | 🔄 In Progress |
| Phase 5 | Big Brain (cross-meeting AI) | ⛔ Blocked |
| Teams | Multi-user workspaces | ⛔ Future |

---

## Feature 1 — Digital Cards

Your live digital identity — shareable, scannable, always up to date.

### What You Can Do
- Create and edit cards: name, title, bio, avatar, links, contact fields (phone, email, website, social)
- Multiple cards per user — personal card, professional card, event-specific card
- Each card has a **unique public URL** (`crelyzor.com/:username` or `/:username/:slug`)
- **QR code** — generated per card, scannable at in-person events
- **vCard download** — tap to save to phone contacts (works on iOS and Android)
- **Contact exchange** — scanner submits their info, you capture a lead automatically
- **Card analytics** — total views, unique views, link clicks, geographic data, referrers, views over time
- **Email signature generator** — one click to generate an HTML signature for Gmail/Outlook
- Multiple card templates: Executive, Minimal, Bold, Creative

### The Public Card Page
Served by the `crelyzor-public` Next.js site — fully SSR, SEO-optimized, Open Graph previews. When someone visits your card link on any device, they see a fast, mobile-first card page. No app install required.

### Status
**Fully built** — backend, dashboard frontend, and public page.

---

## Feature 2 — Smart Meetings (Offline)

Record any in-person or offline meeting, upload the file, and get a full AI-powered breakdown automatically.

### The Flow
1. Create a meeting in Crelyzor
2. Record it on your phone or any device
3. Upload the audio or video file
4. Deepgram transcribes it with **speaker diarization** (who said what, timestamped)
5. AI processes the transcript and auto-generates:
   - Full transcript (timestamped, speaker-labeled)
   - Summary (2–4 paragraph narrative)
   - Key points (bullet list)
   - Action items with category, suggested owner, suggested dates
   - Meeting notes
6. Ask AI anything about the meeting

### What You Can Do With a Meeting
- **Rename speakers** — "Speaker 0" → "John", "Speaker 1" → "Sarah"
- **Edit transcript segments** — correct errors inline
- **Regenerate** title, summary, or full transcript (change language too)
- **Ask AI** — chat interface with the full transcript as context
- **AI content generation** — Meeting Report, Tweet, Blog Post, Follow-up Email
- **Share sheet** — copy transcript, copy summary, download audio, share via email
- **Publish to public link** — toggle public/private, choose what to share (transcript / summary / tasks)
- **Export** — transcript or summary as PDF or TXT
- **Tags** — tag the meeting for filtering and cross-entity views
- **Attachments** — attach files, photos, or links to a meeting
- **Meeting notes** — rich text notes alongside the transcript

### Meeting Types
| Type | Use Case |
|------|----------|
| SCHEDULED | A planned meeting — appears on your calendar |
| RECORDED | A recorded meeting that was uploaded |
| VOICE_NOTE | A quick audio note to yourself |

Voice Notes are shown in their own dedicated section, separate from meetings.

### Status
**Fully built** — full pipeline live in production.

---

## Feature 3 — Smart Meetings (Online)

An AI bot joins your Google Meet or Zoom call, records it, and runs the same AI pipeline automatically.

### The Flow
1. Create a SCHEDULED meeting with a Meet/Zoom link, or a booking comes in with an online event type
2. Recall.ai bot is automatically deployed to the meeting URL before it starts
3. Bot joins the call, records audio
4. After the meeting ends, the same Deepgram + AI pipeline runs
5. Full transcript, summary, tasks — same as offline

### How the Bot Works
- Platform-level Recall.ai key — **users don't need their own API key**
- Users just toggle "Record online meetings" on/off in Settings
- Bot joins at the scheduled start time, leaves after the call ends
- Has configurable auto-leave: waits 10 minutes if no one joins, leaves immediately if everyone else has left

### What Triggers Bot Deployment
1. A booking is confirmed for an ONLINE event type (automatic)
2. A SCHEDULED meeting is created with a meeting link and Recall is enabled (automatic)
3. A Google Calendar event with a Meet link is synced to Crelyzor (automatic)

### Status
**Fully built** — Recall.ai platform integration complete.

---

## Feature 4 — AI Brain (Per Meeting)

Every meeting gets its own AI that deeply understands it.

### Auto-Generated (runs after every transcription)
These fire automatically — no user action required:

| Output | What It Is |
|--------|-----------|
| Summary | 2–4 paragraph narrative of what happened |
| Key points | The most important moments, bulleted |
| Action items | Tasks with owner, category, and suggested dates |
| Meeting title | AI-generated from context if not set |

### Ask AI
A chat interface inside every meeting detail page.

**What you can ask:**
- *"What did Sarah say about the Q3 budget?"*
- *"List all the blockers mentioned in this meeting"*
- *"Give me a timeline of what was discussed"*
- *"Summarize the first 15 minutes only"*
- *"What were the open questions at the end?"*
- *"Who is responsible for the product launch?"*

**How it works:**
- Full transcript with speaker labels is the AI's context
- Answers stream back in real time (Server-Sent Events)
- Conversation history is saved — you can come back to it later
- History is clearable per meeting

### AI Content Generation
One click to turn your meeting into publishable content:

| Type | What Gets Generated |
|------|---------------------|
| Meeting Report | Professional summary document |
| Tweet | Tweetable insight or announcement |
| Blog Post | Long-form post based on discussion |
| Follow-up Email | Ready-to-send email to attendees |

Generated content is cached — regenerating doesn't charge credits.

### AI Model
- **Transcription:** Deepgram Nova-3 Multilingual (45+ languages, speaker diarization)
- **AI processing:** Google Gemini 2.0 Flash (migrated from OpenAI in Phase 4.7)

### Status
**Fully built** — all AI features live in production.

---

## Feature 5 — Scheduling

Cal.com-style availability and booking for solo professionals.

### How It Works
1. Set up your availability (which days and times you're open)
2. Create event types (30-min intro call, 60-min consultation, etc.)
3. Share your booking link — `crelyzor.com/schedule/:username`
4. Guests pick a time, fill out a short form, and confirm
5. A meeting is created in Crelyzor + a Google Calendar event is created automatically

### Event Types
Each event type has:
- Title, description, duration
- Location type: IN_PERSON or ONLINE (auto-generates Meet link)
- Buffer before and after
- Minimum notice (e.g., "can't be booked less than 2 hours out")
- Maximum bookings per day
- Active/inactive toggle

### Availability
- Weekly recurring schedule (e.g., Mon–Fri 9am–5pm)
- Named availability schedules (e.g., "Work Schedule", "Consulting Schedule")
- Date-specific overrides — block specific days or add custom availability
- Timezone-aware — guests see slots in their own timezone

### Slot Engine
Available slots are calculated as:
> Your availability windows − existing Crelyzor meetings − confirmed bookings − Google Calendar busy time − buffers

### The Public Booking Page
Served by `crelyzor-public` — SSR, SEO-optimized. The guest experience:
- Visit `/schedule/:username` → see all your active event types
- Visit `/schedule/:username/:slug` → calendar picker → slot grid → booking form → confirmation page
- Guests can cancel or reschedule via email link

### Email Notifications
| Event | Who Gets It |
|-------|------------|
| Booking received | You (host) |
| Booking confirmation | Guest (with add-to-calendar + cancel link) |
| 24-hour reminder | Guest |
| Booking cancelled | Both parties |

### Status
**Fully built** — end-to-end scheduling live in production.

---

## Feature 6 — Google Calendar Integration

Your Google Calendar is woven into Crelyzor at every level.

### What's Connected
- **Read sync** — your GCal events are pulled in for busy-time calculation in the scheduling slot engine
- **Write sync** — every meeting you create in Crelyzor creates a Google Calendar event automatically
- **Meet link** — when creating a meeting, toggle "Add to Google Calendar" to auto-generate a Google Meet link
- **Unified timeline** — home dashboard and calendar page show GCal events + Crelyzor meetings together
- **Real-time sync (coming)** — GCal push webhooks will sync edits and cancellations in real time (Phase 4.3)

### Settings
- Connect or disconnect Google Calendar in Settings > Integrations
- Shows which Google account is connected
- Sync enable/disable toggle

### Status
**Fully built** — read sync, write sync, Meet link generation, and unified timeline are all live.

---

## Feature 7 — Tasks

A full Todoist-quality task manager, deeply woven into meetings, contacts, and AI.

### Task Sources
| Source | How it's created |
|--------|-----------------|
| Manual | Created by you directly |
| AI Extracted | Automatically from meeting transcripts |
| Meeting Linked | Created on a meeting's task tab |
| Global Quick-Add | Cmd+K from anywhere in the app |

### What a Task Has
- Title and description
- Due date + optional scheduled time
- Priority: HIGH / MEDIUM / LOW
- Status: TODO / IN PROGRESS / DONE
- Linked meeting (click to navigate to meeting)
- Linked contact (card contact)
- Tags
- Subtasks
- Duration (for calendar blocking)
- Transcript context (for AI-extracted tasks — the exact sentence that generated it)
- Recurring rule (daily, weekly, monthly, custom RRULE)

### Views
| View | What It Shows |
|------|--------------|
| Inbox | Tasks with no due date |
| Today | Overdue + due today, split at midnight |
| Upcoming | Next 7 days, grouped by date |
| All Tasks | Full list with filters (status, priority, source, sort) |
| From Meetings | Tasks grouped by meeting name |

### Board View
Kanban-style board with three columns: Todo · In Progress · Done. Drag tasks between columns to update status.

### Calendar Integration
- Tasks with a scheduled time appear as blocks on the calendar
- Drag a task to a time slot to schedule it
- Optionally block time on Google Calendar when scheduling a task

### Power Features
- **Natural language parsing** — type "call John tomorrow at 3pm high priority" and it parses automatically
- **Bulk actions** — select multiple tasks → complete, delete, or change priority
- **Subtasks** — unlimited nesting
- **Contact-linked tasks** — tasks linked to a card contact show on that contact's detail page
- **Keyboard shortcuts** — J/K to navigate, E to edit, D for due date, P for priority, Space to complete

### Status
**Fully built** — all task features live in production.

---

## Feature 8 — Calendar View

A unified calendar showing your entire professional life in one place.

### What You See
- Crelyzor meetings (SCHEDULED + VOICE_NOTE with scheduled time)
- Google Calendar events (all events from connected account)
- Tasks with a scheduled time (as time blocks)
- Tasks with only a due date (as all-day markers at the top of the day column)

### Views
- **Day view** — hour-by-hour grid for one day
- **Week view** — 7-day grid (default)
- **Month view** — full month overview

### Interactions
- Click empty time slot → quick-create: Task or Meeting
- Drag a task to a time slot → sets `scheduledTime`
- Click any event or task → opens detail panel
- Jump to any date from the calendar header

### Status
**Fully built** — all views and interactions live in production.

---

## Feature 9 — Tags

A universal tagging system across all entities in Crelyzor.

### What You Can Tag
- Meetings (and voice notes)
- Cards
- Tasks
- Contacts

### Tags Index Page
`/tags` — see all your tags with counts per entity type. Create, rename, or delete tags inline.

### Tag Detail Page
`/tags/:tagId` — see everything tagged with a specific tag, organized in four sections: Meetings · Cards · Tasks · Contacts. Every tag chip anywhere in the app navigates here.

### Status
**Fully built** — global tags with cross-entity views live in production.

---

## Feature 10 — Global Search

Search across your entire Crelyzor workspace.

### What It Searches
- Meetings (by title, notes)
- Contacts
- Tasks
- Cards

### How to Access
Type in the search bar at the top of the dashboard. Results are grouped by entity type.

### Status
**Fully built** — live in production.

---

## Feature 11 — Notifications & Email

### In-App
- Sonner toast notifications for all actions (meeting created, task completed, etc.)
- "New AI tasks from meeting" badge on home dashboard
- Pending tasks widget showing overdue items

### Email (via Resend)
- Booking received (host)
- Booking confirmed (guest + calendar links)
- 24-hour booking reminder (guest)
- Booking cancelled (both parties)
- Meeting AI ready — when transcript + summary are done
- Daily task digest (8am, opt-in)

### Notification Preferences
All email types are individually toggleable in Settings > Notifications.

### Status
**Fully built** — all email types live in production.

---

## Feature 12 — Onboarding

### First-Run Experience
- 3-step onboarding flow for new users (skippable)
- Getting-started checklist on the home dashboard (driven by real setup state):
  1. Create your first card
  2. Record or upload a meeting / voice note
  3. Connect Google Calendar
  4. Create your first task
- Checklist dismisses permanently once all steps are complete

### Status
**Fully built** — onboarding checklist live in production.

---

## Pricing & Plans

| Feature | Free | Pro — $19/mo | Business |
|---------|------|--------------|----------|
| Digital Cards | Unlimited | Unlimited | Unlimited |
| Scheduling | Unlimited | Unlimited | Unlimited |
| Tasks & Calendar | Unlimited | Unlimited | Unlimited |
| Transcription | 120 min/mo | 600 min/mo | Custom |
| Max single recording | 60 min | 3 hrs | Custom |
| Online meeting bot (Recall.ai) | ❌ | 5 hrs/mo | Custom |
| AI Credits/month | 50 | 1,000 | Custom |
| AI content generation | ❌ | ✅ | ✅ |
| Storage | 2 GB | 20 GB | Custom |
| Email support | ❌ | ✅ | ✅ |
| Dedicated support | ❌ | ❌ | ✅ |

### AI Credits
AI Credits are used for user-initiated AI interactions (Ask AI and content generation). Meeting processing (summary, task extraction) is free — it fires automatically and is included in the transcription flow.

**1 AI Credit ≈ $0.001**

Typical costs:
- Ask AI on a 30-min meeting: ~5 credits
- Ask AI on a 2-hour meeting: ~10 credits
- Generate a Tweet: ~7 credits
- Generate a Meeting Report: ~13 credits

### Unit Economics
- Gross margin on Pro: **~49%** at max usage
- Break-even on free tier: 5% free → Pro conversion
- Cost per free user (maxed): ~$0.77/mo
- Cost per Pro user (maxed): ~$9.69/mo → Revenue: $19 → **$9.31 gross profit**

---

## Technology

### Stack
| Layer | Technology |
|-------|-----------|
| Backend | Node.js, Express 5, TypeScript, Prisma 6 |
| Database | PostgreSQL (Neon) |
| Job Queues | Bull + Redis |
| Dashboard | React 19, Vite, TanStack Query, Zustand, Tailwind, shadcn/ui |
| Public Site | Next.js (App Router), SSR, SEO |
| Storage | Google Cloud Storage |
| Transcription | Deepgram Nova-3 Multilingual |
| AI | Google Gemini 2.0 Flash |
| Meeting Bots | Recall.ai |
| Email | Resend |
| Infrastructure | GCP Cloud Run (backend), Vercel (frontends) |
| Package Manager | pnpm |

### Three Repos
| Repo | Role | URL |
|------|------|-----|
| `crelyzor-backend` | API, business logic, AI pipeline | localhost:4000 |
| `crelyzor-frontend` | Authenticated dashboard | localhost:5173 |
| `crelyzor-public` | Public pages (cards, scheduling, meeting links) | localhost:5174 |

---

## What's In Progress (Phase 4)

### Billing UI (not yet built)
- Settings > Billing tab — plan badge, usage meters, upgrade CTA
- Soft warning banner at 80% usage
- In-context usage indicators (credits shown in Ask AI, minutes shown on upload)
- Hard wall: 402 interceptor → upgrade modal
- `/pricing` public page (SSR, SEO)

### GCal Push Webhooks (Phase 4.3)
- Currently: GCal sync pulls on every dashboard load
- Coming: Google Calendar push webhooks → real-time sync of edits and cancellations
- Impact: Changes in Google Calendar appear in Crelyzor instantly

### First-Run Polish (Phase 4.4)
- QA of new-user walkthrough
- Empty-state copy audit across core pages

### Payment Gateway
- Razorpay account is blocked — not building now
- Early paid users upgraded manually via Prisma Studio
- Will revisit with Cashfree or PayU as drop-in alternatives

---

## Future Scope

### Phase 5 — Big Brain (Cross-Meeting AI)

The biggest planned feature. An AI that knows everything about you across all of Crelyzor — not just one meeting, but your entire history.

**What it enables:**
- *"What do I need to do this week?"* → pulls from tasks, action items, and upcoming meetings across all time
- *"What do I know about Acme Corp?"* → surfaces past meetings with anyone from Acme, every discussion, every action item
- *"Prepare me for my 3pm with John"* → pulls context from every past meeting with John, open items, what was last discussed
- Proactive nudges: *"You haven't followed up on the action item from Monday's meeting"*
- Cross-meeting insights: patterns, recurring topics, relationship context

**Architecture:**
- Vector embeddings for all transcripts, notes, and tasks
- RAG pipeline (Retrieval Augmented Generation) over the user's full data
- Semantic search to retrieve relevant context
- Gemini 2.0 Flash generates answers with citations to specific meetings

**Status:** Explicitly blocked. Starts after Phase 4 is fully complete.

---

### Teams (No Timeline)

After the solo product is mature and profitable, Crelyzor will expand to teams.

**What it adds:**
- Shared workspace — multiple users, one organization
- Team meeting rooms — shared recordings and AI summaries
- Team cards — company card + individual cards under one brand
- Collaborative AI — shared meeting intelligence across the team
- Assigned action items — AI extracts tasks and assigns to the right team member
- Role-based access — Owner, Admin, Member

**Status:** Not scoped. Will be designed after solo phases complete.

---

## What Crelyzor Does NOT Do (Intentionally)

- No video hosting or video calls — Crelyzor records and processes, doesn't host calls
- No email inbox — it sends notifications but isn't a mail client
- No document editing — meetings have notes, not a full doc editor
- No CRM pipeline — contacts and deals are not tracked (yet)
- No team features — solo product only for now
