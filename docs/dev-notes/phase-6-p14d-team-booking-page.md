# Phase 6 P14.d — Public team-member booking pages

Wraps Phase 6 P14. The "Book a call →" CTAs from the team profile page (P14.c) now land on a real two-page flow: an event-type picker and the booking form itself. The booking form reuses the existing personal `BookingFlow` component as-is — the backend's slot + booking endpoints resolve EventType by `(userId, slug)` and infer `teamId` from the resolved row, so the API surface is genuinely team-agnostic and no wire-payload changes were needed.

## What was built

- **`crelyzor-public/src/types/team.ts`** — `PublicTeamMemberSchedulingEventType` + `PublicTeamMemberSchedulingProfile` types. `locationType` is narrowed to `LocationType` (`'IN_PERSON' | 'ONLINE'`) imported from `@/types/scheduling` so the event type composes with `SchedulingEventType` without a cast at the BookingFlow boundary.
- **`crelyzor-public/src/lib/api.ts`** — `getPublicTeamMemberScheduling(slug, username)` SSR helper via the existing `serverRequest`. Throws on 404 (missing team/user, non-member, scheduling disabled, etc.) — caller catches to `notFound()`.
- **`crelyzor-public/src/app/schedule/t/[slug]/[username]/page.tsx` (NEW)** — event-type picker:
  - `TeamChromeStrip`: 28px team logo (raw `<img>` with `referrerPolicy="no-referrer"` per repo convention) OR gold-initials fallback (`rgba(212,175,97,0.1)` bg + `#d4af61` text) · team name `<Link>` to `/t/:slug` · `ChevronRight` divider · "Book with **[Member]**" · gold underline accent (`h-px w-12 bg-[#d4af61]/30`).
  - `MemberHero`: 64px avatar or initials fallback + name + helper copy.
  - Event type cards: title + optional description (line-clamp-2) + Clock badge with duration + Video/MapPin location badge. Each row is a `<Link>` to `/schedule/t/:slug/:username/:eventTypeSlug`.
  - Empty state when `eventTypes.length === 0`: `Calendar` icon + "Nothing bookable yet" + helper copy. Renders inside the white anchor card (NOT 404) — the member exists, just has no team event types yet.
  - Back link `← Back to [Team]` to `/t/:slug`.
  - `generateMetadata`: team+member-aware title "Book with [Member] at [Team] · Crelyzor", description, OG, alternates canonical, `robots: { index: true, follow: true }`.
- **`crelyzor-public/src/app/schedule/t/[slug]/[username]/[eventTypeSlug]/page.tsx` (NEW)** — booking flow page:
  - Same `TeamChromeStrip` at the top (with the middle "Book with [Member]" segment linked back to the picker page).
  - Reuses the existing personal `<BookingFlow>` component, importing directly from `@/app/schedule/[username]/[slug]/BookingFlow`. Props: `username`, `eventType` (matched by `eventTypeSlug`), `host` (coalesces `user.name ?? user.username` so the non-null `host.name: string` type holds), `isEmbed: false`, no `oldBooking`.
  - `generateMetadata`: event-aware title "Book [duration]-min [event title] with [Member] · [Team]", description, OG, canonical, robots index:true.
- **`crelyzor-public/src/app/schedule/[username]/[slug]/BookingFlow.tsx`** — 2 `TODO(P14.d-follow-up)` breadcrumb comments at the hardcoded post-confirm redirect (line ~566) and the personal back-link (line ~620). No behavior change in this chunk; just markers for the `redirectBase` / `backHref` prop refactor when user feedback indicates the chrome loss on the confirm step is confusing.

## Key patterns

- **Backend is team-agnostic at the API surface.** Verified via reviewer audit: `slotService.getSlots` filters by `userId + slug + isActive` (no teamId predicate), and `bookingService.createBooking` reads `teamId` from the resolved `EventType` row and writes it onto the new `Booking` + `Meeting` + `MeetingParticipant`. The wire payload stays identical to the personal booking flow. This means the same `BookingFlow` component works for both contexts without modification.
- **Slug uniqueness premise**: `prisma/schema.prisma` has `@@unique([userId, slug])` on EventType — a user genuinely cannot have personal + team event types with the same slug, so `findFirst({ userId, slug })` always resolves to the correct row.
- **Team chrome strip composition**: the same `TeamChromeStrip` shape lives in both pages but is intentionally not extracted to a shared component — each page tweaks its middle segment (picker shows static text, booking page links back to the picker). DRY here would force a prop-explosion for marginal value.
- **`locationType` narrowing at the type level**: backend service returns `locationType: string` (broad). Narrowing the frontend type to `LocationType` is correct because the backend's domain is in fact `IN_PERSON | ONLINE`, and the narrowed type composes with the personal `SchedulingEventType` so reuse compiles without casts.

