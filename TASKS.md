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
- Meetings list page with context menu actions, type toggle (All | Live | Recordings), skeleton loading
- Recording upload → GCS → Deepgram transcription → OpenAI AI processing (end to end)
- Live recording via browser microphone (FAB)
- MeetingDetail page — wired to real API (transcript, summary, action items, recording player)
- MeetingDetail buttons — Accept, Decline, Complete, Cancel all wired
- MeetingDetail — 3 distinct layouts by type (VoiceNoteDetail / RecordedDetail / ScheduledDetail)
- AI title generation after transcription
- Retry AI button when AI processing fails
- MeetingType system (SCHEDULED | RECORDED | VOICE_NOTE) — backend done
- MeetingSpeaker — auto-created after transcription, rename endpoint, get endpoint
- Voice Notes — separate page (`/voice-notes`), sidebar nav item, home dashboard widget
- Home dashboard — recent meetings, recent voice notes, widgets, skeleton loading
- Settings — theme, profile, URL-based tabs — all wired and working
- Cmd+K command palette — sourced from toolbar, fixed focus ring
- Skeleton loading states — all pages (meetings, cards, home, card editor)
- Light mode background softened, theme flash on hard refresh eliminated

### P0 — Build Next (in order)

1. **Backend:** Ask AI endpoint — `POST /sma/meetings/:id/ask`
2. **Frontend:** Ask AI chat panel inside MeetingDetail
3. **Backend + Frontend:** Auth refresh token (auto-refresh on 401, no more "login again")
4. **Frontend:** Action items CRUD (mark complete, create, delete)
5. **Frontend:** Meeting notes UI (create, delete, show with author + timestamp)
6. **Frontend:** Edit meeting modal (SCHEDULED only)
7. **Frontend:** Delete meeting (VoiceNote + Recorded)

### Not Built Yet ❌
- Ask AI endpoint (backend)
- Ask AI chat interface (frontend)
- Auth refresh token
- Action items CRUD beyond display
- Meeting notes UI
- Edit meeting modal
- Delete meeting

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
