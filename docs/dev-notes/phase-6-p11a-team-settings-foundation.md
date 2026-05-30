# Phase 6 P11.a — Team settings page foundation

`/teams/:teamId/settings` is now a real route with the full tab nav. General + Danger tabs are wired end-to-end. Members / Invites / Usage / Billing render as "Coming in P11.b" stubs so the navigation surface is complete and reviewable.

## What was built

- **Service additions** (`src/services/teamService.ts`):
  - `updateTeam(teamId, payload)` → `PATCH /teams/:teamId`
  - `deleteTeam(teamId)` → `DELETE /teams/:teamId`
  - `transferOwnership(teamId, {targetUserId, teamNameConfirm})` → `POST /teams/:teamId/transfer-ownership`
  - `leaveTeam(teamId)` → `DELETE /teams/:teamId/leave`
  - `listMembers(teamId)` → `GET /teams/:teamId/members`
  - Types: `UpdateTeamPayload`, `TransferOwnershipPayload`, `TeamMemberRow`.
- **Query hooks** (`src/hooks/queries/useTeamQueries.ts`):
  - `useUpdateTeam(teamId)` — invalidates `teams.list` + `teams.detail` on success. **No toast** — surfacing inline because of slug-error / 403 dispatch in the form.
  - `useDeleteTeam(teamId)` / `useTransferOwnership(teamId)` / `useLeaveTeam(teamId)` — toast on success/error, invalidate list (+ detail for transfer).
  - `useTeamMembers(teamId)` — read-only roster, used by the Transfer dialog.
- **NEW `src/pages/team-settings/TeamSettings.tsx`** — mirrors `/settings` page layout exactly (vertical sidebar nav md+ / horizontal pill nav mobile / `?tab=` URL state).
  - Reads `:teamId` + `?tab=`.
  - Fetches `useMyTeams()` and finds the membership for `:teamId`.
  - **Non-member bounce**: if the user isn't a member, redirects to `/` (after the loading state resolves).
- **NEW `src/pages/team-settings/sections/GeneralSection.tsx`** — name + slug + description + logo URL form.
  - Slug field disabled for non-Owners with hint "Only the team owner can change the URL."
  - Save handles 200 / 403 / 409 / other inline + toast.
- **NEW `src/pages/team-settings/sections/DangerSection.tsx`** — three role-gated rows with confirmation Dialogs:
  - Members → Leave team.
  - Owner → Transfer ownership (target select via `useTeamMembers` + team-name confirm input).
  - Owner → Delete team (team-name confirm input).
  - **Post-success**: `setActiveTeam(null)` → `navigate('/')` so the stale team scope can't 403 the next request.
- **NEW `src/pages/team-settings/sections/StubSection.tsx`** — shared "Coming in P11.b" empty-state.
- **Workspace switcher**: added "Team settings" menu item (only visible when active workspace is a team).

## Key patterns

- **Settings page mirror**: P11.a reuses the exact `/settings` layout — vertical sidebar md+ / horizontal pill mobile / `?tab=` URL state / per-section conditional render. Keeps the team area visually consistent with the rest of the app without a new design language.
- **Stub sections from day one**: the four un-shipped tabs each render a clean dashed-border empty-state card. Frontend users see the full surface (no "missing tab" feel) and the navigation can be reviewed in isolation.
- **Role discovery from `useMyTeams`**: deriving `role` from the membership cache avoids a second roundtrip. Future per-team detail (members tab) will use `useTeam(teamId)` but the cheap reads (General + Danger) just need the role + summary.
- **Hooks own the broad cache invalidation**; sections own the inline error dispatch. `useUpdateTeam` does NOT toast on success because the General form needs to differentiate slug-409 (inline) vs generic 4xx (toast). The form awaits `mutateAsync` and dispatches based on `err.status`.
- **Confirmation dialogs require typed team-name strings** for both Transfer and Delete. Cheap, prevents fat-finger destruction, matches the backend's own `teamNameConfirm` requirement on transfer.
- **Post-destructive-action scope reset**: `setActiveTeam(null)` → `navigate('/')`. Required because the next render's apiClient would otherwise send `X-Team-Id: <deleted-team-id>` and hit 403.

## Decisions

- **Stubs over partial UI**: P11.a focused on the smallest end-to-end value (rename + leave/delete). Cramming Members/Invites/Usage in too would have made the chunk untestable. The stub pattern is honest with users + reviewers.
- **Slug field disabled for non-Owners with inline hint** (not hidden). Hiding the field would be more aggressive but discoverable feedback ("Only the team owner can change the URL") is better UX.
- **Transfer Dialog fetches members on-open** via `useTeamMembers(open ? teamId : null)` so we don't load the roster until the user actually opens the Dialog. Saves a request on the common "no transfer needed" path.
- **Workspace switcher gates "Team settings" on active scope**. Personal scope hides it — there's no team to configure. Active team → shows it. Same dropdown surface, no extra navigation noise.
- **Toast for delete/leave/transfer, no toast for update**. Updates can fail in ways the form should explain (409, 403). Destructive actions are one-shot; success toast confirms the irreversible thing happened.
- **`mutateAsync` over `mutate` in the form** — needed for inline dispatch on the error. `mutate` would split the dispatch across the hook's `onError` and the component, fragmenting the source of truth.

## Gotchas

- **Slug field still validates regex even when disabled.** When the user lacks permission, the field shows the current slug; we trust the server's enforcement. The form's `slugValid` check is informational for the OWNER case only — non-OWNERs can't submit anyway because `slug !== team.slug` is the only way to trigger the change, and the field is read-only.
- **`dirty` check uses strict string comparison** for description + logo (`description !== (team.description ?? '')`). The `?? ''` coalesces null/undefined → empty string so editing-then-clearing doesn't accidentally flag dirty.
- **Members tab depends on `useTeamMembers`**, which is already wired in `useTeamQueries`. P11.b just needs the roster UI on top.
- **Transfer Dialog target select** excludes OWNER (server rejects self-transfer); when no other members exist, shows an "Invite someone first" hint instead of an empty select.
- **`active` in WorkspaceSwitcher** is derived from `useMyTeams.find()`. If the team list hasn't loaded yet, "Team settings" doesn't appear — slight delay on first paint. Acceptable.
- **Post-delete/leave/transfer**: the active scope reset MUST happen before navigation. Otherwise the next route's data fetches will fire with the now-invalid `X-Team-Id`. The Danger section does this in the correct order.

## Deferred to P11.b / .c

- **Members tab**: full roster + role change (Owner only) + remove (Admin+).
- **Invites tab**: pending list + resend + cancel + invite-by-email modal.
- **Usage tab**: per-member breakdown via `GET /teams/:teamId/usage` + summary cards + period selector.
- **Billing tab**: owner-only billing surface (links to the personal billing flow for now — team-specific billing comes with Razorpay unblock).
- **Logo upload UX**: needs a backend team-logo upload endpoint. URL field stays as-is until then.

## Verification ideas (post-test)

- Navigate from switcher → "Team settings" only appears in team scope.
- General: edit name/description/logo → save → toast; verify cached data updates everywhere (switcher trigger name, etc.).
- General slug rules: OWNER can edit + 409 inline; non-OWNER disabled with hint.
- Danger member: Leave Dialog → confirm → scope resets to Personal + home.
- Danger owner: Transfer Dialog → must type team name + pick target → success → scope reset.
- Danger owner: Delete Dialog → must type team name → success → scope reset; previously-active team disappears from switcher.
- Non-member bounce: hit `/teams/<random-uuid>/settings` directly → redirected to `/`.
- Stubs render cleanly on mobile + desktop.
