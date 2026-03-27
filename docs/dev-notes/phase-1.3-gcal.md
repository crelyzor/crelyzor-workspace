# Phase 1.3 — Google Calendar Deep Integration

Last updated: 2026-03-27 (complete)

---

## Goal

Make Google Calendar invisible infrastructure. The user connects once. From that moment:
- ONLINE meetings auto-generate a Google Meet link
- Every Crelyzor meeting lands in their Google Calendar
- Their full day (GCal events + Crelyzor meetings) lives in one Crelyzor timeline
- Zero context-switch needed

---

## What Already Exists (from Phase 1.2)

Do not rebuild these — extend them.

| What | Location |
|------|----------|
| GCal re-auth OAuth flow | `src/routes/auth/googleOAuthRoutes.ts` + `GET /auth/google/calendar/connect` |
| `OAuthAccount` with scopes + tokens + auto-refresh | `googleCalendarService.ts` → `getAuthedCalendarClient()` |
| `getCalendarBusyIntervals()` — freebusy read | `googleCalendarService.ts` |
| `insertCalendarEvent()` — booking event write | `googleCalendarService.ts` |
| `deleteCalendarEvent()` — booking event delete | `googleCalendarService.ts` |
| `UserSettings.googleCalendarSyncEnabled` + `.googleCalendarEmail` | `schema.prisma` + `UserSettings` model |
| `Booking.googleEventId` | `schema.prisma` |
| Settings > Integrations GCal section (skeleton) | `calendar-frontend` |

---

## Schema Changes

Two new fields on `Meeting`:

```prisma
model Meeting {
  // ... existing fields ...
  meetLink      String?   // Auto-generated Google Meet URL for ONLINE meetings
  googleEventId String?   // GCal event ID — set when synced to Google Calendar
}
```

Run `pnpm db:migrate` after schema update. Name the migration `add_meeting_meet_link_and_google_event_id`.

---

## Backend Implementation

### P0 — `generateMeetLink(userId)`

Add to `googleCalendarService.ts`.

Uses Google Calendar API to create a throwaway event just to get a Meet link — then immediately deletes the event (or uses conference-only creation if available).

**Simpler approach:** Create a real calendar event with `conferenceData.createRequest`, extract the Meet URL, then delete the event. The Meet link persists even after the event is deleted.

```typescript
export async function generateMeetLink(userId: string): Promise<string | null> {
  try {
    const { client } = await getAuthedCalendarClient(userId, true);
    const calendar = google.calendar({ version: 'v3', auth: client });

    // Create a temporary event just to get a Meet link
    const tempEvent = await calendar.events.insert({
      calendarId: 'primary',
      conferenceDataVersion: 1,
      requestBody: {
        summary: 'temp',
        start: { dateTime: new Date().toISOString() },
        end: { dateTime: new Date(Date.now() + 3600000).toISOString() },
        conferenceData: {
          createRequest: { requestId: crypto.randomUUID() },
        },
      },
    });

    const meetLink = tempEvent.data.conferenceData?.entryPoints?.find(
      (ep) => ep.entryPointType === 'video'
    )?.uri ?? null;

    const eventId = tempEvent.data.id;
    if (eventId) {
      // Delete the throwaway event — the Meet link persists
      await calendar.events.delete({ calendarId: 'primary', eventId }).catch(() => {});
    }

    return meetLink;
  } catch (err) {
    logger.warn('generateMeetLink failed — fail-open', { userId, error: String(err) });
    return null;
  }
}
```

**Hook into `meetingService.createMeeting()`:**

```typescript
// After meeting is created in DB:
if (data.locationType === 'ONLINE' && data.addToCalendar !== false) {
  const settings = await prisma.userSettings.findUnique({ where: { userId } });
  if (settings?.googleCalendarSyncEnabled) {
    const meetLink = await generateMeetLink(userId);
    if (meetLink) {
      await prisma.meeting.update({ where: { id: meeting.id }, data: { meetLink } });
      meeting.meetLink = meetLink;
    }
  }
}
```

### P1 — Write Sync for Meetings

