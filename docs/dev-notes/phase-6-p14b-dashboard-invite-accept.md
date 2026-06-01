# Phase 6 P14.b — Dashboard /invite/:token accept handler

Closes the email-invite loop end-to-end. The CTA from the public preview page (P14.a) now lands on a real dashboard route that completes the accept POST and routes the user into the team. Not-signed-in users are bounced through Google OAuth with a return URL.

## What was built

- **`src/lib/safeNext.ts` (NEW)** — `isSafeNext` / `pickSafeNext` URL-based same-origin validator. Used by both write-site (SignIn) and read-site (AuthCallback) to prevent open-redirect via a crafted `?next=` URL. URL-parsing handles encoded bypasses, backslash variants, and protocol-relative URLs that a naive string check would miss.
- **`src/services/teamService.ts`** — `acceptInviteByToken(token)` (POST `/invites/:token/accept` → `{ membership }`), `declineInviteByToken(token)` (POST `/invites/:token/decline` → void).
- **`src/hooks/queries/useTeamQueries.ts`** — `useAcceptInviteByToken` (setActiveTeam BEFORE invalidate → invalidate `teams.all` + `cards.all` → caller handles success/error via `mutate(token, { onSuccess, onError })`; no toast). `useDeclineInviteByToken` (invalidate `teams.myInvites`).
- **`src/hooks/queries/useAuthQueries.ts`** — `useGoogleLogin()` now accepts `{ next?: string }`. Callback URL becomes `${origin}/auth/callback?next=${encodeURIComponent(next)}` when provided. Backend `isAllowedRedirectUrl` is origin-only (verified via `new URL` parsing in googleController.ts:31-50), so the query string passes through OAuth cleanly. Query string is re-appended on the final redirect via the `?`/`&` separator at line 119.
- **`src/pages/sign-in/SignIn.tsx`** — reads `?next=` via `useSearchParams`, validates with `pickSafeNext`, redirects already-authenticated users straight to `next`, threads `next` into `login()`.
- **`src/pages/auth-callback/AuthCallback.tsx`** — reads `?next=` from `window.location.search`, re-validates (defense-in-depth), navigates to `next` after setting access token. Fallback `/`.
- **`src/pages/invite/InvitePage.tsx` (NEW)** — top-level route (NOT under `AuthGuard`):
  - `!isAuthenticated` → `<Navigate to={`/signin?next=/invite/${token}`} replace />`.
  - Authenticated → fires `acceptInviteByToken.mutate(token)` on mount via a `useRef(false)` guard so React strict-mode's double-effect doesn't double-fire the POST.
  - States: pending (spinner + "Joining team…" + ghost "Decline this invitation"), success (navigate `/teams/:teamId/settings`), 410 (Clock-icon "expired"), 404 ("no longer valid"), 403 ("Different account" — sign out + retry primary, back-to-Crelyzor secondary), other ("Something went wrong" + Try again).
- **`src/pages/invite/index.ts` (NEW)** — barrel re-exporting default.
- **`src/routes/routes.ts`** — lazy `InvitePage` import.
- **`src/App.tsx`** — `<Route path="/invite/:token" element={<InvitePage />} />` registered BEFORE the AuthGuard tree.

## Key patterns

- **`pickSafeNext` for ANY OAuth `next` handoff** — extract the validator once, use at both write-site and read-site. URL-parsing against `window.location.origin` is the canonical same-origin pattern; anything string-based has bypass vectors (`/\\evil.com`, control-character smuggling, etc.).
- **Defense-in-depth re-validation**: SignIn validates before sending; AuthCallback re-validates after the OAuth round-trip. Either check alone would be enough in practice — but the cost of re-running it is zero and the cost of a missed open-redirect is the access token.
- **Strict-mode-safe mutation firing**: `useEffect(() => { if (fired.current) return; fired.current = true; mutate(...); }, [deps])`. Don't put a mutation directly in useEffect without a ref guard — React strict-mode double-invokes effects in dev, which would 404 the second attempt because the first already mutated server state.
- **Top-level route + internal auth gate**: `/invite/:token` handles its own auth flow (Navigate to /signin if not authenticated) rather than being wrapped in `AuthGuard`. AuthGuard's redirect would lose the token, so we want full control over the path.
- **`{ next?: string }` opt-in** on `useGoogleLogin().login()`: existing callers (`SignIn` non-handoff path) still work unchanged. The signature is additive.
- **403 wrong-account UX**: backend hides the invitee email from token holders. Copy stays generic: "This invitation was sent to a different email address. Sign in with the address it was sent to." Primary CTA logs out + redirects to `/signin?next=/invite/:token` so the next sign-in attempt picks up the same invite.

