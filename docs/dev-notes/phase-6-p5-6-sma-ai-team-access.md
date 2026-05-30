# Phase 6 P5.6 — SMA + AI cross-team isolation review

Audit + fix pass over the AI surface. P5.1.c.ii had retrofitted encryption to use `principalForMeeting`, but the access gates + decrypt principals at every reader were still actor-scoped. Result: any team admin (other than the meeting creator) hit 404 on `GET /summary` or decrypted with the wrong principal. P5.6 closes both gaps end-to-end.

## What was built

- **`aiService.loadMeetingMeta`** refactored into the central gate helper:
  - Worker callers pass `undefined` for `teamContext` → legacy `createdById = userId` filter preserved (worker is trusted; the meeting owner's userId is paired in the job payload).
  - HTTP callers pass `null` (personal) or a team ctx → `assertMeetingAccess` enforces P5.1.a team-scope + role rules.
  - Returns `{teamId, createdById}` for `principalForMeeting` + `getQuotaOwner` threading. Single fetch, single gate.
- **9 aiService method signatures grow optional `teamContext`** (defaults to `undefined` for worker compat):
  - `generateSummary`, `extractKeyPoints`, `generateSummaryAndKeyPoints`, `extractTasks`, `processTranscriptWithAI` (orchestrator threads through children), `askAI`, `generateContent`, `getGeneratedContents`.
  - `generateMeetingTitle` untouched — doesn't gate the meeting, just updates by id (caller-gated).
  - All 6 direct-fetch sites replaced with `loadMeetingMeta(meetingId, userId, teamContext, action)`.
- **aiController.ts — 5 legacy gate swaps + 3 decrypt principal fixes**:
  - `getSummary`: `assertMeetingAccess(read)` + decrypt summary/keyPoints under `principalForMeeting(meeting)`. **Real bug**: pre-P5.6, getSummary on team meetings silently failed to decrypt (encrypted under team DEK, decrypted with userId).
  - `regenerateSummary`: `assertMeetingAccess(mutate)` + transcript.fullText decrypt under principal + pass teamContext to `generateSummaryAndKeyPoints`.
  - `regenerateTitle`: `assertMeetingAccess(mutate)` + transcript decrypt under principal.
  - `askAI` / `generateContent` / `getGeneratedContents`: pass `getTeamContext(req)` to aiService.
  - `getAskAIHistory`: `assertMeetingAccess(read)`.
  - `clearAskAIHistory`: `assertMeetingAccess(mutate)`.
  - Imports `principalForMeeting` from meetingService (newly needed).
- **`askAIConversationService` — no functional change**:
  - Conversation rows are scoped by `@@unique([meetingId, userId])` — each member has a private Ask AI conversation per meeting.
  - Encryption already uses `principalForMeeting` from P5.1.c.ii.
  - Cross-member isolation is preserved naturally: ADMIN-A and ADMIN-B each have their own conversation rows on the same team meeting; the per-user lookup never crosses.
- **Worker (`jobProcessor.ts`)** — no change. Continues to call `aiService.processTranscriptWithAI(meetingId, ownerId)` with `teamContext` defaulted to `undefined` (legacy gate).

## Key patterns

- **`undefined` vs `null` vs `TeamContext` distinction on optional gate args.** Worker paths legitimately can't construct a TeamContext (no req, no role). Pre-P5.6 they used `createdById = userId` directly. The clean retrofit makes `teamContext: TeamContext | null | undefined` parameter-meaningful:
  - `undefined` → legacy gate path (worker compat)
  - `null` → HTTP personal scope (assertMeetingAccess with no team)
  - `TeamContext` → HTTP team scope
  Same `loadMeetingMeta` returns the same shape regardless.
- **Real audit-driven retrofit.** P5.6 wasn't a forward-looking design chunk like 5.4.c — it was a "P5.1.c.ii missed the controller layer" cleanup. Lesson: any future encryption-principal retrofit must walk EVERY reader, not just the writer.
- **Per-user Ask AI conversation under team scope is intentional.** Each admin has their own Ask AI session per meeting. Encryption uses the meeting's principal (team DEK on team meetings) so messages are decryptable by ANY team admin — but lookup is userId-scoped so cross-admin reads can't surface another's conversation. Privacy model = shared encryption key, distinct row access.

## Decisions

- **Worker keeps its legacy gate.** Reasoning: worker is in a trusted environment, owner-userId is paired in the job payload, there's no actor/role to construct a TeamContext from. Constructing a synthetic OWNER context (option-b from the plan) was considered but adds confusion. Default `undefined` falls back to the same gate the worker has always used.
- **Single `loadMeetingMeta` for everything.** Could have split into `loadMeetingMetaLegacy` (worker) and `loadMeetingMetaWithTeam` (HTTP). Kept one function with branching on `undefined` because the branches are tiny and the unified call site is more readable.
- **`generateMeetingTitle` not retrofitted.** It doesn't gate on the meeting — it does a blind `update by id`. The CALLER is responsible for gating (aiController.regenerateTitle now does so via `assertMeetingAccess(mutate)`). Worker callers stay trusted.
- **No changes to `askAIConversationService`.** The per-(userId, meetingId) row model already isolates members. Encryption already principal-aware from P5.1.c.ii. The CALLER (aiController) is where the gate belongs.
- **Decrypt fix in `aiController.getSummary` is the highest-impact change** — turned a silently-broken team-meeting summary read into a working one. This was a real correctness bug.

## Gotchas

- **`processTranscriptWithAI` is called from the worker.** It MUST accept undefined teamContext and use the legacy gate. The orchestrator then threads the teamContext through its children. If a future caller forgets to pass teamContext, the worker code path is invoked — which is "wrong" under team ctx (because it bypasses role checks). Mitigation: HTTP callers always pass teamContext (the controller is the only direct caller).
- **`generateSummary` and `generateSummaryAndKeyPoints` now do TWO fetches**: `loadMeetingMeta` (gate) and `findUnique` for title/description. Could be deduped by extending `loadMeetingMeta` to return more fields, but the current shape is clearer. Two fetches per Gemini call is negligible.
- **`aiController.getSummary`'s decrypt fix means EXISTING team-meeting summaries become readable.** No data backfill needed — the ciphertext was always under team DEK; only the decrypt principal needed correction.
- **The async `generateMeetingTitle(meetingId, fullText).catch(...)` in `processTranscriptWithAI`** doesn't pass teamContext — but it doesn't need to (generateMeetingTitle doesn't gate). Worth a re-check if generateMeetingTitle ever grows a gate.

## Verification ideas (post-test)

- DB spot-check: SELECT all team-scope meetings with non-null `MeetingAISummary` → confirm GET /summary works as different admin under team ctx.
- Functional: ADMIN-A regenerates summary on ADMIN-B's team meeting → check Gemini was called + new ciphertext written.
- Privacy: ADMIN-A + ADMIN-B each chat Ask AI on the same team meeting → GET /ask/history returns only own messages for each.
- Worker regression: upload a recording on a team meeting → process-ai job completes → MeetingAISummary written under team DEK + AI-extracted Tasks have `teamId` set.
- Cross-tenant: GET /summary with X-Team-Id mismatching the meeting's teamId → 404 "Meeting not found".
