# Team Invite Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the resend-invite badge not refreshing + add a reusable shareable invite link that any authenticated user can use to join a team without an email invite.

**Architecture:** Three new fields on the `Team` Prisma model store the link token and enabled state. Four new backend endpoints (generate, revoke, get status, join-by-link) extend `teamInviteService` and `teamInviteController`. The frontend adds three React Query hooks, updates `InvitesSection` with an invite-link card, and adds a new `InviteLinkPage` for the join flow.

**Tech Stack:** Express 5, Prisma 6, PostgreSQL, React 19, TanStack Query v5, shadcn/ui, Sonner toasts, Zustand, Motion

---

## File Map

| Action | Path |
|--------|------|
| Modify | `crelyzor-backend/prisma/schema.prisma` |
| Modify | `crelyzor-backend/src/services/teamInviteService.ts` |
| Modify | `crelyzor-backend/src/controllers/teamInviteController.ts` |
| Modify | `crelyzor-backend/src/routes/teamRoutes.ts` |
| Modify | `crelyzor-frontend/src/lib/queryKeys.ts` |
| Modify | `crelyzor-frontend/src/services/teamService.ts` |
| Modify | `crelyzor-frontend/src/hooks/queries/useTeamQueries.ts` |
| Modify | `crelyzor-frontend/src/pages/team-settings/sections/InvitesSection.tsx` |
| Create | `crelyzor-frontend/src/pages/invite-link/InviteLinkPage.tsx` |
| Create | `crelyzor-frontend/src/pages/invite-link/index.ts` |
| Modify | `crelyzor-frontend/src/routes/routes.ts` |
| Modify | `crelyzor-frontend/src/App.tsx` |

---

## Task 1: Prisma Schema Migration

**Files:**
- Modify: `crelyzor-backend/prisma/schema.prisma`

- [ ] **Step 1: Add three fields to the Team model**

In `schema.prisma`, find the `Team` model. After the `dekHistory` relation (around line 1124), add these three fields before `@@index`:

```prisma
  inviteLinkToken     String?   @unique
  inviteLinkEnabled   Boolean   @default(false)
  inviteLinkExpiresAt DateTime?
```

The full block at the bottom of the Team model should look like:

```prisma
  isDeleted Boolean   @default(false)
  deletedAt DateTime?
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt

  inviteLinkToken     String?   @unique
  inviteLinkEnabled   Boolean   @default(false)
  inviteLinkExpiresAt DateTime?

  owner      User             @relation("TeamOwner", fields: [ownerId], references: [id], onDelete: Restrict)
  members    TeamMember[]
  invites    TeamInvite[]
  dekHistory TeamDekHistory[]
  meetings   Meeting[]
  cards      Card[]
  tasks      Task[]
  eventTypes EventType[]
  bookings   Booking[]
  tags       Tag[]
  usage      UserUsage[]

  @@index([ownerId, isDeleted])
}
```

- [ ] **Step 2: Generate and run the migration**

```bash
docker compose exec backend pnpm prisma migrate dev --name add_team_invite_link
```

Expected output: `The following migration(s) have been created and applied: migrations/.../migration.sql`

- [ ] **Step 3: Regenerate the Prisma client in both containers**

```bash
docker compose exec backend pnpm prisma generate
docker compose exec worker pnpm prisma generate
```

- [ ] **Step 4: Restart backend and worker**

```bash
docker compose restart backend worker
```

Confirm backend is healthy:

```bash
curl -s http://localhost:4000/api/v1/health | grep -o '"status":"ok"'
```

Expected: `"status":"ok"`

- [ ] **Step 5: Commit**

```bash
cd crelyzor-backend
git add prisma/schema.prisma prisma/migrations
git commit -m "feat(teams): add invite link fields to Team model"
```

---

## Task 2: Backend Service Functions

**Files:**
- Modify: `crelyzor-backend/src/services/teamInviteService.ts`

- [ ] **Step 1: Add `getInviteLink` service function**

Append the following to `teamInviteService.ts` (after the last `export async function`):