New functions in `googleCalendarService.ts` that mirror `insertCalendarEvent` / `deleteCalendarEvent` but accept a `Meeting` record instead of booking params.

```typescript
export async function createGCalEventForMeeting(
  userId: string,
  meeting: { id: string; title: string; startTime: Date; endTime: Date; location?: string | null; meetLink?: string | null }
): Promise<string | null>

export async function updateGCalEventForMeeting(
  userId: string,
  googleEventId: string,
  updates: { title?: string; startTime?: Date; endTime?: Date; location?: string | null; meetLink?: string | null }
): Promise<void>
```

Both are fail-open. `deleteCalendarEvent` already exists and handles the delete case.

**Hook pattern (fail-open wrapper):**

```typescript
// In meetingService — never let GCal failure affect the meeting write
async function syncMeetingToGCal(userId: string, meeting: Meeting) {
  const settings = await prisma.userSettings.findUnique({
    where: { userId },
    select: { googleCalendarSyncEnabled: true, googleCalendarEmail: true }
  });
  if (!settings?.googleCalendarSyncEnabled || !settings.googleCalendarEmail) return;

  try {
    const googleEventId = await createGCalEventForMeeting(userId, meeting);
    if (googleEventId) {
      await prisma.meeting.update({ where: { id: meeting.id }, data: { googleEventId } });
    }
  } catch (err) {
    logger.warn('GCal meeting sync failed', { meetingId: meeting.id, error: String(err) });
  }
}
```

### P2 — Events Endpoint

New route file: `src/routes/integrationRoutes.ts`

```
GET /api/v1/integrations/google/events?start=ISO&end=ISO  → CalendarEvent[]
GET /api/v1/integrations/google/status                    → { connected, email, syncEnabled }
```

`fetchGCalEvents` uses `calendar.events.list` (not freebusy) — returns actual event titles and metadata. Cache 5 min in Redis keyed by `gcal:events:{userId}:{start}:{end}`.

Normalized response shape:
```typescript
interface CalendarEvent {
  id: string;
  title: string;
  startTime: string; // ISO
  endTime: string;   // ISO
  location?: string;
  meetLink?: string;
  isAllDay: boolean;
}
```

---

## Frontend Implementation

### Types

`src/types/integrations.ts` (new file):

```typescript
export interface CalendarEvent {
  id: string;
  title: string;
  startTime: string;
  endTime: string;
  location?: string;
  meetLink?: string;
  isAllDay: boolean;
  source: 'GOOGLE';
}

export interface GoogleCalendarStatus {
  connected: boolean;
  email: string | null;
  syncEnabled: boolean;
}
```

### `TodayTimeline` Component

`src/components/home/TodayTimeline.tsx`

Replaces the current "Today's meetings" home widget. Shows both sources in one chronological list.

Visual distinction:
- Crelyzor meetings: existing card style with ⋯ menu
- GCal events: slightly muted background, Google Calendar icon (use a small `G` badge or calendar icon from Lucide), no ⋯ menu, clicking opens meet link if present

Data: fetch both in parallel, merge and sort by `startTime`.

```typescript
const todayStart = startOfDay(new Date()).toISOString();
const todayEnd = endOfDay(new Date()).toISOString();

const { data: gcalEvents } = useGoogleCalendarEvents(todayStart, todayEnd);
const { data: meetings } = useTodayMeetings(); // existing hook
```

### "Join Meeting" Button

Show in all 3 MeetingDetail layouts when `meeting.meetLink` is set:

```tsx
{meeting.meetLink && (
  <div className="flex items-center gap-2">
    <Button
      size="sm"
      onClick={() => window.open(meeting.meetLink!, '_blank')}
    >
      <Video className="h-3.5 w-3.5 mr-1.5" />
      Join Meeting
    </Button>
    <Button
      size="icon-sm"
      variant="ghost"
      onClick={() => { navigator.clipboard.writeText(meeting.meetLink!); toast.success('Link copied'); }}
    >
      <Copy className="h-3.5 w-3.5" />
    </Button>
  </div>
)}
```

