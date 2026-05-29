# Phase 6 P5.1.c.ii — aiService + Ask AI encryption rotation + AI credit billing

Closes P5.1. Every encryption site on meeting-scoped AI content now uses `principalForMeeting(meeting)` and both AI-credit deduction points carry `teamId` so the team owner is billed.

## What was built

- `aiService.loadMeetingMeta(meetingId, userId)` — small helper at the top of the file. Fetches the bare-minimum `{ teamId, createdById }` for a meeting under the existing personal-ownership filter. Used by functions that don't otherwise touch the meeting row.
- **Every meeting fetch in aiService extended with `teamId + createdById`** in its `select`. Derive `meetingPrincipal = principalForMeeting(meeting)` once per function and reuse it for every encrypt/decrypt within.
- 18 encrypt/decrypt sites switched from `userId` to `meetingPrincipal`:
  - `generateSummary` — 1 encrypt
  - `extractKeyPoints` — 2 encrypt (uses `loadMeetingMeta`)
  - `generateSummaryAndKeyPoints` — 2 encrypt
  - `extractTasks` — 1 encrypt on `Task.description` (uses `loadMeetingMeta`)
  - `processTranscriptWithAI` (orchestrator) — 4 decrypt + 2 encrypt (fullText, existingSummary, keyPoints, task descriptions, fallback summary/keyPoints upsert)
  - `askAI` — N decrypt on segments + 2 `appendMessage` sites (user message + assistant response)
  - `generateContent` — 2 decrypt (cached content cache hit + transcript) + 1 encrypt (new content row)
  - `getGeneratedContents` — 1 decrypt per content row
- **Two `checkAndDeductCredits` call sites** in aiService now pass `{ teamId: meeting.teamId }`:
  - `askAI` — estimated input/output tokens billed to team owner on team meetings
  - `generateContent` — exact token counts from Gemini billed to team owner
- `askAIConversationService`:
  - `getMessages(userId, meetingId)` — fetches the meeting first (no createdById filter — the conversation row already ties to (meetingId, userId)), derives principal, decrypts under it. Pre-Phase-5 fallback (catch + return "") preserved.
  - `appendMessage(conversationId, role, content, principal)` — **signature changed** from `userId` to `Principal`. Caller passes the principal it already has in scope (aiService.askAI), avoiding an extra meeting fetch per append.

## Key patterns

- **`meetingPrincipal` derived once per function** and threaded through every site within the same scope. Three or more encrypt/decrypt calls in the same function all reference the same `meetingPrincipal` constant. No repeated derivation.
- **`teamId` extracted as `meeting.teamId`** at the call site of `checkAndDeductCredits`. Spreading the team field through `MeteringOpts` is the only payment-attribution surface that needs to flip — keeps billing concentrated in one line per call.
- **`Principal` exported from crypto.ts**, imported by both aiService and askAIConversationService. The type already existed (P3); just opting in here.
- **`loadMeetingMeta` for two-function island use** — `extractKeyPoints` and `extractTasks` didn't fetch the meeting before. Rather than expand their existing flow, a tiny helper does one round trip and returns the two fields the principal needs.
- **Signature change on `appendMessage`** because the alternative (re-fetching the meeting inside) would have been 2N extra Prisma calls per conversation. The caller (askAI) is the only consumer and already has the principal. Worth the 2-line caller diff.

## Decisions

- **`getMessages` doesn't enforce `createdById` ownership.** The original code did. Under team context, a different actor reading their *own* Ask AI history on the same meeting (`@@unique([meetingId, userId])` enforces per-actor segregation) is still author-scoped — there's no way to read someone else's history through this function. The meeting fetch is only there to derive the principal; the access control is implicit in the conversation upsert key.
- **`getMessages` 404s if the meeting is missing.** Different from the old behaviour (empty array on missing conversation). Acceptable: the conversation can't exist without the meeting, and surfacing the missing meeting is more honest than silently returning empty.
- **No back-compat string overload on `appendMessage`.** Two callers, both updated in the same chunk. A `Principal | string` overload would invite future call sites to silently drop the meeting principal — exactly the footgun the explicit form prevents.
- **`processTranscriptWithAI` calls `loadMeetingMeta` at the top** even though it's the orchestrator and could reuse a meeting fetch from its callee. Cleaner — the orchestrator owns the principal and passes through to write functions that re-derive their own. Cost is 1 redundant Prisma read per AI processing run, dwarfed by Gemini latency.
- **`generateContent` and `askAI` pass `meeting.teamId` (not `meeting.teamId ?? null`)** to `checkAndDeductCredits`. The type is already `string | null`; explicit `?? null` would just add noise.

## Gotchas

- `extractKeyPoints` and `extractTasks` now do an extra Prisma round-trip per call (the `loadMeetingMeta` lookup). For the AI pipeline this adds two reads to `processTranscriptWithAI`'s critical path. Acceptable — Gemini calls dominate the latency budget.
- `appendMessage`'s signature change means tests/mocks that exercise it directly need updating. None exist in the current test suite, but flag for future test work.
- The `Principal` type import path is `../../utils/security/crypto` from `services/ai/*`. Used in both the aiService and askAIConversationService — both kept their relative imports clean.
- `getMessages` removed the implicit `createdById` filter inside its conversation lookup but the `@@unique([meetingId, userId])` constraint still enforces per-actor access. If someone refactors that unique key, this becomes a leak path — call it out in the schema if you ever touch it.

## What "P5.1 done" actually means

After this chunk:

- Every meeting-scoped read/write on `/api/v1/meetings/*` and `/api/v1/sma/meetings/*` honours `X-Team-Id` via `resolveTeamContext` + `assertMeetingAccess`.
- Member visibility filtering (creator OR participant only) applies under team context.
- Bull job payloads carry `teamId`; transcription, Recall, and AI metering all bill the team owner via `getQuotaOwner`.
- All meeting-scoped encrypted columns (transcript fullText + segments + summary + keyPoints + AI content + AskAI messages + AI-extracted task descriptions) encrypt under the team DEK on team meetings, user DEK on personal meetings.
- Cross-admin readability works: any team admin (or owner) can read transcripts/summaries/Ask-AI/generated content for any meeting in their team.
- Notes remain author-private (encrypted under author user DEK, even on team meetings) by design — this is the one documented exception to "meeting principal everywhere."

## Out of scope (next sub-tasks)

- P5.2 Cards: `cardService` + `cardContactService` need teamContext honoring + team-scoped `Card.teamId` writes
- P5.3 Tasks: standalone task surface
- P5.4 Scheduling, P5.5 Tags, P5.6 SMA + AI cache (mostly subsumed by P5.1.c.ii but the cross-team AskAIConversation+`MeetingAIContent` scoping needs review)
- P5.7 Recall webhooks: already pass teamId via job payload but the webhook handler doesn't re-resolve under team context yet
- P5.8 Usage endpoint
