# Phase 6 P13 — In-app invite surfaces (WS-driven)

Closes the live-event loop the backend has been emitting since P7. The 5 team WS events (`TEAM_INVITE_RECEIVED`, `TEAM_MEMBER_JOINED/LEFT/ROLE_CHANGED`, `TEAM_MEETING_BOOKED`) now invalidate the right query caches and surface user-visible UI. A new invitee-side endpoint (`GET /teams/me/invites`) lets users discover invites that arrived while they were offline — without it, the panel/dropdown would only show invites that arrived in this tab.

## What was built

### Backend (crelyzor-backend)
- `services/teamInviteService.ts` → `listMyPendingInvites(userId)` filters by `userId + isDeleted=false + acceptedAt/declinedAt/cancelledAt = null + expiresAt > now`. Select narrow: never exposes `token` or `email`. Returns `{ id, role, expiresAt, createdAt, team: { id, name, slug, logoUrl }, invitedBy: { id, name } }`.
- `controllers/teamInviteController.ts` → `listMine` handler. Uses `req.user!.userId` + `apiResponse`.
- `routes/teamRoutes.ts` → `router.get("/me/invites", readLimiter, teamInviteController.listMine)` **registered ABOVE the `/:teamId/*` family** to avoid Express matching `me` as a `:teamId`.

### Frontend (crelyzor-frontend)
- `lib/queryKeys.ts` → added `teams.members(teamId)`, `teams.invites(teamId)`, `teams.myInvites()`.
- `services/teamService.ts` → `MyPendingInvite` + `MyPendingInvitesResponse` types; service methods `listMyInvites`, `acceptInvite(teamId)`, `declineInvite(teamId)`.
- `hooks/queries/useTeamQueries.ts` → `useMyPendingInvites` (60s stale, enabled when authenticated), `useAcceptInvite` (`setActiveTeam(teamId)` THEN invalidate `teams.all + cards.all`), `useDeclineInvite`.
- `hooks/useNotificationSocket.ts` → 5 new WS handlers:
  - `TEAM_INVITE_RECEIVED` → invalidate `teams.myInvites()` + toast "You've been invited to [Team] · invited by [X] as [role]" (5s)
  - `TEAM_MEMBER_JOINED` → invalidate `teams.members(teamId)` + `teams.list()`
  - `TEAM_MEMBER_LEFT` → invalidate `teams.members(teamId)`
  - `TEAM_MEMBER_ROLE_CHANGED` → invalidate `teams.members(teamId)` + `teams.list()`
  - `TEAM_MEETING_BOOKED` → silent invalidation of `meetings.all`. No toast — the broadcast includes the booker, so a toast would echo on their own tab.
- `components/workspace-switcher/WorkspaceSwitcher.tsx` → new "Pending invitations" section above the Workspaces label (only when count > 0). Each row: team avatar + name + "Invited by X as role" + Accept (primary xs) + Decline (ghost xs). Indicator dot on the trigger avatar (`bg-neutral-900 dark:bg-white` with `ring-2 ring-white dark:ring-[#0a0a0a]`).
- `components/notifications/NotificationPanel.tsx` → "Pending invitations" section above Today/Earlier with the same useMyPendingInvites hook + inline accept/decline. Hidden empty state if no invites AND no notifications.

## Key patterns

- **Route ordering matters in Express.** `GET /me/invites` had to be registered before `/:teamId/*` because `me` matches any `:teamId` string. The crelyzor-reviewer flagged this; without the fix the endpoint would have 404'd via wrong handler.
- **`req.user!.userId` not `req.user!.id`** — local convention in teams controllers. Verified by grepping `teamInviteController.ts`.
- **`apiResponse` not `globalResponseHandler`** — also local convention (imported as `apiResponse` from `globalResponseHandler.ts`). Matches the rest of the teams domain.
- **Accept-mutation order**: `setActiveTeam(teamId)` happens BEFORE the broad invalidation, so the `X-Team-Id` header on the refetch carries the new scope. Otherwise the refetch would refresh under the old scope and the new team's data wouldn't appear.
- **TEAM_MEETING_BOOKED self-echo**: `broadcastToTeam` in `teamEventService.ts` fans out to ALL active members (including the booker). The booker already gets HTTP-response confirmation, so toasting on receipt would echo. Solution: silent cache invalidation only.
- **Dot indicator ring**: the trigger avatar dot uses `ring-2 ring-white dark:ring-[#0a0a0a]` so it punches cleanly through whichever background the trigger sits on.

