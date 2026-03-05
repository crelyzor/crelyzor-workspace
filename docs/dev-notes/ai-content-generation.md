# AI Content Generation — Dev Notes

## What was built
`POST /sma/meetings/:meetingId/generate` — generates Meeting Report, Tweet, Blog Post, Follow-up Email. Results cached in DB per meeting + type.

## Schema
`MeetingAIContent` model — keyed by `(meetingId, type)`. Stores generated text + timestamps.

## Content types built
- `MEETING_REPORT` — full structured report
- `TWEET` — 280-char summary
- `BLOG_POST` — long-form post
- `EMAIL` — follow-up email draft

## Types dropped
- `MAIN_POINTS` — redundant with Summary key points section
- `TODO_LIST` — redundant with Tasks

## Patterns used
- Cache-first: check `MeetingAIContent` before calling OpenAI. Return cached if exists.
- `GET /sma/meetings/:meetingId/generated` — returns all cached content for a meeting (loaded on page open).
- Frontend React Query session cache + DB cache = never regenerates unless user explicitly clicks "Redo".

## Gotchas
- Each type needs its own distinct OpenAI prompt template — generic prompts produce poor output.
- Cache by `(meetingId, type)` — upsert pattern, not insert (so Redo overwrites the cached version).
- Frontend shows loading state per-type, not a global loader — user can generate multiple types simultaneously.
