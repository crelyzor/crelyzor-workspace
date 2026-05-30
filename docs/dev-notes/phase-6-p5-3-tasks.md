# Phase 6 P5.3 — Tasks: full team-scoping + AI-extracted task encryption fix

Brings the Tasks surface in line with the meetings/cards retrofits. Also ships the P5.1.c.ii decrypt-corruption fix and an idempotent backfill that heals any rows shipped in the window where the bug was live.

## What was built

### `src/controllers/taskController.ts`

- **4 helpers added at the top of the file** (same shape as meetings/cards):
  - `taskScope(actorId, teamContext) → Prisma.TaskWhereInput` — personal returns `{ teamId: null, userId: actor }` (closes the team-task-in-personal-list leak); team+ADMIN/OWNER returns `{ teamId }`; team+MEMBER returns `{ teamId, userId: actor }`.
  - `principalForTask(task) → Principal` — derives from `task.teamId ?? task.userId`. Pure. Documented as immutable for the row's lifetime (Task.teamId never flips).
  - `verifyTaskAccess(actorId, task, teamContext, "read" | "mutate")` — pure check on a pre-fetched slim row.
  - `assertTaskAccess(actorId, taskId, teamContext, action)` — fetch + verify + return slim row.
- **`decryptTaskDescriptions` refactored** — removed the `userId` parameter. Per-row principal derivation via `principalForTask(t)`. Rows in a single response can come from multiple users / multiple teams under ADMIN scope, so a single principal won't fit. Same pattern as P5.2.b's `getContacts` batch decrypt.
- **9 method retrofits:**
  - `getAllTasks` (`/sma/tasks`) — `taskScope` filter replaces `userId = actor`. **Personal list no longer surfaces team tasks the actor happens to own** (was the same bug class as the cards personal-list leak). Frontend must use `X-Team-Id` to see team tasks.
  - `getTasks` (per-meeting list) — `assertMeetingAccess(read)` on the parent meeting + `taskScope` filter on the task list.
  - `createTask` (per-meeting) — `assertMeetingAccess`. **`task.teamId` inherits from `meeting.teamId`** (security must-fix: prevents a personal-context create from anchoring a personal task on a team meeting). Encrypts description under `principalForTask` of the new row.
  - `createStandaloneTask` — `assertMeetingAccess`/`assertTaskAccess`/`assertCardAccess` on each linked entity. Cross-scope assertion: e.g. parent task on team A and target context = team B → 404 "Parent task is in a different scope." `teamId` inherits from the **first linked entity** (meeting, then parent task, then card), falling back to `teamContext.teamId`, finally `null`.
  - `updateTask` — `assertTaskAccess(mutate)`. All 5 `prisma.task.update({ where: { id, userId } })` sites stripped to `{ id }` (the gate now does the ownership work). Encrypt/decrypt under `principalForTask` of the **existing row** (the row's teamId is immutable, so the principal is the same before/after the update). Recurring spawn carries explicit `teamId: existing.teamId ?? null`. cardId change goes through `assertCardAccess` + cross-scope assertion.
  - `deleteTask` — `assertTaskAccess(mutate)`. **Subtask cascade drops the `userId` filter** — admin deleting a team task cascades to subtasks regardless of who authored each subtask. Orphan subtasks were judged worse than over-cascading; personal context is unchanged (subtasks are still author-owned).
  - `reorderTasks` — `taskScope` ownership check on the bulk update. **Per-row audit log** with `actorId / taskId / ownerId / teamId` so ADMIN reordering a MEMBER's tasks leaves a paper trail (security must-fix).
  - `getSubtasks` — `assertTaskAccess(read)` on parent + `taskScope` on the subtask list.
  - `createSubtask` — `assertTaskAccess(parent, mutate)`. **Subtask inherits `parent.teamId`** (no mixed-state subtasks). Encrypts description under `principalForTask` of the new row.

### `src/services/ai/aiService.ts` — P5.1.c.ii regression fix

- One-line fix: `extractTasks` insert now writes `teamId: meetingMeta.teamId` alongside the existing `userId` + encrypted `description`.
- Bug shape (introduced in P5.1.c.ii, caught in P5.3 review): `description` was encrypted under `meetingPrincipal` (team DEK on team meetings) but `Task.teamId` was left null. After P5.3, `principalForTask` derives from `task.teamId` — on the bugged rows that's null, so it resolves to user DEK and silent decrypt failure on those rows.

### `prisma/migrations/20260530000000_phase6_p5_3_backfill_ai_extracted_task_teamid/migration.sql`

- Idempotent backfill: `UPDATE "Task" SET "teamId" = m."teamId" FROM "Meeting" m WHERE "Task"."meetingId" = m."id" AND "Task"."source" = 'AI_EXTRACTED' AND m."teamId" IS NOT NULL AND "Task"."teamId" IS NULL AND "Task"."description" IS NOT NULL`.
- Safe to re-run (only updates rows still meeting the criteria; second run is a no-op).
- Security reviewer was explicit: backfill is not optional. Code fix alone leaves a window of broken rows.
- Applied to local DB via `prisma migrate deploy`.

## Key patterns

- **`assertTaskAccess` mirrors `assertMeetingAccess` and `assertCardAccess`** — slim fetch (id/userId/teamId), verify, return the slim row. Callers re-query with the appropriate include shape after the gate. The gate is a uniform 404 "Task not found" so cross-tenant probes can't enumerate.
- **Per-row principal in batch decrypt.** `decryptTaskDescriptions` runs on responses that span multiple users (under ADMIN scope, all team-task authors) and possibly multiple teams (a parent task list spanning subtasks across multiple meetings). One global principal won't fit. Per-row `principalForTask(t)` is the only correct call.
- **Inherit-teamId-from-linked-entity** on create paths is the key security pattern. Pre-P5.3, `createTask` would honour the actor's context regardless of the linked meeting's team. Post-P5.3, the linked meeting wins. If you're creating a task on a team meeting, the task is on that team — period. Frontends can't bypass by omitting `X-Team-Id`.
- **`reorderTasks` per-row audit log** is the auditability pattern for any admin-mutating-member-content operation. The log line includes both actor and owner so a future investigation can grep on either side.
- **All-or-nothing principal immutability.** `Task.teamId` never flips after create. `updateTask` reads the existing row's teamId, encrypts/decrypts under that principal, never reassigns. If a future endpoint needs to move a task between teams, it must explicitly re-encrypt the description under the new principal — there's no implicit migration.

## Decisions

- **Personal `GET /sma/tasks` no longer surfaces team tasks.** Same call as the P5.2.a / P5.2.b cards decision: a dual-mode personal list (sometimes-team-included) is a worse bug surface than a stricter scope. Frontend must explicitly request team scope.
- **MEMBER restrictions stay asymmetric vs Cards.** MEMBER can create their own team tasks under team context (different from createCard, which is ADMIN+). Tasks are personal work units; cards are team identity. The asymmetry is intentional.
- **Cross-scope linked-entity rejection returns 404 not 403.** Same enumeration-collapse pattern as the meeting/card gates: "Not found" leaks less than "Forbidden because the parent is on a different team."
- **`deleteTask` cascade drops the `userId` filter intentionally.** Admin deleting a team task wipes all subtasks regardless of subtask author. Orphan subtasks (parent gone, children left dangling) were judged worse than over-cascading on rare cross-author subtask cases.
- **Recurring spawn carries explicit `teamId: existing.teamId ?? null` instead of inheriting from context.** A recurring task on team A spawned by a personal-context update should still belong to team A. The existing row is the source of truth; context is irrelevant.
- **Backfill is a separate migration, not a one-shot script.** Migrations run automatically on deploy; a script wouldn't. Idempotent so re-running is safe.

## Gotchas

- The 5 `prisma.task.update({ where: { id, userId } })` sites in `updateTask` were all individually stripped to `{ id }`. The gate now handles ownership; the inline filter would over-restrict (ADMIN editing a MEMBER's task would 404 itself). Worth re-checking on the next refactor that the gate is mounted before each update.
- `decryptTaskDescriptions` is called from multiple paths (`getAllTasks`, `getTasks`, `getSubtasks`, mutation responses). The signature change (no `userId` param) had to propagate everywhere. Search for `decryptTaskDescriptions(` to verify.
- The backfill migration only heals **AI-extracted** rows. MANUAL tasks on team meetings created in the bug window are not touched — the bug was specific to `extractTasks` not setting `teamId`. MANUAL tasks always went through `createTask` which always set `teamId` correctly.
- `createSubtask` inherits `parent.teamId` even if `teamContext` says otherwise. If the parent is on team A and the actor's context is personal, the subtask still lands on team A. This is intentional; the alternative (rejecting with 400) would be hostile to frontends that don't track context state perfectly.

## Verification

```sql
-- Should return 0 after migration runs:
SELECT COUNT(*)
FROM "Task"
WHERE source = 'AI_EXTRACTED'
  AND "teamId" IS NULL
  AND "description" IS NOT NULL
  AND "meetingId" IN (SELECT id FROM "Meeting" WHERE "teamId" IS NOT NULL);
```

If the count is non-zero post-migration, something in the migration filter is wrong — investigate before deploying further.

## Open follow-ups

- **`taskController` no longer exposes the actor's `userId` on standalone task creation when linking to a team-scoped entity.** `userId` always reads from `req.user.id` (actor), which is correct: the task belongs to the actor, scoped to the linked entity's team. Worth a smoke test on the Reassign endpoint (if one exists) — reassigning a team task between members shouldn't be allowed for MEMBER but the current code doesn't have a dedicated assignee field. Tracking under P5.3 follow-up.
- **Tag-controller task-tag handlers** still rely on `tagService.verifyTaskOwnership` which checks `task.userId = actor`. Needs the same `assertTaskAccess` swap. Bundled under P5.5 (Tags retrofit).
