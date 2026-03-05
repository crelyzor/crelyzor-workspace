# SMA Pipeline — Dev Notes

## What was built
End-to-end Smart Meeting Assistant pipeline: recording upload → GCS → Deepgram → OpenAI → DB.

## Patterns used
- Bull job queue for async processing — never block the upload response
- Two separate processes: `pnpm dev` (API) + `pnpm dev:worker` (Bull worker). Both must run locally.
- Transcription status flows: `NONE → UPLOADED → PROCESSING → COMPLETED → FAILED`
- Frontend polls `/sma/meetings/:id/transcript/status` until `COMPLETED`

## Gotchas
- **GCS lazy env loading**: GCS client must be lazily initialized — ESM hoisting caused it to crash on import if env vars weren't loaded yet. Fixed by using getter functions (`getGCSClient()`) in `config/`.
- **Deepgram response has markdown-wrapped JSON**: Key points and action items come back wrapped in markdown code fences. Must strip `` ```json ... ``` `` before `JSON.parse()`.
- **OpenAI processing is parallel**: Summary, key points, and action items are extracted in parallel (`Promise.all`) — do not run them sequentially.
- **Speaker labels**: Use `displayName` if set on `MeetingSpeaker`, else fall back to `speakerLabel` (e.g. "Speaker 0"). This matters in Ask AI prompt building.

## Decisions
- Nova-2 model with `diarize: true` — best accuracy + speaker separation for price.
- GPT-4o-mini for all AI processing — good enough, significantly cheaper than GPT-4o.
