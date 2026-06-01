# Phase 6 P14.c — Public team profile page (SSR /t/:slug)

The team's public face. SSR-rendered at `crelyzor.app/t/:slug` showing logo, name, description, member roster, and "Book a call" links to bookable members. Uses the already-shipped backend endpoints — no backend work.

## What was built

- **`crelyzor-public/src/types/team.ts` (NEW)** — `PublicTeamProfile`, `PublicTeamMember`, `PublicTeamSchedulingProfile`, `PublicTeamSchedulingMember` types mirroring the backend service shapes.
- **`crelyzor-public/src/lib/api.ts`** — `getPublicTeam(slug)` + `getPublicTeamScheduling(slug)` via the existing `serverRequest` helper. Scheduling is the strict bookable subset (`schedulingEnabled && eventTypes.length > 0` — filtered server-side).
- **`crelyzor-public/src/app/t/[slug]/page.tsx` (NEW)** — SSR async server component:
  - `generateMetadata`: team-aware `title`, `description` from team.description, `robots: index:true`, alternates canonical, OG image from `team.logoUrl` when present, Twitter card.
  - **JSON-LD Organization schema** via existing `safeJsonLd` helper. Includes `name`, `url`, optional `logo`, optional `description`, and `member` array (Person entries). Escapes `< > &` so a malicious team name can't break out of the `<script>` tag.
  - **Hero**: 96px team logo wrapped in `bg-[#0a0a0a]` with `border: 1px solid rgba(212,175,97,0.4)` gold border — or gold-initials fallback on `rgba(212,175,97,0.1)`. Team name `text-3xl font-medium tracking-tight`. Optional description. Meta row "N members" + "Since [Month YYYY]" (icons `Users2` + `Calendar` at 12px, `text-[11px] uppercase tracking-widest`).
  - **Members anchor card**: `bg-white rounded-2xl shadow-[0_2px_16px_rgba(0,0,0,0.06)]` with "MEMBERS" micro-label + responsive 1/2/3-column grid. Each tile: 40px avatar + name + role pill + optional "Book a call →" Link (`/schedule/t/:slug/:username`) when the member is in the bookable Set.
  - **Footer**: "Powered by Crelyzor" Link to `/`.
  - **404**: `getPublicTeam` throws → `notFound()` falls through to existing not-found.tsx.
  - **Bookable resilience**: `getPublicTeamScheduling` wrapped in try/catch — degrades to an empty bookable set so the team page still renders if the scheduling endpoint hiccups.

## Key patterns

- **Bookable detection via Set intersection** between the two endpoints: `Set(scheduling.members.map(m => m.user.username).filter(Boolean))`. O(M) build once + O(1) lookup per member tile. Backend already filters the strict criterion; we just intersect to keep the team-roster display + bookable highlighting in sync.
- **Dual fetch with single-failure tolerance**: getPublicTeam is required (404 → notFound). getPublicTeamScheduling is optional (catch → empty set → degrade). Pattern for any "primary + enrichment" SSR page.
- **`safeJsonLd` for ALL user-supplied JSON-LD content** — the team's `name` and `description` are written by the team owner, so we MUST escape `< > &` before injecting into `<script type="application/ld+json">`. Reuses the existing helper (`crelyzor-public/src/lib/jsonLd.ts`).
- **Premium-public aesthetic per CLAUDE.md**: page bg `bg-neutral-100`, anchor surface `#ffffff`, the only dark element is the logo wrapper (matches the card-page aesthetic: dark accent on light surface). Single gold accent at `#d4af61` for the wrapper border + initials fallback only.
- **Inline `style={{...}}`** for the boxShadow + the dark wrapper + gold tints — Tailwind doesn't ship arbitrary opacities for hex colors cleanly. The inline-style escape hatch mirrors what m/[id] and the card pages already do.
- **Raw `<img>` with `referrerPolicy="no-referrer"`** instead of `next/image` — consistent with existing public pages, avoids forcing `next.config.ts` allowlist changes for every team-logo CDN.

