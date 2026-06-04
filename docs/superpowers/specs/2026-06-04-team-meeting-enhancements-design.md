# Team Meeting Enhancements — Design Spec

**Date:** 2026-06-04
**Phase:** 6 — Teams
**Scope:** `crelyzor-frontend` only — no backend changes required

---

## Overview

Two UI enhancements for the meeting/voicenote detail views when the user is in a team workspace:

1. **Task Assignee Picker** — assign AI-extracted or manually created tasks to team members inline
2. **Speaker → Team Member Dropdown** — identify transcript speakers by picking from a team member list instead of typing

Both features are **team-workspace-only**: they appear only when `activeTeamId` is set in `useTeamStore`. Personal workspace users see no change.

---

## Architecture & Data Flow

### Team context gate
```
useTeamStore().activeTeamId
  null  → personal workspace → features invisible, no code path changes
  uuid  → team workspace     → features active
```

### Team member data
- Fetched via the existing `useTeamMembers(activeTeamId)` hook (`src/hooks/queries/useTeamQueries.ts`)
- Returns `{ members: TeamMemberRow[] }` where each row has `user.id`, `user.name`, `user.email`, `user.avatarUrl`
- **Task assignee picker:** `ActionsTab` reads `activeTeamId` from `useTeamStore` and calls `useTeamMembers` internally — no prop changes to callers (`RecordedDetail`, `VoiceNoteDetail`)
- **Speaker dropdown:** `RecordedDetail` reads `activeTeamId` + calls `useTeamMembers`, passes `teamMembers` down to `SpeakersSection` → `SpeakerChip` as a new optional prop

### Backend
No new endpoints. Existing surfaces cover both features:
- `PATCH /sma/tasks/:taskId` — already accepts `assigneeId?: string | null`
- `PATCH /sma/meetings/:id/speakers/:speakerId` — already accepts `displayName`

---

## Feature 1: Task Assignee Picker

### Files changed
- `src/pages/meeting-detail/SharedTabs.tsx` — `ActionsTab` component

### UI

Each task row gets an **assignee button** at the right end, to the left of the existing delete button.

| State | Appearance |
|-------|-----------|
| Unassigned | Ghost `UserPlus` icon button, `h-6 w-6` |
| Assigned | `w-5 h-5` Avatar (photo or initials fallback), subtle ring on hover |

Clicking either opens a **Popover** (aligned to `end`):
- Scrollable list of team members: `avatar + name + designation`
- "Remove assignee" row at the bottom — only shown when a member is currently assigned
- No search input (team sizes are small)
- While `useTeamMembers` is loading: show 3 skeleton rows inside the popover

### Interaction
1. User clicks assignee button
2. Popover opens with member list
3. User selects a member → `updateTask(task.id, { assigneeId: member.user.id })`
4. Optimistic update: immediately swaps icon to member's avatar (same pattern as `handleToggle`)
5. On error: roll back to previous assignee state

If user clicks "Remove assignee" → `updateTask(task.id, { assigneeId: null })`

### Data already available
`Task` type already carries `assigneeId`, `assigneeName`, `assigneeAvatarUrl` — avatar renders from cached task data, no extra fetch.

### Applies to
- `RecordedDetail` (meetings with transcription)
- `VoiceNoteDetail` (voice notes) — both use `ActionsTab`

---

## Feature 2: Speaker → Team Member Dropdown

### Files changed
- `src/pages/meeting-detail/meetingDetailHelpers.tsx` — `SpeakerChip`, `SpeakersSection`
- `src/pages/meeting-detail/RecordedDetail.tsx` — fetch team members, pass down

### Prop changes

```typescript
// SpeakerChip
{
  speaker: SMASpeaker;
  meetingId: string;
  participantNames?: string[];       // existing — kept for personal workspace fallback
  teamMembers?: TeamMemberRow[];     // new — team workspace
}

// SpeakersSection
{
  speakers: SMASpeaker[];
  meetingId: string;
  participantNames?: string[];       // existing
  teamMembers?: TeamMemberRow[];     // new
}
```

### Behaviour

**Team workspace (`teamMembers` provided and non-empty):**
- Clicking a speaker chip opens a **Popover** (replaces the current text input)
- Popover shows team member list: `avatar + name + designation`
- Selecting a member → `rename({ speakerId: speaker.id, displayName: member.user.name ?? member.user.email })`
- Chip then displays the chosen name with pencil icon for re-editing

**Personal workspace or no members (`teamMembers` absent or empty):**
- Falls back to the existing text input + participant name pill buttons — zero regression

### Edge case: pre-existing display name
A speaker may already have a `displayName` set (from before the team existed, or from a personal meeting). The chip still displays that name and opens the team picker on click. Selecting a member overwrites it.

### Applies to
- `RecordedDetail` only — `VoiceNoteDetail` has no speakers section

---

## Out of Scope

- Adding `assigneeId` to `createTask` (meeting-specific) — assign after creation via the inline picker
- Speaker identification for voicenotes — voicenotes do not have a speakers section
- Any backend changes
- Personal workspace task assignment to team members

---

## Component Inventory

| Component | File | Change |
|-----------|------|--------|
| `ActionsTab` | `SharedTabs.tsx` | Add `useTeamStore`, `useTeamMembers`, assignee button + popover per task row |
| `SpeakerChip` | `meetingDetailHelpers.tsx` | Add `teamMembers?` prop; swap text input for member popover in team context |
| `SpeakersSection` | `meetingDetailHelpers.tsx` | Add `teamMembers?` prop; pass through to `SpeakerChip` |
| `RecordedDetail` | `RecordedDetail.tsx` | Add `useTeamMembers(activeTeamId)`, pass `teamMembers` to `SpeakersSection` |
