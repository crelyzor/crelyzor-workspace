# Phase 6 P5.4.a — EventTypes team-scoping

First chunk of P5.4. Scheduling router now resolves team context for every authenticated route; the four EventType endpoints honour team scope. Booking management + slot/createBooking + scheduleService still pending (5.4.b / 5.4.c).

## What was built

- `routes/schedulingRoutes.ts` — `resolveTeamContext` mounted after `verifyJWT`. One line. Covers all of scheduling (eventType + schedule + booking-management handlers thread it; scheduleController ignores it because per-user availability is the design).
- `services/scheduling/eventTypeService.ts` — full retrofit:
  - `eventTypeScope(actorId, teamContext) → Prisma.EventTypeWhereInput` — same shape as `cardScope` / `taskScope`. Personal: `{teamId: null, userId: actor}`. Team+ADMIN/OWNER: `{teamId}`. Team+MEMBER: `{teamId, userId: actor}`.
  - `verifyEventTypeAccess(actorId, et, teamContext, "read" | "mutate")` — pure check on a pre-fetched slim row. `_mode` arg accepted but currently identical for read/mutate (kept for future divergence).
  - `assertEventTypeAccess(actorId, eventTypeId, teamContext, action)` — slim fetch + verify + return.
  - `assertAvailabilityScheduleOwned(ownerUserId, scheduleId)` — cross-tenant guard. Throws 400 on miss (client input, not a resource lookup).
  - `assertMemberMeetingLinkAllowed(teamContext, meetingLink)` — MEMBER under team ctx CANNOT set/change meetingLink. Throws 403 with specific message (not 404 — this is a published policy, not a hidden-existence concern).
- 4 method retrofits:
  - `listEventTypes` — `eventTypeScope` filter. Closes the personal-list leak (team event types owned by actor would surface in personal mode without it).
  - `createEventType` — writes `teamId: ctx?.teamId ?? null`. MEMBER allowed under team ctx (asymmetric vs createCard — see Decisions). `assertMemberMeetingLinkAllowed` runs FIRST line (consistent with `assertCanCreateTeamCard` placement). `availabilityScheduleId` validated against actor's pool.
  - `updateEventType` — `assertEventTypeAccess(mutate)` gate. Update where clause includes `teamId: ctx?.teamId ?? null` (TOCTOU defence). `availabilityScheduleId` validated against `existing.userId` (admin editing teammate's event type respects teammate's schedule pool — mirrors Cards P5.2.a slug-pool decision). P2025 collapsed to the uniform 404.
  - `deleteEventType` — same gate. updateMany where clause also includes the `teamId` guard. Future-bookings count is owner-agnostic (scoped by eventTypeId), unchanged.
- `controllers/eventTypeController.ts` — 4 handlers thread `getTeamContext(req)`.
- `EVENT_TYPE_SELECT` extended with `teamId` so the frontend can render team-scope badges on event-type lists.

## Key patterns

- **EventType has NO encrypted columns** — no `principalForEventType` helper. The principal pattern is encryption-driven; without encrypted fields it would be dead weight. This is the divergence from cards/tasks but it's correct.
- **Uniform 404 vs published 403.** Access failures collapse to 404. The MEMBER `meetingLink` lockdown stays 403 because it's a published policy the frontend must surface (the user sees "Only team admins can set meeting links" and the API contract advertises it). Hiding it behind 404 would confuse the editor UI.
- **DB-layer TOCTOU guard via `teamId` in the where clause.** Update/delete both include `where: { id, teamId: ctx?.teamId ?? null }`. Even if the gate's slim-fetch races a concurrent team reassignment or membership revocation, the actual mutation must still match the team scope at execution time. P2025 (record-not-found) → uniform 404.
- **Schedule-pool gate scopes to the row owner on update, not the actor.** Admin editing a teammate's event type binds `availabilityScheduleId` to the teammate's pool. Same per-owner rule that cards use for slug uniqueness.
- **`assertMemberMeetingLinkAllowed` only triggers on `meetingLink !== undefined`.** A partial PATCH that omits the field passes through. Only setting or clearing it from a MEMBER's session is rejected.

