# Phase 6 P5.5.a — Tag schema + CRUD + listTags + getTagItems team-scoping

First chunk of P5.5. Tag schema gains `teamId` with two partial unique indexes so personal and team "Important" can co-exist. The 5 Tag CRUD handlers are team-aware end-to-end. Junction handlers (meeting/card/task/contact-tag) get a **bridge fix** — tag-side ownership swaps from the legacy actor-only check to the new team-aware `assertTagAccess`. Entity-side swaps (assertCardAccess / assertTaskAccess / contact-via-card) stay for P5.5.b.

## What was built

- **Schema (`Tag` model)**:
  - `teamId String? @db.Uuid` + Team relation (`onDelete: SetNull`) + `@@index([teamId, isDeleted])`.
  - Dropped Prisma `@@unique([userId, name])`. Migration appends raw SQL for two partial unique indexes:
    - `Tag_user_personal_unique` — `(userId, name) WHERE teamId IS NULL AND isDeleted = false`.
    - `Tag_team_unique` — `(teamId, name) WHERE teamId IS NOT NULL AND isDeleted = false`.
  - `Team.tags Tag[]` back-relation added.
- **Migration**: `20260530064513_phase6_p5_5a_tag_team_scoping/migration.sql` — column + FK + index + drop-old + 2 partial uniques. Idempotent guard via `DROP INDEX IF EXISTS`. Applied to local DB via `docker exec crelyzor-workspace-backend-1 pnpm db:deploy`.
- **`tagService.ts`** — full retrofit:
  - **Helpers**: `tagScope` (where fragment), `verifyTagAccess` (pure check), `assertTagAccess` (slim fetch + verify + return; exported for P5.5.b junctions), `MAX_TAGS_PER_TEAM = 500`.
  - **No `principalForTag`** — Tag has no encrypted columns (same call as EventType).
  - **5 CRUD retrofits**:
    - `listTags` — `tagScope` filter on Tag rows + 4 group-by count queries scope by entity team-scope. Workspace-wide counts under team ctx (every member sees the same number, like Slack channel counts).
    - `createTag` — writes `teamId: ctx?.teamId ?? null`. MEMBER allowed under team ctx (workspace primitives). 500-tag-per-team cap enforced before insert.
    - `updateTag` — `assertTagAccess(mutate)` then `updateMany` with full scope filter (TOCTOU defence). 404 if `count === 0`. P2002 → 409 still works post-gate.
    - `deleteTag` — same gate + `updateMany` pattern + transactional junction cleanup. `tag.delete` audit log line.
    - `getTagItems` — `assertTagAccess(read)` then 4 entity sub-queries scope by entity team-scope. Items reflect workspace activity.
- **Junction bridge fix** (12 handlers — 3 ops × 4 entity types): tag-side check swaps `verifyTagOwnership(tagId, userId)` (actor-only) → `assertTagAccess(userId, tagId, teamContext, "read")` (team-aware). Entity-side check stays legacy — `assertCardAccess / assertTaskAccess / contact-via-card` swap lands in P5.5.b along with the cross-scope guard (`tag.teamId === entity.teamId`).
- **`tagController.ts`** — `getTeamContext(req)` threaded through 17 handlers (5 CRUD + 12 junction). Audit log fields adopt `{actorId, tagId, teamId}` convention.
- **`tagRoutes.ts`** — `resolveTeamContext` mounted after `verifyJWT`.

## Key patterns

