# Phase 6 P5.4.b — Booking management team-scoping

Second chunk of P5.4. Host-side booking surface (listBookings + confirm/decline/cancel) honours team context. Pure helpers extracted to a new module so the worker + public-booking paths can decrypt without dragging the host-side service graph into their startup.

## What was built

- **New module: `src/services/scheduling/bookingPrincipal.ts`** — Prisma-free pure helpers:
  - `BOOKING_NOT_FOUND_MESSAGE` constant (uniform 404 body).
  - `BookingForAccess` type (minimal shape: `{id, userId, teamId}`).
  - `bookingScope(actor, teamContext) → Prisma.BookingWhereInput` — same shape as cardScope/taskScope/eventTypeScope. Personal: `{teamId: null, userId: actor}`. Team+ADMIN/OWNER: `{teamId}`. Team+MEMBER: `{teamId, userId: actor}`.
  - `principalForBooking(booking) → Principal` — derives team-or-user principal from the row. Mirrors principalForMeeting/Card/Task.
  - `verifyBookingAccess(actorId, booking, teamContext, mode)` — pure check, uniform 404.
- **`src/services/scheduling/bookingManagementService.ts`** — full retrofit:
  - `assertBookingAccess` (uses prisma — stays out of bookingPrincipal) — slim fetch by `id + isDeleted` only, then `verifyBookingAccess` against actor + ctx. Returns the slim row including `userId + teamId` so callers can derive principalForBooking and route host-side side effects.
  - Re-exports all 4 pure helpers + the NOT_FOUND constant so downstream consumers have one import surface.
  - 4 method retrofits:
    - `listBookings` — `bookingScope` filter + per-row `principalForBooking(b)` decrypt. `BOOKING_LIST_SELECT` extended with `userId + teamId` (host-identity is now part of the row shape callers can render).
    - `confirmBooking` — **gate BEFORE status check** (enumeration-oracle fix). Full fetch after gate. Host-side side effects (host email fetch, GCal create, Recall bot job, Prepare Task creation, booking-received email, in-app BOOKING_CONFIRMED notification) all target `booking.userId` (host) — not the actor. Recall bot job carries `teamId: booking.teamId ?? undefined`. BookingReminder job carries `teamId`. Prepare Task inherits `{userId: hostId, teamId: booking.teamId}`. DB-layer TOCTOU guard via `teamId: ctx?.teamId ?? null` in update where. Audit log: `booking.confirm` with `{actorId, targetUserId, teamId, bookingId, action}`.
    - `declineBooking` — same gate-then-status pattern. Decline-email to guest uses host's email prefs + host name. Audit log: `booking.decline`.
    - `cancelBooking` — same gate-then-status pattern. GCal delete targets host's calendar (`deleteCalendarEvent(hostId, ...)`). Audit log: `booking.cancel`.
- **`src/controllers/bookingManagementController.ts`** — 4 handlers thread `getTeamContext(req)`.
- **`src/services/scheduling/bookingService.ts`** — forward-compat decrypt switch:
  - `cancelBookingAsGuest` — `decrypt(..., principalForBooking(booking))` replaces `decrypt(..., booking.userId)`. `booking.teamId` added to the select.
  - `getPublicBooking` — same switch; `userId + teamId` stripped from the response shape (internal keys).
- **`src/worker/jobProcessor.ts`** — `BOOKING_REMINDER` handler imports `principalForBooking` from the new module; decrypt switches; `booking.teamId` added to the select.

## Key patterns

- **Pure helpers in a separate module** — the security review flagged that pulling helpers from `bookingManagementService` into a worker would drag the entire host-side service graph (emails, GCal, Recall queue) into the worker startup. Extracting `bookingScope/principalForBooking/verifyBookingAccess` into `bookingPrincipal.ts` (Prisma-free, no service imports) lets the worker + public-booking paths import them safely. The Prisma-coupled `assertBookingAccess` stays inside the host-side service where it's used.
- **Gate BEFORE status check (enumeration-oracle defence).** Existing `confirmBooking`/`declineBooking`/`cancelBooking` had a `findFirst({where: {id, userId, isDeleted}})` + `if (!booking) 404` + `if (status !== "PENDING") 409` flow. Under team context, a MEMBER probing another member's `bookingId` would learn existence+status from the 409 message. The retrofit lifts the access gate to the top: slim-fetch by `id + isDeleted` only → `assertBookingAccess` (uniform 404) → full fetch → status 409. Any caller without access sees only the 404.
- **Actor ≠ host under team context.** This is the load-bearing semantic shift. Under team ctx, ADMIN/OWNER can confirm/decline/cancel a MEMBER's booking. The host (MEMBER) keeps every downstream side effect:
  - **GCal ownership**: insertCalendarEvent / deleteCalendarEvent target the host's OAuth tokens (actor's GCal tokens never reachable).
  - **Recall quota**: hostUserId carried in the Recall bot job → worker resolves quota owner via getQuotaOwner.
  - **Prepare Task ownership**: `{userId: hostId, teamId: booking.teamId}` → task lives on host's task list, under team scope.
  - **Receipt email**: "New booking from [guest]" goes to host's email.
  - **In-app notification**: BOOKING_CONFIRMED notification targets hostId.
  - **Encryption principal**: principalForBooking(booking) → team DEK if team booking, user DEK otherwise.
  - Actor is used ONLY for the access gate + audit log line.
