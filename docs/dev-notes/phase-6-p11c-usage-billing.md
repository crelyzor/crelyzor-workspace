# Phase 6 P11.c — Team Settings: Usage + Billing tabs (closes P11)

Replaces the last two stub tabs with real surfaces. Usage shows 4 summary cards against the team owner's plan limits + per-member breakdown table + client-side CSV export. Billing makes "the owner pays for everything" explicit with role-aware copy + a "Manage billing" CTA only the Owner sees.

## What was built

- **Service** (`src/services/teamService.ts`): `getTeamUsage(teamId)` → `GET /teams/:teamId/usage`. New types `TeamUsageMemberRow`, `TeamUsageLimits`, `TeamUsageResponse` (shape matches backend `teamUsageService.TeamUsageResponse` exactly).
- **Hook** (`src/hooks/queries/useTeamQueries.ts`): `useTeamUsage(teamId)` with `enabled: !!teamId` so members (who can't fetch) don't trigger a 403.
- **NEW `src/pages/team-settings/sections/UsageSection.tsx`**:
  - Member view: permission copy + no fetch.
  - Admin/Owner view: 4 summary cards (Transcription minutes / Recall hours / AI credits / Storage) — each with used vs owner-plan-limit + a progress bar when the limit is finite. "Unlimited" when `limit === -1`; "Not on this plan" when `limit === 0` (FREE plan Recall).
  - "This period · resets <date>" header with the owner's monthly reset date.
  - Per-member breakdown table sorted by `transcriptionMinutes desc` (top consumer first); columns: Member (avatar + name + role badge + email) / Transcription / Recall / AI credits / Storage.
  - **"Export CSV" link** in the header — client-side `Blob` + `<a download>` with filename `<slug>-usage-<YYYY-MM-DD>.csv`. Quote-escapes string fields.
  - Empty-state card when every breakdown row is all zeros.
  - Storage display switches between `GB / MB / KB` based on magnitude.
- **NEW `src/pages/team-settings/sections/BillingSection.tsx`**:
  - Fetches `useTeam(teamId)` for owner identity + plan.
  - Owner view: "You're paying for this team's consumption" + plan badge + "Manage billing" button → `/settings?tab=billing`.
  - Admin/Member view: "<owner name> pays for this team's consumption" + plan badge (no CTA).
  - Subhead: "Every transcription, AI credit, Recall hour, and stored byte on this team counts against the owner's plan limits."
  - FREE-plan-Owner: extra warning card explaining the edge case (team workspaces are normally Pro+).
  - Skeleton state while owner data loads.
- **Wiring** (`TeamSettings.tsx`): replaced the Usage + Billing stubs with the new sections.

## Key patterns

- **Limit semantics from the backend's `getLimitsForPlan` convention**: `-1 = Unlimited`, `0 = Not available on this plan`, `>0 = finite cap`. Reused this directly in the SummaryCard's display logic so frontend doesn't have to know the plan tiers.
- **Sort consumers by transcription minutes desc** — biggest signal of which member is using the workspace. Avoids per-resource sorting which would fragment the story.
- **Client-side CSV export** via `Blob` + invisible `<a download>`. No new endpoint needed; the table data is already in memory. CSV quote-escaping handles names with commas or quotes safely.
- **Owner-identity detection**: `role === 'OWNER' || (user.id === team.ownerId)`. The role check covers the common case via the membership; the userId check is a defensive backup for the rare case where role is `MEMBER` in the membership but the user is still owner (shouldn't happen, but the OR makes intent explicit).
- **Sections own their gating** — UsageSection refuses to fetch for members; BillingSection always renders but switches copy by role. Pattern matches the rest of P11 (each section knows which roles it serves).

## Decisions

- **Period selector deferred** — backend `GET /teams/:teamId/usage` doesn't accept a `?period=` query yet. Spec mentioned This month / Last month / Last 7 days / Custom range. Without backend support, building period buttons would lie to users about what filtering is happening. Defer until backend lands the period query.
- **CSV export, not Excel/JSON** — CSV is universal, easy to generate without a library, and matches the workflow (paste into Google Sheets / Excel). The 7-column shape is small enough to be useful at a glance.
- **No CSV export for the per-resource breakdown** — only the member-level table exports. The summary cards are aggregates already in the row totals.
- **Owner billing edge case**: shipped a tiny "You're on Free" warning card for the unlikely-but-possible case where an Owner of a team is FREE. Should never happen in steady state (backend gates createTeam on Pro+), but covers the edge during admin manual promotions / trials.
- **"Manage billing" button** routes to `/settings?tab=billing` — the existing personal billing surface. There is no team-specific billing; the link makes the connection explicit.
- **Storage row uses `Float`** from backend. Rounded display: `0.42 GB` / `428 MB` / `15 KB`. Tabular nums for column alignment.
- **Recall hours rounding to 1 decimal place** (`.toFixed(1)`) — matches the backend's typical 1-hour-per-meeting deduction granularity.
- **No team-level "upgrade" CTA** — the team is bound to the owner's plan; CTAs belong on the Owner's personal billing page.

## Gotchas

- **`useTeamUsage(canView ? teamId : null)` pattern** — passing `null` keeps the hook always-called (rules-of-hooks) without firing the request. Cleaner than guarding the hook call site.
- **Summary card "of N" subtitle changes shape based on limit**. The `formatLimit` helper centralises this: "Unlimited", "Not on this plan", "120 min", "1000", etc. Keeps the JSX clean.
- **Backend response includes `periodStart` + `resetAt` as ISO strings** (after JSON serialization) even though the type is `Date | null` in `teamUsageService.ts`. The frontend type is `string | null` to match.
- **CSV file naming**: `<slug>-usage-<YYYY-MM-DD>.csv` — `slug` for human-readable, `YYYY-MM-DD` for sortable filename.
- **`useTeam` returns `team.owner` for the BillingSection**. The `useMyTeams` membership cache wouldn't have owner info; need the detail endpoint.
- **`ownerName` fallback chain** — `team.owner?.name ?? team.owner?.email ?? 'the team owner'`. Backstop covers the never-supposed-to-happen case where owner is missing entirely.
- **Member view of Usage**: surface short copy "Only owners and admins can see team usage." Same shape as the Invites member-view in P11.b.
- **`StubSection.tsx`** is no longer imported anywhere — kept on disk as a 22-line utility in case a future tab needs it.

## Phase 6 P11 — fully complete 🎉

| Sub-chunk | Status |
|---|---|
| P11.a Settings page + General + Danger | ✅ |
| P11.b Members + Invites | ✅ |
| **P11.c Usage + Billing** | ✅ this chunk |

## Phase 6 frontend — current state

| Chunk | Status |
|---|---|
| P9.a Workspace switcher | ✅ |
| P9.b Pending invites / Cmd+1..9 | ⏳ (waits for P13) |
| P10 Create team modal + plan gate | ✅ |
| **P11 Team Settings (all sub-chunks)** | ✅ |
| P12 Team-aware content + internal booking | ⏳ next |
| P13 In-app invite surfaces | ⏳ |
| P14 Public team pages (crelyzor-public) | ⏳ |
| P15 Admin portal (crelyzor-admin) | ⏳ |

## Verification ideas (post-test)

- Usage tab as Owner: 4 summary cards reflect owner plan limits; progress bars correct; CSV download produces sortable, escaped rows.
- Usage tab as Member: permission copy; no network request.
- Owner is FREE: Recall card says "Not on this plan"; extra warning card on Billing.
- Owner is BUSINESS: all cards say "Unlimited", no progress bars.
- Empty-team usage (zero rows): empty state card.
- Billing tab as Owner: CTA visible; click navigates to personal billing.
- Billing tab as Admin/Member: read-only owner-attribution copy; no CTA.
- Workspace switch → settings → all six tabs render cleanly across mobile + desktop.
