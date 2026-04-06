# Feature: Guest Cancellation Link (P2)

**What was built:**
Implemented the end-to-end guest cancellation flow, allowing a guest to cancel their meeting autonomously without an account.
- **Backend:** Surface a new `GET /api/v1/public/bookings/:id` endpoint. It returns sanitized, safe public details for a booking using the booking's UUID as an implicit authorization token.
- **Backend (Templates):** Verified that the `cancelUrl` parameter is properly passed to the guest's `bookingConfirmationEmail` template using `PUBLIC_BASE_URL`.
- **Frontend (Public):** Added a new dynamic Next.js App Router path at `crelyzor-public/src/app/bookings/[id]/cancel/page.tsx`. This page is a Server Component that fetches the public booking details natively, mixed with a Client Component (`cancel-form.tsx`) that implements the cancellation UI (reason box, standard Red CTA) which invokes the pre-existing `PATCH /api/v1/public/bookings/:id/cancel` endpoint.

**Patterns used:**
- No `@/components/ui/` components are actively used on the `crelyzor-public` NextJS side. Used raw Tailwind CSS classes to emulate the clean interface aesthetics.
- Leveraged App Router's server components vs client components strictly.
- Failed gracefully when already cancelled.

**Decisions made:**
- Opted to separate the `CancelForm` into a client-boundary component so that the `page.tsx` could safely handle `async` metadata and SSR rendering of data without `use client` blocking it. 
- Passed `bookingId` securely and relied on existing `cancelBookingAsGuest` API rate-limiting properties to prevent abuse enumeration.
