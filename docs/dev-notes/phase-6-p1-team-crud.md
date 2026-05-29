# Phase 6 P1 — Team CRUD Endpoints

Routes mounted at `/api/v1/teams/*` — `POST /`, `GET /`, `PATCH /:teamId`, `DELETE /:teamId`, `POST /:teamId/transfer-ownership`. All behind `verifyJWT`.

## What was built

- `validators/teamSchema.ts` — slug regex + lowercase transform + 23-word reserved denylist (`admin`, `api`, `teams`, `me`, `t`, etc.)
- `services/teamService.ts` — `teamPublicSelect` (never exposes `wrappedDek`/`dekVersion`/soft-delete fields), `getRole`, `createTeam`, `listMyTeams`, `updateTeam`, `deleteTeam`, `transferOwnership`
- `controllers/teamController.ts` — thin Zod-validated pass-throughs
- `routes/teamRoutes.ts` — split rate limits: POST = 10/hr/user, transfer = 5/hr/user, rest = 120/hr/user

## Key patterns

- **KMS-wrap-before-tx** — mirrors `initDekForNewUser`. KMS network I/O happens before `prisma.$transaction` opens; the raw DEK is `Buffer.fill(0)`-wiped in `finally` regardless of tx outcome. The wrapped bytes are written into both `Team.wrappedDek` and `TeamDekHistory` v1 atomically inside the tx.
- **Postgres advisory lock via `pg_advisory_xact_lock`** — closes the plan-limit TOCTOU race on concurrent POST /teams from the same user. Lock key is a stable 63-bit signed bigint derived from `sha256(userId).subarray(0, 8)` with the sign bit masked. Released automatically on tx commit/rollback.
- **`getRole()` returning `null` for non-member-or-team-missing** — every PATCH/DELETE/transfer that hits a teamId the caller doesn't belong to returns **404 Team not found**, never 403. Collapses the existence oracle.
- **`teamPublicSelect`** — single source of truth for safe Team projection. Every Team read in the service uses it. Never use `include: { team: true }` anywhere downstream — always nest `select: teamPublicSelect`.
- **Slug change is Owner-only at the service layer**, not in Zod. Zod accepts `slug?` on the update DTO; the service checks `role !== "OWNER"` and throws 403 when slug is present. Future internal callers can't bypass this by skipping the controller.
- **Transfer ownership reloads the team inside the tx** before comparing `teamNameConfirm` against the live `team.name`. Re-verifies the caller is still owner. Rejects self-target with 400. Target must be an active member with an active user.

## Decisions

- **Auto team-card creation runs post-commit, fail-open** — `cardService.createCard` does async HTML rendering inside its own `$transaction`; nesting would blow the 15s tx budget. Instead we do a minimal `prisma.card.create()` for the team's default card with `slug = "team-${input.slug}"` (the `team-` prefix avoids the `Card @@unique([userId, slug])` collision with the owner's personal card of the same name). HTML rendering is deferred until the owner first edits the card via PATCH /cards/:id. Failure logs at `warn` with `{ teamId, ownerId, slug }` — recovery is "owner creates a card manually." TODO follow-up: reconciliation worker or on-fetch idempotent re-create.
- **Plan limit fallback** — if `SystemConfig` row is missing or unparseable, fall back to hardcoded `{ PRO: 3, BUSINESS: 10 }` constants. Single source of truth is still SystemConfig; fallback exists so a missing/corrupted row doesn't lock all team creation.
- **Defer WS event emission** — `TEAM_CREATED`/`TEAM_DELETED`/`TEAM_OWNER_CHANGED` belong to Phase 6 P7. Stubbing now would add dead code paths.
- **`logoUrl` accepted as any URL in Zod** — no allowlist. Upload + signed-URL gating is the avatar/logo upload feature (separate scope).

## Gotchas

- `.env.local` (not `.env`) holds local `DATABASE_URL`. Always `set -a && source .env.local && set +a` before any `prisma` CLI call when working outside Docker.
- Running `pnpm exec tsx src/index.ts` outside Docker fails to resolve the Redis hostname (`redis://redis:6379`). DB connects fine; queue worker won't. Use `docker compose up` for a full local boot.
- `userIdToBigInt` uses `readBigInt64BE` after masking the high bit — returns a *string* (not a bigint primitive) so it can be interpolated safely into `$executeRawUnsafe`. Parametrising via `$queryRaw` with `Prisma.sql` is overkill for a deterministic hash output, but if the lock key ever sources user input, switch to parametrised form.
