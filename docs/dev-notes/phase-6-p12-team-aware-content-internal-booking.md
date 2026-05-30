# Phase 6 P12 — Team-aware content (audit no-op) + Internal booking modal

The "team-aware content" half of P12 came up empty — server-side X-Team-Id scoping is authoritative and no client-side `userId` filters fight it. The real ship in this chunk is the internal booking modal: a 4-step Dialog accessible from the Meetings page header when in team scope, wired through the public scheduling endpoints already shipped on the backend.

## What was built

- **Audit findings** (no changes needed):
  - `grep userId src/pages/*` — no client-side filter predicates on content pages.
  - Identity chrome — existing `WorkspaceSwitcher` trigger already shows team logo/name/role; spec explicitly forbids a top-strip indicator.
  - Verdict: zero changes; full chunk goes to the booking modal.

- **NEW `src/services/publicSchedulingService.ts`**:
  - `getTeamMemberScheduling(slug, username)` → `GET /public/scheduling/team/:slug/:username`
  - `getSlots(username, eventTypeSlug, date)` → `GET /public/scheduling/slots/...`
  - `createBooking(payload)` → `POST /public/bookings`
  - Types: `PublicScheduledEventType`, `PublicTeamMemberSchedulingProfile`, `PublicSlot`, `CreatePublicBookingPayload`, `PublicBookingResult`.

- **NEW `src/components/teams/BookTeamMemberModal.tsx`** — 4-step Dialog:
  1. **Pick member**: `useTeamMembers(teamId)` filtered to exclude self + members without a username. Avatar + name + email + chevron. Empty state if no other teammates.
  2. **Pick event type**: fetches the member's team-scoped event types via the public profile endpoint. Renders title + duration + ONLINE/IN_PERSON icon. Empty state if no team event types.
  3. **Pick date + slot**: `<input type="date" min={today}>` + grid of slot chips in browser TZ. Empty state on zero availability. Refetches on date change.
  4. **Confirm**: summary card (with / session / when / timezone) + optional 500-char note + "Send booking" button. Submits to `POST /public/bookings` with the booker's name/email pre-filled and browser TZ.
  - Back button on every non-first step; step indicator "Step N of 4" in the dialog description.
  - State reset on close (delayed 200ms so the close anim runs first).
  - Success → toast "Booking sent — pending host approval" → invalidate `queryKeys.meetings.all` → close.

- **Meetings page wiring** (`src/pages/meetings/Meetings.tsx`):
  - Imports `useMyTeams` + `useTeamStore` to derive `activeTeam`.
  - Header gains a "Book teammate" outline button next to "Import calendar" — only when `activeTeamId !== null`.
  - Modal mounted at the bottom of the PageMotion tree when activeTeam exists.

## Key patterns

- **Wrap-existing-public-endpoints, not new internal ones.** The modal POSTs to `/public/bookings` — the same endpoint a guest hits from a public landing page. The booker is "the guest" with pre-filled identity from `useCurrentUser`. Saves a new endpoint + reuses all the backend validation + slot-conflict logic.
- **Stepwise local state** (`step: Step`, `selectedMember`, `selectedEventType`, `date`, `selectedSlot`, `note`) lives in the modal — not in a context or a sub-store. Resets on close. Back button steps backwards through the same state.
- **Browser timezone via `Intl.DateTimeFormat().resolvedOptions().timeZone`** — fallback to `'UTC'`. Used for both the slot fetch and the booking POST.
- **Date input min={today}** — prevents picking past dates without a custom date picker.
- **Today's date helper builds local Y-M-D directly** (`String(now.getMonth() + 1).padStart(2, '0')`) rather than `toISOString().slice(0, 10)` — the latter would shift to UTC and produce wrong date strings for users east of UTC.
- **`activeTeam` derivation** uses the cached `useMyTeams` list — no separate fetch. The modal then reuses that for slug/teamId.

## Decisions

- **Modal mounted in Meetings.tsx, not at the layout level**. The Meetings page is the natural primary entry; mounting it page-local keeps the workspace switcher dropdown small and the layout uncluttered.
- **"Book teammate" only on Meetings** for this chunk. Bookings page + Home FAB could surface it too, but each adds chrome surface area without much new value — the workflow starts from a "look at my schedule" intent which is most naturally the Meetings page.
- **No alternative timezone picker** — the booker's TZ is the only one used. Defer until users complain (rare since the typical case is internal-same-org bookings).
- **Server is authoritative on slot validity**. We don't re-check the slot is still open before POSTing. On 409 (slot taken between fetch + submit), we toast the server message and stay on the confirm step so the user can go back and pick another.
- **Note field is optional, 500-char max**. Matches `guestNote` validation on the backend.
- **Booking success leaves user on /meetings** — modal closes; meetings list invalidates; the new PENDING booking will appear in the host's Bookings page once the host confirms. The booker doesn't navigate anywhere new.
- **Username-less members filtered out** in step 1 because the booking URL needs a username. The membership row's `user.username` can be null.

## Gotchas

- **The booker is created as a guest** server-side, not as an internal attendee. This means the `Booking.guestEmail` is the booker's email; if the booker later signs in, there's no automatic link between their User and the Booking guest row. Acceptable today — `Booking.userId` references the host.
- **Rate limit**: `POST /public/bookings` is 10/hr per IP. Busy admins might hit this. Surfaced as a 429 toast; no client-side retry.
- **Slot picker grid is `grid-cols-3`** — works on mobile and desktop. Could become a horizontal scroll on very wide modals but the 520px max-width keeps it 3-per-row.
- **`useQuery` with manual `queryKey`** for the team-member scheduling + slots — these don't fit the existing `queryKeys` factory cleanly (slug-keyed rather than id-keyed). Inline keys are fine; if we promote them, slot them into `queryKeys.scheduling.*` namespace.
- **`Users` icon already imported** in Meetings.tsx; no new lucide import needed.
- **`activeTeam` recomputes every render** — cheap O(n) over the small teams list. No memoization needed.

## Phase 6 frontend — current state

| Chunk | Status |
|---|---|
| P9.a Workspace switcher | ✅ |
| P9.b Pending invites + Cmd+1..9 | ⏳ (waits for P13) |
| P10 Create team modal + plan gate | ✅ |
| P11 Team Settings (all sub-chunks) | ✅ |
| **P12 Team-aware content + internal booking** | ✅ this chunk |
| P13 In-app invite surfaces (WS handlers + invite UI) | ⏳ next |
| P14 Public team pages (crelyzor-public) | ⏳ |
| P15 Admin portal (crelyzor-admin) | ⏳ |

## Verification ideas (post-test)

- Personal scope on /meetings → no "Book teammate" button.
- Team scope with ≥ 2 members → button visible.
- Click → step 1 lists others (not self, not username-less).
- Pick a teammate without team event types → step 2 empty state.
- Pick an event type → step 3 with today's date + slots.
- Pick a slot → confirm step shows summary with booker TZ pre-filled.
- Submit → toast → modal closes → meetings list invalidates.
- 409 on slot taken → toast; stays on confirm.
- Empty states across all three intermediate steps render cleanly.
