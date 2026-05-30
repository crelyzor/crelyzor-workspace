# Phase 6 P14.a — Public email invite preview page (crelyzor-public)

SSR preview surface at `crelyzor.app/invite/[token]` so anyone clicking the email "Accept invitation" link lands on a clean, branded page that tells them what team invited them, who, and as what role. The actual accept-action requires JWT and lives in the dashboard — P14.b will route the CTA there.

## What was built

- `crelyzor-public/src/types/invite.ts` (NEW) — `PublicInvitePreview` mirrors `GET /api/v1/invites/:token`.
- `crelyzor-public/src/lib/api.ts` → `getInvitePreview(token)`:
  - 404 → `null`
  - 410 → throws `ApiError(410)` so the page can render the expired-card state instead of `notFound()`
  - other non-ok → propagated via `throwApiError`
- `crelyzor-public/src/app/invite/[token]/page.tsx` (NEW) — SSR async server component:
  - `generateMetadata` — team-aware title `"You're invited to [Team] · Crelyzor"`, description from inviter + team, `robots: { index: false, follow: false }`, OG image populated from `team.logoUrl` when available, alternates canonical.
  - Catches `ApiError(410)` → renders `<ExpiredCard />`; `notFound()` on null.
  - Card layout — premium-public aesthetic: `bg-neutral-100` page, centered `max-w-md` white card `rounded-2xl shadow-[0_2px_16px_rgba(0,0,0,0.06)] px-8 py-10`.
  - Team avatar: 72px `rounded-xl` logo OR initials block on `rgba(212,175,97,0.1)` bg with `#d4af61` text (single gold-accent touch per CLAUDE.md).
  - Heading "You've been invited to **[Team]**" + `text-[10px] uppercase tracking-widest text-neutral-500` micro-label "Invited by [inviter] as [role]".
  - Divider + dark CTA `h-11 rounded-xl bg-neutral-900 text-white w-full` linking to `${NEXT_PUBLIC_APP_URL}/invite/${token}` with `referrerPolicy="no-referrer"` (token-leak hardening via Referer header).
  - "Expires in N days" sub-line (or "in less than a day" / "soon").
  - Expired variant: `Clock` icon in neutral-100 disc + "This invitation has expired" + "Ask the team owner to send a new invitation." No CTA.
  - Footer link "Powered by Crelyzor" → `/`.

## Key patterns

- **Sentinel-free error handling for SSR**: instead of returning a `{ expired: true }` union, we throw `ApiError(410)` and catch it in the page. Matches the existing pattern in `m/[id]` and `bookings/[id]/cancel`. The reviewer flagged the sentinel-union approach as awkward narrowing.
- **`referrerPolicy="no-referrer"` on the CTA `<a>`** — the URL contains the bearer-equivalent token, and the browser's default Referer policy would include the full URL in the next-page navigation to the dashboard. The `no-referrer` setting drops the header entirely. Page-level meta would be belt-and-suspenders.
- **Mount-path verified before coding**: backend mounts `publicInviteRouter` at `/invites` (not `/public/invites`) per `routes/indexRouter.ts:113`. Bypassing this would have produced a confident 404. Always re-check the prefix.
- **Premium-public aesthetic per CLAUDE.md**: page-bg `bg-neutral-100`, card-bg `#ffffff`, gold accent `#d4af61` ONLY for the initials fallback, neutral grays elsewhere. No dark-mode handling — this repo is light-themed by design.

## Decisions

- **No accept/decline on the public page** — both require JWT, and crelyzor-public is auth-free by mandate. The CTA links to the dashboard (`NEXT_PUBLIC_APP_URL`) where the actual accept happens. Splits the work cleanly: P14.a (this) = preview; P14.b (next) = dashboard handler that POSTs accept after sign-in.
- **OG image uses team.logoUrl directly** — no dynamic ImageResponse with `#0a0a0a` background. That's a bigger lift and can ship as a polish task later. Plain logo URL is acceptable.
- **`robots: { index: false, follow: false }`** — invitation tokens are bearer credentials. We never want search engines indexing them.
- **Footer link goes to home** — keeps the page navigable without redirecting them away from the action.
- **"Expires soon" copy not used yet** — formatExpiry returns 'in less than a day' for <1 day. Tighter messaging (e.g. red text when <24h) is overkill for v1; readers click promptly or don't.

## Gotchas

- **`ApiError` is exported from `lib/api.ts`** — when catching in the page, import `ApiError` along with `getInvitePreview`. Easy to miss because most pages don't re-import the error class.
- **`{ params }: Promise<...>` is the App Router pattern in 15+** — both `params` and `searchParams` are async. Forgetting to `await params` produces hard-to-diagnose runtime errors that only surface on the live page.
- **No `referrerPolicy` JSX prop name confusion** — it's lowercase `referrerPolicy` in JSX even though the HTML attribute is `referrerpolicy`. React camelCases it like other reflected attrs.
- **Class duplication**: the CTA originally had `block ... flex` — the second wins but it's ugly. Removed the redundant `block`.
- **`generateMetadata` errors out silently** — if the API call throws, we catch and return a generic title. We do NOT want the metadata fetch to crash the page render.
- **The dashboard `/invite/:token` route doesn't exist yet** — clicking the CTA today lands on a 404. That's expected; it ships next chunk.

## Verification (post-test)

- Send an invite to a fresh email. Click the email link → public preview renders with team logo + inviter + role.
- View the page title in browser tab → "You're invited to [Team] · Crelyzor".
- Mobile (390px width) → card sits at max-w-md with healthy gutters; CTA stays full-width.
- Manually mangle the URL → /invite/bogus → falls through to existing not-found.tsx.
- In Prisma Studio, set `expiresAt` of an invite to a past timestamp → /invite/<token> renders the expired card (Clock icon + "This invitation has expired").
- View page source → OG image is the team logoUrl; robots is noindex.
- View Network tab on the dashboard navigation → no Referer header on the request.

## Phase 6 P14 — sub-chunk status

| Sub-chunk | Status |
|---|---|
| **P14.a Public invite preview page** | ✅ this chunk |
| P14.b Dashboard `/invite/:token` handler (accept POST + sign-in redirect) | ⏳ next |
| P14.c Public `/t/:slug` team page | ⏳ |
| P14.d Public `/schedule/t/:slug/:username` team booking page | ⏳ |
