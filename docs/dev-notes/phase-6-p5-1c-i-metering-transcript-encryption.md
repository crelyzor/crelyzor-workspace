# Phase 6 P5.1.c.i — Metering teamId threading + transcript/SMA-edit encryption rotation

First half of the P5.1.c work. Closed the loop on (1) billing — Deepgram and Recall now bill the team owner when in team context — and (2) encryption rotation for transcripts + smaEdit content.

## What was built

- `usageService` — `MeteringOpts = { teamId?: string | null }` exported; all 5 functions (`checkTranscription / deductTranscription / checkRecall / deductRecall / checkAndDeductCredits`) accept `opts?`. Each resolves the payer via `getQuotaOwner({ userId, teamId })` and runs the existing `getPlanAndUsage` / `userUsage.update` against the **payer's** row, not the actor's. Back-compat preserved — no opts arg means `payer = userId` (Phase 5 behaviour).
- Logs in usageService now include `payerId` + `actorId` + `teamId` on every check/deduct emission. Makes mis-attribution diagnosable from observability without a code change.
- `transcriptionService` — fetches `meeting.teamId` alongside `meeting.createdById` in the same `select`; derives `meetingPrincipal = principalForMeeting(recording.meeting)` once. `encrypt(fullText, ...)` + `encrypt(seg.text, ...)` + `getTranscript`'s `decrypt(seg.text, ...)` all use the principal. Both metering calls (`checkTranscription` + `deductTranscription`) pass `{ teamId: meeting.teamId }`.
- `smaEditService` — three functions retrofit:
  - `updateSegment` — slim-fetches the meeting via nested `transcript.recording.meeting.select({ teamId, createdById })`; `encrypt(text, meetingPrincipal)`.
  - `updateSummary` — fetches `teamId` on the meeting select; `encrypt(summary)` + `encrypt(keyPoints)` use the principal.
  - `mergeConsecutiveSpeakerSegments` — `teamId` on meeting select; decrypt + re-encrypt of every segment uses the principal.
- `worker/jobProcessor` — both Recall handlers (`DEPLOY_RECALL_BOT` and `FETCH_RECALL_RECORDING`) read `data.teamId` from the Bull payload (added in P4 schema) and forward it to `checkRecall` / `deductRecall`. `FETCH_RECALL_RECORDING` also carries the teamId into the `TRANSCRIBE` job it enqueues so the downstream transcription worker bills correctly.

## Key patterns

- **`MeteringOpts` as the sole way to pass teamId.** Every metering function uses the same `opts?: { teamId?: string | null }` shape. Callers that don't have teamId (Phase 5 paths, system jobs, future metering points) pass nothing and stay on the actor's quota.
- **`payerId = await getQuotaOwner(...)` inside each function.** No callers compute the payer themselves — the resolver lives inside usageService. This means a future "actor is suspended → bill someone else" rule lives in one place.
- **`meetingPrincipal = principalForMeeting(meeting)` derived once per service call**, then reused at every encrypt/decrypt site within the same function. Saves multiple Prisma lookups for the meeting row and makes the "encryption follows the row, not the actor" invariant impossible to miss.
- **`{ teamId: meeting.teamId }` spread, even when teamId is `null`.** Explicit nulls in the call site make the payer-resolution behaviour visible at every call site. `getQuotaOwner` short-circuits on null and returns userId — same effect as omitting opts, but clearer at the read.
- **Bull payload `data.teamId ?? null` everywhere it's consumed.** Producers add teamId via spread `...(teamId ? { teamId } : {})`; consumers normalise to `null` when reading. Avoids `undefined` leaking into log objects.

## Decisions

- **`getTranscript` retains its `createdById` ownership filter** (not assertMeetingAccess yet). That's a P5.1.b-style controller-level gate; the existing inline filter doesn't break under team context because the controller never calls it with someone else's userId. Documented inline as a follow-up — the SMA controller cutover for transcript endpoints lives in a separate task.
- **`smaEditService.updateSegment` keeps the `createdById` filter** in its nested where for the same reason. Team admins editing other admins' segments will return 404 under the current personal-only gate, which is a regression we'll fix when smaRoutes gets assertMeetingAccess on each transcript-edit handler (small task, deferred to keep this chunk focused).
- **No new tests in this chunk.** The encryption switch is mechanical pattern-replacement; the security invariants were validated in P3 (`cryptoPrincipal.test.ts`) and the access-control logic was validated in P5.1.a. End-to-end correctness needs a live Deepgram + team-context integration test which lives outside the unit suite.
- **`teamId` carried in `TRANSCRIBE` Bull payload, not re-derived in the worker.** The worker has the recording → meeting JOIN it already does for principal derivation, but carrying teamId in the payload makes the billing decision visible at job creation time + observable in Bull dashboards.

## Gotchas

- `updateSegment` originally did `prisma.transcriptSegment.findFirst({ where: { id, transcript: { recording: { meetingId, meeting: { createdById, isDeleted: false } } } } })` — adding `teamId` requires extending the nested `select` chain too, otherwise the Prisma client returns the segment without the meeting's teamId. Easy miss.
- `usageService.checkAndDeductCredits` accepts `opts?` but the **2 callers in aiService still don't pass it** — that's the P5.1.c.ii work. Until then, AI credits are deducted from the actor, not the team owner, for team meetings. Logged as TODO in TASKS.md.
- The personal-context fallback path through every metering function is *the same code* as the team path — they only diverge at `getQuotaOwner`. So a regression that breaks team billing will also break personal billing. Smoke test both during verification.
- `transcribeRecording`'s `meetingPrincipal` is derived from the recording's meeting row, fetched in the same `findFirst` that does the ownership check. If the meeting is soft-deleted between recording upload and the job firing, the function throws 404 before the principal is used — no orphaned encryption call.

## Deferred to P5.1.c.ii (next chunk)

- `aiService.ts` — 18 encrypt/decrypt sites covering summary, keyPoints, content, transcript decrypt, AI-extracted task description. Same pattern as smaEditService: fetch `teamId` on the meeting select, derive `meetingPrincipal`, swap every site.
- `aiService.ts` — 2 `checkAndDeductCredits` call sites (Ask AI + content generation). Add `{ teamId: meeting.teamId }` opts.
- `askAIConversationService.ts` — 2 sites (encrypt user message + decrypt history). Same pattern.

P5.1 closes when P5.1.c.ii lands.
