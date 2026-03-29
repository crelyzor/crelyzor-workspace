# Phase 3 — Todoist-Level Tasks + Calendar View

## Goal

Make tasks a first-class, Todoist-quality system — with views, drag-and-drop, a full detail panel, board view, and Crelyzor-exclusive integrations (meeting context, AI extraction, contact linking, calendar blocking). The `/calendar` page unifies everything.

---

## Why This Matters

Todoist is great but isolated. Crelyzor tasks are **alive** — they know where they came from (a meeting), who they're about (a card contact), and when they need to happen (calendar block). That's the product edge.

---

## Repo Breakdown

| Repo | What changes |
|------|-------------|
| `crelyzor-backend` | Schema additions, new endpoints, view query logic, booking auto-task |
| `crelyzor-frontend` | Entire tasks page rebuild — sidebar nav, detail panel, board view, drag-and-drop, calendar page |
| `crelyzor-public` | No changes needed in Phase 3 |

---

## Schema Changes (`crelyzor-backend/prisma/schema.prisma`)

```prisma
enum TaskStatus {
  TODO
  IN_PROGRESS
  DONE
}

model Task {
  // existing fields ...

  // NEW
  status        TaskStatus  @default(TODO)        // replaces isCompleted boolean
  sortOrder     Int         @default(0)           // drag-to-reorder position
  parentTaskId  String?     @db.Uuid              // subtasks (self-referential)
  cardId        String?     @db.Uuid              // linked card contact

  parent        Task?       @relation("Subtasks", fields: [parentTaskId], references: [id])
  subtasks      Task[]      @relation("Subtasks")
  card          Card?       @relation(fields: [cardId], references: [id], onDelete: SetNull)

  @@index([parentTaskId])
  @@index([cardId])
  @@index([userId, status, isDeleted])
  @@index([sortOrder])
}
```

**Migration note:** `isCompleted` stays on the model for backwards-compatibility during transition. `status = DONE` is the source of truth. Write a migration that sets `status = DONE` where `isCompleted = true`. After frontend is fully migrated, `isCompleted` can be dropped.

---

## New + Modified API Endpoints (`crelyzor-backend`)

### Modified: `GET /tasks`

Add `view` query param:

| view | Logic |
|------|-------|
| `inbox` | `dueDate IS NULL AND scheduledTime IS NULL` |
| `today` | `dueDate <= end of today` (includes all overdue) |
| `upcoming` | `dueDate between tomorrow and +7 days` |
| `all` | no date filter (current behavior) |
| `from_meetings` | `meetingId IS NOT NULL` |

Response for `upcoming` view: return tasks pre-grouped by date (array of `{ date, tasks[] }`).

### New: `PATCH /tasks/reorder`

```typescript
// Body
{ taskIds: string[] }  // ordered array of task IDs

// Logic: set sortOrder = index for each task in the array
// Scope to userId — never reorder another user's tasks
```

### Modified: `POST /tasks` + `PATCH /tasks/:id`

Accept `cardId`, `parentTaskId`, `status` fields.

### New: `GET /tasks/:id/subtasks`

Returns direct children of a task (`parentTaskId = :id`, scoped to `userId`).

### New: `POST /tasks/:id/subtasks`

Creates a task with `parentTaskId = :id`. Inherits `userId` from parent.

### Modified: `bookingManagementService.ts` — auto-create Prepare task

When booking status changes to `CONFIRMED`:
```typescript
// Auto-create task
await prisma.task.create({
  data: {
    userId: booking.eventType.userId,
    meetingId: booking.meetingId,
    title: `Prepare for ${booking.eventType.title} with ${booking.guestName}`,
    dueDate: subHours(booking.startTime, 1),
    priority: 'MEDIUM',
    source: 'MANUAL',
    status: 'TODO',
  }
})
```

---

## Frontend Architecture (`crelyzor-frontend`)

### Route structure

```
/tasks                     → redirects to /tasks/inbox
/tasks/inbox               → Inbox view
/tasks/today               → Today view
/tasks/upcoming            → Upcoming view
/tasks/all                 → All Tasks view
/tasks/from-meetings       → From Meetings view
```

Detail panel is NOT a route — it's a slide-over that sits alongside any view. URL can optionally update to `/tasks/today?task=:id` for deep linking.

### Component tree

```
TasksLayout
├── TasksSidebar          ← nav: Inbox / Today / Upcoming / All / From Meetings
├── TasksViewHeader       ← title, view toggle (List/Board/Grouped), add button
├── TasksViewRouter       ← renders the active view
│   ├── InboxView
│   ├── TodayView
│   ├── UpcomingView      ← grouped by date
│   ├── AllTasksView
│   └── FromMeetingsView  ← grouped by meeting
├── TaskDetailPanel       ← right slide-over, opens on row click
└── QuickAddBar           ← global Cmd+K handler
```

### TaskDetailPanel fields

