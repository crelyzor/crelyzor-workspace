# Phase 6 P8 — Admin API

Five admin endpoints closing Phase 6 backend. SystemConfig CRUD lets founders tune team caps + invite expiry without code changes; team admin overrides let support audit/recover teams; the existing plan override gains structured audit logging.

## What was built

- **SystemConfig CRUD** (`/admin/config`):
  - `GET /admin/config` → returns `{entries, grouped}`. Category is derived from the key prefix before the first `_` (e.g. `max_teams_per_pro_user` → category `max`).
  - `PATCH /admin/config/:key` → upserts. Body `{value: string}`. `updatedBy = req.adminId`. Allows admins to create new keys at runtime — safe because all reads use fallback-defaulted helpers.
- **Team admin overrides** (`/admin/teams`):
  - `GET /admin/teams?include_deleted&search&page&pageSize` → paginated list with owner email + memberCount + isDeleted.
  - `GET /admin/teams/:teamId` → full detail: owner, members (active + departed with role/joinedAt/deletedAt), pending invites.
  - `DELETE /admin/teams/:teamId` → admin override soft-delete. Same cascade shape as Owner delete (team + members + cards in a single transaction).
- **Plan override audit improvement**:
  - `updateUserPlan(userId, plan, adminId?)` now captures `previousPlan` and emits `admin.user.plan.update` with `{adminId, userId, previousPlan, plan}`.

All endpoints sit behind the existing `verifyAdmin` middleware. No DB changes.

## Audit logging strategy

- **Structured `logger.info` lines, not a separate AuditLog table.** Matches existing audit patterns established by `booking.confirm` / `tag.attach` / `task.reorder` from prior P5.x chunks. Log analytics queries can grep on `admin.*` for the full audit feed.
- **SystemConfig has built-in `updatedBy` column** (set since P0). The PATCH handler writes it from `req.adminId` — that's the persistent audit field. The `admin.config.update` log line captures `previousValue` for change-history reconstruction.
- **`admin.team.delete` captures `{adminId, teamId, teamName, teamSlug}`** so a future support investigation can find the right row even after slug churn.
- **No additional ledger model.** Spec wording "writes audit row" was interpreted as the existing `updatedBy` column plus structured logs. If a dedicated AuditLog model becomes necessary (e.g. for compliance), introduce it across all admin paths in one chunk.

## Key patterns

- **Pure CRUD over existing models.** SystemConfig and Team already existed since P0. P8 is shaped purely as new HTTP surface; no schema changes.
- **`req.adminId` carries the actor identity.** Set by `verifyAdmin`. Threaded into every mutating handler so audit fields land correctly.
- **Allowed-on-create config keys.** The PATCH handler is an upsert — admins can introduce a new key without a code change. Runtime safety relies on all reads in app code using `readSystemConfigNumber` (or similar) with a fallback default, which has been the convention since P0.
- **Search via ILIKE on plaintext fields.** Team name and slug are plaintext (no encryption per Phase 5 scope), so `contains` with `mode: insensitive` is the right shape. Re-deletes return 404 — same pattern as the Owner-delete path.

## Decisions

- **Upsert vs strict update on `PATCH /config/:key`**: upsert. Founders can introduce new keys at runtime without a deploy. The trade-off (typos create dead keys) is mitigated by the key regex (`^[a-z0-9_]+$`) + reviewer/PR practice.
- **Category derivation from key prefix**: simple substring split on first `_`. Avoids adding a category column. Categories naturally fall out of the existing key naming (`max_*`, `team_*`).
- **Audit logs over an AuditLog table.** Spec said "writes audit row" — the SystemConfig `updatedBy` column + structured log lines deliver the same outcome with less infrastructure. Revisit when compliance/SOC2 demands it.
- **Re-delete returns 404.** Same shape as Owner-delete + the rest of the soft-delete-first codebase. Keeps responses uniform.
- **`adminTeamService` is in `src/services/admin/`** subdirectory (new). The existing `adminService.ts` is large and handles admin auth + user/plan/stats. Splitting team + config helpers into their own subdir keeps the file boundaries clean and lets future admin chunks (audit log, system health, etc.) live next to them.
- **`updateUserPlan(userId, plan, adminId?)` — adminId is optional** for backward compat (existing callers in the legacy reset path pass no adminId). New admin handler threads it.

## Gotchas

- **`req.adminId!` non-null assertion** at the handler level is safe because `verifyAdmin` runs before every protected route and sets it. But future refactors should verify the middleware is mounted; otherwise the assertion will crash with a runtime TypeError instead of a 401.
- **Admin token via cookie OR Bearer header.** The `me` handler accepts both; other handlers expect the middleware-decoded `req.adminId`. Consistent already; nothing P8-specific.
- **`getTeamDetail` returns ALL members (active + departed).** Frontend should filter by `member.isDeleted` if it only wants the live roster.
- **`adminDeleteTeam` is a soft delete** — the team can be restored by manually flipping `isDeleted = false` in the DB (no API path does this yet). Hard delete + crypto-shred is the existing retention-job concern, unchanged.
- **The team detail's `members.user.email` is plaintext** (login identifier per Phase 5 scope). Acceptable — admins explicitly need to see emails for support. Public team endpoints (P6) hide emails by design.
- **`patchConfig` upserts — no 404 path.** A typo creates a dead key. Frontend should provide an autocomplete + key validation upstream.
- **Pagination cap** at `pageSize: 100` enforced by Zod. Higher caps would risk Prisma query timeouts on the team list with relations.
- **Lint OOM persists.** `NODE_OPTIONS=--max-old-space-size=4096` still required.

## Phase 6 backend — fully shipped 🎉

| Chunk | Status |
|---|---|
| P0 Schema | ✅ |
| P1 Team CRUD | ✅ |
| P2 Members + Invites | ✅ |
| P3 Per-team DEK | ✅ |
| P4 Context middleware | ✅ |
| P5 Team-scoped content | ✅ (5.1 → 5.8) |
| P6 Public team endpoints | ✅ |
| P7 WebSocket events | ✅ |
| **P8 Admin API** | ✅ this chunk |

Phase 6 backend is now fully complete. Frontend chunks (workspace TASKS.md P9 → P15) are the next surface to ship.

## Verification ideas (post-test)

- Hit GET /admin/config → confirm the four P0 seed keys (`max_teams_per_pro_user`, `max_teams_per_business_user`, `max_members_per_team`, `team_invite_expiry_days`) appear under the `max` and `team` categories.
- PATCH each with a new value → re-list → values updated; `updatedBy` populated.
- Backend logs show `admin.config.update`, `admin.team.delete`, `admin.user.plan.update` with the structured fields.
- GET /admin/teams with various filters (search, include_deleted, pagination) returns the expected slices.
- DELETE /admin/teams/:teamId then DELETE again → first returns 200, second returns 404.
- Non-admin token → 401 on every /admin/* endpoint.
