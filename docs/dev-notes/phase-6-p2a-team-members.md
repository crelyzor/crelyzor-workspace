# Phase 6 P2.a — Team Members Management

Four endpoints layered on top of P1's `/api/v1/teams/*` surface.

## What was built

- `GET    /teams/:teamId/members` — list active members with safe `User` projection (id, name, email, username, avatarUrl)
- `PATCH  /teams/:teamId/members/:userId` — Owner-only role change; OWNER excluded from the input enum
- `DELETE /teams/:teamId/members/:userId` — Admin+; Owner protected; self-target rejected with redirect hint
- `DELETE /teams/:teamId/leave` — Owner blocked; transactional with team-existence re-verification

## Key patterns

- **Identical 404 message across all "not-found-or-not-allowed" branches** — `"Team or member not found"`. Both the controller paths and the in-tx target-missing branches return the same body so a logged-in caller cannot distinguish "team doesn't exist" from "I'm not in it" from "target user doesn't exist." Same enumeration-collapse pattern as P1.
- **Row lock on PATCH via `tx.$queryRaw\`SELECT 1 FROM "TeamMember" ... FOR UPDATE\`** — closes the lost-update race on concurrent role mutations. The Zod enum already prevents OWNER escalation; the lock prevents two parallel PATCHes ending in nondeterministic role state.
- **Belt-and-suspenders `target.role !== OWNER` check inside the tx** — even though caller-must-be-OWNER and self-block already cover the legitimate paths, this enforces "no PATCH /members path can ever change the OWNER record" as an invariant at the mutation site. Defense in depth against future refactors or DB corruption.
- **`leaveTeam` re-loads `Team WHERE id AND isDeleted=false` inside the tx** before writing — closes a TOCTOU vs a concurrent `deleteTeam` call.
- **Card cascade scope** — `removeMember` / `leaveTeam` only soft-delete `Card WHERE teamId = ... AND userId = target`. The team's default Card (`userId = team.ownerId`) is untouched on non-owner removal because the WHERE filter excludes it. After `transferOwnership` reassigns ex-owner cards to the new owner, this scope correctly only touches cards the target user personally added.

## Decisions

- **Self-remove vs leave — two distinct endpoints**, not a silent redirect. Different audit-log semantics (admin removed you vs you chose to leave) and clearer WS event distinctions when P7 lands. Self-target on DELETE /members/:userId returns 400 with the redirect hint string.
- **OWNER excluded from `updateMemberRoleSchema` enum** — promotion to OWNER must go through `POST /teams/:teamId/transfer-ownership` (the `teamNameConfirm` guard + old-owner demotion live there). Comment in the schema cites the alternative path.
- **`User.email` exposed to fellow teammates** in `memberPublicSelect`. Matches Slack/Linear/Notion workspace directory norms. `User.email` is plaintext for login; teammates seeing each other's emails is the same trust tier as appearing in the same directory together.
- **Rate-limit buckets:** `teams:member-mutate` = 30/hr/user (admin doing bulk role cleanup hits this naturally); `teams:leave` = 5/hr/user (matches `teams:transfer` precedent — rare and irreversible without re-invite).
- **Defensive JS sort on `listMembers`** — Prisma's enum-order sort follows declaration order, which happens to be OWNER→ADMIN→MEMBER, but the JS-side sort with `ROLE_RANK` decouples the response from any future schema reordering.

## Deferred to later

- `lastActive` on members — Phase 6 P7 (WS presence). `listMembers` omits the field.
- WS events (`TEAM_MEMBER_LEFT`, `TEAM_MEMBER_ROLE_CHANGED`) — Phase 6 P7.
- Re-join semantics (flip `isDeleted=false` on existing TeamMember) — comes with invite acceptance in P2.b.
