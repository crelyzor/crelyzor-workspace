# Phase 6 P11.b — Team Settings: Members + Invites tabs

Replaces the P11.a stub tabs with real surfaces. Admins can invite by email (batch), change roles (Owner-only), remove members; pending invites support Resend + Cancel inline.

## What was built

- **Service additions** (`src/services/teamService.ts`): `inviteMembers / listInvites / resendInvite / cancelInvite / changeMemberRole / removeMember`. New types: `InviteRole`, `InviteMembersPayload` (discriminated union: email-mode | user-mode), `TeamInvite`, `InviteCreateResult` (`{created, skipped}`), `ChangeRolePayload`.
- **Hooks** (`src/hooks/queries/useTeamQueries.ts`): `useTeamInvites`, `useInviteMembers`, `useResendInvite`, `useCancelInvite`, `useChangeMemberRole`, `useRemoveMember`. `useInviteMembers` toast distinguishes "N sent" / "N sent · M skipped" / "Nothing sent — M skipped".
- **NEW `src/pages/team-settings/sections/MembersSection.tsx`** — roster table; Owner gets inline `<select>` on non-Owner non-self rows; Admin+ gets a kebab → Remove confirmation Dialog; empty state with Invite CTA; sorted by role rank then joinedAt.
- **NEW `src/pages/team-settings/sections/InvitesSection.tsx`** — pending invites only; per-row Resend + Cancel icon buttons; expiry label in red when expired; member view is gated with a permission note (doesn't fetch).
- **NEW `src/pages/team-settings/sections/InviteMembersModal.tsx`** — chip-style email input (Enter/comma to add; Backspace deletes last); max 10 (server cap); role select; optional 200-char personal note; submit → toast + close + invalidates members + invites.
- **`TeamSettings.tsx`** — replaced the Members + Invites stubs with the new sections.

## Key patterns

- **Chip input without a library**: a focusable `<div>` containing chip `<span>`s + a transparent `<input>`. Enter/comma commit; Backspace pops the last chip when the input is empty; commit on blur. Lightweight and matches the design system's input look.
- **Role-aware UI scoped to the row**: each `<MemberRow>` derives `canChangeRole`, `canRemove`, `isSelf`, `isOwnerRow` once and the JSX renders only what's allowed. Hides nuance from the consumer (`MembersSection`).
- **Inline `<select>` for role change** instead of a dropdown menu. Native, accessible, two options (ADMIN/MEMBER), trivial. Owner of the team is never shown the select on their own row (Owner cannot demote self via this path; transfer-ownership is the only avenue).
- **Member-view gating in `InvitesSection`** — when role is Member, we don't even fire `useTeamInvites` (we pass `null` as the teamId). Saves a request and prevents the 403 toast from the hook's `onError` for a path the member can't see anyway.
- **`useTeamInvites(canManage ? teamId : null)`** pattern. Conditional `enabled` is the cleanest way to keep the hook always-called (rules-of-hooks) while skipping the actual request.
- **Skipped-emails surfaced in the toast**, not as inline chips. Backend may return `{email, reason: "already_invited" | "already_member" | ...}` per skipped row. For the MVP we just count them; future P11.c could render per-row reasons inside the modal.
- **`useInviteMembers` invalidates BOTH members AND invites caches**. New invitee may be auto-joined (user-mode, future) → members list refreshes. Otherwise → invites list shows the new pending row.

## Decisions

- **Email-mode only (no user-mode typeahead yet)**: backend supports `mode: 'user'` to invite an existing-user by id, but there's no user-search endpoint to power the typeahead. Email-mode covers the workflow today; user-mode lands when we have search.
- **Server is authoritative on email validation**. The chip input runs a basic `^[^\s@]+@[^\s@]+\.[^\s@]+$` regex to prevent obviously bad inputs, but the actual normalization + duplicate detection happens server-side. We just don't add the chip on a client-side fail.
- **Max 10 per batch enforced client-side too**: matches the server's hard cap. The 11th chip simply doesn't add. Counter "N/10" makes the limit visible.
- **Role badge styling reused** between Members + Invites (same `ROLE_BADGE` map). Could be promoted to a shared component if we add more places.
- **Remove confirmation is a separate Dialog per row**, not a global one. Local state per row → no cross-row state shape to manage. Same pattern as the Delete dialog in P11.a.
- **Inline `<select>` for role displays "MEMBER" as default for OWNER** in the role-select value (since the OWNER's role can't be selected — that's the transfer flow). This branch is technically unreachable because we don't render a select on OWNER rows, but the `value=` fallback prevents React's "uncontrolled" warning.
- **Native `<select>` everywhere** (Transfer dialog, role change, role on invite). shadcn Select would be prettier but adds JSX weight + dependencies for a binary choice.
- **`relativeTime`** is a local helper. Settings page might want it too in the future; for now it lives next to its only consumer.

## Gotchas

- **`useTeamInvites` cache key** is `['teams', 'invites', teamId]` — invalidated by `useInviteMembers`, `useResendInvite`, `useCancelInvite`. The Members cache key is `['teams', 'members', teamId]` — invalidated by `useInviteMembers` (for user-mode auto-join), `useChangeMemberRole`, `useRemoveMember`. The two caches don't share keys so a Members change doesn't redundantly refetch Invites.
- **`InviteMembersModal` reset is delayed by 200ms** so the close animation finishes before the input clears. Otherwise the user sees the fields wipe mid-animation.
- **Backspace-to-delete-last-chip** only fires when the input is empty. Pressing Backspace inside a partially typed draft just deletes characters. Standard behaviour but worth noting.
- **Owner's role badge** has stronger borders than Admin/Member — visually distinguishes the workspace owner without resorting to color (per CLAUDE.md's neutral-only constraint).
- **Joined column is hidden on `<sm`** — table density on mobile would be too tight otherwise. Members can still see joined date by tapping a member (future enhancement).
- **Kebab is a single icon button labeled "Remove"**, not a true menu. Once there's a second row action (e.g. "Resend onboarding email"), this should become a `DropdownMenu`. For now, simplest is right.
- **`useResendInvite` and `useCancelInvite` mutations are scoped to the teamId**, not to a specific invite — that's because the `inviteId` is the mutation argument. Invalidation hits the team's invite list, which covers the case where multiple icons race.

## Deferred to P11.c

- **Usage tab** — `GET /teams/:teamId/usage` + summary cards + per-member breakdown + period selector + CSV export.
- **Billing tab** — Owner-only message + link to personal billing.
- **Logo upload UX** — needs a backend team-logo upload endpoint.

## Phase 6 frontend — current state

| Chunk | Status |
|---|---|
| P9.a Workspace switcher | ✅ |
| P9.b Pending invites / Cmd+1..9 | ⏳ |
| P10 Create team modal + plan gate | ✅ |
| **P11.a Team settings: General + Danger** | ✅ |
| **P11.b Team settings: Members + Invites** | ✅ (this chunk) |
| P11.c Team settings: Usage + Billing + Logo upload | ⏳ next |
| P12 Team-aware content + internal booking | ⏳ |
| P13 In-app invite surfaces | ⏳ |
| P14 Public team pages (crelyzor-public) | ⏳ |
| P15 Admin portal (crelyzor-admin) | ⏳ |

## Verification ideas (post-test)

- As Owner, swap a member's role inline → toast → cache refreshes.
- As Admin, remove a member → confirm Dialog → row vanishes; Owner row's kebab is hidden.
- Invite modal: chip behavior (Enter/comma/Backspace) + 10-cap + invalid email rejected.
- Invite success: members + invites caches both refresh.
- Invites tab: resend bumps expiry (refetch shows new date); cancel removes the row.
- Member-view of Invites tab: empty, with permission copy; no network request fired.
