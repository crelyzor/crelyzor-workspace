# Team Card Dashboard Widget

**Date:** 2026-06-03
**Phase:** 6
**Scope:** `crelyzor-frontend` only — no backend changes needed.

---

## Problem

The dashboard home page always shows the user's personal card in the right column
(`DefaultCardWidget`). When the user switches to a team workspace (`activeTeamId` is
set), the dashboard still shows their personal card — there's no team context visible
at a glance.

---

## Goal

When a user is in a team workspace, replace the personal card widget on the dashboard
with the team's digital card, using the same visual pattern and interaction model as
`DefaultCardWidget`.

---

## Behaviour

| Workspace context | Widget shown |
|---|---|
| Personal (`activeTeamId === null`) | `DefaultCardWidget` (unchanged) |
| Team (`activeTeamId` set) | `TeamCardWidget` |

The switch is driven entirely by `useTeamStore` — no URL changes, no new routes.

---

## Component: `TeamCardWidget`

**File:** `src/pages/home/TeamCardWidget.tsx`

**Props:** `{ teamId: string }`

**Data:** `useTeamCards(teamId)` — already exists. Returns `{ teamCard, memberCards }`.
`teamCard` is the card with `isTeamCard: true`. This is what the widget renders.

### States

**Loading:** identical pulse skeleton to `DefaultCardWidget`.

**Has team card:** same structure as `DefaultCardWidget`:
- Header row: `TEAM CARD` label (same micro-label style) + edit icon (→ `/teams/:teamId/settings?tab=cards`) + arrow-up-right icon (→ same)
- Body: `CardPreview` component with team card data
- 3D flip modal: same implementation as `DefaultCardWidget`

**No team card (empty):** dashed border empty state:
- Copy: "Set a team card"
- Sub-copy: "Add a shared card that represents your team"
- CTA clicks → `/teams/:teamId/settings?tab=cards`

---

## `Home.tsx` Change

Read `activeTeamId` from `useTeamStore`. In the right column, conditionally render:

```tsx
{activeTeamId ? (
  <TeamCardWidget teamId={activeTeamId} />
) : (
  <DefaultCardWidget />
)}
```

No other changes to `Home.tsx`.

---

## Files Changed

| File | Change |
|---|---|
| `src/pages/home/TeamCardWidget.tsx` | New component |
| `src/pages/home/Home.tsx` | Import `useTeamStore` + conditional render |

---

## Out of Scope

- Creating or editing team cards (handled in team settings Cards tab)
- Showing member cards on the dashboard
- Any backend changes
