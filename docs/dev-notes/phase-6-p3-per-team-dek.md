# Phase 6 P3 — Per-team DEK plumbing

Made the crypto helpers principal-aware so Phase 6 P5 can route team-scoped writes to the team DEK by passing `{ type: "team", id: row.teamId }` instead of refactoring every encrypt/decrypt call site.

## What was built

- `Principal = { type: "user" | "team"; id: string }` exported from `utils/security/crypto.ts` + `toPrincipal()` normaliser.
- `getDek(principal | string, version)` branches by `principal.type`. User branch unchanged from Phase 5. Team branch reads `Team.wrappedDek` / `TeamDekHistory` and **fails closed with `AppError 500` + `logger.error("team.dek.missing", { teamId })`** if the wrappedDek column is null (NOT NULL on schema, so this is a data-invariant violation, never a normal path).
- `encrypt(plaintext, principal | string)` + `decrypt(ciphertext, principal | string)` accept Principal-or-string. JSDoc on both nudges new code to the explicit form.
- `generateAndWrapDek(): Promise<{ rawDek, wrappedDek }>` — extracted from the old inline blocks in `initDekForNewUser` and `teamService.createTeam`. **Helper owns cleanup on KMS failure** (`rawDek.fill(0)` inside `catch`); **caller owns cleanup on success**.
- `dekCache` keys are `${type}:${id}:${version}` and eviction uses `${type}:${id}:` with a **mandatory trailing colon** to defeat the prefix-of bug (`team:abc1` must not match `team:abc123:*`).
- `teamService.createTeam` switched to `generateAndWrapDek()` + an outer `try { tx } finally { rawDek.fill(0) }` wrapping the team transaction.

## Key patterns

- **Back-compat-by-default API.** `Principal | string` everywhere a string was accepted before. `toPrincipal()` maps strings to `{ type: "user", id }`. Zero existing call sites needed updates; the full cutover to explicit Principals happens organically as P5 lands.
- **JSDoc-deprecated string form on `encrypt`/`decrypt`** — Phase 6 P5 and beyond MUST pass an explicit Principal. The string overload exists only for back-compat on the 200+ Phase 5 call sites. Silent type defaulting on a write would produce an undecryptable row, so the contract is documented at the function signature.
- **Two cache-key fixes carried in one PR**: principal-aware keys + trailing-colon eviction. The colon discipline is enforced by a unit test (`evictDek({type:"team", id:"abc1"})` must NOT touch `team:abc123:*`).
- **`generateAndWrapDek` error contract**: helper's `try { wrap } catch { zero; rethrow }` block means a KMS outage cannot leak the raw DEK back to the caller's stack. Success path returns `{ rawDek, wrappedDek }` and the caller is responsible for `rawDek.fill(0)` — matches the existing `initDekForNewUser` contract (which returns rawDek for cache seeding).
- **Two DEK lookup paths in `getDek`** are intentionally mirrored, not shared. They differ in error semantics: missing user is a "user gone" condition that already had Phase 5 handling; missing team DEK is a fail-closed `team.dek.missing` log+500.

## Decisions

- **Dropped `initDekForNewTeam` from P3.** Spec listed it but there's no caller — Team's DEK is provisioned inline by `teamService.createTeam` via `generateAndWrapDek`. The function only earns its weight when admin DEK rotation (Phase 6 P9) needs to swap an existing team's DEK in place. Adding it now would be dead exported API.
- **Dropped `teamId?` from Bull job interfaces.** Moving to P4 (Context Middleware + Quota Resolver) where the job producers actually populate the field and `getQuotaOwner` consumes it. A type-only addition in P3 with no caller is noise.
- **Cache namespace isolation argued structurally, not probabilistically.** The `type:` prefix guarantees disjoint keyspaces between users and teams even on the (negligibly small) chance of a UUID collision between the two tables. The argument is structural so future code can rely on it.
- **JSDoc warning instead of full cutover** on `encrypt`/`decrypt`. The alternative — flipping 200+ call sites to explicit `{type:"user", id: userId}` — was rejected as out of scope for P3. Net effect: existing code keeps working; new code (P5 onwards) gets pushed toward explicit Principals.

## Test coverage added

10 new vitest cases in `src/utils/security/__tests__/cryptoPrincipal.test.ts`:

1. `toPrincipal` string default
2. `toPrincipal` Principal pass-through
3. `toPrincipal` always-user for string overload (defense against silent team-string mismatch)
4. `dekCache` user/team isolation with the same id
5. `dekCache` string overload routes to user cache + does not collide with team
6. `evictDek` prefix-boundary (`team:abc1` does not evict `team:abc123:*`)
7. `evictDek` multi-version sweep
8. `generateAndWrapDek` shape (32-byte raw, non-empty wrapped)
9. `generateAndWrapDek` produces distinct rawDeks across calls
10. `generateAndWrapDek` zeroes rawDek on KMS failure (spy on `LocalKmsProvider.prototype.wrapKey`)

All 25 existing Phase 5 crypto/cryptoShred tests still pass.

## Gotchas

- The `rawDek` cleanup contract is asymmetric: helper does it on throw, caller does it on success. Document it at the helper's JSDoc — every future consumer must understand they own the success-path zeroing.
- `dekCache` keys shifted from `userId:version` to `user:userId:version`. Any code that scanned cache keys directly (none does today) would need updating. The change invalidates in-memory cache entries on deploy — fine, 60s TTL + one extra KMS roundtrip per active user.
- Tests use `vi.spyOn(crypto, "randomBytes").mockImplementationOnce(...)` with a `(_size: number) => sentinelBytes` cast through `as never` — `randomBytes` is heavily overloaded in Node typings, and the cast keeps the mock terse without weakening the test's assertion.

## Deferred / follow-up

- `initDekForNewTeam` exported helper → Phase 6 P9 (admin DEK rotation).
- `teamId?` on Bull job payloads + `getQuotaOwner` → Phase 6 P4.
- Service-layer cutover (every write that touches a `teamId` row passes a team Principal) → Phase 6 P5, split per-service.
- DB-bound integration tests for cross-principal `getDek` round-trips → P5 integration suite.