## Decisions

- **Single SSR page, no client components** — there's no interactivity beyond Links. Keeping everything in the server component means smaller hydration cost + better SSR/SEO + zero JS for users who only view.
- **Hero logo as a floating dark tile, not a full dark hero band** — the cards-frontend spec explicitly calls for the 96px wrapper. A full dark band would require a lot more design wiring (header band, content offset, etc.) and break the "premium card" feel.
- **Sort by role rank, then join date** — already handled server-side (teamPublicService.ts:116). We just render in the order backend returns.
- **Member tile shows team-card-aware name** — falls back through `user.name → user.username → 'Member'`. The team card's `displayName` is intentionally NOT used as the primary label (teamCard.displayName can differ from the user's actual name and would be confusing on a member roster).
- **"Book a call" link uses team slug + username**, not the team card's slug. The /schedule/t/:slug/:username endpoint (P14.d) is team-scoped scheduling; team cards are a separate identity surface.
- **No retry button on the scheduling fetch failure** — silent degradation is the right choice. Surfacing "we couldn't load bookable status" is noise that the user can't act on.
- **`robots: index:true`** for the team page (unlike the invite preview which is noindex). Team pages are the SEO-targetable surface.
- **OG image only when `team.logoUrl` is present** — omitting `images` is cleaner than falling back to a generic logo, and matches what we did for the invite preview.

## Gotchas

- **Backend route is plural `/public/teams/:slug`** (verified at publicTeamRoutes.ts:18 mounted under `/public` via indexRouter.ts:68). Easy to mirror `getCard`'s singular `/public/card/` and end up with 404s.
- **`team.createdAt` IS in the public response** (verified at teamPublicService.ts:69). If backend ever changes the select, the "Since [Month YYYY]" meta will break.
- **Strict bookable rule lives server-side** — don't try to recreate the "schedulingEnabled && eventTypeCount > 0" check client-side. Trust the scheduling endpoint's filter.
- **`teamCard.slug` exists on each member's row** but is NOT what the booking link uses — the booking URL routes via team slug + username, not card slug. Confusing naming; the `teamCard` is just a public-card surface that the team auto-creates per member (e.g., "alice@acme.crelyzor.app/acme-alice").
- **`grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3`** is the breakpoint cadence — at 390px (iPhone SE) you get one column, at 640px two, at 768px+ three. Tested mentally; should be tested in a real device.
- **JSON-LD `member` array** can grow large for big teams. Currently we emit all members. For very large teams (100+) it might be worth capping at top-N — but for v1 we trust the team size limits enforced server-side.
- **Loading state for SSR**: there isn't one. The page either renders or notFound's. If the backend is slow, Next.js shows a brief blank. Consider adding a `loading.tsx` later if SSR latency becomes a complaint.

## Phase 6 P14 — sub-chunk status after this push

| Sub-chunk | Status |
|---|---|
| P14.a Public /invite/[token] preview | ✅ |
| P14.b Dashboard /invite/:token accept handler | ✅ |
| **P14.c Public /t/:slug team profile page** | ✅ this chunk |
| P14.d Public /schedule/t/:slug/:username booking page | ⏳ next |

## Verification ideas (post-test)

- Create a Pro+ team with name, description, logo URL → /t/<slug> renders the team correctly.
- Member with team event types → "Book a call →" link visible.
- Member without team event types → no "Book a call" link.
- Member without username → no "Book a call" link even if they're in the scheduling response.
- /t/this-doesnt-exist → not-found.tsx.
- View source → JSON-LD Organization schema present, escaped.
- Mobile 390px → 1-column member grid.
- Tab title "<TeamName> · Crelyzor".
- OG preview shows team logo + name + description.
- Team with no logo → gold initials fallback on the hero + member tiles.
