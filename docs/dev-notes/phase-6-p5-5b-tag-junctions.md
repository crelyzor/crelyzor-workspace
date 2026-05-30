# Phase 6 P5.5.b — Tag junction entity-side gate swap + cross-scope guard

Closing chunk of P5.5. The 12 junction handlers (meeting/card/task/contact × 3 ops each) now use team-aware entity-side gates end-to-end. Cross-scope defense-in-depth at attach-time rejects `tag.teamId !== entity.teamId`. Canonical `tag.attach` / `tag.detach` audit logs across all four entity types. Task access helpers extracted from controller into a pure module so cross-service callers can gate without crossing into the controller layer.

## What was built

- **NEW module — `src/services/tasks/taskAccess.ts`** (extracted from `taskController.ts`):
  - Exports: `TASK_NOT_FOUND_MESSAGE`, `TaskForAccess`, `taskScope`, `principalForTask`, `verifyTaskAccess`, `assertTaskAccess`.
  - Pure module — no transactions, no service orchestration. Just slim-fetch + verify + return.
  - Mirrors the shape of `bookingPrincipal.ts` from P5.4.b (same precedent: pure helpers in their own module so workers + public-facing services + cross-domain services can import without dragging the host-side service graph).
- **`src/controllers/taskController.ts`** — inline declarations of `taskScope` / `principalForTask` / `verifyTaskAccess` / `assertTaskAccess` removed (~110 lines), replaced with imports from `../services/tasks/taskAccess`. Unused `TeamRole` / `Principal` / `ROLE_RANK` / `TASK_NOT_FOUND_MESSAGE` imports/consts dropped. Zero behaviour change.
- **`src/services/tagService.ts`** — junction-side full retrofit:
  - **3 new helpers near the top**:
    - `assertTagEntityScopeMatch(tagTeamId, entityTeamId)` — 400 with "Tag and entity must belong to the same scope" on mismatch. Defense-in-depth — structurally implied by both gates running under the same teamContext, but explicit check catches future-context regressions. 400 (not uniform 404) because both gates have already proven access to both rows.
    - `logTagJunction(action, fields)` — canonical audit log line `tag.attach` / `tag.detach` with `{action, actorId, tagId, entityType, entityId, teamId}`. All 12 junction mutations use this.
    - `verifyContactBelongsToCard(cardId, contactId)` — gates contact-tag handlers (contacts inherit scope from parent card; no `Contact.teamId` column).
  - **12 junction retrofits**:
    - **Meeting-tag** (3): keep `assertMeetingAccess` (already P5.1.b shipped). Add cross-scope guard on attach. Audit log canonicalised.
    - **Card-tag** (3): `verifyCardOwnership` → `assertCardAccess(read)`. Cross-scope guard + audit log.
    - **Task-tag** (3): `verifyTaskOwnership` → `assertTaskAccess(read)`. Cross-scope guard + audit log.
    - **Contact-tag** (3): `verifyContactOwnership` dropped. New flow: `assertCardAccess(read)` on parent card + `verifyContactBelongsToCard(cardId, contactId)` + cross-scope guard via `card.teamId` (since contact has no teamId of its own).
  - Legacy `verifyCardOwnership` / `verifyTaskOwnership` / `verifyContactOwnership` functions deleted (no callers remain).
- **`src/controllers/tagController.ts`** — 3 contact-tag handlers pass `params.data.cardId` to the service (cardId was already in route params via `tagContactParamSchema` / `contactIdParamSchema`, just unused before).

## Key patterns

- **Pure access helpers in dedicated modules.** Started in P5.4.b with `bookingPrincipal.ts`. P5.5.b adds `taskAccess.ts`. Pattern: when an access helper crosses service boundaries (booking helpers needed by worker + public; task helpers needed by tagService), extract to a Prisma-only module — no service orchestration, no transaction logic, no imports from sibling services. Cross-service callers import freely without dragging the host service's import graph.
- **Cross-scope guard is structurally implied but explicitly enforced.** Under shared `teamContext`, both `assertTagAccess` and `assertCardAccess`/`assertTaskAccess`/`assertMeetingAccess` already enforce `row.teamId === ctx.teamId`. So in legitimate code paths `tag.teamId === entity.teamId` is guaranteed by the gate equality. The explicit `assertTagEntityScopeMatch` call is defense-in-depth — catches future code paths that forget to pass the same teamContext through both gates (e.g. a new endpoint that mixes contexts intentionally). Cost: one comparison + one error path. Benefit: invariant documented at every call site.
- **400 vs 404 on cross-scope mismatch.** Uniform 404 ("Tag not found") is used everywhere else for access failures (P5.1–P5.4) because the actor cannot prove the resource exists. Cross-scope mismatch is different: the actor has already passed both `assertTagAccess(read)` and the entity gate — they CAN see both. The mismatch is a published business rule. 400 with descriptive message is the right call for frontend UX ("you cannot tag a personal meeting with a team tag").
- **Contact-tag routes already had cardId, just unused.** Routes were already shaped `/cards/:cardId/contacts/:contactId/tags/:tagId` and the param schema included `cardId`, but the legacy service signature ignored it. P5.5.b uses it. Clean — no schema or route changes.
- **Symmetric attach/detach.** Both directions run both gates. Asymmetric design (e.g. detach only checks tag, not entity) would let a deauthorised actor cleanup attempt succeed. Symmetric design keeps the surface uniform — same response shape for "no access" regardless of direction.
- **Cross-scope guard skipped on detach.** Detach is a cleanup operation; even if a stale cross-scope junction row exists somehow, removing it is a no-op or net positive. Skipping the guard avoids 400 errors when a frontend tries to clean up.
- **Detach still requires the tag-side `assertTagAccess`.** A MEMBER under team ctx attempting to detach a team tag they shouldn't see would otherwise get a 200 OK on a no-op delete. The tag gate rejects them with 404 — keeps the policy uniform.

