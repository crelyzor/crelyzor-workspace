# Phase 6 P10 — Team creation modal + plan gate

`/teams/new` is now a real route. Single-page modal with name + auto-derived slug + optional description + optional logo URL. Wired to `POST /teams` with full 402/409 handling and an existing-UpgradeModal handoff for FREE users.

## What was built

- **NEW `src/components/teams/CreateTeamModal.tsx`** — controlled Dialog with:
  - Team name (autofocus, max 100)
  - Team URL slug (auto-derived from name unless user edits; lowercase + hyphens; regex-validated)
  - Description (optional, max 500, textarea, 3 rows)
  - Logo URL (optional, https — full upload UX deferred to P11 settings)
  - FREE-user inline note ("Teams are a Pro feature. You'll be prompted to upgrade…") — defensive copy; the server still gates authoritatively.
- **NEW `src/pages/create-team/CreateTeam.tsx`** — modal-as-page wrapper. PageMotion + auto-opens the modal on mount; closing the modal navigates back to `/`.
- **NEW `src/pages/create-team/index.ts`** — barrel.
- **`src/routes/routes.ts`** — added `CreateTeam` lazy import + export.
- **`src/App.tsx`** — registered `/teams/new` route inside AuthGuard + Layout.

## Key patterns

- **Modal-as-page**. A route renders an always-open modal; closing the modal navigates back. The Layout's existing cross-fade wrapper handles the page-out animation. No extra scaffolding.
- **Auto-derived slug with manual-edit tracking**. `slugManuallyEdited` flag stops further name edits from clobbering a customized slug — Linear-style behaviour.
- **Server-authoritative plan gate, client-side defensive copy**. The backend's `POST /teams` returns 402 with `code: "FEATURE_GATE"` for FREE users. The existing apiClient interceptor opens UpgradeModal automatically; our handler also closes the create modal so the two layers don't stack. The defensive inline note for FREE users sets expectations but never blocks submission.
- **Inline error on 409 slug conflict**. The slug field stays editable + shows "This URL is taken — try another." No toast, no redirect — the user just fixes the slug and resubmits.
- **`useCreateTeam.mutateAsync` + try/catch**. The hook's `onSuccess`/`onError` handle the toast for the success path + generic errors; the call-site handles status-specific outcomes (402 / 409) before the generic toast.

## Decisions

- **Logo URL input, not a dropzone**. The backend doesn't yet expose a team-logo upload endpoint. Until that lands (P11 settings will need it), a plain `https://…` URL field is the honest UX. The full dropzone + storage flow ships with the team-settings page.
- **Switch active workspace immediately on success**. The user lands on `/` already in team scope. Personal data can't bleed in because the next render already carries `X-Team-Id`. The cross-fade in Layout makes the scope swap visible.
- **Navigate to `/` after create, not `/teams/:id/settings`**. The settings page doesn't exist yet (P11). After P11 ships, this redirect can be updated to `/teams/:id/settings` so users land directly in the management area.
- **No slug-availability pre-check**. The spec mentioned a debounced 300ms availability check, but the backend doesn't expose `GET /teams/check-slug`. Submit-time 409 is the source of truth. Adding a pre-check would require a new endpoint that duplicates the existing uniqueness logic; deferred.
- **Modal handles 402 explicitly** even though apiClient does too. The duplicate `openUpgradeModal('FEATURE_GATE')` call is a safety net for the case where the interceptor doesn't recognize the code shape (e.g. a future backend wording change). Closing the create modal first prevents stacked Dialogs.

## Gotchas

- **`slugManuallyEdited` resets on modal close**. The reset useEffect wipes all fields including the flag. Re-opening the modal starts fresh — correct behaviour.
- **Empty slug derivation**. If the user only types emoji or non-ascii into the name, `slugify` returns an empty string. The submit button stays disabled.
- **The Layout's cross-fade wrapper sees both the modal page and the `/` page**. Closing the modal triggers TWO transitions: the modal scale-down (Radix Dialog's built-in) + the Layout's keyed cross-fade. They run in parallel and feel intentional.
- **`navigate('/', { replace: true })`** so the back button doesn't return the user to `/teams/new`. Without `replace`, hitting Back after creating a team would re-open the modal in personal scope.
- **`createMutation.mutateAsync` is used so the catch block runs in the same handler**. Using `mutate` with `onError` would split the error-handling logic across the hook and the component — not ideal for status-specific dispatch.
- **`useUIStore.openUpgradeModal('FEATURE_GATE')` works even without a defined limit code** in the existing copy map — `FEATURE_GATE` is already supported per the UpgradeModal's `LIMIT_COPY`.

## Deferred to P11 (team settings)

- **Logo dropzone / upload UX** — depends on a new team-logo upload endpoint.
- **Editable slug after creation** — handled by the General tab.
- **Description editing** — same place.
- **Inline slug-availability pre-check** — only if a backend `check-slug` endpoint is added; otherwise stays submit-time.

## Verification ideas (post-test)

- Open `/teams/new` directly via URL → modal auto-opens.
- Esc / Cancel → returns to `/`.
- FREE user submits → UpgradeModal opens, create modal closes.
- PRO user submits with a unique slug → 201, switches active scope, lands on `/` in team mode.
- PRO user submits with a taken slug → inline error, no toast, slug stays editable.
- Type "Acme Inc." → slug auto-fills "acme-inc". Edit slug to "acme" → further name edits don't clobber it.
- Empty slug or invalid characters → submit button disabled.
