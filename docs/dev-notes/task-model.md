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

## Phase 3 additions ✅ Done

Fields added in Phase 3:
- `status TaskStatus (TODO | IN_PROGRESS | DONE)` — bidirectionally synced with `isCompleted`. When `status=DONE` → `isCompleted=true`, `completedAt=now`. When `isCompleted=true` → `status=DONE`.
- `sortOrder Int @default(0)` — drag-to-reorder position. `PATCH /sma/tasks/reorder` takes ordered `taskIds[]`, writes sortOrder=index in userId-scoped transaction.
- `parentTaskId UUID?` — self-referential FK. `GET /sma/tasks/:taskId/subtasks` + `POST /sma/tasks/:taskId/subtasks`. Parent ownership verified before creating children.
- `cardId UUID?` — links task to a Card. Card ownership verified on create/update.
- `transcriptContext String?` — transcript sentence for AI_EXTRACTED tasks. Displayed in From Meetings view.

See `docs/dev-notes/phase-3-tasks-calendar.md` for the full design.

## Decisions
- Built `Task` model early (before frontend) to avoid painful data migration later when real user data exists.
- `meetingId` is nullable by design — standalone tasks use the same model.
- Standalone task endpoints live under `/sma/tasks` (same router as meeting-scoped tasks, prefixed by `/sma`). Did not move to `/tasks` — kept everything under `/sma` for consistency.
- `isCompleted` retained on the model alongside `status` for backwards compatibility. Both stay in sync via controller logic. Can be dropped in a future cleanup migration once all consumers use `status`.
