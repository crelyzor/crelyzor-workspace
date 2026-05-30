# Phase 6 P7 — Team WebSocket events

Five typed team-membership event envelopes ride on the existing Phase 4.9 ConnectionRegistry + Redis pub/sub fan-out. Frontends get instant nudges for invites, joins, departures, role changes, and team-meeting bookings — no polling needed.

## What was built

- **`src/websocket/types.ts`** — `WsServerMessage` discriminated union extended with 5 new variants:
  - `TEAM_INVITE_RECEIVED` → direct-message to invitee (only when invite carries `userId`)
  - `TEAM_MEMBER_JOINED` → fan-out to all active members
  - `TEAM_MEMBER_LEFT` → fan-out to remaining members (`leftBy: "self" | "removed"`)
  - `TEAM_MEMBER_ROLE_CHANGED` → fan-out to all members (typically excludes actor)
  - `TEAM_MEETING_BOOKED` → fan-out to all members when booking is team-scoped
- **`src/websocket/notificationSubscriber.ts`** — refactored:
  - Channel `notify:${userId}` now carries the FULL `WsServerMessage` envelope (notifications + team events).
  - NEW `publishToUser(userId, msg)` — canonical publish primitive for any typed message.
  - `publishNotification(userId, payload)` is back-compat — wraps with `{type: "NOTIFICATION", data}` and calls `publishToUser`.
  - Subscriber's message handler: JSON.parse → broadcast as-is (was: always wrap in NOTIFICATION).
- **NEW `src/services/teamEventService.ts`** — fan-out helper:
  - `getActiveTeamMemberIds(teamId)` — fail-open member list resolver.
  - `broadcastToTeam(teamId, msg, opts?)` — internal fan-out with optional `excludeUserId`.
  - 5 exported publishers: `publishTeamInviteReceived`, `publishTeamMemberJoined`, `publishTeamMemberLeft`, `publishTeamMemberRoleChanged`, `publishTeamMeetingBooked`.
- **Service wires** — all post-commit, fail-open via `.catch()`:
  - `teamInviteService.createInvites` → `TEAM_INVITE_RECEIVED` per invitee with a `userId`.
  - `teamInviteService.acceptInviteByToken` + `acceptInviteByTeam` → `TEAM_MEMBER_JOINED` (joiner excluded via `opts.excludeUserId`).
  - `teamMemberService.changeMemberRole` → `TEAM_MEMBER_ROLE_CHANGED` (actor excluded).
  - `teamMemberService.removeMember` → `TEAM_MEMBER_LEFT` (`leftBy: "removed"`).
  - `teamMemberService.leaveTeam` → `TEAM_MEMBER_LEFT` (`leftBy: "self"`).
  - `bookingManagementService.confirmBooking` → `TEAM_MEETING_BOOKED` only when `booking.teamId !== null`.

## Key patterns

- **Single channel, typed envelope.** Rather than adding parallel channels (`team:${userId}`, `notify:${userId}`), the existing `notify:${userId}` channel now carries the full `WsServerMessage` union. One subscriber per instance, one connection map, simpler ops. The cost is the channel name no longer describes the contents — but that's an internal detail.
- **Subscriber dispatches by raw broadcast, publisher constructs the envelope.** The subscriber lost its `wrap-in-NOTIFICATION` step; publishers (notification + team events) wrap before publishing. Cleaner separation of concerns.
- **Fan-out helper with optional `excludeUserId`.** Most team events should NOT be sent to the actor who triggered the change (they already see the result in the HTTP response). Defaulting to "exclude self" was rejected — explicit opts.excludeUserId at the call site makes the intent visible.
- **Fail-open at every hop.** Redis publish errors are caught and logged; member-list fetch errors return `[]` (no-op publish loop); per-call wrappers in `.catch()`. Never throws out of a publish path.
- **Post-commit timing.** Every publish call lives AFTER the `prisma.$transaction` returns. Readers re-fetching off the event see fresh DB state.