- **Partial unique indexes for dual-scope uniqueness.** Personal "Important" and team "Important" need to co-exist (different scopes, distinct semantics). Two `WHERE`-clauses-indexes split the namespace cleanly. Postgres native — no application-layer fallback needed. Same pattern as `TeamInvite`'s `(teamId, email, isDeleted)` partial index from P0.
- **`updateMany` + `count === 0` instead of slim-gate then `update`.** Closes the TOCTOU window between the gate's slim-fetch and the actual write. The `updateMany` includes the full scope filter (`teamId` + `userId` for personal; `teamId` for team) so a stale-context write can't land. P2025 isn't triggered because `updateMany` returns `{count: 0}` for "no match" — we collapse that to the same 404 as the gate.
- **Workspace-wide counts.** All members under team ctx see the same count, not per-actor counts. Documented as a deliberate trade-off (consistent with Slack channel counts / Notion workspace stats). The leak surface is small (an integer count, no entity content), and computing "accessible count" would double every group-by query.
- **Workspace primitive vs owned content distinction.** Tags ≠ cards. Cards are owned content (createCard ADMIN+). Tags are shared vocabulary (createTag any role). Inline comments document the asymmetry explicitly so the next reviewer doesn't "fix" it.
- **Mutate → 404, not 403, for MEMBERs on team tags.** Same enumeration-collapse pattern as prior chunks. MEMBER probing a team tag ID gets the same response for not-found / wrong-team / wrong-role. No role-leak oracle.
- **Bridge-then-full-swap split.** P5.5.a updates only the tag-side ownership check in the 12 junction handlers (otherwise day-one functional break: team tag created by A couldn't be attached by B). Entity-side checks + cross-scope guard land together in P5.5.b. This keeps each PR's diff manageable while bridging the gap.

## Decisions

- **MEMBER may create team tags.** Workspace primitives, low security surface (tag names are advisory). Inline comment explicitly notes the asymmetry vs createCard. Cap at 500 team tags prevents pollution.
- **`onDelete: SetNull` on Tag.team** (vs Cascade). Consistent with Phase 6 soft-delete-first policy — team hard-delete only runs via retention job. SetNull only triggers on hard delete. Schema reviewer flagged a potential orphan-conflict edge case (a hard-deleted team's tag reverts to `teamId=null`, may collide with a same-named personal tag belonging to the same `userId` via the partial-personal index) — tracked as a retention-worker spec follow-up.
- **Case-sensitive uniqueness retained.** Current behaviour. Migration to `LOWER(name)` or `CITEXT` is a non-breaking future change once duplicate complaints surface.
- **Workspace-wide counts** over per-actor counts. Reviewer-accepted. Documented inline.
- **Bridge-then-swap split** for junction handlers. Avoids a day-one functional break without overloading P5.5.a's diff. Entity-side gate swap in P5.5.b carries the cross-scope guard.
- **Tag.teamId is immutable post-create.** No API path moves a tag between scopes. If a future endpoint needs this, it must coordinate with the partial indexes (a rename might trigger uniqueness conflicts in the destination scope).
- **`@@unique([userId, name])` drop is safe.** All pre-migration rows have `teamId IS NULL`, so the personal partial index is a strict superset of the old constraint.

## Gotchas

- **`updateMany` returns `count`, not the row.** After successful update, the service re-fetches via `findUnique({id})` to return the updated tag. Two queries per update — acceptable given the TOCTOU defence requires the where-clause filter in the write.
- **Junction handlers' tag-side check now accepts a MEMBER-created team tag.** Pre-P5.5.a, `verifyTagOwnership` rejected this (tag.userId !== actor). Frontend code that expected "tag attach fails if I didn't create the tag" no longer holds.
- **Workspace-wide count semantics are eventually surface-visible.** A MEMBER may see `meetingTags: 5` on a team tag while only being allowed to access 2 of those meetings. Frontend may want to label the count as "team-wide" or `~5` to manage expectations.
- **MEMBER attempting to mutate team tag returns 404 not 403.** Frontend retry logic that distinguishes "not found" from "forbidden" must handle 404 as a possible legitimate response.
- **`@@unique([userId, name])` drop hides an edge.** A user can now have a personal "Urgent" AND be a team-member of a team with team "Urgent" — both visible under different scopes. UI surfacing both in a combined view would see two "Urgent" tags. Currently no combined view exists.
- **Tag.userId stays as creator** even on team tags. Attribution metadata, NOT auth. Don't filter by `tag.userId = actor` on team tags — it would miss tags created by other team members.

## Deferred to P5.5.b

- **Entity-side gate swap in 12 junction handlers**:
  - `verifyCardOwnership` → `assertCardAccess(read)` (card-tag handlers).
  - `verifyTaskOwnership` → `assertTaskAccess(read)` (task-tag handlers).
  - `verifyContactOwnership` → contact-via-card check using `assertCardAccess(read)` + verify contact belongs to card (contact-tag handlers).
  - Meeting-tag handlers already use `assertMeetingAccess` — verified, no swap needed.
- **Cross-scope guard**: enforce `tag.teamId === entity.teamId` at attach-time. Prevents a personal tag from being attached to a team entity (and vice versa). Critical because the bridge currently allows cross-scope attaches as a transition state.
- **Audit logs on junction handlers** — `tag.attach` / `tag.detach` lines mirroring the CRUD `tag.delete` pattern.

## Verification ideas (post-test)

- Apply migration in staging → run a SELECT on `pg_indexes WHERE tablename = 'Tag'` to confirm both partial uniques + dropped old index.
- Personal regression: existing tag list + counts on existing data.
- Team flow: create team tag as MEMBER, attach via different ADMIN, decrement on detach.
- Cap test: bulk-create 501 team tags → expect 409 on row 501.
- Partial index race: two concurrent createTags with same name → second one gets 409.
- Case-sensitivity: "Urgent" and "urgent" succeed as separate tags (current behaviour).
