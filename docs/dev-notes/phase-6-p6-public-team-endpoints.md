# Phase 6 P6 — Public team endpoints

Three no-auth read endpoints powering the public team-branded surface in `crelyzor-public`. Closes Phase 6 P6 fully.

## What was built

- **`GET /public/teams/:slug`** — team profile + member roster.
  - Response: `{team: {id, name, slug, description, logoUrl, createdAt}, members: PublicTeamMember[], stats: {memberCount}}`
  - Member shape: `{user: {id, name, username, avatarUrl}, role, teamCard: {slug, displayName, avatarUrl} | null}`
  - Sort: role rank (OWNER → ADMIN → MEMBER), then joinedAt ascending within each role.
  - Excludes soft-deleted users + soft-deleted members + soft-deleted teams.
  - Each member's team-scoped Card is included if exists (P1 auto-creates one on member join).

- **`GET /public/scheduling/team/:slug/profile`** — bookable member roster for the team scheduling landing page.
  - Response: `{team: {name, slug, description, logoUrl}, members: PublicTeamSchedulingMember[]}`
  - Member shape: `{user: {name, username, avatarUrl}, eventTypeCount}`
  - Filters: active member + has username + scheduling enabled + has ≥ 1 active team event type.
  - Members with no team event types are OMITTED so the guest UI doesn't render dead tiles.

- **`GET /public/scheduling/team/:slug/:username`** — specific member's team event types.
  - Response: `{team: {name, slug, logoUrl}, user: {name, username, avatarUrl, timezone}, eventTypes: [...]}`
  - Event types filtered by `{userId: member.userId, teamId: team.id, isActive, isDeleted: false}`.
  - 404 (uniform) if any of: team missing, user missing, user has no username, user is not an active member, scheduling disabled.

- **Files**: `validators/publicTeamSchema.ts`, `services/teamPublicService.ts`, `controllers/publicTeamController.ts`, `routes/publicTeamRoutes.ts` (all new), mounted under `/public` in `indexRouter.ts`.

## Key patterns

- **Public read-only services have no team context.** Slug is the public identifier; access is implicit. No `assertTeamAccess` or `getRole` calls — these are intentionally world-readable.
- **Privacy filter at the query level.** No `email`, no `settings`, no private workspace state surfaced. Only name, username, avatar, role, public card fields. Schema-level guarantee.
- **Bookable-member filter for the scheduling profile.** A member with scheduling disabled OR no team event types isn't shown. Guests see only members they can actually book. Mirrors how Cal.com hides empty team members.
- **Uniform 404 across the trio**. Single `NOT_FOUND_MESSAGE = "Team not found"`. Matches the rest of `/teams/*` (admin + member) enumeration-collapse convention.
- **Existing slot URL stays unchanged.** `/public/scheduling/slots/:username/:eventTypeSlug` resolves team event types automatically because `EventType @@unique([userId, slug])` is per-owner; a member can have at most ONE event type per slug (personal OR team). Confirmed in P5.4.c reviewer feedback.

## Decisions

- **Role surfaced on the public roster.** Spec explicitly listed it. Other platforms (Linear, Notion) include role on public team pages too — it's helpful context, not sensitive.
- **`teamCard` included on the team profile.** Each member's team-scoped business card lives on `/public/cards/:username` (existing endpoint). Including the basic card fields here lets the frontend render the roster with link previews without an extra fetch per member.
- **Members with no username are filtered out** of the scheduling profile + member sub-page. Without a username, there's no booking URL to construct. The team profile still surfaces them (with `username: null`) because the team page is informational, not actionable.
- **NO `email` anywhere.** Even though it's technically plaintext in the DB (login identifier), exposing emails on a public team page is a privacy regression. Workspace-internal `/teams/:teamId/members` (auth-required) keeps showing emails.
- **`isActive` filter on team cards in the roster join.** A team member can have multiple cards (personal + team); we only want the team-scoped one, and only if active.
- **`stats.memberCount` reflects active members only.** Soft-deleted/inactive users are subtracted. Matches what the team profile rendering shows.

## Gotchas

- **`User.username` can be `null`.** Always handle the null branch on the public surface. Member sub-page rejects on null with 404; team profile surfaces `username: null` for completeness.
- **`UserSettings` can be missing entirely for a brand-new user.** The Optional chain `m.user.settings?.schedulingEnabled` returns `undefined` → filtered out as "not bookable" on the scheduling profile. This is the intended behaviour — a user who hasn't visited Settings yet isn't bookable.
- **Multiple cards per member.** The Prisma include for `cards` uses `take: 1` plus a filter on `teamId = team.id AND isDeleted: false AND isActive: true`. If a member somehow has multiple active team-scoped cards (shouldn't happen — `Card @@unique([userId, slug])`), we surface one arbitrarily. Document for future migration.
- **No rate-limit-per-slug**. `apiLimiter` is per-IP. A guest probing slugs to enumerate teams will hit the per-IP cap before harming the system. Spec did not call for slug-pattern detection.
- **`EventType.locationType` returned as string** (Prisma's enum becomes a string in the select). Public consumers may want to know the type for icon rendering; leaving as a string keeps the frontend flexible.

## Phase 6 backend — current state

| Chunk | Status |
|---|---|
| P0 Schema | ✅ |
| P1 Team CRUD | ✅ |
| P2 Members + Invites | ✅ |
| P3 Per-team DEK | ✅ |
| P4 Context middleware | ✅ |
| P5 Team-scoped content (5.1 → 5.8) | ✅ all sub-chunks |
| **P6 Public team endpoints** | ✅ this chunk |
| P7 WebSocket events | ⏳ next |
| P8 Admin API | ⏳ |

After P6, the team-branded public surface is wired end-to-end. P7 brings real-time membership change events; P8 brings the admin overrides + SystemConfig editor.

## Verification ideas (post-test)

- Create a team, add a couple of members → `GET /public/teams/:slug` returns the full roster.
- Soft-delete the team → endpoint returns 404.
- Have one member create a team event type → they appear in `/scheduling/team/:slug/profile` with `eventTypeCount > 0`. Disable their scheduling → they disappear from the list.
- Visit `/scheduling/team/:slug/:member-username` → see only their team event types, not their personal ones.
- Try an unrelated `username` under the team slug → 404.
- Existing `/public/scheduling/slots/:username/:event-type-slug` continues to work for team event types (regression).
- No `email` field in any of the three response payloads (security check).
