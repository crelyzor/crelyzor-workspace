# Phase 6 P5.8 — UserUsage scope split + team usage endpoint

Closes Phase 6 P5 fully. UserUsage drops its 1:1 relationship with User; each user now has one personal row plus one row per team they own. Limit checks aggregate across all rows for the payer; deducts target the specific `(payerId, scopeTeamId)` row. New `GET /teams/:teamId/usage` endpoint surfaces per-member breakdown for ADMIN/OWNER.

## What was built

- **Schema (`UserUsage` model)**:
  - `userId @unique` dropped. Replaced by two partial unique indexes in raw SQL:
    - `UserUsage_user_personal_unique`: `(userId) WHERE teamId IS NULL` — at most one personal row per user.
    - `UserUsage_user_team_unique`: `(userId, teamId) WHERE teamId IS NOT NULL` — at most one row per (user, team) pair.
  - `@@index([userId, teamId])` composite for scoped lookups.
  - `User.usage` relation changed from `UserUsage?` → `UserUsage[]`.
  - Migration `20260530082833_phase6_p5_8_user_usage_scope_split` applied locally.
- **`src/services/billing/usageService.ts`** — full refactor for multi-row semantics:
  - `getOrCreateScopedUsage(userId, teamId | null)` — race-safe findFirst → create → P2002 fallback.
  - `getAggregateUsage(payerId)` — sums every row for the payer.
  - **Aggregate-for-check, scoped-for-deduct**: every `check*` aggregates across the payer's rows against their plan limit; every `deduct*` writes to a specific `(payerId, scopeTeamId)` row via `getOrCreateScopedUsage` then `increment`.
  - `getUserUsage(userId)` returns aggregate counters + the personal row's `periodStart`/`resetAt`. Shape preserved for `billingController.getBillingUsage` backward compat.
  - `resetUserUsage(userId)` switched from `update` to `updateMany` — resets every row for the user.
  - `runMonthlyReset` already `updateMany` → works without modification.
  - Exposed `getOrCreateScopedUsage` + `getAggregateUsage` on the service surface for the team usage endpoint.
- **`src/services/adminService.ts → resetUserUsage`**: switched from `upsert({where: {userId}})` (no longer a valid unique lookup) to `updateMany` + lazy personal-row create. Returns the personal row for the admin response.
- **NEW `src/services/teamUsageService.ts`** — `getTeamUsage(teamId)` returns `{team, summary, breakdown, ownerLimits, periodStart, resetAt}`. Members with no consumption yet are filled with zeros. Owner plan limits come from the team owner's plan (the actual payer).
- **NEW `src/controllers/teamUsageController.ts → getUsage`** — ADMIN+ only via inline `getRole` + ROLE_RANK check. MEMBER gets uniform 404 "Team not found" (matches the `/teams/*` enumeration-collapse convention).
- **`src/routes/teamRoutes.ts`** — `router.get("/:teamId/usage", readLimiter, teamUsageController.getUsage)` mounted under the existing `verifyJWT` + read-limiter scope.

## Key patterns

- **Partial unique indexes for dual-scope uniqueness** — same pattern Tag used in P5.5.a. Personal "Important" co-exists with team "Important"; here personal `(userId, null)` row co-exists with one row per team owned. Postgres natively, no application-layer enforcement.
- **Get-or-create with P2002 fallback** — Prisma's `upsert` requires a compound unique that the schema exposes. Partial unique indexes are invisible to Prisma's compound-key generator. The race-safe alternative: `findFirst` first; on miss, `create`; if `create` throws P2002, the row was created by a concurrent caller — refetch. Same pattern as the bridge for tag uniqueness.
- **Aggregate-for-check, scoped-for-deduct.** Limits cap total consumption; deducts attribute to a specific scope. Both must agree on the payer (via `getQuotaOwner`) but disagree on row selection. Documented in code comments at every call site to prevent future drift.
- **Backward compat by preserving response shape.** `getUserUsage` returns the same field names as before. The personal row's `resetAt` becomes the canonical "your month resets on X" for UI display, even though team rows can have their own (slightly different) reset dates.
- **Owner plan defines team limits.** The team doesn't have its own plan — consumption against the team is billed against the team owner's plan limits. Reflects the team-scheduling design (OWNER pays for everything).
- **`updateMany` for admin reset** — admin can't know about every team-scoped row, so reset must update every row matching `userId`. `updateMany` is the only API that does this without enumeration.

## Decisions

