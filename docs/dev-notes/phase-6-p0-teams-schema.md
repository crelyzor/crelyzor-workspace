# Phase 6 P0 — Teams Schema

Migration: `20260529033811_phase6_teams_schema`

## What was added

- **`TeamRole` enum** — `OWNER | ADMIN | MEMBER`
- **`SystemConfig`** — key/value store for platform limits. Seeded with `max_teams_per_pro_user=3`, `max_teams_per_business_user=10`, `max_members_per_team=50`, `team_invite_expiry_days=7` via raw SQL `INSERT ... ON CONFLICT DO NOTHING` so the migration is re-runnable.
- **`Team`** — owns content via `wrappedDek Bytes` (NOT NULL) + `dekVersion Int`. Owner relation uses `onDelete: Restrict` so a user with active teams cannot be deleted before ownership transfer.
- **`TeamMember`** — `@@unique([teamId, userId])` so re-joining flips `isDeleted` on an existing row instead of inserting a new one.
- **`TeamInvite`** — `userId?` set when invitee already has an account (delivery routing). Email stored plaintext (server-side lookup without per-user DEK; same reasoning as `User.email`).
- **`TeamDekHistory`** — append-only, hard-cascades on `Team` delete to crypto-shred the team's encryption key.
- **`teamId UUID?`** + `onDelete: SetNull` Team relation on `Meeting`, `Card`, `Task`, `EventType`, `Booking`, `UserUsage`.

## Decisions

- **No `Team.wrappedDek` NULL fallback.** Insertion must happen inside the `teamService.createTeam()` transaction that wraps a fresh DEK via Cloud KMS first. No controller may call `prisma.team.create()` directly.
- **`TeamInvite` uniqueness via partial unique index, not Prisma `@@unique`.** Prisma 6 cannot express partial uniques. The constraint lives as raw SQL in the migration:
  ```sql
  CREATE UNIQUE INDEX team_invite_active_uniq
    ON "TeamInvite" ("teamId", "email")
    WHERE "isDeleted" = false
      AND "acceptedAt" IS NULL
      AND "declinedAt" IS NULL
      AND "cancelledAt" IS NULL;
  ```
  This lets cancelled/declined/accepted invites coexist while preventing duplicate open invites for the same email.
- **Dashboard hot-path indexes** — `Meeting` and `Task` get `@@index([teamId, isDeleted, createdAt(sort: Desc)])` for the "list my team's items" query at scale. Other team-scoped models use `@@index([teamId, isDeleted])`.
- **`teamId onDelete: SetNull` on content tables** — hard-deleting a team turns previously-team-scoped rows into orphaned personal rows. Acceptable because team hard-delete only happens via retention sweep after explicit soft-delete window; service layer is expected to hard-delete team-scoped encrypted rows in the same sweep so undecryptable ciphertext does not survive.
- **`UserUsage.userId @unique` kept as-is.** Spec implies `groupBy(['userId', 'teamId'])` aggregation; today there is still only one row per user with a mutable `teamId` attribution. Restructuring to multi-row per user is a P4 (Context Middleware + Quota Resolver) concern, not P0.

## Gotchas

- `.env.local` (not `.env`) carries `DATABASE_URL` locally. Use `set -a && source .env.local && set +a` before any `prisma` CLI invocation, or Prisma falls back to the empty `.env` and fails with P1012.
- The crelyzor-reviewer initially suggested treating `@@unique([teamId, email, isDeleted])` as sufficient; it is not (boolean column only allows one row per state). Always reach for a partial unique index when "uniqueness applies only while active" is the actual rule.
- `prisma migrate dev --create-only` requires DB connectivity even though it does not apply; Postgres must be reachable.

## Follow-ups (not in P0)

- Wire `teamService.createTeam()` in P1 with atomic DEK generation + Team insert + OWNER `TeamMember` + auto-created team `Card`.
- Decide `UserUsage` data model for true per-team attribution before P4.
- Pair team hard-delete with a cascading hard-delete sweep of team-scoped encrypted rows (Phase 6 retention work).
