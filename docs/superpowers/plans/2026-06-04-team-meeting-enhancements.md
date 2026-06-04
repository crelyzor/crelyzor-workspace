# Team Meeting Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add inline task-assignee picker and team-member speaker dropdown to meeting/voicenote detail views when the user is in a team workspace.

**Architecture:** Both features are gated by `activeTeamId` from `useTeamStore` — invisible in personal workspace. `AssigneePicker` already exists at `src/pages/tasks/components/AssigneePicker.tsx` with a `compact` mode; wire it into `ActionsTab`. For speakers, add a `teamMembers?` prop to `SpeakerChip`/`SpeakersSection` that swaps the text input for a popover list.

**Tech Stack:** React 19, TypeScript 5, TanStack Query v5, Zustand, shadcn/ui Popover, Lucide icons

**No backend changes required.** `PATCH /sma/tasks/:taskId` already accepts `assigneeId`, and `PATCH /sma/meetings/:id/speakers/:speakerId` already handles `displayName`.

---

## File Map

| File | Change |
|------|--------|
| `src/pages/meeting-detail/SharedTabs.tsx` | Add `useTeamStore`, `useTeamMembers`, `AssigneePicker` to `ActionsTab`; add optimistic assign handler |
| `src/pages/meeting-detail/meetingDetailHelpers.tsx` | Add `teamMembers?` prop + popover branch to `SpeakerChip`; add `teamMembers?` prop to `SpeakersSection` |
| `src/pages/meeting-detail/RecordedDetail.tsx` | Fetch team members via `useTeamMembers(activeTeamId)`; pass to `SpeakersSection` |

---

## Task 1: Wire AssigneePicker into ActionsTab

**Files:**
- Modify: `src/pages/meeting-detail/SharedTabs.tsx`

### Context

`ActionsTab` lives near the bottom of `SharedTabs.tsx`. It already imports `useQueryClient`, `queryKeys`, `useUpdateTask`, `useDeleteTask`, and the full `Task` type. The `AssigneePicker` component at `src/pages/tasks/components/AssigneePicker.tsx` accepts `{ teamId, value, onChange, compact? }` — `compact={true}` renders a small `w-6 h-6` avatar/icon button that opens a member popover.

- [ ] **Step 1: Add imports**

In `SharedTabs.tsx`, add these three import lines directly after the existing import block (after line ~77 where `formatTimestamp` etc. are imported from `./meetingDetailHelpers`):

```typescript
import { useTeamStore } from '@/stores/teamStore';
import { useTeamMembers } from '@/hooks/queries/useTeamQueries';
import { AssigneePicker } from '@/pages/tasks/components/AssigneePicker';
```

- [ ] **Step 2: Add team-context wiring inside ActionsTab**

Inside `ActionsTab`, after the existing `const { mutate: deleteTask } = useDeleteTask(meetingId);` line, add:

```typescript
const { activeTeamId } = useTeamStore();
const { data: membersData } = useTeamMembers(activeTeamId);
const members = membersData?.members ?? [];
```

- [ ] **Step 3: Add the optimistic assign handler**

After the `handleCreate` function (around line ~803 in the current file), add:

```typescript
const handleAssign = (task: Task, assigneeId: string | null) => {
  const member = assigneeId ? members.find((m) => m.user.id === assigneeId) : null;
  qc.setQueryData(
    queryKeys.sma.tasks(meetingId),
    (old: { tasks: Task[]; total: number; hasMore: boolean } | undefined) =>
      old
        ? {
            ...old,
            tasks: old.tasks.map((t) =>
              t.id === task.id
                ? {
                    ...t,
                    assigneeId: member?.user.id ?? null,
                    assigneeName: member?.user.name ?? null,
                    assigneeAvatarUrl: member?.user.avatarUrl ?? null,
                  }
                : t
            ),
          }
        : old
  );
  updateTask(
    { taskId: task.id, data: { assigneeId } },
    {
      onError: () => {
        qc.setQueryData(
          queryKeys.sma.tasks(meetingId),
          (old: { tasks: Task[]; total: number; hasMore: boolean } | undefined) =>
            old
              ? {
                  ...old,
                  tasks: old.tasks.map((t) =>
                    t.id === task.id
                      ? {
                          ...t,
                          assigneeId: task.assigneeId,
                          assigneeName: task.assigneeName,
                          assigneeAvatarUrl: task.assigneeAvatarUrl,
                        }
                      : t
                  ),
                }
              : old
        );
      },
    }
  );
};
```

