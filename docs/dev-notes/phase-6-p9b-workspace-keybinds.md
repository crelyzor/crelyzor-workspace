# Phase 6 P9.b — Workspace Keybinds + Command Palette

**Date:** 2026-06-01

## What was built

`Cmd/Ctrl+1..9` global keyboard shortcuts for instant workspace switching. `Cmd+1` = Personal, `Cmd+2`..`Cmd+9` = team slots (in list order). A "Switch Workspace" command group in the command palette shows the same shortcuts as hints.

## Files changed

- **`src/hooks/useWorkspaceKeybinds.ts`** — new hook, mounted in Layout
- **`src/layout/Layout.tsx`** — calls `useWorkspaceKeybinds()`
- **`src/components/command-palette/CommandPalette.tsx`** — added "Switch Workspace" CommandGroup

## Patterns

**Ref-stable event listener:** `teamsRef.current = teams` on every render; event handler reads `teamsRef.current` instead of closing over `teams`. This avoids re-registering the listener on every React Query refetch while keeping the data fresh.

**Read Zustand via `getState()` in event handlers:** `useTeamStore.getState().setActiveTeam()` instead of destructuring from the hook. Avoids stale closures entirely.

## Gotchas

- **`commandPaletteOpen` guard is required.** `Cmd+N` inside the palette would switch workspace while the user is trying to navigate items. Guard via `useUIStore.getState().commandPaletteOpen`.
- **`switchWorkspace` must be declared after `runCommand`** in the component. Both are `const` arrow functions — no hoisting. TDZ error at runtime if reversed.
- **`Cmd+1..9` overrides browser tab switching** (`preventDefault()` is called). Intentional, same trade-off as Linear/Figma/Slack. The shortcuts only fire outside inputs.
- The "Switch Workspace" CommandGroup is hidden when the user has no teams (prevents a single-item "Personal only" section).
