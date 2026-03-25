# Phase 1.2 — Scheduling & Online Meetings

Design decisions, data model, flows, and implementation notes.

---

## What We're Building

A solo professional can:
1. Set their weekly availability and create event types ("30-min call", "1-hour consult")
2. Share `/schedule/:username` — guests pick a time and book
3. Booking creates a `Meeting` in Crelyzor automatically
4. If Google Calendar is connected → busy times are respected + a Calendar event is created
5. If Recall.ai is enabled + event type is ONLINE → bot joins and auto-transcribes

The existing Phase 1 recording/transcription/AI pipeline is **unchanged** — scheduling is just a new way for meetings to get created.

---

## Data Model

### `UserSettings` (new — one-to-one with User)

Keeps User table clean. All feature flags and scheduling config live here.

```prisma
model UserSettings {
  id     String @id @default(uuid()) @db.Uuid
  userId String @unique @db.Uuid

  // Scheduling
  schedulingEnabled   Boolean @default(true)
  minNoticeHours      Int     @default(24)   // min hours before a slot can be booked
  maxWindowDays       Int     @default(60)   // how far out guests can book
  defaultBufferMins   Int     @default(15)   // gap between back-to-back bookings

  // Integrations
  googleCalendarSyncEnabled Boolean @default(false)
  googleCalendarEmail       String? // connected account
  recallEnabled             Boolean @default(false)
  recallApiKey              String? // encrypted at rest

  // AI & Transcription
  autoTranscribe      Boolean @default(true)
  autoAIProcess       Boolean @default(true)
  defaultLanguage     String  @default("en")

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)
}
```

### `EventType` (new)

```prisma
model EventType {
  id          String       @id @default(uuid()) @db.Uuid
  userId      String       @db.Uuid
  title       String                          // "30-min intro call"
  slug        String                          // "intro" → /schedule/:username/intro
  description String?
  duration    Int                             // minutes
  locationType LocationType @default(IN_PERSON)
  meetingLink String?                         // Zoom/Meet URL — ONLINE only
  bufferBefore Int         @default(0)        // minutes
  bufferAfter  Int         @default(0)        // minutes
  maxPerDay    Int?                           // null = unlimited
  isActive    Boolean      @default(true)

  isDeleted Boolean   @default(false)
  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  user     User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  bookings Booking[]

  @@unique([userId, slug])
  @@index([userId, isActive])
  @@index([userId, isDeleted])
}

enum LocationType {
  IN_PERSON
  ONLINE
}
```

### `Availability` (new)

User's repeating weekly schedule.

```prisma
model Availability {
  id        String @id @default(uuid()) @db.Uuid
  userId    String @db.Uuid
  dayOfWeek Int    // 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  startTime String // "09:00" (24h, user's local timezone)
  endTime   String // "17:00"

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, dayOfWeek])
  @@index([userId])
}
```

**Default on user sign-up:** Mon–Fri 09:00–17:00 (5 rows created automatically).

### `AvailabilityOverride` (new)

Specific date overrides — for blocking a day off.

```prisma
model AvailabilityOverride {
  id        String   @id @default(uuid()) @db.Uuid
  userId    String   @db.Uuid
  date      DateTime @db.Date // specific calendar date
  isBlocked Boolean  @default(true)

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, date])
  @@index([userId])
}
```

### `Booking` (new)

```prisma
model Booking {
  id          String        @id @default(uuid()) @db.Uuid
  eventTypeId String        @db.Uuid
  userId      String        @db.Uuid  // the host
  meetingId   String?       @unique @db.Uuid  // created Meeting

  // Guest info
  guestName  String
  guestEmail String
  guestNote  String?

  // Time
  startTime DateTime
  endTime   DateTime
  timezone  String    // guest's timezone at time of booking

  status BookingStatus @default(CONFIRMED)

  // Google Calendar
  googleEventId String?

  cancelReason String?
  canceledAt   DateTime?

  isDeleted Boolean   @default(false)
  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  eventType EventType @relation(fields: [eventTypeId], references: [id])
  user      User      @relation(fields: [userId], references: [id])
  meeting   Meeting?  @relation(fields: [meetingId], references: [id])

  @@index([userId])
  @@index([eventTypeId])
  @@index([guestEmail])
  @@index([startTime])
  @@index([status, isDeleted])
}

enum BookingStatus {
  CONFIRMED
  CANCELLED
  NO_SHOW
}
```

