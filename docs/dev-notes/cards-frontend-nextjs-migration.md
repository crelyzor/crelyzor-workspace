# cards-frontend Next.js Migration — Dev Notes

## What was built
Full migration from Vite + React to Next.js App Router. Mobile-first. PWA setup. SSR + OG previews.

## Key decisions
- **App Router** (not Pages Router) — required for `generateMetadata` per-page OG tags.
- **Mobile-first**: `max-w-sm` narrow card layout, scales up gracefully. Business cards are a mobile use case.
- **3D flip card must be `'use client'`** — uses `useState` for flip state. Cannot be a server component.
- **No React Query** — this is SSR. Data fetched in server components directly via `lib/api.ts`. React Query stays in `calendar-frontend` only.

## PWA setup
- `app/manifest.ts` — root manifest
- `app/api/icon/route.tsx` — dynamic icon via `ImageResponse`
- `app/api/manifest/[username]/route.ts` — per-user manifest (name + start_url from card data)

## Gotchas
- **vCard download**: uses `fetch` + blob URL in client component. Falls back to `window.open` if fetch fails.
- **3D flip in SSR context**: works fine as long as the flip component is `'use client'` — no hydration issues.
- **Dev port**: runs on `:5174` (`next dev -p 5174`) — not default 3000 (conflicts with backend).
- **Font**: Inter — NOT DM Sans (that's calendar-frontend). Do not mix.
- **TailwindCSS 3** (not v4) — cards-frontend uses v3. calendar-frontend uses v4.

## File structure
```
app/[username]/page.tsx         — SSR server component, calls generateMetadata
app/[username]/CardView.tsx     — 'use client' flip card
```