```typescript
// ── Invite link ────────────────────────────────────────────────────────────

export async function getInviteLink(
  actorId: string,
  teamId: string,
): Promise<{
  enabled: boolean;
  token: string | null;
  linkUrl: string | null;
  expiresAt: string | null;
}> {
  const role = await getRole(actorId, teamId);
  if (!role || ROLE_RANK[role] < ROLE_RANK.ADMIN) {
    throw new AppError("Only admins and owners can manage the invite link", 403);
  }

  const team = await prisma.team.findFirst({
    where: { id: teamId, isDeleted: false },
    select: {
      inviteLinkToken: true,
      inviteLinkEnabled: true,
      inviteLinkExpiresAt: true,
    },
  });

  if (!team) throw new AppError("Team not found", 404);

  const token = team.inviteLinkEnabled ? team.inviteLinkToken : null;
  const linkUrl =
    token ? `${env.FRONTEND_URL}/invite/link/${token}` : null;

  return {
    enabled: team.inviteLinkEnabled,
    token,
    linkUrl,
    expiresAt: team.inviteLinkExpiresAt?.toISOString() ?? null,
  };
}
```

- [ ] **Step 2: Add `generateInviteLink` service function**

```typescript
export async function generateInviteLink(
  actorId: string,
  teamId: string,
): Promise<{
  enabled: boolean;
  token: string;
  linkUrl: string;
  expiresAt: string | null;
}> {
  const role = await getRole(actorId, teamId);
  if (!role || ROLE_RANK[role] < ROLE_RANK.ADMIN) {
    throw new AppError("Only admins and owners can generate the invite link", 403);
  }

  const token = generateToken();

  await prisma.team.update({
    where: { id: teamId, isDeleted: false },
    data: {
      inviteLinkToken: token,
      inviteLinkEnabled: true,
    },
  });

  logger.info("Team invite link generated", { teamId, actorId });

  return {
    enabled: true,
    token,
    linkUrl: `${env.FRONTEND_URL}/invite/link/${token}`,
    expiresAt: null,
  };
}
```

- [ ] **Step 3: Add `revokeInviteLink` service function**

```typescript
export async function revokeInviteLink(
  actorId: string,
  teamId: string,
): Promise<void> {
  const role = await getRole(actorId, teamId);
  if (!role || ROLE_RANK[role] < ROLE_RANK.ADMIN) {
    throw new AppError("Only admins and owners can revoke the invite link", 403);
  }

  await prisma.team.update({
    where: { id: teamId, isDeleted: false },
    data: {
      inviteLinkEnabled: false,
      inviteLinkToken: null,
    },
  });

  logger.info("Team invite link revoked", { teamId, actorId });
}
```

- [ ] **Step 4: Add `joinByLink` service function**

```typescript
export async function joinByLink(
  actorId: string,
  token: string,
): Promise<{ membership: { teamId: string; role: TeamRole; team: { id: string; name: string; slug: string } } }> {
  const team = await prisma.team.findFirst({
    where: {
      inviteLinkToken: token,
      inviteLinkEnabled: true,
      isDeleted: false,
    },
    select: {
      id: true,
      name: true,
      slug: true,
      inviteLinkExpiresAt: true,
    },
  });

  if (!team) throw new AppError("This invite link is invalid or has been revoked", 404);

  if (team.inviteLinkExpiresAt && team.inviteLinkExpiresAt < new Date()) {
    throw new AppError("This invite link has expired", 410);
  }

  const existing = await prisma.teamMember.findFirst({
    where: { teamId: team.id, userId: actorId, isDeleted: false },
  });
  if (existing) throw new AppError("You are already a member of this team", 409);

  await prisma.teamMember.upsert({
    where: { teamId_userId: { teamId: team.id, userId: actorId } },
    create: { teamId: team.id, userId: actorId, role: "MEMBER" },
    update: { isDeleted: false, deletedAt: null, role: "MEMBER" },
  });

  await publishTeamMemberJoined(team.id, actorId);

  logger.info("User joined team via invite link", { teamId: team.id, actorId });

  return {
    membership: {
      teamId: team.id,
      role: "MEMBER",
      team: { id: team.id, name: team.name, slug: team.slug },
    },
  };
}
```

- [ ] **Step 5: Verify the file compiles**

```bash
docker compose exec backend pnpm tsc --noEmit 2>&1 | head -30
```

