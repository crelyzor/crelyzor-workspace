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

```
System:
You are an AI assistant for a meeting titled "[Meeting Title]"
that took place on [Date].
Your job is to answer questions about this specific meeting based
only on the transcript provided.
Be concise. Reference speaker names when available.
If the answer isn't in the transcript, say so clearly.

Context (transcript):
[Speaker 0 - John]: "We need to finalize the budget by Friday..."
[Speaker 1 - Sarah]: "I think we should push it to next week..."
...

User:
[User's question]
```

---

## What's Built vs What's Not

| Feature | Status |
|---------|--------|
| Deepgram transcription | ✅ Built |
| Speaker diarization | ✅ Built |
| AI summary generation | ✅ Built |
| Key points extraction | ✅ Built |
| Action item extraction | ✅ Built |
| Meeting notes | ✅ Built |
| Ask AI — backend endpoint | ❌ Not built |
| Ask AI — frontend chat UI | ❌ Not built |
| Pre-generated decisions/follow-ups | ❌ Not built |
| Big Brain — embeddings pipeline | ❌ Not built |
| Big Brain — RAG query interface | ❌ Not built |
| Recall.ai integration | ❌ Not built |