## Decisions

- **Auto-accept on mount, not a confirm-then-accept preview**: the public page at crelyzor-public `/invite/[token]` IS the preview (shows team, inviter, role). This route is the action. A second confirmation would be friction.
- **Success navigates to `/teams/:teamId/settings`**: lands on the Members tab so the new joiner immediately sees who else is on the team. Alternative `/` would feel anticlimactic.
- **No toast in the mutation hook itself**: InvitePage owns the success/error rendering. A toast would compete with the page-level state cards.
- **"Decline this invitation" placed in the pending state**: it's the rare path but having it accessible from the loading spinner makes it discoverable. Placed as a ghost text-button (`text-[12px] text-muted-foreground`) so it doesn't compete with the primary "joining" affordance.
- **No "Retry" automatic backoff**: the unknown-error state has a manual Retry button. If the user is on a flaky network, manual control is better than silent retries that could land twice (the POST is not idempotent — second call would 404).
- **`/teams/:teamId/settings` not `/teams/:teamId`**: the latter route doesn't exist in App.tsx — only the settings page does.

## Gotchas

- **Backend redirectUrl validation is origin-only** — `isAllowedRedirectUrl` parses via `new URL` and checks the origin. Query strings and paths are not checked, which is correct: we want to round-trip arbitrary internal paths. Don't add path validation server-side or it'll break the next-flow.
- **`isSafeNext('/')`** intentionally returns true so the no-handoff path is the canonical fallback.
- **Backslash variants need explicit rejection** before `new URL` parsing — Chrome silently normalises `/\` → `/` in some contexts which would resolve `/\\evil.com` to a cross-origin URL. The helper rejects `startsWith('/\\')` first.
- **AuthCallback's `processed` ref already prevents double-fire** in dev strict-mode — the new `next` logic doesn't need its own guard, it's already inside the once-only block.
- **`useGoogleLogin` is NOT a hook in the React-Query sense** — it's a function-returning hook. Calling `useGoogleLogin().login({ next })` is fine; doesn't need useMemo.
- **`mutate(token, { onSuccess, onError })`** signature: per-call handlers are additive to (not replacements for) the hook-level `onSuccess`/`onError`. So the hook's `setActiveTeam + invalidate` still runs even though the page also gets `onSuccess` for navigation.
- **`ApiError` is exported from `@/lib/apiClient`** — easy to miss because most callers don't catch by class. `instanceof ApiError` + `.status` is the canonical pattern.
- **`/teams/:teamId/settings` route exists in App.tsx**, but `/teams/:teamId` does not. Confirmed before writing the navigate target.

## Phase 6 P14 — sub-chunk status after this push

| Sub-chunk | Status |
|---|---|
| P14.a Public /invite/[token] preview | ✅ |
| **P14.b Dashboard /invite/:token accept handler** | ✅ this chunk |
| P14.c Public /t/:slug team page | ⏳ |
| P14.d Public /schedule/t/:slug/:username booking page | ⏳ |

## Verification ideas (post-test)

- Cold path (not signed in): email → public preview → CTA → /signin?next=/invite/X → Google OAuth → AuthCallback honors `next` → /invite/X → POST accept → /teams/:teamId/settings.
- Warm path (signed in): /invite/X → instant spinner → /teams/:teamId/settings.
- Decline path: /invite/X → click "Decline this invitation" → POST decline → /.
- 410 expired: edit `expiresAt` past in Prisma Studio → /invite/X renders expired card.
- 404 already accepted/declined/cancelled → "no longer valid" card.
- 403 wrong account: sign in as a different user → /invite/X → "Different account" card → Sign-out CTA → /signin?next=/invite/X.
- Open-redirect hardening: /signin?next=https://evil.com, /signin?next=//evil.com, /auth/callback?next=//evil.com#accessToken=foo — all ignored, fallback `/`.