- **Multi-row per user over single-row with a `teamId` partition key.** Considered keeping UserUsage 1:1 and using a separate `TeamUsageLedger` for the breakdown, but two write paths create divergence risk. Single-table multi-row is more honest about the data model and matches Prisma idioms.
- **`getUserUsage(userId)` returns aggregate, not per-scope.** Frontend personal billing UI shows ONE consumption bar per resource. Aggregating across all the actor's rows preserves the existing rendering without team-aware UI work. P11 (frontend) adds the per-team UI separately.
- **`MEMBER → 404` on team usage endpoint, not 403.** Same enumeration-collapse pattern as the rest of `/teams/*`. ADMIN/OWNER visibility decisions stay opaque to lower roles.
- **Owner limits surfaced in response.** Frontend needs to render consumption vs limits per resource. The team owner is the actual payer; the limits come from their plan, not from a notional "team plan."
- **`periodStart` / `resetAt` from the first team row.** Could pull from every member's row but in practice they're created lazily with the same `getNextMonthStart()`. Surface the first available row's dates as canonical.
- **No P5.8 migration for pre-existing rows.** All pre-P5.8 rows have `teamId IS NULL` → strictly covered by the personal partial unique. The team rows materialise on-demand from the next consumption event. Pre-P5.8 ledger entries that should have been team-scoped (member work on team meetings) stay on the OWNER's personal row — lost attribution. Documented in DONE block as non-fixable for already-debited consumption.

## Gotchas

- **`User.usage` relation type changed from `UserUsage?` to `UserUsage[]`.** Any code that destructured `user.usage` expecting a single object (e.g. `user.usage?.transcriptionMinutesUsed`) now breaks — it's an array. No call site does this today (verified via grep) but worth a note for future code.
- **Lint OOM persists.** `NODE_OPTIONS=--max-old-space-size=4096` still required to run ESLint. P5.8 doesn't add significantly to the codebase but the ceiling is unchanged. Documented in DONE blocks; pre-existing growth issue.
- **Race on `getOrCreateScopedUsage`**: two workers calling concurrently — first wins `create`, second hits P2002 → catches → refetches the row that won. No data loss; `increment` is atomic in `update`. Confirmed race-safe.
- **`resetUserUsage` lazy create.** If a user has never consumed anything, they have no ledger rows. Admin reset for that user does `updateMany` with 0 rows affected → must then create the personal row to give the admin a row to inspect in the response. Slight asymmetry but cleanest path.
- **`getTeamUsage` returns zero-rows for members with no consumption.** Visible to ADMIN — they see "Member X: 0 minutes, 0 hours, 0 credits, 0 GB" even if Member X has never used the team's pool. Acceptable; surfaces member existence in the breakdown. If a future change wants "only show members with non-zero consumption," filter post-hoc.

## P5 retrofit — fully complete

| Chunk | Status |
|---|---|
| P5.1 Meetings | ✅ 4 sub-chunks |
| P5.2 Cards | ✅ 2 sub-chunks |
| P5.3 Tasks | ✅ + encryption fix |
| P5.4 Scheduling | ✅ 3 sub-chunks |
| P5.5 Tags | ✅ 2 sub-chunks |
| P5.6 SMA + AI | ✅ access + decrypt audit |
| P5.7 Recall webhooks | ✅ webhook teamId passthrough |
| P5.8 Usage endpoint | ✅ this chunk |

Phase 6 P5 (team-scoped content) is now fully shipped end-to-end.

## Remaining Phase 6 backend chunks

- P6 — Public team endpoints (`GET /public/teams/:slug`, public team scheduling profile, team-URL slot resolution)
- P7 — WebSocket events for team membership changes
- P8 — Admin API (SystemConfig + team admin overrides)

## Verification ideas (post-test)

- Schema spot-check on staging: `SELECT * FROM pg_indexes WHERE tablename = 'UserUsage'` shows both partial uniques + composite index, no legacy `UserUsage_userId_key`.
- Team member consumes → team row materialises. Owner's personal row unaffected.
- Aggregate check: OWNER on PRO with 599 min personal + 1 min team → 612nd combined minute returns 402.
- `GET /teams/:teamId/usage` as ADMIN: 200 with full breakdown. As MEMBER: 404.
- Admin reset zeros every row for the target user across personal + every team they own.
- Monthly cron resets all due rows in one pass.
- Billing UI for personal use: `GET /billing/usage` returns same shape as pre-P5.8 (aggregate counters + personal row's reset cycle).
