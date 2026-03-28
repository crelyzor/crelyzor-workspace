# Phase 1.4 — Recall.ai Platform Integration (Implementation Notes)

## What Was Built

Migrated Recall.ai from a per-user BYO-key model to a platform-level service. One `RECALL_API_KEY` in the backend `.env` serves all users. Users see a simple "Auto-record online meetings" toggle in Settings — no API key management.

Also expanded bot deployment scope: bots now deploy for manual SCHEDULED meetings with video links, not just bookings.

## Changes Made

### Backend
- **Schema:** Dropped `recallApiKey` from `UserSettings`. `recallEnabled` kept as user toggle.
- **Environment:** Replaced `RECALL_ENCRYPTION_KEY` with `RECALL_API_KEY` in Zod env schema.
- **recallService.ts:** Reads key from `env.RECALL_API_KEY` internally. Added `joinAt` param + `automatic_leave` config. Removed `assembly_ai` transcript provider (we use our own Deepgram pipeline).
- **jobProcessor.ts:** Removed all `decrypt()` calls and per-user key queries. Worker uses platform key. Added `joinAt` calculation (5 min before startTime).
- **userSettingsService.ts:** `toClientSettings` now appends `recallAvailable: boolean` (derived from `!!env.RECALL_API_KEY`). Removed encryption import. Enabling `recallEnabled` checks env key instead of per-user key.
- **Routes/Controller:** Removed `PUT /settings/recall-api-key` endpoint entirely.
- **Deleted:** `src/utils/encryption.ts` (only Recall used it), `saveRecallApiKeySchema` from validators.
- **meetingService.ts:** After creating a SCHEDULED meeting, checks for video link + recallEnabled + RECALL_API_KEY and queues bot deploy job.
- **isVideoMeetingUrl.ts:** New utility — allowlist of known video platforms (Google Meet, Zoom, Teams, Webex) prevents arbitrary URLs from being sent to Recall API.

### Frontend
- **types/settings.ts:** Replaced `hasRecallApiKey` with `recallAvailable: boolean`.
- **settingsService.ts:** Removed `saveRecallApiKey()` method.
- **useSettingsQueries.ts:** Removed `useSaveRecallApiKey` hook.
- **Settings.tsx:** Replaced API key input section with simple toggle card. Shows disabled state when `!recallAvailable`. Label: "Auto-record online meetings" (vendor name hidden).

## Patterns

- **Platform key pattern:** Same as OpenAI, Deepgram, GCS — key in `.env`, validated in `environment.ts` Zod schema (optional), accessed via `env.RECALL_API_KEY`. Feature gracefully degrades when key absent.
- **Fail-open for external services:** Bot deploy in `meetingService.ts` uses try/catch with empty catch — same pattern as GCal sync. External service failure never blocks core operations.
- **URL allowlist:** `isVideoMeetingUrl()` validates URLs before passing to third-party APIs. Prevents SSRF-by-proxy with user-supplied `location` field.

## Decisions

1. **Collapsed P0 + P1 into one atomic change** — dropping the schema column and env var while code still referenced them would create a broken intermediate state. All changes shipped together.
2. **bookingManagementService.ts was already clean** — only checked `recallEnabled`, never touched `recallApiKey` directly. No changes needed.
3. **Worker calculates `joinAt` from `meeting.startTime`** — 5 minutes before start, passed as ISO string to Recall API. This replaces the booking service's delay calculation for the job queue timing.
4. **`location` fallback requires URL validation** — security review flagged that `location` is free-text user input. Added `isVideoMeetingUrl()` allowlist to prevent non-video URLs from being sent to Recall.

## Gotchas

- `.env.example` was very outdated (still referenced MongoDB). Rewrote it completely to match current `environment.ts` schema.
- The `setRecallKeySaved` state variable in Settings.tsx was referenced but never declared — it was a latent bug in the old code. Removed along with the entire API key section.
- Repo directories are named `crelyzor-backend` / `crelyzor-frontend` / `crelyzor-public`, not `calendar-backend` / `calendar-frontend` / `cards-frontend`. The CLAUDE.md uses the old names. Subagents need the actual paths.
