# Recurring Tasks

## What Was Built

RRULE-based recurring tasks — set Daily / Weekly / Monthly on any task via a "Repeat" picker in `TaskDetailPanel`. When a recurring task is marked Done, the backend automatically spawns the next occurrence with the computed `dueDate`.

## Patterns Used

**Backend spawn logic** lives in `taskController.ts` `updateTask` handler (no separate service — project convention). Trigger condition: `resolvedStatus === "DONE" && existing.status !== "DONE" && taskRecurringRule`. The `resolvedStatus` variable is the derived status after the isCompleted↔status sync block — always use this, not the raw payload `status`.

**Fail-open try/catch** wraps the spawn. If rrule or DB creation fails, the task update still succeeds. Error is logged but not thrown.

**`recurringRule` for spawn** uses `recurringRule !== undefined ? recurringRule : existing.recurringRule` — handles the case where the user sets recurringRule and completes in the same PATCH.

## Gotchas

**rrule ESM import** — `import { RRule } from "rrule"` throws `SyntaxError: The requested module 'rrule' does not provide an export named 'RRule'` in ESM context. Use:
```typescript
import rruleLib from "rrule";
const { RRule } = rruleLib;
```

**rrule `after()` is exclusive** — `rule.after(baseDate)` returns the first occurrence *strictly after* baseDate. This is correct (avoids same-day duplicate when baseDueDate = today).

**DTSTART defaults to parse time** — `RRule.fromString("FREQ=DAILY")` sets DTSTART to now. `rule.after(pastDate)` returns the next occurrence from DTSTART onward, not from pastDate. For a task with `dueDate` yesterday, the spawned task gets `dueDate = today` (not tomorrow). It shows in the **Today** view, not Upcoming.

**Rate limiter + dev loop** — hammering the API during a restart burns through the `PATCH /sma/tasks/:taskId` rate limit (60/hr) and `auth:refresh` limit (10/15min). To reset in dev: `node --env-file=.env -e "import('@upstash/redis').then(async ({Redis}) => { const r = new Redis({url: process.env.UPSTASH_REDIS_REST_URL, token: process.env.UPSTASH_REDIS_REST_TOKEN}); const keys = await r.keys('ratelimit:*'); for (const k of keys) await r.del(k); console.log('cleared', keys); })"` from the backend directory.

## Schema

```prisma
recurringRule     String?
recurringParentId String?   @db.Uuid
recurringParent   Task?     @relation("RecurringTasks", fields: [recurringParentId], references: [id], onDelete: SetNull)
recurringChildren Task[]    @relation("RecurringTasks")
@@index([recurringParentId])
```

## Decisions

- Only 3 RRULE values supported (DAILY/WEEKLY/MONTHLY) — stored as full RRULE string (`FREQ=DAILY`) for forward compatibility with custom rules later
- Zod uses `z.enum(["FREQ=DAILY","FREQ=WEEKLY","FREQ=MONTHLY"])` not `z.string().max()` — enum validates intent, not length
- `recurringParentId` chains all occurrences back to the original task (not to the immediate parent), so the chain is flat regardless of how many times it recurs