## Decisions

- **Two pages, not one**: mirrors the personal `/schedule/[username]` + `/schedule/[username]/[slug]` split. Single-page approaches that fold the picker into the booking form would force conditional rendering inside `BookingFlow` (which is already a busy 700-line client component).
- **Reuse `BookingFlow` directly, no wrapper component**: the team page just mounts `<BookingFlow>` with the right props. No "TeamBookingFlowWrapper" indirection — the team chrome strip is a sibling, not a parent. Avoids re-rendering or stale-prop concerns inside the deep booking component.
- **Post-confirm redirect lands on the personal `/schedule/<username>/<slug>/confirmed` page**: known limitation, documented inline. Functionally correct (booking is on the right team in the database), just lacks team branding on the confirm step. The two `TODO(P14.d-follow-up)` comments at the hardcoded paths in `BookingFlow.tsx` mark the refactor when a follow-up adds `redirectBase` / `backHref` props.
- **Back link to `/t/:slug`, not the home page**: keeps the guest in the team scope. Personal `/schedule/[username]` doesn't have a back link of its own, but the team page benefits from one because the team chrome already implies a parent.
- **Empty state inside the white anchor card, not 404**: a member who exists but has no team event types is a meaningful state to render — "Ask them to set up scheduling" — whereas a 404 would lose context. Mirrors how the personal page handles "no active event types".
- **Robots: index:true on both pages**: team-public surfaces are SEO targets. The invite preview was noindex because it carries a bearer token in the URL; team-booking URLs are stable slugs and meant to be shareable.

## Gotchas

- **`SchedulingProfile.user.name` is typed `string` (non-null) on the personal endpoint**, but the team-member endpoint returns `string | null`. Coalesce at the page boundary (`profile.user.name ?? profile.user.username`) before passing to `BookingFlow`. Without this coalesce, TypeScript errors on the host prop.
- **`SchedulingEventType.locationType` is `LocationType`, not `string`**. Backend service in `teamPublicService.ts` types this as `string` in its interface, but the actual runtime values are always `IN_PERSON` / `ONLINE`. Narrowing the frontend type to `LocationType` is correct and necessary for composition.
- **`/schedule/t/...` URL namespace** could collide with a user named `t` — the personal `/schedule/[username]` route would intercept first under Next.js routing precedence, but `/schedule/t/...` always wins for this nested path. The convention is sensible; just don't expose a public username called exactly `t` (the backend would already reject it as too short).
- **The team chrome strip uses inline `style` for the gold underline + initials background** — Tailwind doesn't ship arbitrary opacities for arbitrary hex colors cleanly. The repo convention is to use inline styles for gold accents (matches existing card pages + the team profile page).
- **`BookingFlow` is a client component** (`'use client'` at top of file). The server-component team page imports it and renders it as a child — Next.js handles the client boundary automatically.
- **`profile.user.username` is `string` (non-null) on the team-member endpoint** — the backend explicitly 404s when `!user.username` (line 266 in teamPublicService.ts), so by the time the profile lands on the page, username is guaranteed.

## Phase 6 P14 — sub-chunk status after this push

| Sub-chunk | Status |
|---|---|
| P14.a Public /invite/[token] preview | ✅ |
| P14.b Dashboard /invite/:token accept handler | ✅ |
| P14.c Public /t/:slug team profile page | ✅ |
| **P14.d Public team-member booking pages** | ✅ this chunk — P14 wraps |

## Verification ideas (post-test)

- /t/<team-slug> → "Book a call →" on a bookable member → /schedule/t/<team-slug>/<username> shows team chrome + member hero + event type list.
- Click an event type → /schedule/t/<team-slug>/<username>/<event-slug> shows the team chrome strip above the standard booking flow.
- Submit a booking → lands on the (personal) confirmed page; verify in the dashboard the new Booking has `teamId` set and the team owner's plan absorbed usage.
- Member with no team event types → "Nothing bookable yet" empty state.
- 404 cases: bad team slug, bad username, bad event-type slug → not-found.tsx.
- View source on both pages → team-aware title, robots index:true, canonical alternates.
- Mobile 390px → chrome strip wraps cleanly, cards stack to single column.
- Team without a logo → gold-initials fallback on the chrome strip.
