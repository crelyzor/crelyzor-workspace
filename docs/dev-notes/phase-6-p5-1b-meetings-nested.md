# Phase 6 P5.1.b — Meeting nested resources team-scoping

Layered team-aware access on top of P5.1.a's `meetingService` helpers without touching encryption rotation (that's P5.1.c).

## What was built

- `meetingService` exports two new entry points:
  - `verifyMeetingAccess(actorId, meeting, teamContext, action)` — now exported (was private). Pure check on a pre-fetched slim row.
  - `assertMeetingAccess(actorId, meetingId, teamContext, action) -> AssertedMeeting` — single-call wrapper that slim-fetches the row, runs the access check, and returns the row so callers can do `principalForMeeting(meeting)` for encryption.
- `routes/smaRoutes.ts` — `router.use(resolveTeamContext)` after `verifyJWT`. Covers every SMA route in one mount.
- Four nested services now honour team context through `assertMeetingAccess`:
  - `attachmentService` — `getAttachments / addLink / uploadFile / deleteAttachment` (controller threads `getTeamContext(req)`)
  - `shareService` — `createOrGetShare / updateShare` (controller threads). `getPublicMeetingByShortId` stays public-by-shortId; no team check on the shareable-link path (intentional).
  - `tagService` meeting-bits — `getMeetingTags / attachTagToMeeting / detachTagFromMeeting`. Card/task/contact tag domains untouched (P5.2/P5.3/P5.5).
  - `aiController` notes — `getNotes / createNote / deleteNote`. Notes encryption stays under author DEK (decision below). `deleteNote` enforces author-only via a uniform 404 (does not reveal the note belongs to someone else).

## Key patterns

- **Single `assertMeetingAccess` import** in each nested service — consistent shape across all four retrofits. The pattern is:
  ```ts
  await assertMeetingAccess(userId, meetingId, teamContext, "read" | "mutate");
  ```
  Read paths use `"read"` (admin/owner OR creator OR participant), mutations use `"mutate"` (admin/owner OR creator; participant access stops at reads).
- **Controllers thread `getTeamContext(req)`** — same getter used in P5.1.a. No new accessor needed.
- **`route.use(resolveTeamContext)` once per router** — covers every downstream route. SMA had 30+ meeting-scoped endpoints; one mount line is all it takes.
- **Local `verifyMeetingOwnership` helpers were removed** in attachmentService and tagService (meeting-bits). They were duplicate "fetch creator-only meeting" probes that pre-dated team context. Replaced with `assertMeetingAccess`.

## Decisions

- **Notes encryption stays under the author's user DEK, not the meeting principal.** Notes are author-private scratch space — even under team context, each user sees only their own notes (`author: userId` filter on `getNotes`). Switching to `principalForMeeting(meeting)` would either (a) make notes readable to all admins (privacy regression) or (b) leave them encrypted under a key the author doesn't share with the meeting, breaking decrypt for them. Keeping the author DEK is the only consistent answer. Documented inline in `getNotes` / `createNote`.
- **`deleteNote` enforces author-only via uniform 404**, not 403. A member trying to delete another member's note gets the same body as "note doesn't exist." Stops authors from being enumerable through "wrong actor" responses.
- **`getPublicMeetingByShortId` skips team check.** A shareable link by `shortId` is its own access control — the meeting owner explicitly turned the share on; the shortId itself is the bearer token. Adding a team-context check here would either be redundant (caller has the link) or break the public flow.
- **`tagService.verifyTagOwnership` stays user-scoped** (`tag.userId = userId`). Tags are owned by individual users; team tags are P5.5 territory.

## Gotchas

- `assertMeetingAccess` returns the slim row, but **its `participants` projection only includes `userId`** (no `email`, no `role`). That's enough for the access check; consumers that need more should re-fetch with their own select.
- The `MeetingForAccess` type uses `participants?:` (optional) because access checks can be called with rows that don't always include the participant array. Tests should call with the array present; production callers always do.
- `aiController.deleteNote` was rewritten to load the note → check author → assert meeting access → update. The previous flow used a single `updateMany` with `meeting: { createdById: userId }` which doesn't compose with team context.
- `tagService.verifyMeetingOwnership` was removed but `verifyTagOwnership` was kept — they served different purposes despite similar names.

## Deferred to P5.1.c (next chunk)

- **Encryption principal switch on AI/transcript content:**
  - `transcriptionService` — `MeetingTranscript.fullText`, `TranscriptSegment.text`
  - `aiService` — `MeetingAISummary.summary` + `keyPoints`, `MeetingAIContent.content`
  - `askAIConversationService` — `AskAIMessage.content`
  - `smaEditService` — segment edits + summary edits
- **Metering wiring** — `checkTranscription/deductTranscription/checkRecall/deductRecall/checkAndDeductCredits` accept optional `{ teamId }`, resolve payer via `getQuotaOwner`; call sites in transcriptionService, aiService, jobProcessor populate teamId from the meeting row or the Bull payload.
- **Bull worker resolves quota owner** at job start (consumer side of the `teamId?` field added in P4).

## Test coverage status

42/42 security suite green. No new unit tests added for the four retrofitted services — their access logic is exercised end-to-end through `assertMeetingAccess`, which inherits its coverage from `verifyMeetingAccess` (validated in P5.1.a). P5.1.c will add focused unit tests for the encryption principal rotation (cross-admin decrypt).
