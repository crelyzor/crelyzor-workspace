# MeetingDetail — 3 Layouts — Dev Notes

## What was built
Three distinct MeetingDetail layouts based on `MeetingType`. A thin router shell picks the right layout.

## Layout map
| Type | Component | Layout style |
|------|-----------|-------------|
| `VOICE_NOTE` | `VoiceNoteDetail` | Minimal header, flat scroll (no tabs) |
| `RECORDED` | `RecordedDetail` | Compact header, speakers section, tabs |
| `SCHEDULED` | `ScheduledDetail` | Full header with status badge + participants + quick actions, tabs |

## Patterns used
- `MeetingDetail` is a thin shell — reads `meeting.type`, renders the right layout component.
- All 3 layouts share the same React Query hooks (`useNotes`, `useTasks`, `useTranscript`, etc.).
- Transcription status polling lives in the shell — passed down as prop.
- 30s post-`COMPLETED` polling for AI title (title generation is async after transcription).

## Sections present in all 3 layouts
Notes, Tasks, Ask AI, Generate (AI content), Share sheet.

## Gotchas
- `VOICE_NOTE` has no participants, no conflict detection, no scheduling fields — guard these in `ScheduledDetail` only.
- Recording player only shows when `MeetingRecording` exists — always check before rendering.
- `MeetingProvider` field must be on `DisplayMeeting` type — was missing initially and caused runtime errors.

## Decisions
- Flat scroll for voice notes (no tabs) — voice notes are quick captures, tabs add friction.
- Tabs for recorded/scheduled — they have more content sections and users need to jump between them.