> Note: No PENDING status — bookings are confirmed immediately on creation. If we need approval flow later, add it then.

---

## Slot Calculation Engine

The core scheduling logic. Lives in `src/services/scheduling/slotService.ts`.

```
GET /public/scheduling/slots?userId=&eventTypeId=&date=YYYY-MM-DD
```

**Algorithm:**

```
1. Load EventType (duration, bufferBefore, bufferAfter)
2. Load UserSettings (minNoticeHours, schedulingEnabled)
3. Load Availability for the requested dayOfWeek
4. Check AvailabilityOverride for the specific date → if blocked, return []
5. Generate candidate slots within the availability window
   (slot interval = duration, e.g. 30-min slots every 30 mins)
6. Load existing busy times for that date:
   a. Confirmed Bookings (startTime/endTime + buffers)
   b. User's Meetings in Crelyzor (SCHEDULED, not deleted)
   c. Google Calendar events (if googleCalendarSyncEnabled)
7. Filter out any candidate slot that overlaps with busy times
8. Filter out slots within minNoticeHours from now
9. Return remaining slots as { startTime, endTime }[]
```

**Timezone handling:**
- User's availability is stored in their timezone (from `User.timezone`)
- Slot calculation converts to UTC internally
- API response returns slots in UTC; client renders in guest's local timezone

---

## Booking Creation Flow

`POST /public/bookings` (no auth required)

```
1. Validate slot is still available (re-run slot check for that exact time)
2. Create Booking (status: CONFIRMED)
3. Create Meeting (type: SCHEDULED, createdById: userId, startTime, endTime)
4. Link Booking.meetingId → Meeting.id
5. If googleCalendarSyncEnabled → create Google Calendar event (async, non-blocking)
6. If recallEnabled + locationType === ONLINE → queue Recall bot deployment (async)
7. Return booking confirmation
```

