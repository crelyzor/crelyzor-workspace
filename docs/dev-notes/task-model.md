# Task Model (replacing MeetingActionItem) — Dev Notes

## What was built
Replaced `MeetingActionItem` with a proper `Task` model with `TaskSource` and `TaskPriority` enums.

## Schema
```
Task {
  id, userId, meetingId (nullable), title, description,
  isCompleted, completedAt, dueDate, priority (TaskPriority),
  source (AI_EXTRACTED | MANUAL), createdAt, updatedAt, isDeleted, deletedAt
}
```

## Patterns used
- Meeting-linked tasks: `meetingId` set. Standalone tasks (Phase 3): `meetingId: null`.
- AI extraction writes tasks with `source: AI_EXTRACTED`. Manual creation uses `source: MANUAL`.
- Soft delete only — never hard delete task records.

## Gotchas
- `MeetingActionItem` was dropped entirely — no migration needed (no production data worth keeping at time of drop).
- Always scope task queries to `userId` — never fetch tasks by `meetingId` alone without verifying ownership.

## Phase 3 additions (planned)

New fields being added in Phase 3:
- `status TaskStatus (TODO | IN_PROGRESS | DONE)` — replaces `isCompleted` boolean. DONE = isCompleted for backwards compatibility.
- `sortOrder Int` — drag-to-reorder position, scoped per user.
- `parentTaskId UUID?` — self-referential FK for subtasks.
- `cardId UUID?` — links task to a Card contact.
- `transcriptContext String?` — the transcript sentence that generated an AI-extracted task. Only set when `source = AI_EXTRACTED`. Used in the "From Meetings" view tooltip.

See `docs/dev-notes/phase-3-tasks-calendar.md` for the full design.

## Decisions
- Built `Task` model early (before frontend) to avoid painful data migration later when real user data exists.
- `meetingId` is nullable by design — standalone tasks use the same model.
- Endpoints live under `/sma/meetings/:meetingId/tasks` (meeting-scoped) and `/sma/tasks/:taskId` (individual operations).
- In Phase 3, standalone task endpoints move to `/tasks` (not under `/sma`).
