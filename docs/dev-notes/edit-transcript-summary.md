# Edit Transcript / Summary

## What Was Built

Inline editing for transcript segments and AI summary content.

**Backend:**
- `PATCH /sma/meetings/:meetingId/transcript/segments/:segmentId` — edit segment text
- `PATCH /sma/meetings/:meetingId/summary` — edit summary, key points, or meeting title

**Frontend:**
- `SegmentRow` component — hover shows pencil, click text or pencil to edit inline
- `SummaryTab` — pencil buttons next to "AI Summary" and "Key Points" headings

## Files

**Backend:**
- `src/validators/transcriptEditSchema.ts` — Zod schemas
- `src/services/smaEditService.ts` — `updateSegment()` + `updateSummary()`
- `src/controllers/transcriptController.ts` — `patchSegment`, `patchSummary` handlers
- `src/routes/smaRoutes.ts` — 2 PATCH routes

**Frontend:**
- `src/services/smaService.ts` — `patchSegment()`, `patchSummary()`
- `src/hooks/queries/useSMAQueries.ts` — `useUpdateSegment()`, `useUpdateSummary()`
- `src/pages/meeting-detail/SharedTabs.tsx` — `SegmentRow`, updated `SummaryTab`

## Patterns

**Segment ownership verification** — must traverse the full chain via Prisma nested where:
```typescript
prisma.transcriptSegment.findFirst({
  where: {
    id: segmentId,
    transcript: {
      recording: { meetingId, meeting: { createdById: userId, isDeleted: false } },
    },
  },
})
```
`TranscriptSegment` has no `userId` or `isDeleted` — ownership goes through `recording.meeting`.

**Summary + title in one transaction** — `MeetingAISummary` and `Meeting` are different models. When both are updated together, use `$transaction`. Even for title-only updates (update meeting + read summary), wrap in `$transaction` for convention compliance.

**`patchSummary` returns `{ summary, title? }`** — the frontend `useUpdateSummary` invalidates `meetings.detail` when `title` is present in the response, which refreshes the meeting header.

## Gotchas

- `TranscriptSegment` has no soft delete field — it cascade-deletes from `MeetingTranscript`. Don't add `isDeleted` checks on segments.
- The transcript's `fullText` field is NOT updated when a segment is edited. It's the original raw Deepgram output. Only `TranscriptSegment.text` is updated — this is intentional (segments are the display source, fullText is for AI processing history).
- `MeetingAISummary` is 1:1 with `meetingId` (unique constraint). Always use `findUnique` / `update where: { meetingId }`.
- Use `invalidateQueries` (not optimistic updates) for segment edits — transcript arrays can be large and partial optimistic patching is fragile.
- Pre-existing: `getTranscript` and `getTranscriptionStatus` in `transcriptController.ts` were using `res.json()` directly. Fixed during this PR to use `apiResponse` + `AppError`.

## UX Decisions

- Transcript: click on text OR hover pencil to enter edit mode. Escape cancels.
- Summary: explicit pencil button (not click-on-text) to avoid accidental edits in a longer paragraph.
- Key Points: edited as a textarea with one point per line — split on `\n`, filter empty lines on save.
- No `toast.success` on segment save (silent update — text changes in place). Summary save shows `toast.success('Saved')`.
