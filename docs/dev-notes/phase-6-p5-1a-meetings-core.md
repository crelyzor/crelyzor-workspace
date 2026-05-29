# Phase 6 P5.1.a — Meetings core CRUD team-scoping

Mounted `resolveTeamContext` on `/meetings`, then taught the meeting CRUD path + creation flow to honour `req.teamContext`. No nested resources, no metering wiring — those are P5.1.b and P5.1.c.

## What was built

- `routes/meetingRoutes.ts` — `router.use(resolveTeamContext)` after `verifyJWT`. All 12 routes downstream now have `req.teamContext` populated (null in personal context, `{ teamId, role }` under team context).
- `services/meetings/meetingService.ts` — three new helpers at the top of the file:
  - `meetingScope(actorId, teamContext)` — returns the Prisma `where` fragment for every read. Personal: `teamId IS NULL AND (createdById = actor OR participants.some(userId = actor))`. Team + MEMBER: `teamId = ctx.teamId AND (creator OR participant)`. Team + ADMIN/OWNER: `teamId = ctx.teamId`.
  - `principalForMeeting(meeting)` (exported) — derives `Principal` from the row, not the actor. `meeting.teamId` set → `{ type: "team", id }`; null → `{ type: "user", id: createdById }`.
  - `verifyMeetingAccess(actorId, meeting, teamContext, "read" | "mutate")` — uniform 404 ("Meeting not found") on every "not accessible" branch. Hard MEMBER-creator-only on mutations; participant access stops at reads.
- Method signatures updated to accept `teamContext: TeamContext | null = null`:
  - `createMeeting` — writes `meeting.teamId = teamContext?.teamId ?? null`; encrypts `guestEmail` under `principalForMeeting(newMeeting)`; under team + MEMBER role, verifies all participants are active TeamMembers of the same team (prevents leaking team-meeting visibility to outsiders); Bull `RecallBotJobData` payload carries `teamId`; enqueue log includes `teamId` + `billedTo` with `TODO(P5.1.c)` reminder.
  - `updateMeeting/cancelMeeting/completeMeeting/deleteMeeting` — identity fetch (slim select including `teamId`/`createdById`/`isDeleted`/`participants`), then `verifyMeetingAccess`. Same MEMBER participant-allowlist guard on `updateMeeting`.
  - `getMeetings/getMeetingsWithoutPagination` — accept `teamContext` in `params`; spread `meetingScope(...)` into the where clause.
  - `importMeetingsFromIcs` — throws 400 if `teamContext` set ("ICS import is not yet available in team context"). Defer to P5.1.b for proper team-import semantics.
- `meetingInclude` + `meetingListInclude` gain `team: { select: { id, name, slug } }` so frontend can render team badges without an extra fetch.
- `controllers/meetingController.ts` — every handler reads `getTeamContext(req)` and passes through. `getMeetingById` is a controller-inline two-step fetch (slim probe → access decision → full include) because the service doesn't yet expose a unified `getMeetingById` method.

## Key patterns

- **`meetingScope()` returns a `where` fragment, not a wrapper function.** Spread `...meetingScope(actorId, ctx)` into the existing `where: {}`. Keeps Prisma type inference working and composes cleanly with `isDeleted: false` + status filters.
- **`principalForMeeting(meeting)` is the single source of truth for encrypt/decrypt principals on meeting-scoped content.** Always derive from the meeting row, never from the actor. A team admin re-encrypting a team meeting's content under their personal DEK would break decryption for every other admin — security review caught this and the helper enforces it.
- **Uniform 404 across access branches.** Same enumeration-collapse pattern as P1/P2. A non-member can't tell whether a team meeting exists; a personal-context caller can't tell whether `:meetingId` refers to a team meeting they'd see under team context.
- **Two-step fetch on `getMeetingById`** (controller) — slim projection runs the access check, full projection only runs once allowed. Prevents accidental payload leaks on cross-team probes.
- **MEMBER participant-allowlist** on `participantUserIds` (createMeeting + updateMeeting). Without this, a MEMBER editing their own meeting could add an outsider as a participant, leaking meeting visibility outside the team.

## Decisions

- **Personal `getMeetings` keeps "creator OR participant" visibility** (not just creator). Mirrors the pre-Phase-6 personal behaviour; tightening to creator-only would be a regression. Mutations still require creator.
- **`getMeetingById` lives in the controller for now** instead of a service method. The service doesn't have a single-meeting fetch today, so adding one alongside the team-scoping retrofit was scope creep. P5.1.b lifts it into `meetingService.getMeetingById(actorId, meetingId, teamContext)` when the SMA service needs it.
- **Bull RecallBotJobData.teamId populated, worker still bills `hostUserId`.** P5.1.c wires `getQuotaOwner` into the Recall metering. Today the team owner is NOT billed for team-meeting recording — the actor is. Documented at the enqueue site with `TODO(P5.1.c)` so the gap is visible in logs.
- **ICS import gated to personal-only.** Bulk-creating team meetings from a file has different ownership semantics (who pays for transcription on historic imports, who sees what) — defer until we can spec it.
- **Soft-delete check moved into `verifyMeetingAccess`** (not the scope), so writes that want to touch deleted rows (future admin restore?) compose correctly. Reads compose `meetingScope` + `isDeleted: false` explicitly.

## Gotchas

- `principalForMeeting` relies on `meeting.teamId` being immutable for the meeting's lifetime. Today this holds — we have no service endpoint to move a meeting between teams. If we ever add one, the existing encrypted rows would become unreadable. Mark as admin-tool-only with re-encryption requirement.
- `verifyMeetingAccess(... "mutate")` for MEMBER role rejects participants who aren't creators — they get a 404 not 403. Same identical body as the read-not-allowed case (intentional: no enumeration). UX should explain "only the meeting creator can edit" at the call site.
- `updateMeeting`'s `participantUserIds` field — MEMBER editing their own team meeting can only add active TeamMembers. ADMIN/OWNER can add anyone. Spec ambiguity: I picked the conservative "MEMBER only" interpretation; if ADMINs need to invite outsiders to a team meeting we can loosen later.
- Bull payload uses spread `...(committedMeeting.teamId ? { teamId: ... } : {})` to keep the field optional. Workers can ignore undefined until P5.1.c.

## Deferred to P5.1.b / P5.1.c

- Nested resources: attachments, tags-on-meetings, share (private side), notes, transcript segment edits, AI summary, AI content gen, Ask AI conversations → P5.1.b for the simpler four (attachments/tags/share/notes), P5.1.c for the AI/transcript ones (encryption principal switch is more involved).
- Metering wiring: `checkTranscription/deductTranscription/checkRecall/deductRecall/checkAndDeductCredits` signature change + call-site updates → P5.1.c.
- `meetingService.getMeetingById` service method → P5.1.b when SMA services need a unified gate.
- ICS team-import semantics → P5.1.b spec + impl.
