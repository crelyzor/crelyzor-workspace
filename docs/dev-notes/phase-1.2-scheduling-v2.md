# Phase 1.2 Scheduling — V2 Upgrades

**Status:** Planned. Execute after explicit DB reset confirmation.
**Prerequisite:** Run `prisma db push --force-reset` (dev DB only, no real data).

---

## Context

Three things discovered during Phase 1.2 testing that need to be fixed:

1. **Multiple availability schedules** — current model is one schedule per user. Need Cal.com-style named schedules with multiple time slots per day and per-event-type linking.
2. **Booking status** — bookings currently auto-confirm. Should be PENDING → host approves/declines.
3. **Dashboard Schedule button** — disabled with "coming soon". Should open create SCHEDULED meeting modal.

---

## Task 1 — DB Schema Reset + New Models

> Run first. Everything depends on this.

**Step:** `cd crelyzor-backend && PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION="yes, proceed" prisma db push --force-reset`

**Schema changes:**

### New model: `AvailabilitySchedule`
```prisma
model AvailabilitySchedule {
  id        String  @id @default(uuid()) @db.Uuid
  userId    String  @db.Uuid
  name      String                          // "Working Hours", "Consulting Hours"
  timezone  String  @default("UTC")         // IANA, e.g. "America/New_York"
  isDefault Boolean @default(false)

  isDeleted Boolean   @default(false)
  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  user       User                   @relation(fields: [userId], references: [id])
  slots      Availability[]
  overrides  AvailabilityOverride[]
  eventTypes EventType[]

  @@index([userId, isDeleted])
  @@index([userId, isDefault])
}
```

### Modified: `Availability`
- Remove `userId` — belongs to a schedule now
- Add `scheduleId` FK → `AvailabilitySchedule`
- Remove `@@unique([userId, dayOfWeek])` — multiple slots per day allowed
- Add `@@index([scheduleId, dayOfWeek, isDeleted])`

### Modified: `AvailabilityOverride`
- Replace `userId` with `scheduleId` FK → `AvailabilitySchedule`
- Change `@@unique([userId, date])` → `@@unique([scheduleId, date])`

### Modified: `EventType`
- Add `availabilityScheduleId String? @db.Uuid` — nullable, falls back to default schedule
- Add relation to `AvailabilitySchedule`

### Modified: `BookingStatus` enum
```prisma
enum BookingStatus {
  PENDING     // ← NEW: booking requested, awaiting host approval
  CONFIRMED
  DECLINED    // ← NEW: host declined
  CANCELLED
  RESCHEDULED
  NO_SHOW
}
```

### Modified: `Booking`
- Change default: `status BookingStatus @default(PENDING)`

### Modified: `User`
- Remove `availabilities` and `availabilityOverrides` relations
- Add `availabilitySchedules AvailabilitySchedule[]`

---

## Task 2 — Backend: Schedule CRUD Service + API

**Files to create:**
- `src/services/scheduling/scheduleService.ts`
- `src/controllers/scheduleController.ts`
- `src/validators/scheduleSchema.ts`

**Service functions:**
```typescript
listSchedules(userId)                         // GET all, default first
createSchedule(userId, { name, timezone })    // auto-sets isDefault if first
updateSchedule(userId, id, { name, timezone })
deleteSchedule(userId, id)                    // cannot delete default; reassign first
copySchedule(userId, id, newName)             // deep copy slots + overrides
setDefaultSchedule(userId, id)               // unsets old default, sets new
```

**New routes (add to `schedulingRoutes.ts`):**
```
GET    /scheduling/schedules
POST   /scheduling/schedules
PATCH  /scheduling/schedules/:id
DELETE /scheduling/schedules/:id
POST   /scheduling/schedules/:id/copy
POST   /scheduling/schedules/:id/set-default
```