## Decisions

- **MEMBER may create their own team event types under team context.** Asymmetric vs createCard (which is ADMIN+ only). Justification: team-scheduling design has each member owning their own availability and bookable surface within the team. Forcing ADMIN+ on createEventType would require admins to provision every member's calendar, which kills the product model. Inline comment in createEventType documents this so the next reviewer doesn't "fix" it back to symmetry.
- **MEMBER may NOT set/change meetingLink under team context.** Privilege-escalation surface: a member could publish an attacker-controlled URL on a public booking page that renders under the team's brand. The lockdown applies to both create and update. ADMIN/OWNER unrestricted.
- **No principal helper / no encryption.** EventType columns are all plaintext today and stay that way. No DEK indirection is needed; the access gate alone enforces team scope.
- **`_mode` arg kept on `verifyEventTypeAccess` even though read==mutate today.** Future P5.4.b (booking host visibility) might diverge them — e.g. an OWNER reading a member's event-type usage stats vs mutating. Cheaper to keep the arg than to add it later.
- **TOCTOU guard via DB-layer where clause, not advisory locks.** No `pg_advisory_xact_lock` needed because the EventType row's `teamId` is immutable post-create (no admin endpoint reassigns it). The race window is small (gate → write); the where-clause guard collapses it cleanly.
- **P2025 collapses to the uniform 404.** A TOCTOU race or stale context that lands a no-op update would otherwise leak `Record to update not found`. The catch arm rewrites to the canonical 404 body.

## Gotchas

- The update where clause now requires `teamId` to match. If the row's `teamId` flips between gate and write (which shouldn't happen — `EventType.teamId` is immutable post-create today), the update silently misses and P2025 fires. Designed behaviour. If a future endpoint adds "move event type to another team," it must coordinate with this gate.
- `EVENT_TYPE_SELECT` now includes `teamId`. Frontend services that destructure responses should add the field or ignore it gracefully. Currently no frontend consumes scheduling APIs under team context yet, so this is forward-compatible.
- `availabilityScheduleId` gate fires only when the field is explicitly set on the request body. A PATCH that omits it doesn't touch the schedule binding. A PATCH that sends `availabilityScheduleId: null` clears the binding without hitting the schedule pool — also correct.
- MEMBER-creates-own-team-event-type with `meetingLink` produces a 403 from `assertMemberMeetingLinkAllowed` BEFORE the create transaction. No partial side effects (no slug taken, no schedule cross-bind happens before the check).

## Deferred to P5.4.b

- Booking management team-scoping (`listBookings` / `confirmBooking` / `declineBooking` / `cancelBooking` in `bookingManagementService.ts`) — ADMIN/OWNER sees all team bookings, MEMBER sees own.
- `getQuotaOwner` threading through `usageService` for booking-driven attribution (currently attributes to the host).
- Auto-create "Prepare for [meeting]" Task on booking confirm — must inherit `teamId` from the EventType.
- Recall bot job payload — already carries `teamId` via P5.1.c.i for transcription, but `recallBotQueue.add` in `confirmBooking` doesn't pass it yet. To wire.
- Audit log for ADMIN-mutating-MEMBER bookings (declining / cancelling).
- Rate limit on `createEventType` (currently unthrottled).

## Deferred to P5.4.c

- Public `createBooking` slot-engine resolution against team-scoped event types (currently scoped by username only — Team event types resolve via the same path; spec says "slot engine works unchanged" so the change is at the booking-side: `Booking.teamId` inherits from `eventType.teamId`).
- `scheduleService` — schedules stay user-owned (each member's availability is personal). The retrofit is mainly: list operations under team context should still scope to actor (no cross-member schedule visibility) — likely a no-op or one-liner.
