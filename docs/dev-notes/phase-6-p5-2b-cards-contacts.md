# Phase 6 P5.2.b — Cards: contacts list / analytics / multi-card paths

Second chunk of P5.2. The contact-side surface and the read-only analytics paths now honour team context. With this and P5.2.a, the full Cards service is team-aware.

## What was built

- `services/cardService.ts`
  - New helper `contactScope(actorId, teamContext)` — routes via the `card` relation. Personal context: contacts on actor-owned cards. Team context + ADMIN/OWNER: contacts on any team card. Team context + MEMBER: contacts on own team cards only. Explicitly adds `card.isDeleted: false` because `cardScope` deliberately omits soft-delete (per its own docstring).
  - New constant `MAX_IMPORT_ROWS = 5000` — CSV import hard cap.
  - `getContacts` — `contactScope` replaces the old `userId = actor` filter. Per-row decrypt via `principalForCard(c.card)` so contacts encrypted under the team DEK (post-P5.2.a) decrypt cleanly. Card include extended with `userId + teamId` (stripped from response shape before return).
  - `updateContactTags` — loads the contact with parent card info, runs `verifyCardAccess(mutate)`. Returns the **decrypted** contact (matching `getContacts` shape) so the frontend never sees encrypted `Bytes` in the PATCH response (security review must-fix).
  - `deleteContact` — same access model as `updateContactTags`. Soft-delete preserves the row for audit; `ContactTag` rows stay live (restore path keeps tagging).
  - `exportContacts` — same scope + decrypt-principal retrofit as `getContacts`. Per-batch card include extended with `userId + teamId`.
  - `importContactsFromCsv` — `assertCardAccess(mutate)` on the target card. `MAX_IMPORT_ROWS` cap raised as a 400 with row count in the error message. Per-row encryption uses `principalForCard(targetCard)`. Caps DoS via multi-million-row CSV.
  - `getCardAnalytics` — `assertCardAccess(read)` replaces the `userId = actor` filter. Identical body shape after gate.
  - `getCardMeetings` — `assertCardAccess(read)` on the card. Additionally adds a meeting-level scope `{OR: [{teamId: ctx.teamId}, {createdById: actor}]}` so a cross-tenant linked contact can't leak meetings from a *different* team to the actor (security-reviewer must-fix). Otherwise an admin on team A looking up a contact that happens to also be linked to a meeting on team B would see that meeting.
- `controllers/cardController.ts` — 7 handlers thread `getTeamContext(req)` through to the service.

## Key patterns

- **`contactScope` is a where fragment over the `card` relation.** Not a wrapper. The explicit `card.isDeleted: false` is the load-bearing detail — `cardScope` doesn't carry it because cardScope callers always combine with their own `isDeleted: false`. Contacts query the parent's deletion state via the relation, so it must be added here.
- **`getCardMeetings` cross-tenant defence is at the meeting level, not the contact level.** The contact lookup is allowed (the actor has access to the contact via the card), but the *meetings list* is filtered to only meetings the actor can see. Subtle but important: the access check on the contact is for "can you fetch the contact", which is separate from "which meetings linked to it are you allowed to see."
- **Per-row principal derivation in batch decrypt.** `exportContacts`'s batches may span multiple cards owned by different team members under ADMIN scope. Each row's principal is derived from its own card, not from a single global principal. Same pattern as `decryptTaskDescriptions` in P5.3.
- **`updateContactTags` decrypts in the response.** The PATCH response returns the same shape as `getContacts` — including plaintext `email/phone/note`. Reviewer was explicit: a mutation endpoint returning encrypted `Bytes` is a foot-gun; the frontend will either crash or render garbage.

## Decisions

- **`MAX_IMPORT_ROWS = 5000`** picked to be generous for legitimate use cases (the prior Phase 3.3 CSV import path had no implicit cap; the largest tested import was ~800 rows). Larger imports should chunk client-side. Hard 400 instead of silent truncation — silent truncation is a data-loss bug pretending to succeed.
- **`getCardMeetings` does NOT relax the cross-tenant filter under personal context.** Personal-context callers only see meetings they own (`createdById = actor`). Team context callers see meetings they own *or* meetings on the current team — never meetings from a different team, even if a participant matches.
- **`ContactTag` rows stay live on `deleteContact` soft-delete.** Cascading would lose tagging on restore. The tag-lookup queries (`getTagItems`, contact-tag filters) already filter by `contact.isDeleted: false` so live tag rows pointing at a soft-deleted contact are silently ignored. If the contact is restored, tags reappear.
- **No backfill needed.** Pre-P5.2.a contacts on personal cards were encrypted under user DEK; they continue to decrypt under user DEK via `principalForCard` (which returns `{type: "user", id: card.userId}` for personal cards). Post-P5.2.a contacts on team cards are encrypted under team DEK; they decrypt under team DEK via `principalForCard` (which returns `{type: "team", id: card.teamId}` for team cards). The version byte in the ciphertext disambiguates the DEK version within each principal.

## Gotchas

- `updateContactTags` used to return raw Prisma output without decryption. Anything that was previously rendering `email`/`phone` from the PATCH response will now see plaintext (was previously seeing Buffer/Bytes — i.e. nothing useful). Worth re-checking the contact list UI's optimistic-update path on retag.
- `getCardMeetings`'s additional meeting-level filter changes the result set under team context: a contact linked to meetings across multiple teams now only returns meetings on the *current* team plus actor-owned meetings. Before P5.2.b, the query returned all meetings the contact participated in. This is the intended security tightening.
- `importContactsFromCsv` errors with a 400 at row 5,001 — the error message includes the actual row count. The full file is parsed *before* the cap check because the row count is the count we want to expose. If parsing 50MB CSVs becomes a real issue, streaming parse + early-bail would be the next step.

## Open follow-ups

- **`exportContacts` memory ceiling.** Currently accumulates the full CSV in memory across batches. An admin exporting full team-contact set could be tens of thousands of rows. Streaming the CSV directly to `res.write` would avoid the accumulation. Flagged inline as `TODO`.
- **`tagController` card-tag + contact-tag handlers** still use `tagService.verifyCardOwnership` which trusts `card.userId = actor`. The card-side handlers need the same `assertCardAccess` swap that meeting-tag bits got in P5.1.b. The contact-side handlers need `assertCardAccess` + `verifyContactBelongsToCard`. Bundled under P5.5 (Tags retrofit) per the original split.
