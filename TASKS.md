# Crelyzor — Master Task List

Last updated: 2026-03-02

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
- Meeting CRUD (create, update, cancel)
- Meetings list page
- Google OAuth sign-in

### Has Code — Broken/Incomplete ⚠️
- Recording upload UI — exists but not connected to backend
- MeetingDetail page — exists but shows mock/hardcoded data (transcript, summary, action items)
- Transcription status polling — not wired up on frontend
- AI summary display — has UI but not fetching real data
- Action items UI — has UI but not fetching real data

### Not Built Yet ❌
- Ask AI endpoint (backend)
- Ask AI chat interface (frontend)
- Meeting notes UI
- Edit meeting modal

---

## Phase 1 — Priority Build Order

- [ ] Ask AI endpoint — `POST /sma/meetings/:id/ask` (backend)
- [~] Wire MeetingDetail to real API — replace all mock data (frontend)
- [~] Recording upload UI — connect to backend, show progress (frontend)
- [~] Transcription status polling — NONE → PROCESSING → COMPLETED (frontend)
- [~] Action items UI — fetch real data, mark complete, create manually (frontend)
- [ ] Meeting notes UI — create and delete notes (frontend)
- [ ] Ask AI chat interface — in meeting detail page (frontend)
- [ ] Edit meeting modal (frontend)

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