## Decisions

- **Reused the existing `notify:` channel** rather than introducing a separate `team:` channel. Same subscriber, same connection map. The alternative (per-domain channels) would require parallel subscriptions per user → linear scaling penalty per connection.
- **Direct-message vs fan-out per event**: invite events are direct (one invitee). All other events are fan-out (every team member needs to see them). The publisher API exposes both shapes — direct via `publishToUser`, fan-out via `broadcastToTeam` inside `teamEventService`.
- **Joiner is excluded from `TEAM_MEMBER_JOINED`.** Reasoning: their UI already drove the action. If a future use case wants "you joined" toasts on the joiner's other tabs, drop the exclude.
- **Actor excluded from `TEAM_MEMBER_ROLE_CHANGED`.** Same logic — they have the result in the HTTP response.
- **Departed user NOT in active member list.** No exclude needed for `TEAM_MEMBER_LEFT` — `getActiveTeamMemberIds` already returns only active members (the row was soft-deleted before publish).
- **`TEAM_MEETING_BOOKED` is team-only.** Personal bookings (booking.teamId === null) skip this path. Personal bookings already drive in-app `BOOKING_CONFIRMED` notifications.
- **Payload shape stays minimal.** Payloads carry enough to drive a UI nudge (badge update, toast, list reorder); frontends re-fetch the full entity when they need deep state. Avoids the message-size pressure of stuffing entire entities into Redis pub/sub.
- **No new auth.** Existing `wsAuth` is unchanged. Existing connection registry handles everything.
- **`publishNotification` kept as a back-compat wrapper.** Every existing caller (notificationService) continues to work without modification.

## Gotchas

- **Bug fix on the role-change return path.** `changeMemberRole` previously did `return prisma.$transaction(...)` directly. Adding the post-commit publish required converting that to `const result = await ... ; publish ; return result`. Caught the change in code review; would have silently dropped the WS event otherwise.
- **The `notify:` channel name is misleading now.** It carries notifications AND team events. Documented inline so future code doesn't add `team:` channels by reflex.
- **Existing notification payloads in flight at deploy time.** During a rolling deploy, instances on the new code expect the envelope-shaped messages from Redis. Old instances publish bare `WsNotificationPayload`. The new subscriber's JSON.parse will fail with a non-envelope shape because there's no `type` field — error logged, message dropped. Acceptable for the deploy window; eliminates after restart. Documented for the operator.
- **`TeamInvite.userId` may be `null`** for email-only invites. The fan-out skips them — the email itself is the notification.
- **`TEAM_INVITE_RECEIVED` payload uses `role: "ADMIN" | "MEMBER"`** because Phase 6 doesn't allow inviting OWNERs. Defensive narrowing at the publish site (`row.role === "OWNER" ? "ADMIN" : row.role`) collapses the never-happens case to ADMIN for type safety.
- **Lint OOM persists.** `NODE_OPTIONS=--max-old-space-size=4096` still required.

## Phase 6 backend — current state

| Chunk | Status |
|---|---|
| P0 → P6 | ✅ |
| P7 WebSocket events | ✅ (this chunk) |
| P8 Admin API | ⏳ next — last Phase 6 backend chunk |

After P8, Phase 6 backend is fully shipped. Phase 6 frontend (P9 → P15 in the workspace TASKS.md) follows.

## Verification ideas (post-test)

- Two browser sessions for different users with /ws open in DevTools → trigger each event type → confirm the right user(s) receive the right typed message in the right shape.
- Invitee with no userId (email-only) — confirm no WS event (email arrives instead).
- Personal booking confirm — confirm no `TEAM_MEETING_BOOKED` event.
- Multi-instance simulation: scale backend to 2 replicas, ensure events from instance A reach a user connected to instance B (Redis pub/sub handles this transparently).
- Existing NOTIFICATION events continue to flow with the same payload shape.