**Seed logic:** On first call to `getOrCreateUserSettings`, also create a default `AvailabilitySchedule` (name: "Working Hours", timezone: user's timezone or UTC) and seed Mon–Fri 09:00–17:00 slots under it.

---

## Task 3 — Backend: Rewrite Availability Service

**File:** `src/services/scheduling/availabilityService.ts`

**Changes:**
- All functions take `scheduleId` instead of `userId`
- `getAvailability(userId, scheduleId)` — returns all slots grouped by day
- `patchAvailability(userId, scheduleId, slots[])` — upsert multiple slots per day; each slot has `{ dayOfWeek, startTime, endTime }`; allow adding/removing individual slots
- `addSlot(userId, scheduleId, { dayOfWeek, startTime, endTime })`
- `removeSlot(userId, scheduleId, slotId)`
- Overrides: `getOverrides(userId, scheduleId)`, `createOverride(...)`, `deleteOverride(...)`

**Validators update (`availabilitySchema.ts`):**
- Slot schema: `{ dayOfWeek, startTime, endTime }` (no `isOff` flag — absence of slots = unavailable)
- Validate no overlapping slots on the same day

---

## Task 4 — Backend: Update Slot Engine + Booking Service

**File:** `src/services/scheduling/slotService.ts`

**Changes:**
- Load event type's `availabilityScheduleId`; if null, load user's default schedule
- Use schedule's `timezone` field instead of `user.timezone` for availability window calculation
- Replace `findUnique({ userId_dayOfWeek })` with `findMany({ scheduleId, dayOfWeek, isDeleted: false })` — multiple slots, merge windows
- Replace override lookup: use `scheduleId_date` instead of `userId_date`

**File:** `src/services/scheduling/bookingService.ts`

**Changes:**
- Same availability lookup pattern as slot engine
- Change booking creation: `status: "PENDING"` (was `"CONFIRMED"`)
- Remove GCal event creation + Recall bot queuing from `createBooking` — move to `confirmBooking`
- Update conflict check: include `PENDING` bookings as busy (prevent double-booking before approval)

---

## Task 5 — Backend: Booking Approval Flow

**File:** `src/services/scheduling/bookingManagementService.ts`

**New functions:**
```typescript
confirmBooking(userId, bookingId)
// PENDING → CONFIRMED
// Trigger: insertCalendarEvent (fail-open)
// Trigger: queue Recall bot if recallEnabled + ONLINE (fail-open)

declineBooking(userId, bookingId, reason?)
// PENDING → DECLINED
// No GCal, no Recall
```

**New controller:** add `confirmBooking` and `declineBooking` to `bookingManagementController.ts`

**New routes (add to `schedulingRoutes.ts`):**
```
POST /scheduling/bookings/:id/confirm
POST /scheduling/bookings/:id/decline
```

**Validator:** extend `bookingManagementSchema.ts` with `declineBookingBodySchema` (optional reason).

---

## Task 6 — Frontend: Types + Service + Hooks

**File:** `src/types/settings.ts`

Add:
```typescript
export interface AvailabilitySchedule {
  id: string;
  name: string;
  timezone: string;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AvailabilitySlot {
  id: string;
  scheduleId: string;
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  updatedAt: string;
}

export interface ScheduleAvailability {
  dayOfWeek: number;
  slots: AvailabilitySlot[];
}
```

Update `BookingStatus`: add `'PENDING'` and `'DECLINED'`

**File:** `src/services/settingsService.ts`

Add `schedulesApi`:
```typescript
schedulesApi = {
  list()
  create({ name, timezone })
  update(id, { name?, timezone? })
  delete(id)
  copy(id, newName)
  setDefault(id)
  getSlots(scheduleId)           // GET /scheduling/schedules/:id/availability
  patchSlots(scheduleId, slots)  // PATCH /scheduling/schedules/:id/availability
  getOverrides(scheduleId)
  createOverride(scheduleId, date)
  deleteOverride(scheduleId, overrideId)
}
```

Add to `bookingsApi`:
```typescript
confirm(id)
decline(id, reason?)
```

**File:** `src/lib/queryKeys.ts`

Add:
```typescript
scheduling.schedules()
scheduling.scheduleSlots(scheduleId)
scheduling.scheduleOverrides(scheduleId)
```

**File:** `src/hooks/queries/useSchedulingQueries.ts`

Add: `useSchedules`, `useCreateSchedule`, `useUpdateSchedule`, `useDeleteSchedule`, `useCopySchedule`, `useSetDefaultSchedule`, `useScheduleSlots`, `useUpdateScheduleSlots`, `useScheduleOverrides`, `useCreateScheduleOverride`, `useDeleteScheduleOverride`, `useConfirmBooking`, `useDeclineBooking`

---

## Task 7 — Frontend: Redesign Availability Tab

**Design:** Two-panel layout.

**Left panel — Schedule list:**
- List all schedules, default has a star/badge
- "+ New Schedule" button → dialog (name + timezone picker)
- Click schedule to select it
- Each schedule row has: name, timezone, edit name button, copy button, delete button (disabled if default), set-as-default button

**Right panel — Schedule editor (selected schedule):**

*Header:* Schedule name (editable inline), timezone picker (IANA, searchable dropdown)

*Weekly grid:*
- 7 rows (Sun–Sat)
- Each row: day label + list of time slot pairs + "+ Add slot" button
- Each slot: `[start time input] to [end time input] [delete button]`
- Multiple slots per day allowed (e.g. 09:00–12:00 and 14:00–17:00)
- Validation: no overlapping slots on same day, endTime > startTime

*Blocked Dates:*
- Date picker → "Block Date" button
- List of blocked dates as deletable badges
- Scoped to the selected schedule (not global)

*Save button:* saves all dirty slots in one PATCH call

---

## Task 8 — Frontend: Event Type Form — Schedule Picker

**File:** `src/pages/settings/Settings.tsx` → `EventTypesSection`

In the create/edit event type dialog, add a field:

```
Availability Schedule
[ Working Hours (default) ▼ ]
```

- Dropdown populated from `useSchedules()`
- Default option shows "(default)" label
- Value stored as `availabilityScheduleId` (nullable — null = use default)

---

## Task 9 — Frontend: Bookings Tab — PENDING + Approve/Decline

**File:** `src/pages/settings/Settings.tsx` → `BookingsSection`

**Changes:**
- Add `PENDING` and `DECLINED` to status filters
- Default filter: `PENDING` (most actionable view first)
- PENDING bookings show two action buttons: **Approve** (green-ish) and **Decline** (destructive)
- Approve → calls `confirmBooking` mutation → toast "Booking confirmed"
- Decline → opens small dialog with optional reason → calls `declineBooking` → toast "Booking declined"
- Status badge styles: PENDING = amber dot, DECLINED = red dot

---

## Task 10 — Frontend: Enable Dashboard Schedule Button

**File:** `src/components/home/StartMeetingFab.tsx`

- Remove `disabled` and "Soon" badge from the Schedule button
- `onClick`: close FAB menu, navigate to `/meetings?create=scheduled`

**File:** `src/pages/meetings/Meetings.tsx`

- On mount, read `?create=scheduled` search param
- If present: auto-open the existing create SCHEDULED meeting modal, clear the param from URL
- The modal already exists — just needs to be triggered programmatically

---

## Execution Order

```
Task 1  → DB reset (needs user confirmation: "yes, proceed")
Task 2  → Schedule CRUD backend
Task 3  → Availability service rewrite
Task 4  → Slot engine + booking service update
Task 5  → Booking approval endpoints
Task 6  → Frontend service layer
Task 7  → Availability tab UI
Task 8  → Event type schedule picker
Task 9  → Bookings tab PENDING UI
Task 10 → Schedule FAB button
```

Tasks 2–5 can be done in parallel after Task 1.
Tasks 6–10 can be done in parallel after Tasks 2–5 (need the API contracts).