Expected: no output (or only pre-existing warnings unrelated to teamInviteService).

- [ ] **Step 6: Commit**

```bash
git add src/services/teamInviteService.ts
git commit -m "feat(teams): add invite link service functions"
```

---

## Task 3: Backend Controller + Routes

**Files:**
- Modify: `crelyzor-backend/src/controllers/teamInviteController.ts`
- Modify: `crelyzor-backend/src/routes/teamRoutes.ts`

- [ ] **Step 1: Add controller handlers**

Add these four handlers to the bottom of `teamInviteController.ts`:

```typescript
// ── Invite link (Phase 6 P16) ─────────────────────────────────────────────

export const getInviteLink = async (req: Request, res: Response) => {
  const actorId = req.user!.userId;
  const params = teamIdParamSchema.safeParse(req.params);
  if (!params.success) throw new AppError("Invalid team id", 400);

  const data = await teamInviteService.getInviteLink(actorId, params.data.teamId);

  return apiResponse(res, {
    statusCode: 200,
    message: "Invite link fetched",
    data,
  });
};

export const generateInviteLink = async (req: Request, res: Response) => {
  const actorId = req.user!.userId;
  const params = teamIdParamSchema.safeParse(req.params);
  if (!params.success) throw new AppError("Invalid team id", 400);

  const data = await teamInviteService.generateInviteLink(actorId, params.data.teamId);

  return apiResponse(res, {
    statusCode: 201,
    message: "Invite link generated",
    data,
  });
};

export const revokeInviteLink = async (req: Request, res: Response) => {
  const actorId = req.user!.userId;
  const params = teamIdParamSchema.safeParse(req.params);
  if (!params.success) throw new AppError("Invalid team id", 400);

  await teamInviteService.revokeInviteLink(actorId, params.data.teamId);

  return apiResponse(res, {
    statusCode: 200,
    message: "Invite link revoked",
  });
};

export const joinByLink = async (req: Request, res: Response) => {
  const actorId = req.user!.userId;
  const token = req.params.token as string;
  if (!token) throw new AppError("Missing invite token", 400);

  const data = await teamInviteService.joinByLink(actorId, token);

  return apiResponse(res, {
    statusCode: 200,
    message: "Joined team",
    data,
  });
};
```

- [ ] **Step 2: Add rate limiter and register routes in teamRoutes.ts**

Add a rate limiter after the existing `inviteRespondLimiter` declaration:

```typescript
// Join-by-link is a one-shot action; tight limit to prevent brute-forcing tokens.
const inviteLinkJoinLimiter = userRateLimit(
  10,
  60 * 60 * 1000,
  "teams:invite-link-join",
);
// Generate/revoke is an admin action — very infrequent.
const inviteLinkMutateLimiter = userRateLimit(
  20,
  60 * 60 * 1000,
  "teams:invite-link-mutate",
);
```

Register routes. The join-by-link route must go BEFORE the `/:teamId/*` family (same pattern as the existing `/me/invites` comment):

```typescript
// Phase 6 P16 — join-by-link. Must be registered BEFORE the /:teamId/* family
// below, otherwise Express matches "join-by-link" as a :teamId param.
router.post(
  "/join-by-link/:token",
  inviteLinkJoinLimiter,
  teamInviteController.joinByLink,
);
```

Then add the three team-scoped invite-link routes after the existing `/:teamId/invites/:inviteId` cancel route:

```typescript
// ── Invite link (Phase 6 P16) ────────────────────────────────────────────────
router.get(
  "/:teamId/invite-link",
  readLimiter,
  teamInviteController.getInviteLink,
);
router.post(
  "/:teamId/invite-link/generate",
  inviteLinkMutateLimiter,
  teamInviteController.generateInviteLink,
);
router.delete(
  "/:teamId/invite-link",
  inviteLinkMutateLimiter,
  teamInviteController.revokeInviteLink,
);
```

- [ ] **Step 3: Verify compile**

```bash
docker compose exec backend pnpm tsc --noEmit 2>&1 | head -30
```

Expected: no output.

- [ ] **Step 4: Smoke-test the endpoints**

First get a valid JWT (copy from browser DevTools → Application → localStorage → `auth-store` → `accessToken`). Replace `<TOKEN>` and `<TEAM_ID>` below.

