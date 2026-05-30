# Phase 6 P5.4.c — Public booking creation + scheduleService + slot engine

Closing chunk of P5.4. Public createBooking inherits `teamId` from the resolved EventType so team event types automatically produce team-scoped bookings + meetings + meeting-participants, all encrypted under the team DEK. scheduleService + slotService are intentional no-ops.

## What was built

- **`src/services/scheduling/bookingService.ts` — `ensureBookingMeetingParticipants`** signature change. New arg `bookingPrincipal: Principal`. MeetingParticipant.guestEmail encrypts under it instead of `hostUserId`. `hostUserId` still drives the ORGANIZER row's `userId` FK (kept, doc-clarified).
- **`createBooking`** — derives the booking's principal once after fetching EventType, then writes `teamId` + encrypts under the principal:
  - EventType select extended with `teamId`.
  - `bookingPrincipal = principalForBooking({userId: user.id, teamId: eventType.teamId})`.
  - Meeting insert carries `teamId: eventType.teamId`.
  - Booking insert carries `teamId: eventType.teamId`.
  - All 3 guest PII fields (guestName, guestEmail, guestNote) encrypt under `bookingPrincipal`.
  - MeetingParticipant call passes `bookingPrincipal`.
- **`Principal` type imported** from crypto for explicit ensureBookingMeetingParticipants signature.
- **scheduleService** — no change. Schedules are user-owned (each member's availability is personal under the team-scheduling design). Documented no-op so future reviewers don't ask.
- **slotService** — no change per spec. Event type resolution by `userId + slug` is unchanged; team event types still belong to a member, and `EventType @@unique([userId, slug])` ensures deterministic lookup.

## Key patterns

- **Principal derivation from the resolved row, never the request.** `bookingPrincipal` reads `teamId` from the server-resolved EventType row (looked up by public `username + slug`). The guest cannot inject `teamId`. Same row-level security pattern as cards/meetings/tasks under team scope.
- **Single principal, three writes.** Booking.teamId, Meeting.teamId, and MeetingParticipant.guestEmail all derive their encryption principal from `EventType.teamId`. This isn't just three independent writes — it's three writes that MUST agree, because later reads decrypt the participant under the meeting's principal (P5.1.a) and the booking under its own principal (P5.4.b decrypt switch). If any of the three diverged, decrypt would silently fail.
- **`hostUserId` vs `bookingPrincipal` separation** in ensureBookingMeetingParticipants. Reviewer flag fix: don't conflate the ORGANIZER FK with the encryption principal. After this chunk, `hostUserId` drives the ORGANIZER row's `userId` field; `bookingPrincipal` drives the ATTENDEE row's `guestEmail` encryption. Two separate concerns, two separate args.
- **Forward-compat reads were already in place.** P5.4.b shipped the decrypt switches (`cancelBookingAsGuest`, `getPublicBooking`, BOOKING_REMINDER worker, bookingManagementService) so by the time P5.4.c writes team-scoped bookings, every reader is already principal-aware. Zero observable change on existing personal bookings.
- **Schedules stay personal, intentionally.** ScheduleService's `userId`-only scoping is correct under the team-scheduling design: each team member owns their own availability pool, and ADMIN does not micro-manage members' calendars. The `resolveTeamContext` middleware mounted on `/scheduling` (P5.4.a) populates `req.teamContext` for all handlers, but scheduleController ignores it — which is the design.

## Decisions

- **Meeting.teamId is set from EventType.teamId** at booking-creation time. Consistent with `meetingService.createMeeting`'s direct-create path. Without this, team-booked meetings would be invisible to other team admins via meeting team-scope (P5.1.a).
- **No public team-URL routing yet** — `/schedule/:username/:slug` resolves team event types using the same path as personal ones. Team-branded URLs like `/schedule/t/:teamSlug/:memberUsername` are P6 frontend work. Reviewer confirmed this is acceptable for P5.4.c (no extra data leak — guest sees only what the host's profile already exposes).
- **Reschedule path stays principal-stable.** Old booking marked RESCHEDULED retains its original encryption (no re-encrypt). New booking encrypts under the current EventType's principal. Since `EventType.teamId` is immutable post-create AND the reschedule re-resolves the same eventType row (same `eventTypeSlug` + same `username`), the two principals are always equal.
- **`teamId: eventType.teamId` written explicitly** (could be `null`). Prisma treats explicit `null` and `undefined` identically for nullable scalar columns; explicit `null` is self-documenting and matches the rest of the codebase's convention.
- **scheduleService no-op is documented**, not coded. Future reviewers will inevitably ask why P5.4 didn't touch scheduleService — the dev note explains: each member owns their own pool by design; no cross-tenant visibility is required or desirable.
- **BOOKING_RECEIVED notification fan-out to admins is OUT of scope.** Reviewer flagged that for team event types, the "new booking" notification could fan out to all team admins (not just the host). Notification routing concern, not encryption. Tracked as a follow-up for P9 (frontend workspace switcher) or a separate notification-fanout pass.

## Gotchas

- **`MeetingParticipant.guestEmail` decrypts under the MEETING principal**, not the booking principal. They're equal at create time because both inherit from `EventType.teamId`, but conceptually the participant's principal is the meeting's. If a future endpoint moves a participant between meetings (it shouldn't), the principal contract breaks.
- **EventType `@@unique([userId, slug])` matters.** A user CANNOT have both a personal and a team event type with the same slug — the constraint is per-owner across team scope. So `createBooking`'s `findFirst({userId, slug})` always returns the unique row. If you ever change this constraint to `@@unique([userId, teamId, slug])`, createBooking's lookup needs to disambiguate.
- **Public createBooking does not receive a team context.** The teamId is read from the resolved EventType, never from the request. Don't accidentally pass `X-Team-Id` from a public client expecting it to override the EventType's team.
- **MeetingParticipant lookup-by-email via blind index still works** across the principal switch. `HMAC_BLIND_INDEX_KEY` is separate from the DEK; changing encryption principal doesn't invalidate blind indexes. Verified in P5.4.b security review.
- **Reschedule path's old-booking decrypt** uses its row's principal (the old principal, which equals the new principal for the reasons above). Don't accidentally pass the new principal to the old row's decrypt.

## P5.4 — complete

- 5.4.a — EventTypes team-scoping (helpers + scope + mutability + meetingLink guard + availabilityScheduleId cross-tenant guard)
- 5.4.b — Booking management team-scoping (pure helpers extracted to bookingPrincipal.ts + actor/host split + gate-before-status + audit logs + forward-compat decrypt switches in worker + public)
- 5.4.c — Public createBooking writes teamId + encrypts under principal

Next chunks in the broader P5 retrofit:
- P5.5 — Tags polymorphic retrofit (Tag.teamId + cross-domain tag handlers card-tag/contact-tag/task-tag/meeting-tag — meeting-tag already done in P5.1.b)
- P5.6 — SMA + AI cross-team isolation review (per-meeting Ask AI cache + AIContent cache scoping)
- P5.7 — Recall webhook quota attribution under team ctx
- P5.8 — Usage endpoint (`GET /teams/:teamId/usage`) — drives the `UserUsage.groupBy([userId, teamId])` schema restructure

## Verification ideas

- Book a team event type as a guest → check `SELECT teamId FROM "Booking"` matches team's id, same for created Meeting.
- As a DIFFERENT team admin, GET /scheduling/bookings with X-Team-Id → see the booking with decrypted guest name + email.
- MeetingParticipant decrypts cleanly on meeting detail under team ctx (P5.1.a path).
- Reschedule a team booking → old + new both readable, both under team DEK.
- Personal bookings unaffected.