---

## What NOT to Build in Phase 1.3

- **Two-way sync (GCal edits → Crelyzor)** — requires push webhooks (`calendar.events.watch`), channel management, and conflict resolution. Phase 2.
- **Multiple Google accounts** — model supports it (`OAuthAccount[]`) but UX doesn't need it yet.
- **Zoom integration** — Phase 2+.
- **Full calendar page (`/calendar`)** — Phase 3. The `TodayTimeline` home widget is the entry point; the full calendar page builds on top.
- **Tasks on calendar** — Phase 3. `TodayTimeline` is designed to accept a third data source; tasks plug in when `scheduledTime` is added to the Task model.

---

## Build Order (all complete ✅)

```
1.  Schema: meetLink + googleEventId on Meeting  [backend] ✅
2.  DB migration (pnpm db:push)                  [backend] ✅
3.  createGCalEventForMeeting() — one API call   [backend] ✅
    gets both GCal event + Meet URL (no separate
    generateMeetLink step needed)
4.  Hook createMeeting → addToCalendar flag      [backend] ✅
5.  meetLink in all meeting responses (scalar)   [backend] ✅
6.  Frontend: Meeting types + query keys         [frontend] ✅
7.  TodayTimeline component                      [frontend] ✅
8.  useGoogleCalendarEvents hook + service       [frontend] ✅
9.  Wire TodayTimeline into home dashboard       [frontend] ✅
10. GCal write sync (create/update/delete)       [backend] ✅
11. GET /integrations/google/events + status     [backend] ✅
12. "Join Meeting" in all 3 layouts              [frontend] ✅
13. Meeting create form: addToCalendar switch    [frontend] ✅
14. Settings > Integrations: live GCal status   [frontend] ✅
15. DELETE /integrations/google/disconnect       [backend] ✅
```

## Implementation Notes

### Key decisions

**`createGCalEventForMeeting` instead of `generateMeetLink`:**
The spec called for a separate `generateMeetLink` function that creates a throwaway event. The actual implementation combines both steps — `createGCalEventForMeeting` with `requestMeetLink: true` creates the real calendar event AND gets the Meet URL in one API call. Cleaner.

**`addToCalendar` is the opt-out flag:**
Frontend sends `addToCalendar: true` on ONLINE meeting creation. Backend Zod schema accepts it as `boolean?`. GCal sync only fires when `addToCalendar === true` AND GCal is connected. Fail-open: if GCal is not connected, meeting is created without a Meet link (no error).

**VoiceNoteDetail + RecordedDetail meet link:**
These show a simple text link "Join meeting →" in the metadata row (date/duration area), not a button CTA. This is intentional — for past meetings, the Join link is reference info, not a primary action. ScheduledDetail gets the full Button treatment since the user might actually click to join.

**TodayTimeline GCal event interactivity:**
GCal events with `meetLink` render as `motion.a` (clickable, hover, cursor-pointer). GCal events without `meetLink` render as `motion.div` (display-only, no hover, no cursor). This prevents confusing click areas that do nothing.

**Disconnect scope stripping:**
`disconnectGCalendar` strips only `CALENDAR_SCOPE` and `CALENDAR_READONLY_SCOPE` from `OAuthAccount.scopes`. The base Google identity scope is preserved — user stays logged in to Crelyzor. Existing meetings that have `googleEventId` retain the field; GCal sync stops silently (fail-open).

### Gotchas

- GCal event `meetLink` comes from `conferenceData.entryPoints[0].uri` (type = `"video"`), not from `hangoutLink` (deprecated).
- Redis caches GCal events as JSON with `Date` serialized to ISO strings. On cache hit, dates must be re-hydrated (`new Date(cached.startTime)`).
- `motion.a` vs `motion.div` distinction for GCal rows in TodayTimeline is important — mixing them caused event handler issues on rows that should be non-clickable.
- `queryKeys.settings.all` is a plain array (not a function) — spread it correctly: `{ queryKey: queryKeys.settings.all }`, not `{ queryKey: queryKeys.settings.all() }`.
