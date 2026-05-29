# Phase 6 P5.2.a — Card CRUD team-scoping + public submitContact encryption

First chunk of P5.2. Card CRUD, helpers, and the public submitContact encryption principal switch shipped. Contact list / analytics / multi-card paths deferred to P5.2.b.

## What was built

- `routes/cardRoutes.ts` — `resolveTeamContext` mounted after `verifyJWT`. One line. Inline `TODO(P5.2.b)` comment on the tag-route deferral.
- `validators/cardSchema.ts` — `createCardSchema` and `updateCardSchema` switched to `.strict()`. The validator now rejects unknown keys (including `teamId` and `userId`) as a 400 before the service layer ever sees them.
- `services/cardService.ts` — 4 new exported helpers near the top:
  - `cardScope(actorId, teamContext) → Prisma.CardWhereInput` — personal returns `{ teamId: null, userId: actor }` (the leak fix); team+ADMIN/OWNER returns `{ teamId }`; team+MEMBER returns `{ teamId, userId: actor }`.
  - `principalForCard(card)` — exported `Principal`. Documented as immutable for the card's lifetime.
  - `verifyCardAccess(actorId, card, teamContext, "read" | "mutate")` — pure check on a pre-fetched slim row.
  - `assertCardAccess(actorId, cardId, teamContext, action)` — fetch + verify + return row (mirrors `assertMeetingAccess`).
  - Private `assertCanCreateTeamCard(teamContext)` helper — first-line MEMBER rejection for any path that creates a team-scoped card.
- 6 methods retrofitted with `teamContext: TeamContext | null = null`:
  - `createCard` — `assertCanCreateTeamCard` as the **first line**; writes `teamId = ctx.teamId`; slug-conflict probe scopes to actor.
  - `getUserCards` — uses `cardScope` (closes the team-card-in-personal-list leak).
  - `getCardById` — single-fetch + in-memory `verifyCardAccess`. No two-step like meetings — cardInclude is small.
  - `updateCard` — `assertCardAccess(mutate)` gate; **slug uniqueness probe + default-card unset + username lookup all scope to `card.userId` (not the actor)** because slug uniqueness is per-owner, not per-actor. An admin editing a teammate's team card must respect that teammate's own-slug pool.
  - `deleteCard` — same gate; default-card promotion also scopes to `card.userId`.
  - `duplicateCard` — `assertCanCreateTeamCard` (dup is effectively a create) + `assertCardAccess(read)` on source; dup inherits source's `teamId`; new card owned by the actor.
- `submitContact` (public, no auth) — slim-fetch extended with `teamId`; `encrypt(email/phone/note, principalForCard(card))` replaces the old `encrypt(..., card.userId)`. Public form is the access control; principal is derived server-side from the row.
- `controllers/cardController.ts` — 6 handlers thread `getTeamContext(req)`. `previewCard` untouched (pure render, no DB).

## Key patterns

- **`cardScope()` returns a `where` fragment**, not a wrapper. Spread `...cardScope(actorId, ctx)` into `where: { isDeleted: false, ... }`. Same pattern as `meetingScope` from P5.1.a.
- **Owner-scoped probes inside admin-editable mutations.** `updateCard` and `deleteCard` look up `card.userId` for the slug-conflict probe and the default-card unset, NOT the actor's userId. This is the subtlety that took most of the diff in updateCard: an admin editing a member's card must respect the member's own per-owner slug pool, not the admin's own pool. Spec was silent on this; the implementation is the conservative-and-correct interpretation.
- **`assertCanCreateTeamCard` runs on the very first line** of `createCard` and `duplicateCard`. Reviewers flagged this explicitly: putting the role check after the slug-conflict probe would leak which slugs a team has by causing different errors for "slug taken" vs "you can't create here." The check goes first.
- **Strict Zod + service-layer immutability defence.** The `.strict()` schema is the first guard against `Card.teamId` flipping post-create. The service layer reinforces by never spreading `teamId` from the input DTO into a Prisma update.
- **Single-fetch `getCardById`** — `cardInclude` is small (just `_count`), so no need for the two-step "slim probe → access → full include" pattern that meetings used. One fetch + `verifyCardAccess` on the returned row.
- **`submitContact` derives principal entirely server-side** from the card row. The submitter is anonymous; the row drives encryption. Same security model as Phase 5 public reads.