```bash
# Get current link state (should be enabled:false, token:null on fresh team)
curl -s -H "Authorization: Bearer <TOKEN>" \
  http://localhost:4000/api/v1/teams/<TEAM_ID>/invite-link | jq .

# Generate a link
curl -s -X POST -H "Authorization: Bearer <TOKEN>" \
  http://localhost:4000/api/v1/teams/<TEAM_ID>/invite-link/generate | jq .

# Get link state again (should show enabled:true with token)
curl -s -H "Authorization: Bearer <TOKEN>" \
  http://localhost:4000/api/v1/teams/<TEAM_ID>/invite-link | jq .
```

Expected first call: `{ "data": { "enabled": false, "token": null, "linkUrl": null, "expiresAt": null } }`
Expected generate call: `{ "data": { "enabled": true, "token": "...", "linkUrl": "http://localhost:5173/invite/link/...", "expiresAt": null } }`

- [ ] **Step 5: Commit**

```bash
git add src/controllers/teamInviteController.ts src/routes/teamRoutes.ts
git commit -m "feat(teams): invite link controller + routes"
```

---

## Task 4: Frontend — Resend Fix + Service Layer + Query Keys

**Files:**
- Modify: `crelyzor-frontend/src/lib/queryKeys.ts`
- Modify: `crelyzor-frontend/src/services/teamService.ts`
- Modify: `crelyzor-frontend/src/hooks/queries/useTeamQueries.ts`

- [ ] **Step 1: Add `inviteLink` key to queryKeys.ts**

In `src/lib/queryKeys.ts`, find the `teams` object and add one line after `myInvites`:

```typescript
  teams: {
    all: ['teams'] as const,
    list: () => [...queryKeys.teams.all, 'list'] as const,
    detail: (teamId: string) =>
      [...queryKeys.teams.all, 'detail', teamId] as const,
    members: (teamId: string) =>
      [...queryKeys.teams.all, 'members', teamId] as const,
    invites: (teamId: string) =>
      [...queryKeys.teams.all, 'invites', teamId] as const,
    myInvites: () => [...queryKeys.teams.all, 'my-invites'] as const,
    inviteLink: (teamId: string) =>
      [...queryKeys.teams.all, 'invite-link', teamId] as const,
  },
```

- [ ] **Step 2: Add invite-link types and service methods to teamService.ts**

Add the `TeamInviteLink` interface after `MyPendingInvitesResponse` (before the `teamService` object):

```typescript
export interface TeamInviteLink {
  enabled: boolean;
  token: string | null;
  linkUrl: string | null;
  expiresAt: string | null;
}
```

Then add three new methods inside the `teamService` object (after `declineInviteByToken`):

```typescript
  /** GET /teams/:teamId/invite-link — Admin+. Current invite link state. */
  getInviteLink: (teamId: string) =>
    apiClient.get<TeamInviteLink>(`/teams/${teamId}/invite-link`),

  /** POST /teams/:teamId/invite-link/generate — Admin+. Create or replace token. */
  generateInviteLink: (teamId: string) =>
    apiClient.post<TeamInviteLink>(`/teams/${teamId}/invite-link/generate`),

  /** DELETE /teams/:teamId/invite-link — Admin+. Disable and clear token. */
  revokeInviteLink: (teamId: string) =>
    apiClient.delete<void>(`/teams/${teamId}/invite-link`),

  /** POST /teams/join-by-link/:token — JWT required. Join team via invite link. */
  joinByLink: (token: string) =>
    apiClient.post<{ membership: { teamId: string; role: TeamRole; team: { id: string; name: string; slug: string } } }>(
      `/teams/join-by-link/${token}`
    ),
```

- [ ] **Step 3: Fix `useResendInvite` — add `myInvites` invalidation**

In `src/hooks/queries/useTeamQueries.ts`, find `useResendInvite` and update its `onSuccess`:

```typescript
export const useResendInvite = (teamId: string) => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (inviteId: string) =>
      teamService.resendInvite(teamId, inviteId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['teams', 'invites', teamId] });
      queryClient.invalidateQueries({ queryKey: queryKeys.teams.myInvites() });
      toast.success('Invite resent');
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to resend';
      toast.error(msg);
    },
  });
};
```

