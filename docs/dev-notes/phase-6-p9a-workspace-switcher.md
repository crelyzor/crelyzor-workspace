# Phase 6 P9.a — Workspace switcher foundation

First frontend chunk of Phase 6. The dashboard can now enter team context and reach every team-scoped backend surface shipped in P5 → P6. Cross-fades on switch, sessionStorage-persisted scope per tab, `X-Team-Id` injected into every authenticated request.

## What was built

- **`src/stores/teamStore.ts`** — Zustand store with Zustand's `persist` + `sessionStorage`:
  - State: `activeTeamId: string | null` (null = personal scope).
  - Action: `setActiveTeam(teamId | null)`.
  - Persistence: sessionStorage so a refresh keeps scope but new tabs start fresh.
- **`src/services/teamService.ts`** — `listMyTeams / createTeam / getTeam` with typed `TeamRole`, `TeamMembership`, `TeamSummary`, `TeamDetail`, `CreateTeamPayload`.
- **`src/hooks/queries/useTeamQueries.ts`** — `useMyTeams / useTeam / useCreateTeam` (toast-wrapped, `queryKeys.teams.*` cache).
- **`src/lib/queryKeys.ts`** — added `teams: {all, list, detail(teamId)}` namespace.
- **`src/lib/apiClient.ts`** — `X-Team-Id` injected from `useTeamStore.getState().activeTeamId` into all three request fns (`request`, `requestForm`, `requestText`). Null = no header.
- **`src/components/workspace-switcher/WorkspaceSwitcher.tsx`** — replaces the legacy UserMenu. Sections: user header → Workspaces label → Personal row with check + team rows with role → Create team CTA → divider → Profile / Settings / Getting started / Sign out.
- **`src/layout/Layout.tsx`** — swapped `<UserMenu />` → `<WorkspaceSwitcher />`; wrapped `<main>` children in `<AnimatePresence mode="wait">` + `<motion.div key={scopeKey}>` → 220ms cross-fade on workspace switch.
- **`src/components/user-menu/` — DELETED.** No remaining references; switcher is the only entry point.

## Key patterns

- **Header injection via store read at request time.** apiClient reads `useTeamStore.getState().activeTeamId` on every call. No subscriber pattern needed — Zustand's `getState()` always returns the latest value.
- **`AnimatePresence mode="wait"` + `key={scopeKey}` for scope cross-fade.** React remounts the route subtree when `key` changes; Motion handles the fade. No per-page changes needed.
- **Broad `queryClient.invalidateQueries()` on switch.** Every cache key implicitly belongs to a scope (queries use the current header at fetch time). Refetching everything is simpler than per-domain invalidation and the network cost is acceptable on switch (an explicit user action).
- **sessionStorage over localStorage.** Per-tab workspace context matches the design spec — a user can have personal in one tab + a team in another. localStorage would force the same scope everywhere.
- **Trigger identity reflects active scope.** Personal: user's avatar + name. Team: team logo (or building icon fallback) + team name. PlanBadge still shows the user's plan because team plans don't exist as a concept — the team owner pays.

## Decisions

- **Store on `getState()`, not a subscriber hook.** Reading state directly inside apiClient avoids re-rendering apiClient on every store change. The request is per-call, so a per-call read is correct.
- **`X-Team-Id: null` → no header at all** (not `null` as a string). Backend's `resolveTeamContext` treats missing header as personal scope. Sending `X-Team-Id: null` would 400 (invalid UUID).
- **Switcher dropdown width 280px** (up from UserMenu's 220px) — room for the workspace rows + role subtitle.
- **Active workspace marked with a Check icon.** Standard pattern, also reinforces which scope is active when the dropdown opens.
- **"Create team" navigates to /teams/new** — that route doesn't exist yet (P10 builds it). For now the click is harmless; users see a 404. Acceptable for the foundation chunk.
- **Deferred to P9.b**: pending invites surface in the dropdown (depends on P13 invite UI), command palette "Switch workspace" section, Cmd+1..9 keybinds, stale-active-team recovery (server 403 → auto-reset to personal). Each is a small follow-up; the user can manually switch back today.
- **Broad invalidation over per-domain.** Tried scoping to specific keys; the surface is too wide (meetings, cards, tasks, scheduling, billing, search — every list and detail). Broad invalidation is correct.

## Gotchas

- **The 5174 cards-frontend and 5175 admin do NOT share this store.** Each app has its own apiClient. Cards-frontend is public-only (no auth), so it doesn't need X-Team-Id. Admin uses its own JWT scope. Only crelyzor-frontend has the team switcher.
- **Edits to apiClient affected three functions** (`request`, `requestForm`, `requestText`). Easy to miss one; the existing pattern of token injection had the same shape, which made the diff symmetrical.
- **`useMyTeams` is staleTime 60s.** A new team created in another tab won't show up for up to a minute. Acceptable — `useCreateTeam` invalidates the list explicitly.
- **`AnimatePresence mode="wait"` waits for the exit animation before mounting the new content.** Adds ~220ms perceived latency on switch but feels intentional. Without `mode="wait"`, both subtrees mount simultaneously and layout jumps.
- **The cross-fade fires even on the FIRST mount** (`AnimatePresence`'s initial animation). Acceptable — it's a subtle 220ms fade-in on app load, matches PageMotion's existing pattern.
- **DELETED files in Git**: the user-menu directory removal is in the working tree. Make sure the commit captures the deletion (no separate `git rm` needed — `git add -A` or explicit paths handle it; `git add src/components/user-menu` won't work since the dir is gone, but `git commit -a` or staging the parent will).

## Phase 6 frontend — current state

| Chunk | Status |
|---|---|
| **P9 Workspace switcher** | ✅ P9.a foundation (this); P9.b follow-ups deferred |
| P10 Team creation modal + plan gate | ⏳ next |
| P11 Team settings page | ⏳ |
| P12 Team-aware content + internal booking | ⏳ |
| P13 In-app invite surfaces | ⏳ |
| P14 Public team pages (`crelyzor-public`) | ⏳ |
| P15 Admin portal (`crelyzor-admin`) | ⏳ |

## Verification ideas (post-test)

- DevTools → Network → confirm `X-Team-Id` header appears on EVERY authenticated request when in team scope; absent in personal scope.
- Switch in tab A → tab B (already open) keeps its scope (sessionStorage is per-tab).
- Hard refresh in team mode → scope persists.
- Open a new tab → starts in personal.
- Logout → sessionStorage clears via authStore.logout? Actually no — sessionStorage entries persist across logout/login of the same tab. Worth a future cleanup: clear `crelyzor:team` on logout. Tracked as a follow-up.
- 404 on `/teams/new` is expected pre-P10.