- [ ] **Step 4: Add AssigneePicker to each task row**

In the task list JSX, the row currently ends with the delete `<Button>`. Find this block (around line ~920):

```tsx
{/* Delete button — visible on row hover */}
<Button
  variant="ghost"
  size="icon"
  className="shrink-0 h-6 w-6 text-neutral-400 hover:text-red-500 dark:hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity"
  onClick={() => deleteTask(task.id)}
>
  <Trash2 className="w-3 h-3" />
</Button>
```

Replace it with (assignee picker inserted before delete, only shown in team workspace):

```tsx
{/* Assignee picker — team workspace only */}
{activeTeamId && (
  <div className="shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
    <AssigneePicker
      teamId={activeTeamId}
      value={task.assigneeId ?? null}
      onChange={(id) => handleAssign(task, id)}
      compact
    />
  </div>
)}

{/* Delete button — visible on row hover */}
<Button
  variant="ghost"
  size="icon"
  className="shrink-0 h-6 w-6 text-neutral-400 hover:text-red-500 dark:hover:text-red-400 opacity-0 group-hover:opacity-100 transition-opacity"
  onClick={() => deleteTask(task.id)}
>
  <Trash2 className="w-3 h-3" />
</Button>
```

- [ ] **Step 5: Show assignee avatar even when not hovering (assigned tasks)**

The picker above hides on non-hover. But if a task already has an assignee, the avatar should always be visible. Change the wrapper:

```tsx
{/* Assignee picker — team workspace only */}
{activeTeamId && (
  <div className={`shrink-0 transition-opacity ${task.assigneeId ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'}`}>
    <AssigneePicker
      teamId={activeTeamId}
      value={task.assigneeId ?? null}
      onChange={(id) => handleAssign(task, id)}
      compact
    />
  </div>
)}
```

- [ ] **Step 6: Type-check**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
pnpm tsc --noEmit 2>&1 | grep -E "SharedTabs|AssigneePicker|teamStore|teamQueries" | head -20
```

Expected: no errors in those files.

- [ ] **Step 7: Commit**

```bash
git add src/pages/meeting-detail/SharedTabs.tsx
git commit -m "feat(teams): add inline assignee picker to meeting task rows"
```

---

## Task 2: Team-member dropdown for SpeakerChip

**Files:**
- Modify: `src/pages/meeting-detail/meetingDetailHelpers.tsx`

### Context

`SpeakerChip` currently shows a text input + participant quick-pick pills when in edit mode. When `teamMembers` is provided and non-empty, it should instead open a `Popover` with team member rows. The fallback (text input) must remain intact when `teamMembers` is absent or empty.

`SpeakersSection` simply passes `participantNames` through to each chip — needs the same `teamMembers?` prop added and passed through.

- [ ] **Step 1: Update imports in meetingDetailHelpers.tsx**

Replace the current import block at the top of the file:

```typescript
/* eslint-disable react-refresh/only-export-components */
// Shared helpers for MeetingDetail layouts
import { useState, useEffect, useRef } from 'react';
import { Loader2, Users, Pencil } from 'lucide-react';
import type { SMASpeaker } from '@/services/smaService';
import { useRenameSpeaker } from '@/hooks/queries/useSMAQueries';
```

With:

```typescript
/* eslint-disable react-refresh/only-export-components */
// Shared helpers for MeetingDetail layouts
import { useState, useEffect, useRef } from 'react';
import { Check, Loader2, Users, Pencil } from 'lucide-react';
import type { SMASpeaker } from '@/services/smaService';
import type { TeamMemberRow } from '@/services/teamService';
import { useRenameSpeaker } from '@/hooks/queries/useSMAQueries';
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover';
```

- [ ] **Step 2: Add teamMembers prop to SpeakerChip signature**

Find the `SpeakerChip` function signature:

```typescript
export function SpeakerChip({
  speaker,
  meetingId,
  participantNames = [],
}: {
  speaker: SMASpeaker;
  meetingId: string;
  participantNames?: string[];
}) {
```

Replace with:

