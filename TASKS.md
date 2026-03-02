# Crelyzor — Master Task List

Last updated: 2026-03-03

> **Rule:** When you complete a task, change `- [ ]` to `- [x]` and move it to the Done section.
> **Legend:** `[ ]` Not started · `[~]` Has code but broken/incomplete · `[x]` Done and working

See per-repo tasks for implementation details:
- [calendar-backend/TASKS.md](./calendar-backend/TASKS.md)
- [calendar-frontend/TASKS.md](./calendar-frontend/TASKS.md)
- [cards-frontend/TASKS.md](./cards-frontend/TASKS.md)

---

## Phase 1 — Current State

### Working ✅
- Cards (create, edit, public page, QR, vCard, contacts, analytics)
- Google OAuth sign-in
- Meeting CRUD (create, update, cancel, complete)
- Meetings list page with context menu actions
- Recording upload → GCS → Deepgram transcription → OpenAI AI processing (end to end)
- Live recording via browser microphone (FAB)
- MeetingDetail page — wired to real API (transcript, summary, action items, recording player)
- MeetingDetail buttons — Accept, Decline, Complete, Cancel all wired
- AI title generation after transcription
- Retry AI button when AI processing fails
- MeetingType system (SCHEDULED | RECORDED | VOICE_NOTE) — backend done

### P0 — In Progress 🔨
These are the next things to build, in order:

1. **Backend:** Auto-create MeetingSpeaker records after transcription
2. **Backend:** Speaker rename endpoint
3. **Frontend:** MeetingDetail — 3 distinct layouts by type (VOICE_NOTE / RECORDED / SCHEDULED)
4. **Frontend:** Voice Notes section in sidebar + separate from Meetings list

### Not Built Yet ❌
- Ask AI endpoint (backend)
- Ask AI chat interface (frontend)
- Meeting notes UI
- Edit meeting modal
- Voice Notes sidebar section

---

## Phase 1.2 — Future (Do not start yet)

- [ ] Recall.ai integration
- [ ] Cal.com style scheduling
- [ ] Google Calendar sync

---

## Phase 2 — Future

- [ ] AI Big Brain (RAG over all user data)

---

## Phase 3 — Future

- [ ] Tasks (Todoist-style)

---

## Teams — Future Scope

Not scoped. Do not build.