**Atomicity:** Steps 2+3+4 are wrapped in a `prisma.$transaction`. Steps 5+6 are fire-and-forget (failures logged, don't break the booking).

---

## API Routes

```
# Event Types (auth required)
GET    /scheduling/event-types
POST   /scheduling/event-types
PATCH  /scheduling/event-types/:id
DELETE /scheduling/event-types/:id

# Availability (auth required)
GET    /scheduling/availability
PATCH  /scheduling/availability          # bulk upsert all days
POST   /scheduling/availability/overrides
DELETE /scheduling/availability/overrides/:id

# Public (no auth)
GET    /public/scheduling/profile/:username     # event types for booking page
GET    /public/scheduling/slots                 # ?userId=&eventTypeId=&date=
POST   /public/bookings                         # create booking

# Booking management (auth required)
GET    /scheduling/bookings                     # host sees all their bookings
PATCH  /scheduling/bookings/:id/cancel

# Public booking cancel (no auth — guest uses token from email, future)
PATCH  /public/bookings/:id/cancel
```

---

## Public Pages (`cards-frontend`)

### `/schedule/:username`
- SSR — fetch user's active event types
- Shows event type cards: title, duration, location type, description
- Each links to `/schedule/:username/:slug`
- OG: "{name}'s booking page"

### `/schedule/:username/:slug`
- SSR for initial render, client-side for slot loading
- Calendar view — month grid, available dates highlighted
- Guest picks date → slots load client-side (GET /public/scheduling/slots)
- Guest picks slot → booking form (name, email, note, timezone shown)
- Submit → POST /public/bookings → redirect to confirmation

### `/schedule/:username/:slug/confirmed?bookingId=`
- Confirmation page
- Shows: what, when, with who, location/link
- "Add to Google Calendar" button (generates .ics or Google Calendar URL)
- "Cancel booking" link (future)

---

## Settings UI (`calendar-frontend`)

### Settings page structure

```
/settings
├── Profile          (name, username, bio, avatar, timezone)
├── Scheduling       (on/off, min notice, max window, buffer)
├── Event Types      (manage your bookable event types)
├── Availability     (weekly schedule grid)
├── Integrations
│   ├── Google Calendar (connect/disconnect, sync status)
│   └── Recall.ai       (on/off, API key)
├── AI & Transcription (auto-transcribe, auto-AI, default language)
└── Privacy & Data   (export, delete account)
```

---

## Google Calendar Integration

**OAuth scope needed:** `https://www.googleapis.com/auth/calendar` (already have `calendar.readonly` from login — need to re-request write scope)

**Read (busy times):**
- Call `calendar.freebusy.query` for the requested date range
- Returns busy intervals → merged with Crelyzor meetings in slot engine
- Cache for 5 minutes to avoid hammering the API per slot request

**Write (on booking confirmed):**
- Call `calendar.events.insert` with:
  - `summary`: event type title
  - `start`/`end`: booking times
  - `attendees`: [{ email: guestEmail }]
  - `description`: guest note if any
  - `location`: address (IN_PERSON) or meeting link (ONLINE)
- Store returned `event.id` as `Booking.googleEventId`

**On booking cancelled:**
- Call `calendar.events.delete(googleEventId)`

---

## Recall.ai Integration

**When it fires:**
- Booking confirmed AND `locationType === ONLINE` AND `UserSettings.recallEnabled === true`

**Flow:**
```
Booking confirmed
  → queue job: { type: 'recall-deploy', bookingId, meetingLink, startTime }
  → worker picks up job ~5 mins before startTime
  → call Recall API: POST /v1/bots { meeting_url, bot_name: "Crelyzor Assistant" }
  → store recallBotId on Meeting (new field)
  → Recall webhook fires when bot joins: audio stream starts
  → Deepgram receives audio → existing transcription pipeline
  → AI pipeline fires after → same as Phase 1
```

**New field on Meeting:**
```prisma
recallBotId String? // Recall.ai bot ID, set when bot is deployed
```

**Recall webhook endpoint:** `POST /webhooks/recall`
- Verify signature
- On `bot.status_change` (JOINING → IN_CALL → DONE) → update Meeting status
- On audio data → stream to Deepgram

---

## Configuration & Feature Flags

### Who controls what

| Setting | Level | Default |
|---|---|---|
| schedulingEnabled | UserSettings | true |
| minNoticeHours | UserSettings | 24 |
| maxWindowDays | UserSettings | 60 |
| defaultBufferMins | UserSettings | 15 |
| googleCalendarSyncEnabled | UserSettings | false |
| recallEnabled | UserSettings | false |
| autoTranscribe | UserSettings | true |
| autoAIProcess | UserSettings | true |
| defaultLanguage | UserSettings | "en" |
| locationType | EventType | IN_PERSON |
| bufferBefore/After | EventType | 0 |
| isActive | EventType | true |

### Recall fires only when:
`recallEnabled === true` AND `EventType.locationType === ONLINE`

### Google Calendar busy times used only when:
`googleCalendarSyncEnabled === true` AND Google OAuth token is valid

---

## Build Order

1. **Schema + migration** — all 4 new models + UserSettings
2. **Settings backend** — UserSettings CRUD, default creation on sign-up
3. **Settings UI** — full settings page with all sections (Scheduling, AI, Privacy)
4. **Event types backend + UI**
5. **Availability backend + UI** — weekly grid
6. **Slot calculation engine**
7. **Public booking pages** (cards-frontend)
8. **Booking creation API**
9. **Google Calendar read** (busy times in slot engine)
10. **Google Calendar write** (event on booking)
11. **Recall.ai** — bot deployment + webhook

Each step is independently shippable. Stop after step 8 for a working booking system without integrations.