## Decisions

- **Closed the personal `GET /cards` leak now, not later.** Before P5.2.a, a user's `/cards` query had no `teamId` filter, so team-default cards (owned by the user, with `teamId` set) showed up alongside personal cards. After P5.2.a, personal scope explicitly excludes team cards. Frontend must call with `X-Team-Id` to see them. Reviewers agreed: a dual-mode personal scope (with/without `teamId` filter) is the kind of inconsistency that bites later. Flagged in the DONE message as a frontend-visible behaviour change.
- **MEMBER role rejected on team-context createCard + duplicateCard.** Conservative default. Team cards come from `teamService.createTeam` (auto-default) or from ADMIN+. Easy to relax later if a real need surfaces.
- **MEMBER duplicating an ADMIN's team card is allowed** but the result is `{ userId: MEMBER, teamId: ctx.teamId }`. Same encryption (team DEK), still visible to ADMIN/OWNER via team scope, mutation rights stop at the dup owner. Not a leak — flagged for dev-note clarity per security-reviewer.
- **`getCardById` is single-fetch + in-memory check**, not two-step. Cardinclude is leaner than meetingInclude (no nested transcripts/participants/attachments) so the full-payload-on-cross-team-probe risk that drove the two-step pattern doesn't apply.
- **`updateCard`'s slug/username/default scope uses `card.userId`, not the actor**. The slug uniqueness invariant lives in `Card.@@unique([userId, slug])` — per-owner, not per-actor. Adjusting these probes to `card.userId` is the correct semantic, and it surfaces the broader principle: admin-editable mutations on cards owned by another team member should still respect that member's per-owner state.
- **No backfill needed** for the encryption principal switch on `submitContact`. Team cards from P1's `createTeam` are auto-empty (no contacts at time of P5.2.a). All NEW contacts on team cards encrypt under team DEK; all existing contacts on personal cards continue under user DEK. Version byte in the ciphertext drives DEK lookup regardless.

## Gotchas

- `updateCardSchema` previously accepted unknown keys silently. After `.strict()`, any client sending a stale extra field gets a 400. Verify no production frontend sends fields the schema doesn't list. (Spot-checked controller flow — should be clean, but watch the early error logs.)
- `updateCard`'s flow reads the card twice: once via `assertCardAccess` (slim select) and once via the existing `findFirst({ where: { id, isDeleted: false } })` (full row for the update logic). The duplication is fine for correctness; could be deduped into a single fetch + access check later if it ever shows up in profiling.
- `principalForCard` requires `{ userId, teamId }` only — keep the input type narrow so future callers can't pass an actor mistake. The exported signature enforces this at the type level.
- `Card.teamId` immutability is enforced at three layers: Zod `.strict()`, service-layer strip (no spread of `teamId` from input), and the absence of any admin endpoint that mutates it. `transferOwnership` flips `Card.userId` only; `teamId` stays. If a future migration adds a "move card between teams" path, it must also re-encrypt every contact row.
- `duplicateCard`'s new card uses `userId = actor` + `teamId = source.teamId`. Under team context, this means an ADMIN duplicating an ADMIN's team card results in a card owned by the duplicating admin, scoped to the team. Under personal context, source.teamId is null, so the dup is personal. Both consistent.

## Deferred to P5.2.b (next chunk)

- `getContacts` / `exportContacts` / `updateContactTags` / `deleteContact` / `importContactsFromCsv` — multi-card surface. Needs a cross-card-scope helper (cards owned across personal + multiple teams) and decrypt principal switch via `principalForCard(card)` per row.
- `getCardAnalytics` / `getCardMeetings` — read-only access check + cross-reference to meetings (which already team-scope per P5.1.a).
- `trackView` — anonymous public-write. No auth, no team context. Probably stays as-is but worth confirming.

## Deferred to P5.5 (Tags retrofit)

- `tagController.getCardTags / attachTagToCard / detachTagFromCard` — currently use `tagService.verifyCardOwnership` which trusts `card.userId = actor`. Needs the same `assertCardAccess` swap that meeting-tag bits got in P5.1.b.
- `tagController.getContactTags / attachTagToContact / detachTagFromContact` — same pattern, scoped by card → contact.