## Decisions

- **Extract taskAccess BEFORE swapping junction handlers.** Could have inlined access checks in tagService, but that duplicates logic and creates drift risk. Extract first, swap second. Bonus: taskController loses ~110 lines of inline declarations.
- **`verifyContactBelongsToCard` is a tagService-local helper, not a cardService export.** Contacts are a relationship concept, not a top-level entity. The check is simple (one findFirst by id+cardId+isDeleted) and there's no second caller. If a future caller needs it, promote to `cardService.assertContactBelongsToCard`.
- **`assertTagEntityScopeMatch` returns 400 with specific message.** Not 404 (because access is already proven), not 409 (no resource conflict — just scope mismatch). Frontend can surface this distinctly from authentication / not-found errors.
- **Detach skips the cross-scope guard.** Cleanup operations should be lenient. If a buggy state arises with cross-scope junction rows, detach should clear them, not refuse.
- **Audit log naming canonicalised to `tag.{action}`.** Matches `booking.confirm` / `booking.decline` / `booking.cancel` precedent from P5.4.b. Structured fields adopt `{actorId, targetUserId|tagId, teamId, entityType, entityId, action}` convention.
- **`EntityType = "meeting" | "card" | "task" | "contact"`** declared as a local type alias in tagService for the audit helper's type safety. Tied to the four supported entity domains; not promoted to a global type because the audit log is the only consumer.
- **`taskAccess.ts` lives under `src/services/tasks/`** even though no `taskService.ts` exists. The convention is: helper modules go in the directory of their domain. If a future `taskService.ts` ships, it sits next to `taskAccess.ts`. Same pattern as `meetings/meetingService.ts` (a directory with future room).
- **Lint requires `NODE_OPTIONS=--max-old-space-size=4096`.** Default heap (~2GB) ran out during ESLint. Not introduced by P5.5.b — pre-existing codebase size. Documented in DONE block; should be added to `package.json` lint script or CI config as a follow-up.

## Gotchas

- **`assertMeetingAccess` returns a row with `participants` array**, not just `{id, teamId}`. The cross-scope guard only reads `meeting.teamId` so no issue, but if a future caller destructures expecting a smaller shape, the import contract is more permissive than the use site needs.
- **`assertCardAccess` returns `{id, userId, teamId, isDeleted}`**, no relations. Cross-scope guard reads `card.teamId` — fine. If contact-tag's `assertCardAccess` ever needs the card's contacts inline, that's a separate fetch (today's pattern doesn't require it).
- **Contact-tag handler signatures changed** from `(userId, contactId, tagId, ctx?)` to `(userId, cardId, contactId, tagId, ctx?)`. Any external caller (none in current codebase) would break. Controller already updated.
- **`verifyContactBelongsToCard` is a separate query after `assertCardAccess`.** Could be merged into a single fetch (`prisma.cardContact.findFirst({where: {id, cardId, isDeleted: false}, include: {card: {select: {userId, teamId, isDeleted}}}})`) for a minor perf win. Kept separate for clarity — gate first, then existence check.
- **Lint OOM is independent of P5.5.b.** The codebase has grown past ESLint's default heap. Not a P5.5.b regression. Need to bump NODE_OPTIONS in package.json lint script or CI config — small follow-up.
- **`tag.attach` / `tag.detach` log lines now structured differently from pre-P5.5.b.** Old logs were `logger.info("Tag attached to meeting", {meetingId, tagId, userId})`. New logs are `logger.info("tag.attach", {action, actorId, tagId, entityType, entityId, teamId})`. Log analytics queries grepping the old message string will need to be updated.

## Verification ideas (post-test)

- Cross-scope reject: personal tag attached to team meeting → 400 with "different scope" message.
- ADMIN tagging a teammate's task under team ctx → works (previously verifyTaskOwnership rejected because task.userId !== ADMIN).
- MEMBER under team ctx attempting to tag a teammate's task → 404 (MEMBER own-only).
- Contact-tag URL routing: contact C1 under card A, POST `/cards/B/contacts/C1/tags/:tagId` → 404 "Contact not found" (verifyContactBelongsToCard rejects).
- Audit log shape: backend logs show `tag.attach` and `tag.detach` events with the canonical structured fields.
- Personal regression: existing personal tag attach/detach to personal meeting/card/task/contact continues to work.
- Meeting-tag from P5.1.b/P5.5.a bridge: team tag attached to team meeting as ADMIN succeeds.

## P5.5 — complete

- 5.5.a — Schema + Tag CRUD + listTags + getTagItems + junction tag-side bridge fix
- 5.5.b — Junction entity-side gate swap + cross-scope guard + audit logs + taskAccess module

P5.5 fully closed. Tags are workspace-aware end-to-end across all four entity types.

## Remaining P5 retrofit chunks

- P5.6 — SMA + AI cross-team isolation review (per-meeting Ask AI cache + AIContent cache scoping)
- P5.7 — Recall webhook quota attribution under team ctx
- P5.8 — Usage endpoint `GET /teams/:teamId/usage` + UserUsage groupBy schema restructure
