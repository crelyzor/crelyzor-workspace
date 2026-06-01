# Phase 6 P15 — Admin Portal: Teams + Config Pages

**Date:** 2026-06-01

## What was built

Two new admin portal pages: `/config` (SystemConfig live editor) and `/product-teams` (Crelyzor product team management). Both consume Phase 6 P8 backend endpoints that were already built and waiting.

## Files changed

- **`src/lib/queryKeys.ts`** — added `config` and `teams` namespaces
- **`src/services/adminService.ts`** — added `SystemConfigEntry`, `AdminTeam`, `AdminTeamDetail` types + service functions
- **`src/pages/SystemConfigPage.tsx`** (new) — grouped config editor with autosave
- **`src/pages/TeamsPage.tsx`** (new) — teams table + TeamDetailPanel
- **`src/App.tsx`** — routes `/config` + `/product-teams` + nav links

## Patterns

**Per-row local state with useEffect sync:** Each `ConfigRow` manages its own `localValue` state initialized from the prop. A `useEffect([entry.value])` keeps it in sync when the query cache updates. The `lastSavedRef` tracks the last clean value for numeric revert.

**Single-trigger save:** Pressing Enter blurs the input (`e.currentTarget.blur()`). The `onBlur` handler is the sole save trigger. This avoids double-mutation (Enter → blur → double save).

**Type detection from original value:** `isNumericValue(entry.value)` is called in `ConfigRow` on the **prop** (`entry.value`), not on the mutable local state. This prevents the type from "forgetting" it was numeric after a user types something invalid.

**Cache update on mutation success:** The config mutation's `onSuccess` updates the query cache directly via `qc.setQueryData` (rebuilding `entries` and `grouped`), avoiding a full refetch. Individual `ConfigRow` components react via their `useEffect([entry.value])`.

## Route naming

The new teams page is at `/product-teams` (not `/teams`). The existing `/team` route is for admin portal member management. Two similarly named routes would be confusing. "Crelyzor Teams" in nav, `/product-teams` in URL.

## Gotchas

- **No `Checkbox` component in admin ui/**: used native `<input type="checkbox">` with Tailwind `accent-foreground` for the include-deleted toggle.
- **Debounce must use `useRef`:** The existing `UsersPage.tsx` has a bug where debounce uses a bare `let` (re-created each render, so `clearTimeout` never fires on the right timer). `TeamsPage` fixes this with `useRef<ReturnType<typeof setTimeout>>`.
- **Team delete invalidates by prefix `["admin", "teams"]`**: `qc.invalidateQueries({ queryKey: ["admin", "teams"] })` invalidates both the list and detail queries in one call.
