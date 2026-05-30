# Phase 6 P5.7 — Recall webhook quota attribution under team ctx

Single-file fix closing the only remaining gap in the Recall payload chain. The webhook now selects `meeting.teamId` and forwards it to the FETCH_RECALL_RECORDING job, so downstream Recall hour deduction + transcription minute attribution land on the team owner instead of the personal host on team meetings.

## What was built

- **`src/controllers/recallWebhookController.ts`** — 4 small edits:
  - Meeting select extended with `teamId: true` so the row's team scope is available at dispatch time.
  - `handleStatusChange` signature gains a `teamId: string | null` parameter.
  - Main webhook handler passes `meeting.teamId` to `handleStatusChange`.
  - When queuing FETCH_RECALL_RECORDING, the job payload spreads `...(teamId ? { teamId } : {})` matching the forwarding convention already used in the worker → TRANSCRIBE chain (`jobProcessor.ts:363`).
  - The "Recall recording fetch queued" log line carries `teamId` for observability.

No other files changed. No schema changes. No new endpoints.

## Audit findings (pre-P5.7)

The chain was almost complete from prior P5.x sub-chunks. P5.7 was a verification pass + tiny patch.

| Hop | Producer / writer | State before P5.7 | Notes |
|---|---|---|---|
| Booking → DEPLOY_RECALL_BOT | `bookingManagementService.confirmBooking` | ✅ carries `teamId` | P5.4.b |
| Manual SCHEDULED meeting → DEPLOY_RECALL_BOT | `meetingService.createMeeting` | ✅ carries `teamId` | P5.1.a |
| DEPLOY_RECALL_BOT worker → `checkRecall` | `jobProcessor.ts:258` | ✅ uses `data.teamId` | P5.1.c |
| Webhook → FETCH_RECALL_RECORDING | `recallWebhookController.handleStatusChange` | ❌ **missing** | **fixed in P5.7** |
| FETCH_RECALL_RECORDING worker → `deductRecall` | `jobProcessor.ts:377` | ✅ uses `data.teamId` | P5.1.c |
| FETCH_RECALL_RECORDING → TRANSCRIBE | `jobProcessor.ts:363` | ✅ forwards `data.teamId` | P5.1.c |
| TRANSCRIBE worker → Deepgram quota | `transcriptionService` | ✅ uses `teamId` for `checkTranscription` | P5.1.c.i |

The webhook handler was the only producer of FETCH_RECALL_RECORDING jobs (confirmed via grep). No other entry points needed patching.

## Key patterns

- **`...(teamId ? { teamId } : {})` spread for optional Bull payload fields.** Matches the forwarding convention used throughout the worker chain. Avoids writing `teamId: null` into the payload (the field is optional in `RecallRecordingJobData`) and keeps the payload shape consistent with how prior chunks chain teamId.
- **Audit-then-fix retrofit.** Like P5.6, P5.7 wasn't a forward-looking design chunk — it was a verification pass over an already-mostly-complete chain. Lesson: when retrofitting a chain of jobs/handlers (transcription → AI → billing), inventory every hop end-to-end. P5.1.c had the producer/consumer halves right but missed the webhook hop in the middle because the webhook isn't part of the worker.
- **Webhook handlers need the same teamId plumbing as HTTP controllers.** Webhook is a producer of internal jobs even though it's an external entry point. Treat it like any other producer.

## Decisions

- **Single-file edit, no test suite changes.** The Recall webhook path is exercised end-to-end in staging when bookings flow through. Adding a unit test for the teamId-passthrough behaviour requires Bull mocking + a synthetic webhook payload — disproportionate effort for a 4-line code change. Verified via the existing test suite (47/47 green confirms no regression).
- **No retroactive correction.** Team meetings whose webhooks fired pre-P5.7 had their Recall hours / transcription minutes debited from the host instead of the team owner. Not a fixable ledger entry without manual `UserUsage` row migration. Documented in the DONE block; non-blocking.
- **`handleStatusChange` signature grows by one positional arg.** Could have wrapped existing args in an options object, but the function is only called from one site (the main webhook handler) and adding a position is mechanical. If a future change adds more args, refactor to an options bag then.

## Gotchas

- **`...(teamId ? { teamId } : {})` vs `teamId: teamId ?? undefined`**: both work. Picked the spread form because it matches the existing pattern in `jobProcessor.ts` for the worker → TRANSCRIBE forwarding. Consistency over brevity.
- **Webhook handler's safe wrapper** (`handleRecallWebhookSafe`) catches unhandled errors and returns 200 to prevent Recall.ai retry storms. teamId passthrough doesn't change error semantics — if the meeting lookup throws, the wrapper still returns 200. Good.
- **The `handleStatusChange` function is only called from `handleRecallWebhook` line 185.** No other call sites need updating. Confirmed via grep.
- **Pre-P5.4.b booked meetings** whose `recallBotId` was set before the booking flow learned about teamId: their `meeting.teamId` will be null in the webhook lookup → personal-attribution path. Correct; no surprise behaviour.

## P5 retrofit chunks — status

| Chunk | Status | Notes |
|---|---|---|
| P5.1 Meetings | ✅ | 5.1.a / 5.1.b / 5.1.c.i / 5.1.c.ii |
| P5.2 Cards | ✅ | 5.2.a / 5.2.b |
| P5.3 Tasks | ✅ | + AI-extracted task encryption fix |
| P5.4 Scheduling | ✅ | 5.4.a / 5.4.b / 5.4.c |
| P5.5 Tags | ✅ | 5.5.a / 5.5.b |
| P5.6 SMA + AI | ✅ | Access-gate + decrypt-principal audit |
| P5.7 Recall webhook | ✅ | This chunk — closing the chain |
| P5.8 Usage endpoint | ⏳ next | `GET /teams/:teamId/usage` + `UserUsage.groupBy([userId, teamId])` schema restructure |

After P5.8 lands, P5 (team-scoped content) is fully closed.

## Verification ideas (post-test)

- Bull payload spot-check on staging: when a Recall webhook fires for a team-booked meeting, inspect the queued FETCH_RECALL_RECORDING job — `data.teamId` should be set.
- UserUsage ledger spot-check: after a team-booked meeting recording is processed, `SELECT userId, teamId, recallHoursUsed FROM "UserUsage" WHERE userId = '<team-owner-userId>'` should show the +1 hour. The host's UserUsage row should NOT have been incremented (unless they ALSO did personal work).
- Personal regression: personal-meeting webhook still queues FETCH_RECALL_RECORDING with no teamId in payload → personal-attribution path.
- Log scan: backend logs show "Recall recording fetch queued" with `teamId: "<team-uuid>"` for team meetings, `teamId: null` for personal.