- [ ] **Step 4: Add `useTeamInviteLink`, `useGenerateInviteLink`, `useRevokeInviteLink`, and `useJoinByLink` hooks**

Append these to the bottom of `useTeamQueries.ts`:

```typescript
// ── Invite link (Phase 6 P16) ─────────────────────────────────────────────

export const useTeamInviteLink = (teamId: string | null) =>
  useQuery({
    queryKey: teamId
      ? queryKeys.teams.inviteLink(teamId)
      : ['teams', 'invite-link', 'null'],
    queryFn: () => teamService.getInviteLink(teamId!),
    enabled: !!teamId,
    staleTime: 30_000,
  });

export const useGenerateInviteLink = (teamId: string) => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => teamService.generateInviteLink(teamId),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: queryKeys.teams.inviteLink(teamId),
      });
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to generate link';
      toast.error(msg);
    },
  });
};

export const useRevokeInviteLink = (teamId: string) => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: () => teamService.revokeInviteLink(teamId),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: queryKeys.teams.inviteLink(teamId),
      });
      toast.success('Invite link revoked');
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to revoke link';
      toast.error(msg);
    },
  });
};

export const useJoinByLink = () => {
  const queryClient = useQueryClient();
  const setActiveTeam = useTeamStore((s) => s.setActiveTeam);
  return useMutation({
    mutationFn: (token: string) => teamService.joinByLink(token),
    onSuccess: (data) => {
      setActiveTeam(data.membership.teamId);
      queryClient.invalidateQueries();
    },
    onError: () => {
      // InviteLinkPage renders its own error states inline — no toast here.
    },
  });
};
```

- [ ] **Step 5: Verify TypeScript in frontend**

```bash
cd crelyzor-frontend && pnpm tsc --noEmit 2>&1 | head -30
```

Expected: no errors in the files we touched.

- [ ] **Step 6: Commit**

```bash
cd crelyzor-frontend
git add src/lib/queryKeys.ts src/services/teamService.ts src/hooks/queries/useTeamQueries.ts
git commit -m "feat(teams): invite link service + query hooks + resend badge fix"
```

---

## Task 5: InvitesSection UI

**Files:**
- Modify: `crelyzor-frontend/src/pages/team-settings/sections/InvitesSection.tsx`

- [ ] **Step 1: Add imports**

At the top of `InvitesSection.tsx`, update the imports block to add:

```typescript
import { useState } from 'react';
import { Copy, Link, RefreshCw, Trash2, Mail, RotateCcw, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { toast } from 'sonner';
import {
  useCancelInvite,
  useGenerateInviteLink,
  useResendInvite,
  useRevokeInviteLink,
  useTeamInviteLink,
  useTeamInvites,
} from '@/hooks/queries/useTeamQueries';
import type { TeamInviteLink, TeamInvite, TeamRole } from '@/services/teamService';
```

