# Phase 1.4 — Recall.ai Platform Integration

## Summary

Recall.ai moves from a per-user BYO-key integration to a **platform-level service**. One `RECALL_API_KEY` in the backend `.env`, managed by us. Users see a simple toggle — no API key management.

## Why

1. **Consistency** — Deepgram, OpenAI, GCS are all platform keys. Recall was the only outlier asking users to create a separate account.
2. **Friction** — "Create Recall.ai account → get API key → paste into settings" kills conversion. A toggle doesn't.
3. **Cost control** — We pay per bot-minute. For early solo users this is negligible and predictable.
4. **Simplicity** — One key, one place, no encryption layer needed for per-user storage.

## Architecture Change

```
BEFORE (per-user key):
  User saves API key → encrypted in UserSettings.recallApiKey (AES-256-GCM)
  Worker decrypts per-user key → calls Recall API
  Frontend: API key input + show/hide + save button + toggle

AFTER (platform key):
  RECALL_API_KEY in .env → recallService reads from env
  Worker calls Recall API with platform key
  User toggles recallEnabled on/off (no key management)
  Frontend: simple toggle, shown only when platform supports Recall
```

## Recall Bot Configuration Changes

**Transcript provider:** Changed from `assembly_ai` to Deepgram (via our own pipeline — bot records, we download recording, run through existing Deepgram + AI pipeline).

**Bot deployment payload (new):**
```json
{
  "meeting_url": "<link>",
  "bot_name": "Crelyzor",
  "join_at": "<ISO 5 min before start>",
  "automatic_leave": {
    "waiting_room_timeout": 600,
    "noone_joined_timeout": 180
  }
}
```

**Bot deployment scope (expanded):**
- Phase 1.2: only deployed when a booking is confirmed (ONLINE event type)
- Phase 1.4: also deployed when a manual SCHEDULED meeting is created with a meeting link (`meetingLink` or `meetLink`)

## Schema Changes

**UserSettings:**
```diff
- recallApiKey     String?  // encrypted at rest — REMOVED
  recallEnabled    Boolean @default(false)  // KEPT — user toggle
```

**Environment:**
```diff
+ RECALL_API_KEY=<platform-level key>       // Required for Recall features
  RECALL_WEBHOOK_SECRET=<webhook-hmac-key>  // Already exists
- RECALL_ENCRYPTION_KEY=<64-char-hex>       // REMOVED — no per-user encryption
```

## Pipeline (unchanged in concept)

```
Booking confirmed OR manual meeting created (with link + recallEnabled)
  → Queue delayed job (5 min before start)
  → Worker reads RECALL_API_KEY from env
  → deployBot(meetingLink) → Recall bot joins call
  → Bot records → call ends → Recall fires webhook
  → Webhook: "done" status → queue recording fetch job
  → Download recording → upload to GCS → transcription → AI processing
  (Same pipeline as manual uploads — one code path for everything)
```

## Frontend Changes

**Settings > Integrations > Recall section:**
- Remove: API key input, save button, "API key saved" badge
- Keep: toggle "Auto-record online meetings"
- New: toggle only shown when backend reports `recallAvailable: true`
- New: disabled state "Recording bot not available on this instance" when `!recallAvailable`
- Copy change: "Enable Recall.ai bot" → "Auto-record online meetings" (don't expose vendor name)

## Decisions

1. **Don't use Recall's built-in transcript** — We download the recording and run it through our own Deepgram pipeline. One transcription path for everything (manual uploads + Recall recordings). Simpler, more control, consistent quality.

2. **`recallAvailable` flag** — Backend sends this in `GET /settings/user` so frontend knows whether to show the toggle at all. Derived from `!!process.env.RECALL_API_KEY`. Self-hosted instances without a Recall key gracefully hide the feature.

3. **Encryption utilities** — If only Recall used `encrypt`/`decrypt`, remove `encryption.ts` entirely. If other features use it, just remove Recall imports.

4. **Manual meetings get Recall too** — Not just bookings. If user creates a SCHEDULED meeting with a video call link, and `recallEnabled` is true, deploy bot.

## Risks

- **Rate limits:** One Recall account serves all users. Fine for MVP. Add per-user rate limits later if needed.
- **Bot deployed, user disables toggle mid-meeting:** Webhook handler already checks `recallEnabled` — recording won't be processed. Bot leaves naturally.
- **No RECALL_API_KEY in env:** Features gracefully degrade. `recallAvailable: false`, toggle hidden. No errors.
- **Existing encrypted keys in DB:** Migration drops `recallApiKey` column. Old encrypted data is discarded — harmless.

## Reference

Patterns inspired by (but not copied from) `sma-backend` at `/Users/harshkeshari/Developer/experimentlabs-workspace/sma-backend`:
- Platform-level API key in env (not per-user)
- `join_at` + `automatic_leave` in bot deployment payload
- `bot.status_change` webhook handling with status flow
- Recording download as stream → GCS upload
- Deepgram as transcript provider (not AssemblyAI)
