# Crelyzor — Architecture

## System Overview

Three applications, one backend, one database.

```
┌─────────────────────────────────────────────────────────┐
│                      CRELYZOR                           │
│                                                         │
│  ┌──────────────────┐    ┌───────────────────────────┐  │
│  │ calendar-frontend│    │     cards-frontend         │  │
│  │  (Auth Dashboard)│    │   (Public Frontend)        │  │
│  │  React + Vite    │    │   Next.js — SSR/SEO        │  │
│  │                  │    │                            │  │
│  │ - Meetings       │    │ - /:username (card page)   │  │
│  │ - Cards mgmt     │    │ - /:username/:slug         │  │
│  │ - SMA interface  │    │ - /m/:id (published mtg)  │  │
│  │ - Home dashboard │    │ - /schedule/:username      │  │
│  │ - Publish toggle │    │ - Contact form             │  │
│  └────────┬─────────┘    └──────────────┬─────────────┘  │
│           │                             │               │
│           └──────────────┬──────────────┘               │
│                          │                              │
│              ┌───────────▼────────────┐                 │
│              │   calendar-backend     │                 │
│              │   (Node.js + Express)  │                 │
│              │                        │                 │
│              │ - Auth (Google OAuth)  │                 │
│              │ - Meetings API         │                 │
│              │ - Cards API            │                 │
│              │ - SMA API              │                 │
│              │ - Public endpoints     │                 │
│              │ - AI processing        │                 │
│              └─────────┬─────────────┘                  │
│                        │                               │
│         ┌──────────────┼──────────────────┐            │
│         │              │                  │            │
│  ┌──────▼──────┐ ┌─────▼──────┐  ┌───────▼───────┐   │
│  │  PostgreSQL  │ │   Redis    │  │  Google Cloud  │   │
│  │  (Prisma)   │ │  (Bull     │  │  Storage       │   │
│  │             │ │   queues)  │  │  (recordings)  │   │
│  └─────────────┘ └────────────┘  └───────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Two frontend paradigms, one backend:**
- `calendar-frontend` — authenticated dashboard, Vite + React (CSR is fine, no SEO needed)
- `cards-frontend` — public frontend, Next.js App Router (SSR required for SEO + OG previews)
- Both repos are fully independent — no shared packages, same design language by convention

---

## External Integrations

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Google OAuth  │     │    Deepgram      │     │    OpenAI       │
│                 │     │                  │     │                 │
│ - Sign In       │     │ - Transcription  │     │ - Summaries     │
│ - Calendar sync │     │ - Diarization    │     │ - Action items  │
│ - (Zoom future) │     │   (who said what)│     │ - Ask AI        │
└─────────────────┘     └─────────────────┘     │ - Big Brain     │
                                                 └─────────────────┘

┌─────────────────┐
│   Recall.ai     │  ← Phase 1.2
│                 │
│ - Bot joins     │
│   Google Meet   │
│   or Zoom       │
│ - Streams audio │
│   to Deepgram   │
└─────────────────┘
```

---

## Tech Stack

### Backend (`calendar-backend`)

| Layer | Technology |
|-------|-----------|
| Runtime | Node.js ≥ 20 |
| Framework | Express 5 |
| Language | TypeScript 5 |
| ORM | Prisma 6 |
| Database | PostgreSQL |
| Job Queue | Bull + Redis |
| File Storage | Google Cloud Storage |
| Transcription | Deepgram Nova-2 |
| AI | OpenAI GPT-4o-mini |
| Auth | JWT + Google OAuth 2.0 |
| Validation | Zod |
| Logging | Pino + Winston |

### Frontend — Dashboard (`calendar-frontend`)

| Layer | Technology |
|-------|-----------|
| Framework | React 19 |
| Language | TypeScript 5 |
| Build | Vite 6 |
| Routing | React Router 7 |
| Styling | TailwindCSS 4 + shadcn/ui |
| State | Zustand |
| Data Fetching | React Query (TanStack Query v5) |
| Animations | Motion (Framer Motion) |
| Icons | Lucide React |
| Notifications | Sonner |