(Remove the original import of `Mail, RotateCcw, X` from lucide-react since they're now in the combined import above.)

- [ ] **Step 2: Add `InviteLinkCard` component**

Add this component inside `InvitesSection.tsx`, before the `InvitesSection` function:

```typescript
function InviteLinkCard({ teamId }: { teamId: string }) {
  const { data: linkData, isLoading } = useTeamInviteLink(teamId);
  const generateMutation = useGenerateInviteLink(teamId);
  const revokeMutation = useRevokeInviteLink(teamId);
  const [confirmRevoke, setConfirmRevoke] = useState(false);

  const handleCopy = () => {
    if (!linkData?.linkUrl) return;
    navigator.clipboard.writeText(linkData.linkUrl).then(() => {
      toast.success('Link copied to clipboard');
    });
  };

  const handleRevoke = () => {
    revokeMutation.mutate(undefined, {
      onSuccess: () => setConfirmRevoke(false),
    });
  };

  if (isLoading) {
    return (
      <div className="rounded-xl border border-neutral-200 dark:border-neutral-800 p-4 animate-pulse">
        <div className="h-3 bg-neutral-200 dark:bg-neutral-800 rounded w-24 mb-3" />
        <div className="h-8 bg-neutral-100 dark:bg-neutral-900 rounded-lg w-full" />
      </div>
    );
  }

  const hasLink = linkData?.enabled && linkData.linkUrl;

  return (
    <div className="rounded-xl border border-neutral-200 dark:border-neutral-800 p-4 space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Link className="w-3.5 h-3.5 text-muted-foreground" />
          <span className="text-xs font-medium text-foreground">Invite link</span>
        </div>
        {hasLink && !confirmRevoke && (
          <Button
            variant="ghost"
            size="xs"
            className="text-muted-foreground hover:text-red-500 dark:hover:text-red-400 h-6 px-2"
            onClick={() => setConfirmRevoke(true)}
          >
            <Trash2 className="w-3 h-3 mr-1" />
            Revoke
          </Button>
        )}
      </div>

      {hasLink ? (
        <>
          <div className="flex items-center gap-2">
            <Input
              readOnly
              value={linkData.linkUrl!}
              className="text-xs h-8 font-mono bg-neutral-50 dark:bg-neutral-900 cursor-default select-all"
              onFocus={(e) => e.target.select()}
            />
            <Button
              variant="outline"
              size="icon-sm"
              onClick={handleCopy}
              title="Copy link"
            >
              <Copy className="w-3.5 h-3.5" />
            </Button>
            <Button
              variant="outline"
              size="icon-sm"
              onClick={() => generateMutation.mutate()}
              disabled={generateMutation.isPending}
              title="Regenerate link"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${generateMutation.isPending ? 'animate-spin' : ''}`} />
            </Button>
          </div>
          <p className="text-[11px] text-muted-foreground">
            Anyone with this link can join as a member. Regenerating immediately invalidates the old link.
          </p>
          {confirmRevoke && (
            <div className="flex items-center gap-2 pt-1">
              <span className="text-[11px] text-muted-foreground flex-1">
                Revoke this link? Anyone who has it won't be able to join.
              </span>
              <Button
                variant="ghost"
                size="xs"
                onClick={() => setConfirmRevoke(false)}
                className="h-6 px-2 text-xs"
              >
                Cancel
              </Button>
              <Button
                variant="destructive"
                size="xs"
                onClick={handleRevoke}
                disabled={revokeMutation.isPending}
                className="h-6 px-2 text-xs"
              >
                {revokeMutation.isPending ? 'Revoking…' : 'Revoke'}
              </Button>
            </div>
          )}
        </>
      ) : (
        <div className="flex items-center justify-between">
          <p className="text-[11px] text-muted-foreground">
            Generate a link anyone can use to join this team.
          </p>
          <Button
            variant="outline"
            size="sm"
            onClick={() => generateMutation.mutate()}
            disabled={generateMutation.isPending}
            className="h-7 text-xs shrink-0 ml-3"
          >
            {generateMutation.isPending ? 'Generating…' : 'Generate link'}
          </Button>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 3: Mount `InviteLinkCard` in `InvitesSection`**

In the `InvitesSection` function, after the opening `<div className="space-y-6">` and the `<SectionHeader .../>`, add the invite link card (only shown when `canManage`):

```tsx
  return (
    <div className="space-y-6">
      <SectionHeader
        title="Pending invites"
        description={
          isLoading
            ? ''
            : `${invites.length} pending invite${invites.length === 1 ? '' : 's'}`
        }
      />

      {canManage && <InviteLinkCard teamId={teamId} />}

      {isLoading ? (
        <InvitesSkeleton />
      ) : invites.length === 0 ? (
        <EmptyInvites />
      ) : (
        // ... rest of existing JSX unchanged
```

- [ ] **Step 4: Verify no TypeScript errors**

```bash
cd crelyzor-frontend && pnpm tsc --noEmit 2>&1 | grep InvitesSection
```

Expected: no output.

- [ ] **Step 5: Manual test in browser**

1. Open `http://localhost:5173/teams/<your-team-id>/settings` and navigate to the Invites tab.
2. Confirm the "Invite link" card appears with a "Generate link" button.
3. Click "Generate link" — should show the URL input, Copy button, and Regenerate button.
4. Click Copy — toast "Link copied to clipboard" should appear.
5. Click Regenerate — spinner, then new URL appears.
6. Click Revoke → confirm dialog → Revoke → card resets to "Generate link".
7. Resend an existing invite → badge in workspace switcher should clear (this was the bug fix in Task 4).

- [ ] **Step 6: Commit**

```bash
git add src/pages/team-settings/sections/InvitesSection.tsx
git commit -m "feat(teams): invite link card in InvitesSection"
```

---

## Task 6: InviteLinkPage + Route Registration

**Files:**
- Create: `crelyzor-frontend/src/pages/invite-link/InviteLinkPage.tsx`
- Create: `crelyzor-frontend/src/pages/invite-link/index.ts`
- Modify: `crelyzor-frontend/src/routes/routes.ts`
- Modify: `crelyzor-frontend/src/App.tsx`

- [ ] **Step 1: Create `InviteLinkPage.tsx`**

Create `src/pages/invite-link/InviteLinkPage.tsx`:

```typescript
import { useEffect, useRef, useState } from 'react';
import { Navigate, useNavigate, useParams } from 'react-router-dom';
import { Link2Off, Loader2, Users } from 'lucide-react';
import PageMotion from '@/components/PageMotion';
import { Button } from '@/components/ui/button';
import { useAuthStore } from '@/stores';
import { useJoinByLink } from '@/hooks/queries/useTeamQueries';
import { ApiError } from '@/lib/apiClient';

type ErrorKind = 'not-found' | 'expired' | 'already-member' | 'unknown';

function classifyError(err: unknown): ErrorKind {
  if (err instanceof ApiError) {
    if (err.status === 404) return 'not-found';
    if (err.status === 410) return 'expired';
    if (err.status === 409) return 'already-member';
  }
  return 'unknown';
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-6 py-12">
      <div className="w-full max-w-md bg-card border border-border rounded-2xl px-8 py-10 shadow-sm">
        {children}
      </div>
    </div>
  );
}

function IconDisc({ children }: { children: React.ReactNode }) {
  return (
    <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mx-auto">
      {children}
    </div>
  );
}

export default function InviteLinkPage() {
  const { token } = useParams<{ token: string }>();
  const navigate = useNavigate();
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const joinMutation = useJoinByLink();
  const fired = useRef(false);
  const [errorKind, setErrorKind] = useState<ErrorKind | null>(null);

  useEffect(() => {
    if (!isAuthenticated || !token) return;
    if (fired.current) return;
    fired.current = true;

    joinMutation.mutate(token, {
      onSuccess: (data) => {
        navigate(`/teams/${data.membership.teamId}/settings`, { replace: true });
      },
      onError: (err) => {
        setErrorKind(classifyError(err));
      },
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAuthenticated, token]);

  if (!token) return <Navigate to="/" replace />;

  if (!isAuthenticated) {
    return (
      <Navigate
        to={`/signin?next=${encodeURIComponent(`/invite/link/${token}`)}`}
        replace
      />
    );
  }

  if (errorKind === 'not-found') {
    return (
      <PageMotion>
        <Shell>
          <IconDisc>
            <Link2Off className="w-6 h-6 text-muted-foreground" />
          </IconDisc>
          <h1 className="text-lg font-medium text-foreground text-center mt-6 tracking-tight">
            Link not found
          </h1>
          <p className="text-sm text-muted-foreground text-center mt-2">
            This invite link is invalid or has been revoked by the team admin.
          </p>
          <Button
            variant="outline"
            className="w-full mt-6"
            onClick={() => navigate('/', { replace: true })}
          >
            Back to Crelyzor
          </Button>
        </Shell>
      </PageMotion>
    );
  }

  if (errorKind === 'expired') {
    return (
      <PageMotion>
        <Shell>
          <IconDisc>
            <Link2Off className="w-6 h-6 text-muted-foreground" />
          </IconDisc>
          <h1 className="text-lg font-medium text-foreground text-center mt-6 tracking-tight">
            Link expired
          </h1>
          <p className="text-sm text-muted-foreground text-center mt-2">
            Ask the team admin to generate a new invite link.
          </p>
          <Button
            variant="outline"
            className="w-full mt-6"
            onClick={() => navigate('/', { replace: true })}
          >
            Back to Crelyzor
          </Button>
        </Shell>
      </PageMotion>
    );
  }

  if (errorKind === 'already-member') {
    return (
      <PageMotion>
        <Shell>
          <IconDisc>
            <Users className="w-6 h-6 text-muted-foreground" />
          </IconDisc>
          <h1 className="text-lg font-medium text-foreground text-center mt-6 tracking-tight">
            You're already a member
          </h1>
          <p className="text-sm text-muted-foreground text-center mt-2">
            You already belong to this team.
          </p>
          <Button
            className="w-full mt-6"
            onClick={() => navigate('/', { replace: true })}
          >
            Go to workspace
          </Button>
        </Shell>
      </PageMotion>
    );
  }

  if (errorKind === 'unknown') {
    return (
      <PageMotion>
        <Shell>
          <IconDisc>
            <Link2Off className="w-6 h-6 text-muted-foreground" />
          </IconDisc>
          <h1 className="text-lg font-medium text-foreground text-center mt-6 tracking-tight">
            Something went wrong
          </h1>
          <p className="text-sm text-muted-foreground text-center mt-2">
            We couldn&rsquo;t process this invite link. Try again.
          </p>
          <div className="mt-6 space-y-2">
            <Button
              className="w-full"
              onClick={() => {
                fired.current = false;
                setErrorKind(null);
                joinMutation.reset();
                joinMutation.mutate(token!, {
                  onSuccess: (data) =>
                    navigate(`/teams/${data.membership.teamId}/settings`, {
                      replace: true,
                    }),
                  onError: (err) => setErrorKind(classifyError(err)),
                });
              }}
              disabled={joinMutation.isPending}
            >
              {joinMutation.isPending ? 'Joining…' : 'Try again'}
            </Button>
            <Button
              variant="ghost"
              className="w-full"
              onClick={() => navigate('/', { replace: true })}
            >
              Back to Crelyzor
            </Button>
          </div>
        </Shell>
      </PageMotion>
    );
  }

  return (
    <PageMotion>
      <Shell>
        <IconDisc>
          <Loader2 className="w-6 h-6 text-muted-foreground animate-spin" />
        </IconDisc>
        <h1 className="text-lg font-medium text-foreground text-center mt-6 tracking-tight">
          Joining team…
        </h1>
        <p className="text-sm text-muted-foreground text-center mt-2">
          Hang tight — we're finalising your membership.
        </p>
      </Shell>
    </PageMotion>
  );
}
```

- [ ] **Step 2: Create the barrel export**

Create `src/pages/invite-link/index.ts`:

```typescript
export { default } from './InviteLinkPage';
```

- [ ] **Step 3: Add lazy import to routes.ts**

In `src/routes/routes.ts`, add a lazy import after the existing `InvitePage` import:

```typescript
const InviteLinkPage = lazy(() => import('@/pages/invite-link'));
```

Then add it to the exported `routes` object:

```typescript
export const routes = {
  // ... existing routes ...
  InviteLinkPage,
};
```

- [ ] **Step 4: Register route in App.tsx**

In `src/App.tsx`, after the existing `/invite/:token` route, add:

```tsx
{/* Phase 6 P16 — join via shareable team link. Handles its own auth redirect. */}
<Route path="/invite/link/:token" element={<InviteLinkPage />} />
```

Also destructure `InviteLinkPage` from `routes` at the top:

```typescript
const {
  // ... existing destructures ...
  InviteLinkPage,
} = routes;
```

- [ ] **Step 5: Verify TypeScript**

```bash
cd crelyzor-frontend && pnpm tsc --noEmit 2>&1 | head -20
```

Expected: no errors.

- [ ] **Step 6: End-to-end test**

1. In the Invites tab of team settings, generate an invite link and copy it.
2. Open a private/incognito tab, paste the link.
3. Confirm redirect to `/signin?next=/invite/link/<token>`.
4. Sign in — confirm redirect back to the link URL, then the "Joining team…" spinner appears, then navigate to team settings.
5. Try the same link again (already a member) — confirm "You're already a member" screen.
6. Revoke the link from settings. Try the old URL — confirm "Link not found" screen.

- [ ] **Step 7: Commit**

```bash
git add src/pages/invite-link/ src/routes/routes.ts src/App.tsx
git commit -m "feat(teams): InviteLinkPage + route registration"
```
