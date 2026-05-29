# Phase 6 P4 — Context middleware + quota resolver

Pure plumbing — no call-site cutover. P5 sub-tasks consume what this builds.

## What was built

- `Request.teamContext?: { teamId: string; role: TeamRole } | null` — added to the existing Express type augmentation in `authMiddleware.ts` (single place for all `Request` extensions to avoid module-merge conflicts).
- `getTeamContext(req)` typed accessor (`middleware/teamContext.ts`) — returns `TeamContext | null`, **throws** if `req.teamContext` is `undefined`. The throw surfaces "developer forgot to mount `resolveTeamContext`" as a 500 in dev/staging instead of a silent 403 in prod.
- `resolveTeamContext` middleware — reads `X-Team-Id`, validates as UUID, calls `teamService.getRole`, populates `req.teamContext`. Identical 403 body ("Not a member of this team") on missing/soft-deleted/non-member. Must run after `verifyJWT`.
- `verifyTeamRole("ADMIN" | "OWNER")` factory — guards routes that demand a minimum role. NO route-param variant — `/teams/:teamId/*` controllers keep the inline `getRole` pattern from P1/P2.
- `getQuotaOwner({ userId, teamId?, req? })` in `services/billing/quotaService.ts`:
  - `teamId` null/undefined → returns `userId`.
  - `teamId` set + team active → returns `team.ownerId`.
  - `teamId` set + team missing or soft-deleted → **throws `AppError 410`** with `logger.error`. **No silent fallback to userId** — that would mis-attribute billing to the per-user actor on a stale team reference.
  - Optional `req` parameter memoises the lookup via `req[Symbol.for("crelyzor.teamQuotaCache")]`. Cache is GC'd with the Request.
- `TranscriptionJobData`, `AIProcessingJobData`, `RecallBotJobData`, `RecallRecordingJobData`, `BookingReminderJobData` — each gained optional `teamId?: string`. Header comment in `queue.ts` documents the worker contract.

## Key patterns

- **Symbol-keyed request cache, not WeakMap.** Express keeps the `Request` alive for the full response lifecycle, so weak-ref semantics buy nothing over a per-instance property. `req[Symbol.for("crelyzor.teamQuotaCache")]` is simpler, debuggable, and GC-equivalent.
- **Identical 403 for all "team-not-accessible" branches** in `resolveTeamContext` — same enumeration-collapse pattern as P1/P2.
- **Fail-loud `getQuotaOwner`** — the billing principal is a security-equivalent contract. A silent fallback would let stale Bull jobs (team deleted between enqueue and execute) bill the per-user actor for owner-payable work. Bull handles the thrown `AppError` as a job failure → retry/dead-letter.
- **`vi.hoisted` for prisma mocks in vitest** — `vi.mock` is hoisted above all imports, so the mock factory can't close over a plain `const`. Use `const { fn } = vi.hoisted(() => ({ fn: vi.fn() }))` to lift the spy alongside the mock.
- **`TEAM_ID_REGEX` exported from `teamContext.ts`** — single UUID regex source for `resolveTeamContext` and any future code that handles a teamId from an external source. Don't rely on Zod-only validation when the same value flows through both HTTP params and headers.

## Decisions

- **No `verifyTeamMember` route-param variant.** `/teams/:teamId/*` controllers already do inline `getRole(actorId, teamId)` in P1/P2. Adding a second middleware-based pattern fragments the codebase. One source of truth.
- **`logger.error` on getQuotaOwner fallback path.** Team gone while a request still references it = data-integrity issue (stale job, race with delete, or bug). Errors should be alertable.
- **Explicit `select: { ownerId: true, isDeleted: true }`** on the Team lookup — never widen to include team metadata (could leak into billing logs).
- **Deferred to P5 (per-service):**
  - Mounting `resolveTeamContext` on any route tree.
  - Threading `teamId` through `checkTranscription/deductTranscription/checkRecall/deductRecall/checkAndDeductCredits` and their call sites.
  - The `UserUsage` `groupBy(['userId', 'teamId'])` multi-row-per-user restructure → debated and decided at P5.8 (Usage endpoint) where the breakdown surfaces.
- **Deferred (observability/hardening):**
  - Startup assertion that `verifyTeamRole`-using routes also mount `resolveTeamContext` upstream (a boot-time route-registration scan).
  - CI grep for `req.teamContext` access without `resolveTeamContext` in the route chain.
  - Both are good hygiene but belong in a separate observability pass, not P4 plumbing.

## Test coverage

7 vitest cases in `services/billing/__tests__/quotaService.test.ts`:
1. `teamId` omitted → returns `userId`, no Prisma call
2. `teamId: null` → returns `userId`, no Prisma call
3. `teamId` valid + team active → returns `team.ownerId`, Prisma called with explicit narrow select
4. `teamId` valid + team soft-deleted → throws `AppError`
5. `teamId` valid + team missing → throws `AppError`
6. Per-`Request` cache hit avoids the second Prisma call
7. Two distinct `Request` objects do NOT bleed cache (assertion: 2 Prisma calls, not 1)

Full security suite: 47/47 green across 5 test files (Phase 5 crypto, crypto-shred, log formatter, crypto-principal, quota).