### Frontend — Public (`cards-frontend`)

| Layer | Technology |
|-------|-----------|
| Framework | Next.js (App Router) |
| Language | TypeScript 5 |
| Rendering | SSR — required for SEO + OG previews |
| Styling | TailwindCSS 4 + shadcn/ui |

**Public routes served:**
- `/:username` — card page
- `/:username/:slug` — specific card
- `/m/:id` — published meeting (Phase 1 P2)
- `/schedule/:username` — availability + booking (Phase 1.2)

---

## API Structure

All routes under `/api/v1/`

```
/auth/*                    Auth (Google OAuth, JWT refresh)
/users/*                   User profile management
/meetings/*                Meeting CRUD, participants, availability
/cards/*                   Digital card management (auth required)
/public/cards/*            Public card endpoints (no auth)
/public/meetings/:shortId  Published meeting page data (no auth — Phase 1 P2)
/sma/*                     Smart Meeting Assistant
  /sma/meetings/:id/recordings        Upload, list, delete
  /sma/meetings/:id/transcript        Get transcript + status
  /sma/meetings/:id/summary           Get + regenerate AI summary
  /sma/meetings/:id/tasks             CRUD tasks
  /sma/meetings/:id/notes             CRUD meeting notes
  /sma/meetings/:id/ask               Ask AI (streaming SSE)
  /sma/meetings/:id/publish           Publish/unpublish meeting (Phase 1 P2)
/storage/*                 File upload signed URLs
/integrations/*            Google Calendar, Recall.ai (Phase 1.2)
```

---

## Smart Meeting Assistant — Data Flow

```
User uploads recording file
         │
         ▼
  Multer middleware (file handling)
         │
         ▼
  Upload to Google Cloud Storage
         │
         ▼
  Deepgram API called
  ├── Nova-2 model
  ├── diarize: true (speaker separation)
  ├── smart_format: true
  └── punctuate: true
         │
         ▼
  Transcript stored in PostgreSQL
  ├── MeetingTranscript (full text)
  └── TranscriptSegment[] (speaker + timestamp per segment)
         │
         ▼
  OpenAI processing (parallel)
  ├── generateSummary()
  ├── extractKeyPoints()
  └── extractActionItems()
         │
         ▼
  Results stored in PostgreSQL
  ├── MeetingAISummary
  └── MeetingActionItem[]
         │
         ▼
  Frontend polls transcriptionStatus
  NONE → UPLOADED → PROCESSING → COMPLETED
```

---

## Ask AI — Architecture (To Build)

```
User types question in chat
         │
         ▼
  POST /sma/meetings/:id/ask
  { question: "What did John say about the budget?" }
         │
         ▼
  Fetch full transcript from DB
         │
         ▼
  Build OpenAI prompt:
  ├── System: "You are an AI assistant for meeting: [title]"
  ├── Context: Full transcript with speaker labels
  └── User: The question
         │
         ▼
  OpenAI streaming response
         │
         ▼
  Stream back to frontend
         │
         ▼
  Chat interface renders answer
```

**Upgrade path for Phase 2 (Big Brain):**
- Chunk transcripts → embed → store in vector DB
- RAG retrieval across ALL meetings, not just one
- Answers with citations to specific meetings + timestamps

---

## Database Schema — Key Models

See `calendar-backend/prisma/schema.prisma` for full schema.

**Core relationships:**

```
User
 ├── Cards (1:many)
 │    ├── CardContact (1:many)
 │    └── CardView (1:many)
 │
 └── Meetings (created by, 1:many)
      ├── MeetingParticipant (many:many with User)
      ├── MeetingRecording (1:1)
      │    └── MeetingTranscript (1:1)
      │         └── TranscriptSegment (1:many)
      ├── MeetingAISummary (1:1)
      ├── MeetingActionItem (1:many)
      ├── MeetingNote (1:many)
      ├── MeetingSpeaker (1:many)
      └── MeetingStateHistory (1:many)
```
