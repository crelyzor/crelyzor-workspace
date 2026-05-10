# PRO & Business Plan Badges + Celebration Design

## Goal
Surface a user's PRO or Business plan status through a one-time celebration moment and persistent badges across the dashboard and public card.

## Architecture
- **Trigger:** Post-Stripe redirect → frontend reads `user.plan` from auth store → checks `localStorage` flag `plan_celebrated` → shows overlay once → sets flag
- **Badge data source:** `user.plan` field (already on the User model, values: `FREE | PRO | BUSINESS`)
- **No backend changes required** — plan is already on the JWT/user object

---

## The Celebration Overlay

- Full-screen overlay, fades in on mount
- Auto-dismisses after 3 seconds (or on click)
- Shows once only — guarded by `localStorage.getItem('plan_celebrated')`
- After dismiss: sets `localStorage.setItem('plan_celebrated', 'true')`
- Confetti animation (canvas-confetti library)
- Center card: badge + message + CTA to close

**PRO message:** "You're on Pro. Everything just got smarter."
**Business message:** "Welcome to Business. Built for how serious teams work."

---

## The Badge

| Plan | Label | Color | Usage |
|------|-------|-------|-------|
| `PRO` | `PRO` | Gold `#d4af61` | Pill with gold border + text |
| `BUSINESS` | `BUSINESS` | Indigo `#6366f1` | Pill with indigo border + text |
| `FREE` | — | — | No badge shown |

### Badge locations

1. **Sidebar** — next to user's name in the bottom user section
2. **Settings page** — under avatar, above email
3. **Public card (crelyzor-public)** — subtle chip below the user's title on their card page

---

## Components

### `PlanBadge` (crelyzor-frontend)
```
src/components/PlanBadge.tsx
```
- Props: `plan: 'FREE' | 'PRO' | 'BUSINESS'`
- Returns null for FREE
- Renders a small pill with correct color

### `PlanCelebrationOverlay` (crelyzor-frontend)
```
src/components/PlanCelebrationOverlay.tsx
```
- Reads `user.plan` from auth store
- Checks `localStorage.getItem('plan_celebrated')`
- Renders full-screen overlay with confetti + badge + message
- Auto-dismisses after 3s, sets localStorage flag on dismiss

### `PlanBadge` (crelyzor-public)
```
src/components/PlanBadge.tsx
```
- Same logic, simpler — just renders the pill for the public card page

---

## Integration Points

| Location | File | Change |
|----------|------|--------|
| Sidebar user section | `crelyzor-frontend/src/layout/Sidebar.tsx` | Add `<PlanBadge plan={user.plan} />` |
| Settings page | `crelyzor-frontend/src/pages/settings/SettingsPage.tsx` | Add `<PlanBadge>` under avatar |
| App root | `crelyzor-frontend/src/App.tsx` | Mount `<PlanCelebrationOverlay />` once |
| Public card | `crelyzor-public/src/app/[username]/page.tsx` | Add `<PlanBadge>` below title |

---

## Dependencies
- `canvas-confetti` — npm package for confetti animation (lightweight, ~8kb)

---

## What's Explicitly Out of Scope
- No backend changes
- No email triggered by this
- No repeat celebrations (one-time only)
- Teams plan not included (future scope)
