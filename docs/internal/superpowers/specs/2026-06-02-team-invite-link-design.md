# Team Invite Link — Design Spec

**Date:** 2026-06-02
**Phase:** 6 (Teams)
**Scope:** Fix resend-invite badge + add reusable invite-by-link feature

---

## Overview

Two related changes:

1. **Bug fix** — `useResendInvite` doesn't invalidate `queryKeys.teams.myInvites()`, so the invitee's pending-invite badge never refreshes after an admin resends.
2. **Feature** — Team owners/admins can generate a shareable link. Any authenticated user with the link can join the team without needing an email invite.

---

## 1. Schema

Add three fields to the `Team` model in `prisma/schema.prisma`:

```prisma
inviteLinkToken     String?   @unique
inviteLinkEnabled   Boolean   @default(false)
inviteLinkExpiresAt DateTime?
```

- `inviteLinkToken` — 32-byte random hex string (same entropy as existing email invite `token`). `@unique` so Prisma can look it up directly.
- `inviteLinkEnabled` — false means the link is paused/revoked. Keeps the token on the record so the admin can re-enable without regenerating (but current UI always regenerates on enable).
- `inviteLinkExpiresAt` — optional. Initial implementation leaves this null (no expiry). UI can add expiry controls later.

Migration: non-breaking, all new nullable/defaulted fields.

---

## 2. Backend

### 2a. New endpoints

| Method | Path | Middleware | Description |
|--------|------|------------|-------------|
| `POST` | `/teams/:teamId/invite-link/generate` | `verifyJWT`, `requireTeamRole(['OWNER','ADMIN'])` | Generate or replace invite link token |
| `DELETE` | `/teams/:teamId/invite-link` | `verifyJWT`, `requireTeamRole(['OWNER','ADMIN'])` | Revoke link (disable + clear token) |
| `POST` | `/teams/join-by-link/:token` | `verifyJWT` | Join team via invite link |

**Generate (`POST .../generate`)**
- Generates `crypto.randomBytes(32).toString('hex')` token
- Sets `inviteLinkEnabled = true`, `inviteLinkToken = token`
- Returns: `{ token, linkUrl, expiresAt: null }`
- `linkUrl` = `${process.env.FRONTEND_URL}/invite/link/${token}`

**Revoke (`DELETE .../invite-link`)**
- Sets `inviteLinkEnabled = false`, `inviteLinkToken = null`
- Returns 204

**Join by link (`POST /teams/join-by-link/:token`)**
- Looks up team by `inviteLinkToken`
- Guards: token must exist, `inviteLinkEnabled = true`, `inviteLinkExpiresAt` null or in future, team not deleted
- Checks caller is not already a member → 409 if so
- Creates `TeamMembership` with `role: 'MEMBER'` (link joins always as member)
- Emits `TEAM_MEMBER_JOINED` WebSocket event to team (same as email accept flow)
- Returns: `{ membership: { teamId, role, team: { id, name, slug } } }`

### 2b. Team detail response

Include invite link state in `GET /teams/:teamId` response so the settings page can render the current link without a separate request:

```typescript
inviteLink: {
  enabled: boolean;
  token: string | null;
  linkUrl: string | null;
  expiresAt: string | null;
}
```

### 2c. Resend fix

In `teamInviteService.resendInvite` — no change needed server-side, the logic is correct.

The fix is frontend-only: `useResendInvite` in `useTeamQueries.ts` must also invalidate `queryKeys.teams.myInvites()` on success so the invitee's badge reflects the refreshed invite.

---

## 3. Frontend

### 3a. Resend fix

`src/hooks/queries/useTeamQueries.ts` — `useResendInvite.onSuccess`:

```typescript
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ['teams', 'invites', teamId] });
  queryClient.invalidateQueries({ queryKey: queryKeys.teams.myInvites() });
  toast.success('Invite resent');
},
```

### 3b. New query hooks

Add to `useTeamQueries.ts`:

```typescript
export const useGenerateInviteLink = (teamId: string) => { ... }  // useMutation
export const useRevokeInviteLink = (teamId: string) => { ... }    // useMutation
export const useJoinByLink = () => { ... }                         // useMutation
```

On generate/revoke success: invalidate `queryKeys.teams.detail(teamId)` so the settings page re-renders with updated link state.

### 3c. InvitesSection UI

`src/pages/team-settings/sections/InvitesSection.tsx` — add "Invite link" card above the email invite form.

**States:**

- **No link / revoked:** Single "Generate invite link" button
- **Link active:**
  - Read-only URL input showing the full link
  - "Copy link" button (uses `navigator.clipboard.writeText`)
  - "Regenerate" button (replaces token — existing link immediately stops working)
  - "Revoke" button (shows inline confirmation before calling DELETE)

Only OWNER and ADMIN roles see this section (same gate as the rest of InvitesSection).

### 3d. Join page

Route: `/invite/link/:token` → handled by a new `InviteLinkPage` component (or extend existing `InvitePage`).

Preferred: new lightweight page at `src/pages/InviteLinkPage.tsx` to keep `InvitePage` (email token flow) clean.

**Flow:**
1. Page mounts → calls `POST /teams/join-by-link/:token`
2. Loading state while mutation runs
3. On success → `setActiveTeam(teamId)`, broad cache invalidate, navigate to `/`
4. On 404 (token not found / disabled) → show "This invite link is invalid or has expired"
5. On 409 (already a member) → show "You're already a member" + link to go to workspace
6. If unauthenticated → redirect to `/signin?redirect=/invite/link/:token`

Register route in `App.tsx`:
```tsx
<Route path="/invite/link/:token" element={<InviteLinkPage />} />
```
Must NOT be wrapped in AuthGuard (same pattern as `/invite/:token` — the page handles its own auth redirect).

---

## 4. Error cases

| Scenario | HTTP | User-facing message |
|----------|------|---------------------|
| Token not found | 404 | "This invite link is invalid or has expired" |
| Link disabled | 404 | (same — don't reveal link exists but is paused) |
| Link expired | 410 | "This invite link has expired" |
| Already a member | 409 | "You're already a member of this team" |
| Team at member cap (future) | 402 | Handled by existing upgrade flow |

---

## 5. What this does NOT include

- Link expiry controls in the UI (fields are on schema, controls can be added in a future iteration)
- Public join (unauthenticated) — join requires a Crelyzor account
- Per-link role selection — link joins always create `MEMBER` role
- Usage analytics (how many joined via link)
