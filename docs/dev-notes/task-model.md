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

## Decisions
- Built `Task` model early (before frontend) to avoid painful data migration later when real user data exists.
- `meetingId` is nullable by design — future standalone tasks (Phase 3) will use the same model.
- Endpoints live under `/sma/meetings/:meetingId/tasks` (meeting-scoped) and `/sma/tasks/:taskId` (individual operations).