```typescript
export function SpeakerChip({
  speaker,
  meetingId,
  participantNames = [],
  teamMembers,
}: {
  speaker: SMASpeaker;
  meetingId: string;
  participantNames?: string[];
  teamMembers?: TeamMemberRow[];
}) {
```

- [ ] **Step 3: Add open state for the popover**

Inside `SpeakerChip`, after the existing state declarations (`editing`, `value`), add:

```typescript
const [open, setOpen] = useState(false);
```

- [ ] **Step 4: Add the team-member popover branch**

`SpeakerChip` currently has two return paths: the text-input editing state, and the default pill button. Add a third path — insert it **before** the `if (editing)` block:

```tsx
// Team workspace: popover with member list instead of text input
if (teamMembers && teamMembers.length > 0) {
  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <button
          className="group flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-neutral-100 dark:bg-neutral-800 text-neutral-700 dark:text-neutral-300 border border-neutral-200 dark:border-neutral-700 hover:border-neutral-400 dark:hover:border-neutral-500 transition-colors"
          title={`${speaker.speakerLabel} — click to identify`}
        >
          <span>{speaker.displayName ?? speaker.speakerLabel}</span>
          <Pencil className="w-2.5 h-2.5 text-neutral-400 opacity-0 group-hover:opacity-100 transition-opacity" />
        </button>
      </PopoverTrigger>
      <PopoverContent align="start" sideOffset={4} className="p-1.5 w-48">
        {teamMembers.map((m) => (
          <button
            key={m.user.id}
            type="button"
            className="w-full flex items-center gap-2.5 px-3 py-2 rounded-md text-sm text-neutral-700 dark:text-neutral-300 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
            onClick={() => {
              rename(
                {
                  speakerId: speaker.id,
                  displayName: m.user.name ?? m.user.email,
                },
                { onSettled: () => setOpen(false) }
              );
            }}
          >
            {m.user.avatarUrl ? (
              <img
                src={m.user.avatarUrl}
                alt={m.user.name ?? m.user.email}
                className="w-5 h-5 rounded-full object-cover shrink-0"
                referrerPolicy="no-referrer"
              />
            ) : (
              <div className="w-5 h-5 rounded-full bg-neutral-200 dark:bg-neutral-700 flex items-center justify-center text-[9px] font-semibold text-neutral-600 dark:text-neutral-300 shrink-0">
                {(m.user.name ?? m.user.email)[0].toUpperCase()}
              </div>
            )}
            <span className="flex-1 text-left truncate">
              {m.user.name ?? m.user.email}
            </span>
            {speaker.displayName === (m.user.name ?? m.user.email) && (
              <Check className="w-3.5 h-3.5 text-neutral-500 shrink-0" />
            )}
          </button>
        ))}
        {isPending && (
          <div className="flex items-center justify-center py-2">
            <Loader2 className="w-3.5 h-3.5 animate-spin text-neutral-400" />
          </div>
        )}
      </PopoverContent>
    </Popover>
  );
}
```

- [ ] **Step 5: Add teamMembers prop to SpeakersSection**

Find the `SpeakersSection` function signature:

```typescript
export function SpeakersSection({
  speakers,
  meetingId,
  participantNames,
}: {
  speakers: SMASpeaker[];
  meetingId: string;
  participantNames: string[];
}) {
```

Replace with:

```typescript
export function SpeakersSection({
  speakers,
  meetingId,
  participantNames,
  teamMembers,
}: {
  speakers: SMASpeaker[];
  meetingId: string;
  participantNames: string[];
  teamMembers?: TeamMemberRow[];
}) {
```

- [ ] **Step 6: Pass teamMembers through to each SpeakerChip in SpeakersSection**

Find the `SpeakerChip` usage inside `SpeakersSection`:

```tsx
<SpeakerChip
  key={s.id}
  speaker={s}
  meetingId={meetingId}
  participantNames={participantNames}
/>
```

Replace with:

```tsx
<SpeakerChip
  key={s.id}
  speaker={s}
  meetingId={meetingId}
  participantNames={participantNames}
  teamMembers={teamMembers}
/>
```

- [ ] **Step 7: Update the hint text in SpeakersSection**

Find:

```tsx
<p className="text-[10px] text-neutral-400 dark:text-neutral-500 mt-2">
  {hasUnnamed
    ? 'Click a speaker to name them — or pick from participants'
    : 'Click a speaker to rename'}
</p>
```