## Decisions

- **Two separate surfaces (switcher + panel), one shared hook** — `useMyPendingInvites` is the single source of truth. Both surfaces use the same accept/decline mutations. Avoids drift.
- **No notification-row type for invites** — invites have their own lifecycle (Accept/Decline) different from notifications (Read/Delete). Keeping the `Notification` schema clean and giving invites a parallel surface is cleaner than overloading `NotificationType`.
- **Toast on TEAM_INVITE_RECEIVED but not TEAM_MEMBER_JOINED** — being invited is high-signal for the invitee; another member joining is low-signal noise for everyone else. The Members tab refreshes silently.
- **Cards.all invalidation on accept** — `acceptInviteByToken` auto-creates a team-card for the new joiner (`tryCreateMemberTeamCard`). Cards list needs to refresh to show it.
- **Listed invites are scoped to existing User accounts only** — backend `listMyPendingInvites` filters by `userId`. Email-only invites (no userId because the invitee doesn't have an account yet) aren't returned. They land via the email-flow only.
- **Decline doesn't switch active team** — declined invites disappear from the list; no scope change. Accept switches.

## Gotchas

- **Express route specificity**: any new collection-level route under a path with `:resourceId/*` must be added BEFORE the param routes, or use a path prefix that can't collide (e.g. `/-/me/invites`). We chose `/me/invites` as the convention because `me` reads naturally.
- **Stores barrel imports**: `useAuthStore` and `useTeamStore` both come from `@/stores` (the barrel). Easy to forget to add a new store hook to the barrel.
- **`useMyPendingInvites` enabled guard**: the `enabled: isAuthenticated` keeps the query call legal under React Query's rules-of-hooks while preventing a 401 burst at app load before the auth store rehydrates.
- **Accept/Decline button styling**: NotificationPanel uses the shadcn `Button size="xs"`; WorkspaceSwitcher uses raw `<button>` (inline `text-[11px] px-2 py-1` styling) because the dropdown's typographic rhythm is tighter than the panel.
- **WS payload narrowing**: the message handler downcasts to a Record then asserts to the specific shape. We don't import the backend types directly (separate workspace). If/when a shared types package lands, swap these in.
- **Accept happens via team-scoped endpoint, not token-scoped**: `acceptInvite(teamId)` calls `POST /teams/:teamId/invites/accept`. This is the existing pre-shipped accept route; the token-scoped one (`POST /invites/:token/accept`) is for email-flow only and used by P14.b.
- **In-app accept doesn't navigate away**: after accept, the cross-fade fires (from the broad invalidation + team switch). The user stays on the page they were on. Some apps redirect to /teams/:teamId — we don't, because the user typically opened the panel mid-flow and shouldn't be yanked away.

## Phase 6 frontend — current state

| Chunk | Status |
|---|---|
| P9.a Workspace switcher | ✅ |
| P9.b Pending invites in switcher + Cmd+1..9 | 🟡 invites done in P13; keybinds still ⏳ |
| P10 Create team modal + plan gate | ✅ |
| P11 Team Settings (a + b + c) | ✅ |
| P12 Team-aware content + internal booking | ✅ |
| **P13 In-app invite surfaces** | ✅ this chunk |
| P14 Public team / invite pages (crelyzor-public) | ⏳ next (P14.a started) |
| P15 Admin portal (crelyzor-admin) | ⏳ |

## Verification ideas (post-test)

- Two browsers: A invites B → B sees toast + dot + invite row in switcher + panel.
- B accepts in switcher → cross-fade + new team in list.
- B accepts in panel → same outcome; panel closes.
- B declines → invite disappears; no scope change.
- A removes B → B's `teams.members` cache invalidates silently.
- B owner changes a role on another member → both see the cache refresh.
- Cold-start: sign B out, send an invite, sign back in → invite is in both surfaces from the persisted `GET /teams/me/invites` call (not just the WS event).
- TEAM_MEETING_BOOKED arrives → meetings list refreshes; no toast on the booker's own tab.
