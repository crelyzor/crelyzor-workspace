# Phase 6 P2.b — Team Invites

Nine endpoints — six on the existing `/api/v1/teams/:teamId/invites/*` admin surface, three on a new public `/api/v1/invites/:token` mount.

## What was built

- `POST   /teams/:teamId/members/invite` — discriminated union (mode=user|email), team-scoped advisory lock + member-cap pre-check, 200 with `{created, skipped}` payload + per-row `emailSent` flag.
- `GET    /teams/:teamId/invites` — pending only (`isDeleted=false AND acceptedAt IS NULL AND declinedAt IS NULL AND cancelledAt IS NULL`).
- `POST   /teams/:teamId/invites/:inviteId/resend` — bumps `expiresAt` from live SystemConfig + re-sends email.
- `DELETE /teams/:teamId/invites/:inviteId` — sets `cancelledAt + isDeleted=true`; rejects already-accepted with redirect hint to remove-member.
- `POST   /teams/:teamId/invites/accept` + `decline` — in-app variants; lookup by `OR: [{email: actor.email}, {userId: actor.id}]` to support both invite modes.
- `GET    /invites/:token` — **no auth**; returns `{team: {name, logoUrl}, role, inviter: {name FIRST-NAME-ONLY}, expiresAt}` only. Never returns invitee email, team slug, or invite id. 410 on expired.
- `POST   /invites/:token/accept` + `decline` — JWT; enforces normalised email match.

## Key patterns

- **Discriminated Zod union via `z.discriminatedUnion("mode", ...)`** — gives proper TS narrowing inside the service (`if (input.mode === "email")` narrows to the email shape). Cleaner than a single object with `.superRefine` and better error messages.
- **Team-scoped advisory lock** — `pg_advisory_xact_lock(sha256("team:" + teamId)[0..8])` keyed on **teamId** (not actor) because the invariant being protected (member-cap) is per-team. Two parallel admin batches now serialise behind the same team lock. Same hashing pattern as P1's `withUserAdvisoryLock` but team-scoped.
- **`{created, skipped}` partial-success payload** — pre-checks `existingMembers` and `existingOpenInvites` inside the tx before inserting, so the response deterministically classifies each input as created vs skipped (reason=`already_member`|`already_invited`). Keeps P2002 on the partial unique index as a safety-net (still caught and downgraded to skipped).
- **Per-row `emailSent` flag** — after the tx commits, the service does N synchronous Resend calls (matches existing fail-open pattern in admin invites, booking confirmation, etc.). Failures don't fail the response; the admin UI gets a per-row boolean and can offer "click to resend" for the failures.
- **Email normalisation: NFKC + lowercase + trim** via new `utils/security/normalize.ts::normalizeEmail`. Phase 5's `blindIndex` keeps its existing `lowercase + trim` only — adding NFKC there would invalidate every previously-stored blind index, so the new util is intentionally separate. Documented in the file header.
- **HTML escape on `message`** via new `utils/security/htmlEscape.ts`. The email template (`templates/teamInvite.ts`) calls `escapeHtml(...)` on every user-controlled interpolation (inviter name, team name, message). The accept-URL embeds a hex-only token and is safe without escape.
- **Public payload privacy** — `getInviteByToken` drops `team.slug` (tenant identifier useful for phishing pretexts if the link leaks) and reduces `inviter.name` to first name via `name.split(/\s+/)[0]`. Never returns the invitee email.
- **Email-match guard on accept** — `invite.email !== normalizeEmail(user.email)` → 403 "This invite isn't addressed to your account". Prevents lifting tokens out of someone else's inbox.
- **Re-join semantics preserve `joinedAt`** — `acceptInviteCore` looks up the existing `TeamMember` row by `@@unique([teamId, userId])`; if it's soft-deleted, flips `isDeleted=false`, clears `deletedAt`, applies the role from the invite, **but does not touch `joinedAt`**. New members get a fresh row. Audit-history-preserving.
- **Identical 404 across the team-side surface** — every `getRole`-null path returns `"Team or invite not found"`. Same enumeration-collapse pattern as P1/P2.a.
- **Token URL** — `${env.PUBLIC_URL}/invite/${token}` (PUBLIC_URL = `https://crelyzor.com`, the Next.js public site that already has `app/invite/[token]/page.tsx` planned per `crelyzor-public/TASKS.md`).

## Decisions

- **Bull queue for emails — deferred.** Synchronous Resend matches the existing fail-open pattern (admin invites, booking confirmation, meeting-ready). Batch of 10 emails = ~2s sync; acceptable for v1. Move to Bull when telemetry shows latency complaints.
- **Cancel rejects already-accepted** with 400 (not silent no-op) + redirect to remove-member. Admins shouldn't accidentally "cancel" a joined member.
- **Skipped reasons surfaced verbatim** — `already_member` and `already_invited` are distinct so the UI can show the right CTA ("Open profile" vs "Resend invite").
- **Re-invite after cancel is allowed** — the partial unique index `team_invite_active_uniq` only enforces uniqueness while open; cancelled invites flip `isDeleted=true` and exit the index, so the same email can be re-invited cleanly. Confirmed safe vs cancel/re-invite race.
- **Defensive role narrowing at the email template boundary** — `TeamInvite.role` is typed as the full `TeamRole` union by Prisma but validated to ADMIN|MEMBER only by Zod. Two service call sites narrow with `role === "OWNER" ? "ADMIN" : role` rather than casting, so a future OWNER value in the DB doesn't silently render as the wrong role label.

## Deferred to later

- **WS events** — `TEAM_INVITE_RECEIVED`, `TEAM_MEMBER_JOINED` (on accept). Phase 6 P7.
- **Pino redaction for token in URL** — server logs the URL by default; adding a redact path for `req.params.token` and `req.url` on invite routes is logger-config scope, not P2.b. Follow-up task. Mentioned in security-review output.
- **Reconciliation worker** for fail-open Card creation (joined-member team Card) — owner can manually create cards from the dashboard for now.
