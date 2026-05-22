# Phase 4.9 — In-App Notifications

## What was built

End-to-end in-app notification system: backend schema + WebSocket delivery + frontend bell/panel + real-time client hook + settings toggles. Users get a red badge, a scrollable panel, and live push toasts when bookings, AI processing, or task due dates fire.

## Architecture

**Backend:**
- `Notification` Prisma model with `@@index([userId, createdAt(sort: Desc)])` for efficient list queries
- `UserSettings` extended with 4 `inApp*` boolean preference fields
- `notificationService.ts` — fail-open `createNotification()` (never throws), cursor-based list, soft delete
- `PREF_MAP satisfies Record<NotificationType, string>` — compile-time exhaustiveness check for preference → setting mapping
- Triggers wired into `bookingManagementService.ts` (BOOKING_RECEIVED), `jobProcessor.ts` (BOOKING_REMINDER, MEETING_AI_COMPLETE, TASK_DUE_SOON), additive alongside existing email sends
- WebSocket server (not SSE): `CONNECTED` on auth, `NOTIFICATION` push, `PING`/`PONG` keepalive, exponential backoff on client

**Frontend:**
- `src/services/notificationService.ts` — 5 API methods, `Notification` + `NotificationType` types
- `src/hooks/queries/useNotificationQueries.ts` — `useInfiniteQuery` (cursor = `createdAt` ISO string, `initialPageParam: undefined as string | undefined`)
- `src/hooks/useNotificationSocket.ts` — WS hook, derives URL from `VITE_API_BASE_URL`, handles both absolute (`http://...`) and relative (`/api`) base
- `src/components/notifications/NotificationBell.tsx` — spring badge animation with `AnimatePresence`
- `src/components/notifications/NotificationPanel.tsx` — `useCallback` setRef pattern for IntersectionObserver, `</div>` body (no ScrollArea — not installed)
- `src/layout/Layout.tsx` — bell + socket hook mounted for whole session

## Gotchas

**Cursor must be `createdAt` ISO string, not UUID.** If you sort by `createdAt desc` you must cursor by `createdAt` — UUID cursors don't match the sort order and break pagination. Zod validator uses `z.string().datetime()`, not `z.string().uuid()`.

**`markRead` must always do the update, even when already read.** The original had an early return to skip the DB write, but that returned a narrow `{ id, isRead }` shape instead of the full `NOTIFICATION_SELECT` shape, causing a TypeScript error at the call site.

**BOOKING_CANCELLED should NOT notify the host.** `cancelBooking()` is host-initiated — notifying the actor of their own action is noise. Only guest-initiated events send host notifications.

**WebSocket URL derivation is environment-dependent.**
- `VITE_API_BASE_URL = http://localhost:3000/api` → strip `/api`, replace `http` → `ws` → `ws://localhost:3000/ws`
- `VITE_API_BASE_URL = /api` (relative) → build from `window.location.origin`, replace `http` → `ws` → `ws://localhost:5173/ws` (Vite proxies /ws → backend)

**`unmounted` flag + `ws.onclose = null` is required for clean cleanup.** Without setting `onclose = null` before calling `ws.close()`, the reconnect timer fires on intentional unmount.

**`queryKeys.notifications.all` (not `.list()`) for broad invalidation.** On a NOTIFICATION push, invalidate the parent key to bust both `list` and `unreadCount` caches in one call.

**IntersectionObserver sentinel pattern for infinite scroll** — use `useCallback` to create the `setRef` callback that disconnects/reconnects the observer each time `hasNextPage` or `isFetchingNextPage` changes. Passing the observer a stale ref would miss the next page or double-fire.

## Decisions

- **WebSocket over SSE**: backend already had a WS server registered on the Express app; SSE would have required a new route + different connection semantics. WS also supports bidirectional messages (PING/PONG keepalive without polling).
- **Cursor by `createdAt`, not by `id`**: natural match for the sort order; avoids UUID collisions when multiple notifications land in the same millisecond (composite index covers it).
- **Fail-open notifications**: `createNotification()` wraps everything in try/catch. A notification failure should never break a booking confirmation or AI processing result.
- **No `ScrollArea`**: component not installed in this project. Plain `<div className="flex-1 overflow-y-auto">` achieves the same result without the dependency.