Replace with:

```tsx
<p className="text-[10px] text-neutral-400 dark:text-neutral-500 mt-2">
  {teamMembers && teamMembers.length > 0
    ? 'Click a speaker to identify them from your team'
    : hasUnnamed
    ? 'Click a speaker to name them — or pick from participants'
    : 'Click a speaker to rename'}
</p>
```

- [ ] **Step 8: Type-check**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
pnpm tsc --noEmit 2>&1 | grep -E "meetingDetailHelpers|SpeakerChip|SpeakersSection" | head -20
```

Expected: no errors in those files.

- [ ] **Step 9: Commit**

```bash
git add src/pages/meeting-detail/meetingDetailHelpers.tsx
git commit -m "feat(teams): add team-member speaker identification dropdown"
```

---

## Task 3: Feed team members from RecordedDetail

**Files:**
- Modify: `src/pages/meeting-detail/RecordedDetail.tsx`

### Context

`RecordedDetail.tsx` already imports `useTeamStore` — actually it does not yet. It calls `SpeakersSection` without `teamMembers`. This task adds the fetch and wires it through.

- [ ] **Step 1: Add imports to RecordedDetail.tsx**

After the existing import block (around line ~50), add:

```typescript
import { useTeamStore } from '@/stores/teamStore';
import { useTeamMembers } from '@/hooks/queries/useTeamQueries';
```

- [ ] **Step 2: Read activeTeamId and fetch members**

Inside the `RecordedDetail` component, after the existing `const { data: speakers } = useSpeakers(...)` line (around line ~114), add:

```typescript
const { activeTeamId } = useTeamStore();
const { data: membersData } = useTeamMembers(activeTeamId);
```

- [ ] **Step 3: Pass teamMembers to SpeakersSection**

Find the existing `SpeakersSection` call in the JSX (around line ~317):

```tsx
<SpeakersSection
  speakers={speakers}
  meetingId={rawMeeting.id}
  participantNames={rawMeeting.participants
    .map((p) => p.user?.name ?? p.guestEmail ?? null)
    .filter((n): n is string => !!n)}
/>
```

Replace with:

```tsx
<SpeakersSection
  speakers={speakers}
  meetingId={rawMeeting.id}
  participantNames={rawMeeting.participants
    .map((p) => p.user?.name ?? p.guestEmail ?? null)
    .filter((n): n is string => !!n)}
  teamMembers={membersData?.members}
/>
```

- [ ] **Step 4: Full type-check across all three files**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
pnpm tsc --noEmit 2>&1 | head -40
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add src/pages/meeting-detail/RecordedDetail.tsx
git commit -m "feat(teams): wire team members into speakers section from RecordedDetail"
```

---

## Task 4: Manual verification

No automated tests exist for this frontend. Verify manually:

- [ ] **Step 1: Start the dev environment**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace
docker compose up -d
```

- [ ] **Step 2: Switch to a team workspace**

Open `http://localhost:5173`, sign in, switch the workspace selector to a team that has at least one other member.

- [ ] **Step 3: Verify task assignee picker**

Navigate to any meeting with tasks (or voice note at `/meetings/:id`). In the Tasks tab:
- Hover over a task row — confirm a small user icon appears to the left of the delete button
- Click the icon — confirm a popover opens listing team members
- Select a member — confirm the icon swaps to their avatar immediately (optimistic update)
- Hover the avatar — confirm their name shows as a tooltip
- Click the avatar again — confirm "Unassigned" option appears at top; select it — confirm the avatar reverts to the user icon

- [ ] **Step 4: Verify speaker dropdown**

Navigate to a meeting with a completed transcription (Transcript tab shows segments with "Speaker 1", "Speaker 2" etc.). In the speakers section:
- Confirm chips show team members popover on click (not a text input)
- Select a team member — confirm the chip label updates to their name
- Clicking again — confirm the previously selected member has a checkmark

- [ ] **Step 5: Verify personal workspace fallback**

Switch workspace selector back to personal. Open any meeting:
- Task rows: confirm no assignee icon appears anywhere
- Speaker chips: confirm the existing text input + participant pill buttons still work

- [ ] **Step 6: Final commit (if any fixups were made)**

```bash
git add -p
git commit -m "fix(teams): meeting enhancement fixups from manual testing"
```
