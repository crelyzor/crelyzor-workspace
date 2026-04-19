# Crelyzor — AI Brain

## Overview

AI in Crelyzor works at two levels:

1. **Per-Meeting Brain** — AI that deeply understands one specific meeting
2. **Big Brain** — AI that knows everything across all your meetings, contacts, and schedule

---

## Level 1 — Per-Meeting Brain

Every meeting in Crelyzor gets its own AI brain once a transcript is available.

### Auto-Generated (runs after transcription)

These are generated automatically without user action:

| Output | What It Is |
|--------|-----------|
| Summary | 2-4 paragraph narrative of what happened |
| Key Points | Bulleted list of most important moments |
| Action Items | Tasks with owner, category, suggested dates |
| Decisions Made | Explicit decisions captured from the conversation |
| Follow-ups Required | Things that need a response or next step |

### Ask AI (User-initiated)

A chat interface inside every meeting detail page.

**What the user can ask:**
- "What did Sarah say about the Q3 budget?"
- "List all the blockers mentioned in this meeting"
- "Who is responsible for the product launch?"
- "Give me a timeline of what was discussed"
- "What were the open questions at the end?"
- "Summarize the first 15 minutes only"

**How it works:**
- Full transcript with speaker labels is injected as context
- OpenAI processes the question against the full transcript
- Answer is streamed back to the chat interface
- Conversation history is preserved within the session

**Architecture:**
```
POST /sma/meetings/:meetingId/ask
{
  "question": "What did John say about pricing?",
  "conversationHistory": []  // optional, for multi-turn
}

Response:
{
  "answer": "John mentioned that...",
  "relevantSegments": [...]  // optional: timestamp references
}
```

---

## Level 2 — Big Brain (Phase 2)

The Big Brain is a cross-meeting, cross-workspace AI. It knows:

- Every meeting transcript you've had
- Every action item (completed or not)
- Your contacts and what you know about them
- Your schedule and upcoming commitments
- Your tasks

### Capabilities

**Weekly briefing:**
> "What do I need to focus on this week?"
> → Pulls from pending action items, upcoming meetings, overdue tasks

**Context about a person:**
> "What do I know about Jane from Acme Corp?"
> → Surfaces: past meetings with Jane, what was discussed, action items involving her, her card contact info

**Meeting preparation:**
> "Prepare me for my 3pm call with the product team"
> → Summarizes: previous meetings with these people, open action items, last decisions made, context

**Proactive nudges:**
> "You have 3 action items from last week's meeting that haven't been completed"
> "You mentioned following up with Tom — you haven't yet"

### Architecture (Phase 2)

```
All transcripts + notes + action items
         │
         ▼
  Chunking + Embedding
  (text-embedding-3-small or similar)
         │
         ▼
  Vector Store (pgvector or Pinecone)
         │
When user asks something:
         │
         ▼
  Semantic search over all embeddings
         │
         ▼
  Retrieve top-K relevant chunks
         │
         ▼
  Build prompt with retrieved context
         │
         ▼
  OpenAI generates answer with citations
```

---

## AI Models

| Use Case | Model | Why |
|----------|-------|-----|
| Meeting summary, key points | GPT-4o-mini | Fast, cheap, accurate enough |
| Action item extraction | GPT-4o-mini | Structured output (JSON) |
| Ask AI (per meeting) | GPT-4o-mini | Context fits in window |
| Big Brain Q&A | GPT-4o | Better reasoning across large context |
| Embeddings | text-embedding-3-small | Cost-effective for RAG |
| Transcription | Deepgram Nova-2 | Best accuracy + diarization |
| Online meeting bot | Recall.ai | Real-time bot for Google Meet / Zoom |

---

## Deepgram Configuration

```typescript
{
  model: "nova-3",  // Multilingual — upgraded at Phase 4.1
  diarize: true,          // Speaker separation (Speaker 0, Speaker 1...)
  smart_format: true,     // Paragraph breaks, formatting
  punctuate: true,        // Punctuation
  utterances: true,       // Segment by utterance (not word-level)
}
```

Speaker labels map to `MeetingSpeaker` — user can rename "Speaker 0" → "John" after the fact.

---

## Ask AI — Prompt Design

Each request builds the OpenAI messages array as:

```
[system]  — meeting title + "answer based solely on transcript" instruction
[user]    — prior turn 1 (if history exists)
[assistant] — prior answer 1
... up to 6 prior messages (3 exchanges) ...
[user]    — "Transcript:\n<context>\n\nQuestion: <current question>"
```

The transcript context is relevance-filtered (`buildRelevantAskAIContext`) and capped at ~12,000 chars (~3k tokens) to control cost on long meetings.

**Conversation persistence:** Each meeting has one `AskAIConversation` row per user (`@@unique([meetingId, userId])`). Every user/assistant turn is an `AskAIMessage` row. History loads on tab open; the last 6 messages are injected as context on every new question.

```
POST /sma/meetings/:meetingId/ask
  → getOrCreateConversation(userId, meetingId)
  → getMessages(userId, meetingId) — last 6 for context
  → appendMessage(conversationId, "user", question)
  → stream OpenAI response (SSE)
  → appendMessage(conversationId, "assistant", fullResponse)

GET  /sma/meetings/:meetingId/ask/history  → full message list
DELETE /sma/meetings/:meetingId/ask/history → clears all messages
```

---

## What's Built vs What's Not

| Feature | Status |
|---------|--------|
| Deepgram transcription (Nova-3 Multilingual) | ✅ Built |
| Speaker diarization + rename | ✅ Built |
| AI summary generation | ✅ Built |
| Key points extraction | ✅ Built |
| Task extraction (AI_EXTRACTED) | ✅ Built |
| Meeting notes | ✅ Built |
| Ask AI — streaming SSE endpoint | ✅ Built |
| Ask AI — frontend chat UI (all 3 layouts) | ✅ Built |
| Ask AI — conversation persistence (PostgreSQL) | ✅ Built |
| Ask AI — rolling context window (last 6 messages) | ✅ Built |
| Ask AI — clear conversation | ✅ Built |
| AI content generation (Report, Tweet, Blog, Email) | ✅ Built |
| Pre-generated decisions/follow-ups | ❌ Not built |
| Big Brain — embeddings pipeline | ❌ Not built (Phase 5) |
| Big Brain — RAG query interface | ❌ Not built (Phase 5) |
| Recall.ai integration | ✅ Built |
