# Teams — Design Spec

**Date:** 2026-05-09
**Phase:** 7

---

## Overview

Teams is a workspace layer on top of Crelyzor's personal product. A Pro user can create up to 3 teams (configurable). After switching into a team workspace, all product surfaces — meetings, cards, tasks, scheduling — are fully scoped to that team. Nothing overlaps with personal or other teams.

---

## Workspace Model

The top-left area (currently shows user name + avatar) becomes a workspace switcher dropdown. Options:

- Personal (default)
- Team 1
- Team 2
- Team 3 (up to 3, or however many the user has created)
- + Create team (if under limit)

Switching is a full context switch — the app reloads scoped to the selected workspace. No bleed between contexts ever.

---

## Roles

Three roles per team:

| Role | Permissions |
|------|-------------|
| **Owner** | Full access — see all meetings, reassign tasks, manage members, billing owner |
| **Admin** | Same as Owner except cannot delete the team or transfer ownership |
| **Member** | See own meetings only, cannot reassign tasks |

Only one Owner per team (the creator). Ownership can be transferred.

---

## Cards

### Team Card
- Auto-created when a team is created
- Public page at `crelyzor.app/t/:slug`
- Contains team name, logo, description, and a roster of members with their roles
- Owner/Admin can edit

### Member Cards
- When a user joins a team, a team-scoped member card is auto-created for them
- Populated with their name and profile info from their account
- Member can edit their team card independently of their personal card
- Visible on the team's public page

---

## Meetings

- All meetings created while in team context belong to the team
- **Owner/Admin:** See all team meetings
- **Member:** Sees only meetings they are a participant in
- When a member leaves or is removed, their meetings remain in the team — visible to Owner/Admin — but the departed member loses all access immediately

---

## Tasks

- AI extracts tasks from meeting transcripts and assigns them based on speaker attribution
- **Owner/Admin:** Can reassign any task to any team member
- **Member:** Cannot reassign — only works on tasks assigned to them
- All tasks are visible to Owner/Admin; members see only their own tasks

---

## Scheduling

### External Booking
- Each team member gets a team-scoped booking link: `/schedule/t/:slug/:username`
- Visitors book a specific member directly based on that member's availability
- Each member configures their availability within the team context (separate from personal scheduling)

### Internal Booking
- From inside the team dashboard (meetings or scheduling section), a team member can book a meeting with another team member
- Picks the member, sees their real-time availability, selects a slot, confirms
- Booking creates a meeting in the team's meeting context

---

## Billing

All consumption is billed to the **team owner** — the Pro user who created the team.

This covers:
- Transcription minutes (for all team meetings)
- Storage (recordings, attachments)
- AI credits (summaries, Ask AI, task extraction)

Members and Admins consume the owner's quota. They do not pay.

**In team settings**, the Owner sees a usage breakdown by member — how many transcription minutes, AI credits, and storage each person has used.

### Plan Limits (all configurable from admin portal)
| Config Key | Default |
|---|---|
| `max_teams_per_pro_user` | 3 |
| `max_members_per_team` | TBD — discuss with Enterprise |
| `team_transcription_minutes_per_month` | Shared with user's Pro quota |
| `team_max_storage_gb` | Shared with user's Pro quota |

Pro user creates a team → their existing Pro quota is shared across personal + all teams. There is no separate team quota — it all draws from the same pool, which is why the owner can see per-member usage.

---

## Member Onboarding

Owner or Admin can invite members in two ways (both enabled by default, configurable from admin portal):

1. **Search existing users** — by email or username; they receive an in-app notification and can accept/decline
2. **Email invite** — enter any email; recipient gets a link; if they don't have an account, they create one as part of joining; lands directly in the team on completion

Pending invites are visible in team settings with a cancel option.

---

## Team Creation Flow

1. User (must be on Pro) clicks "+ Create team" in workspace switcher
2. Enters: team name, team slug (auto-suggested, editable, unique), optional logo
3. Team is created — team card is auto-generated at `crelyzor.app/t/:slug`
4. Lands in the new team workspace
5. Prompted to invite first members

---

## System Config Table

All limits and feature flags are stored in a `SystemConfig` table (key-value, editable from admin portal). The codebase reads from DB — nothing hardcoded. Self-hosters can modify without touching code.

---

## Data Model

### New models

```
Team
  id          UUID PK
  name        String
  slug        String UNIQUE
  ownerId     UUID FK → User
  logoUrl     String?
  createdAt   DateTime
  deletedAt   DateTime?  (soft delete)

TeamMember
  id          UUID PK
  teamId      UUID FK → Team
  userId      UUID FK → User
  role        Enum (OWNER | ADMIN | MEMBER)
  joinedAt    DateTime
  leftAt      DateTime?  (set on removal, not deleted)

SystemConfig
  key         String PK
  value       String
  updatedAt   DateTime
  updatedBy   String  (admin user reference)
```

### Modified models

All existing content models get a nullable `teamId`:

```
Meeting     → teamId UUID? FK → Team
Card        → teamId UUID? FK → Team
Task        → teamId UUID? FK → Team
EventType   → teamId UUID? FK → Team
Booking     → teamId UUID? FK → Team
```

`null` = personal context. Set = team context. Queries always filter by context (either `teamId IS NULL` or `teamId = ?`).

---

## Access Control

All team-scoped routes enforce:
1. User is authenticated (`verifyJWT`)
2. User is an active member of the team (`verifyTeamMember` middleware)
3. Role check where needed (`verifyTeamRole('ADMIN' | 'OWNER')`)

A `leftAt`-set TeamMember record = no access. Membership check always filters `leftAt IS NULL`.

---

## What's Out of Scope (Phase 7)

- Enterprise plan (unlimited + pay-as-you-go) — separate phase
- Team-level AI (shared knowledge base across team meetings) — Phase 8 Big Brain
- Team notifications (Slack/email) — Phase 7.x
- Admin portal changes for team management — Phase 7.x

---

## Open Questions

- `max_members_per_team` default value — decide when Enterprise plan is designed
- Does a user's Pro quota pool across personal + all teams, or does team creation allocate a dedicated sub-quota? (Current spec: shared pool — revisit if owners complain about member abuse)
