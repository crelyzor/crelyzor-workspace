---
description: Scan calendar-backend for Prisma queries missing isDeleted: false filter — the most dangerous soft-delete bug in Crelyzor.
allowed-tools: [Read, Glob, Grep, Bash]
---

Scan `calendar-backend/src` for unsafe Prisma queries.

## What to look for

### 1. Missing soft-delete filter
Any `findMany`, `findFirst`, or `findUnique` on user-data models that doesn't include `isDeleted: false`.

Models that have soft delete: `Meeting`, `Card`, `Task`, `MeetingNote`, `MeetingRecording`, `CardContact`, `MeetingAISummary`

Safe pattern:
```typescript
prisma.meeting.findMany({ where: { userId, isDeleted: false } })
```

Unsafe pattern:
```typescript
prisma.meeting.findMany({ where: { userId } }) // missing isDeleted filter!
```

### 2. Hard deletes on protected models
Any `prisma.[model].delete(` on user data models — should use soft delete instead:
```typescript
// Wrong
await prisma.meeting.delete({ where: { id } })

// Right
await prisma.meeting.update({ where: { id }, data: { isDeleted: true, deletedAt: new Date() } })
```

### 3. Missing userId scope
Any query that fetches by `id` alone without scoping to `userId`:
```typescript
// Wrong — any user can fetch any meeting
prisma.meeting.findUnique({ where: { id } })

// Right
prisma.meeting.findUnique({ where: { id, userId } })
```

## Output Format

```
DB SAFETY REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRITICAL — Missing isDeleted filter:
  - services/meeting/meetingService.ts:45 — findMany missing isDeleted: false
  - services/task/taskService.ts:23 — findFirst missing isDeleted: false

CRITICAL — Hard delete on protected model:
  - services/card/cardService.ts:67 — prisma.card.delete() found

WARNING — Missing userId scope:
  - services/meeting/meetingService.ts:89 — findUnique by id only

All clear ✓ (if nothing found)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Fix all CRITICAL issues immediately and show the corrected code.