- Title (inline editable `<textarea>` that auto-resizes)
- Description (plain text, multiline)
- Due date (date picker)
- Scheduled time (start + end time picker — creates calendar block)
- Priority (P1 / P2 / P3 / P4 pill selector)
- Status (TODO / IN PROGRESS / DONE toggle)
- Tags (multi-select from user's tags)
- Linked meeting (chip with meeting title, click → navigate to meeting)
- Linked contact (card picker — search by name)
- Subtasks (inline list with add input)

### TaskRow design

```
[ priority border ] [ ○ toggle ] [ title ]  [ meeting chip ]  [ contact avatar ]  [ due date ]  [ tags ]  [ ··· ]
```

- Left border 3px: red (P1), orange (P2), sky (P3), transparent (P4/none)
- Due date: gray if future, red + "Overdue" if past
- Meeting chip: truncated title, click → navigate
- Contact avatar: initials circle, click → navigate to card
- Hover → delete icon appears (far right)
- Click row (not on interactive elements) → opens TaskDetailPanel

### Board view columns

```
TODO          IN PROGRESS      DONE
────────      ───────────      ────
[task]        [task]           [task]
[task]                         [task]
+ Add task
```

Drag between columns → `PATCH /tasks/:id` with `{ status: 'IN_PROGRESS' }`.

### Drag and drop library

Use `@dnd-kit/core` + `@dnd-kit/sortable` — already the standard for React. Handles both list reorder and board column drag.

### From Meetings view — the Crelyzor exclusive

Tasks grouped by meeting:

```
Q4 Strategy Kickoff  ·  Dec 10
  ○  Draft the proposal deck          AI
  ○  Send budget to finance            AI
  ✓  Schedule follow-up               Manual

1:1 with Sarah  ·  Dec 8
  ○  Update roadmap doc               AI
```

- Hover task row → tooltip shows the exact transcript line that generated it (from `transcriptContext` — store this when AI extracts tasks)
- Click meeting header → navigate to meeting detail
- Completed tasks shown collapsed under a "Show completed" toggle

**Backend note:** AI task extraction in `aiService.ts` should store `transcriptContext: string` (the relevant sentence) when `source = AI_EXTRACTED`. Add this field to the `Task` schema.

---

## Integration Points (cross-repo)

| Trigger | Where | What happens |
|---------|-------|-------------|
| AI extracts tasks from meeting transcript | `crelyzor-backend/aiService.ts` | Tasks created with `meetingId`, `source: AI_EXTRACTED`, `transcriptContext` |
| Booking confirmed | `crelyzor-backend/bookingManagementService.ts` | "Prepare for..." task auto-created with `meetingId`, `dueDate = startTime - 1hr` |
| Task has `scheduledTime` | `crelyzor-frontend/calendar` | Appears as time block on `/calendar` |
| Task has `cardId` | `crelyzor-frontend/cards` | Task appears in Card detail page under "Related Tasks" |
| Drag task to calendar slot | `crelyzor-frontend/calendar` | Sets `scheduledTime` via `PATCH /tasks/:id` |
| Click meeting chip on task | `crelyzor-frontend/tasks` | Navigate to `/meetings/:id` |

---

## Natural Language Quick-Add Parser

Simple regex, no LLM:

```typescript
// Input: "Follow up with John tomorrow P1 #Launch"
// Parse:
// - title: "Follow up with John"
// - dueDate: tomorrow (relative date keywords: today, tomorrow, next week, mon/tue/etc.)
// - priority: P1 (pattern: /\bP[1-4]\b/i)
// - tags: ["Launch"] (pattern: /#(\w+)/g)
```

Keywords: `today`, `tomorrow`, `next week`, `monday`–`sunday` → resolve to absolute dates.

---

## Build Order (sequential)

1. **Schema migration + API** — P0 backend work. Unblocks everything else.
2. **Task detail panel** — biggest UX gap. Do this before any view work.
3. **Task row redesign** — update existing list with new design system.
4. **Sidebar nav + Today/Upcoming/Inbox views** — makes it feel like Todoist.
5. **Board view** — needs `status` field from step 1.
6. **From Meetings view** — most Crelyzor-specific, highest value.
7. **Drag and drop** — polish layer on top of working list/board.
8. **Global quick-add** — final polish.
9. **Calendar page** — `/calendar` route with unified view.

---

## Gotchas

- Always scope task queries to `userId`. Subtask queries must verify the parent task belongs to the user.
- `sortOrder` is per-user, per-view. Reorder API must only update tasks belonging to the authenticated user.
- When `status` is set to `DONE`, also set `isCompleted = true` and `completedAt = now()` for backwards compatibility until `isCompleted` is fully deprecated.
- `transcriptContext` field on Task is optional — only set when `source = AI_EXTRACTED`. Don't require it on manual tasks.
- Board view drag between columns should be optimistic — update UI immediately, roll back on API error.
- `@dnd-kit/core` requires each draggable to have a unique string `id`. Use task UUIDs directly.