- **Forward-compat decrypt switch.** Pre-P5.4.c, all bookings have `teamId === null`, so `principalForBooking(b)` returns `{type: "user", id: b.userId}` — byte-identical to the legacy `decrypt(b.*, b.userId)` call. Zero observable change today. Once P5.4.c writes `Booking.teamId` on team-event-type bookings, decrypt automatically routes to the team DEK with no further changes.
- **DB-layer TOCTOU guard.** Update where clauses include `teamId: ctx?.teamId ?? null` (mirrors P5.4.a's EventType pattern). The gate verifies `row.teamId === ctx.teamId` so they're equal at execution time — the where is defence-in-depth against a concurrent X-Team-Id swap.
- **Audit log naming convention.** `{actorId, targetUserId, teamId, bookingId, action}` — matches existing audit patterns (avoided inventing `hostId` per security-reviewer flag).

## Decisions

- **Helpers extracted to a new file, not co-located.** Security reviewer flagged worker coupling; cleanest fix is a Prisma-free module. The single new file is worth the indirection vs alternative options (re-exporting from worker boundary; duplicating helpers; etc.). bookingManagementService re-exports them for callers that only need one import surface.
- **Re-exports from bookingManagementService.** The host-side service re-exports the pure helpers so the controller and downstream code can keep a single import line. Both `import {bookingScope} from ".../bookingManagementService"` and `import {bookingScope} from ".../bookingPrincipal"` work — direct path is mandatory for the worker + public paths (to avoid pulling host-side deps); the re-export is convenience for host-side callers.
- **MEMBER own-only mutate.** MEMBER under team ctx can confirm/decline/cancel only their own bookings (gate returns 404 on cross-member). Asymmetric vs cards/event-types where MEMBER also can't mutate ADMIN content under team scope. Bookings follow the same pattern.
- **Gate placement strict before status checks.** Reviewers flagged that the existing 409 messages (`Cannot confirm a booking with status DECLINED`) leak state to anyone who can hit the endpoint. Fix is structural: gate → status → mutation. Three 409 branches in cancelBooking + one each in confirm/decline were all repositioned.
- **`BOOKING_LIST_SELECT` exposes `userId + teamId`.** Frontend needs these to render scope badges (e.g. "Team booking" pill) on the bookings list. Other controllers (e.g. eventType) already expose teamId — staying consistent.
- **GCal/Recall/Task all target host even when actor is ADMIN.** This is the semantic decision flagged in the plan: who owns the side effects? Host owns the calendar (their OAuth), host owns the Recall hours (their quota under team owner aggregation), host owns the task surface (their work). Actor is a privileged operator, not a side-effect target.

## Gotchas

- **`assertBookingAccess` does a slim fetch + the existing methods then do a second full fetch.** Two queries per mutation. Could be deduped into a single fetch + access check, but the access fields are minimal (id, userId, teamId) and the second fetch needs the relations (eventType, meetingId, guest PII). Optimisation opportunity if profiling flags it.
- **`tx.booking.updateMany` where clauses now include `teamId`.** A test asserting "update by id only" would see 0 rows affected if `teamId: ctx?.teamId ?? null` doesn't match. Watch out in any future test that doesn't set ctx correctly.
- **Worker imports `principalForBooking` from the scheduling module.** Worker process starts independently from API; the import path resolves correctly because the module has no Prisma-client init side effects. If a future refactor adds top-level side effects to bookingPrincipal.ts, the worker startup will pull them in.
- **`cancelBookingAsGuest` and `getPublicBooking` are public (no auth).** Their decrypt switch is forward-compat only. There's no access gate to insert here — the booking ID + signed URL (cancelBookingAsGuest) or username/slug guard (getPublicBooking) provide access control. Don't accidentally pull `assertBookingAccess` into them; they have no actor.
- **`BOOKING_LIST_SELECT` change is observable to frontend.** Existing list consumers will start seeing `userId + teamId` fields they didn't have before. Forward-compat unless a strict-mode response parser rejects unknown fields.

## Deferred to P5.4.c

- **`createBooking` writes `Booking.teamId = eventType.teamId`** — the public booking creation path resolves the host's event type, and team-scoped event types should produce team-scoped bookings. This is the single largest behaviour change in P5.4.c.
- **`createBooking` encrypts guest PII under `principalForBooking(booking)`** — currently encrypts under `user.id` (host). Once Booking.teamId is set, encryption should use the team DEK.
- **`ensureBookingMeetingParticipants`** in bookingService.ts encrypts the guest email for MeetingParticipant under hostUserId — same switch needed.
- **`scheduleService`** — schedules stay user-owned (each member's availability is personal under the team-scheduling design). The retrofit is minimal: list operations under team context should still scope to actor (no cross-member schedule visibility). Likely a one-liner or no-op.
- **Slot engine** — works unchanged per spec. Public slot URL `/public/scheduling/slots/:username/:eventTypeSlug` resolves event type by `userId + slug`. For team-scoped event types (post-P5.4.c), the resolution should match against `EventType.teamId = team.id` if the public team-booking flow uses team URLs. P6 spec defers team-URL routes to phase 6 frontend.
- **Recall webhook handler** — receives bot done callback, looks up the meeting, processes recording. Needs team-aware quota attribution. Marked as P5.7 separately but Recall write-path lives partly in createBooking → P5.4.c carries the booking-side; P5.7 carries the webhook side.

## Verification ideas (for the post-test loop)

- ADMIN confirming a MEMBER's PENDING booking: receipt email lands in MEMBER's inbox; Prepare task on MEMBER's list with `teamId`; GCal event on MEMBER's calendar.
- MEMBER attempting cross-member cancel under team ctx: 404 (NOT 409 with status leak).
- Personal-context actor attempting to cancel a team booking: 404.
- Personal bookings (existing rows) continue to decrypt guest names + emails correctly on the list.
- Recall bot job (queued on team confirm) carries `teamId` in payload — verify via Redis MONITOR.
