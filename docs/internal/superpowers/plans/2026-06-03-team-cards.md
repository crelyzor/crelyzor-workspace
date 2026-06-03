# Team Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Cards tab to Team Settings showing the team card (owner-editable) and all member cards (each member edits their own, others view-only), using the existing card flip interaction.

**Architecture:** New `GET /teams/:teamId/cards` endpoint returns team card + member-card roster. Frontend adds a Cards tab to TeamSettings that queries this endpoint, renders the existing card flip panel for view interactions, and passes canEdit based on role/userId. Card editor URL preview swapped to `/t/{teamSlug}/{slug}` when the card has a teamId.

**Tech Stack:** Express 5, Prisma 6, TypeScript 5, React 19, TanStack Query v5, Tailwind, shadcn/ui, Lucide, Motion

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `crelyzor-backend/src/services/teamCardService.ts` | Create | `getTeamCards` service logic |
| `crelyzor-backend/src/controllers/teamCardController.ts` | Create | Controller for `GET /:teamId/cards` |
| `crelyzor-backend/src/routes/teamRoutes.ts` | Modify | Wire new route |
| `crelyzor-backend/src/services/cardService.ts` | Modify | Add `team: { select }` include to `getCardById` |
| `crelyzor-frontend/src/types/card.ts` | Modify | Add `teamId`, `team` to `Card` interface |
| `crelyzor-frontend/src/lib/queryKeys.ts` | Modify | Add `teams.cards(teamId)` |
| `crelyzor-frontend/src/services/teamService.ts` | Modify | Add `TeamCardEntry`, `TeamCardsResponse`, `getTeamCards` |
| `crelyzor-frontend/src/hooks/queries/useTeamQueries.ts` | Modify | Add `useTeamCards` hook |
| `crelyzor-frontend/src/pages/team-settings/sections/CardsSection.tsx` | Create | Cards tab UI |
| `crelyzor-frontend/src/pages/team-settings/TeamSettings.tsx` | Modify | Add cards tab to SECTIONS + render |
| `crelyzor-frontend/src/pages/team-settings/index.ts` | Modify | Export `CardsSection` |
| `crelyzor-frontend/src/pages/card-editor/CardEditor.tsx` | Modify | Team URL preview |

---

## Task 1: Backend — `GET /teams/:teamId/cards` endpoint

**Files:**
- Create: `crelyzor-backend/src/services/teamCardService.ts`
- Create: `crelyzor-backend/src/controllers/teamCardController.ts`
- Modify: `crelyzor-backend/src/routes/teamRoutes.ts`

- [ ] **Step 1: Create the service file**

Create `crelyzor-backend/src/services/teamCardService.ts`:

```typescript
import { Prisma } from "@prisma/client";
import prisma from "../db/prismaClient";
import { AppError } from "../utils/errors/AppError";
import { getRole } from "./teamService";

const cardSelect = {
  id: true,
  userId: true,
  teamId: true,
  slug: true,
  displayName: true,
  title: true,
  bio: true,
  avatarUrl: true,
  coverUrl: true,
  links: true,
  contactFields: true,
  theme: true,
  templateId: true,
  showQr: true,
  htmlContent: true,
  htmlBackContent: true,
  isDefault: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
  _count: { select: { contacts: true, views: true } },
} satisfies Prisma.CardSelect;

export type TeamCardRow = Prisma.CardGetPayload<{ select: typeof cardSelect }>;

export interface TeamCardEntry {
  member: { id: string; name: string | null; avatarUrl: string | null };
  role: "OWNER" | "ADMIN" | "MEMBER";
  card: TeamCardRow | null;
}

export async function getTeamCards(
  teamId: string,
  actorId: string,
): Promise<{ teamCard: TeamCardRow | null; memberCards: TeamCardEntry[] }> {
  const role = await getRole(actorId, teamId);
  if (!role) throw new AppError("Team not found", 404);

  const team = await prisma.team.findFirst({
    where: { id: teamId, isDeleted: false },
    select: { ownerId: true },
  });
  if (!team) throw new AppError("Team not found", 404);

  const [allCards, allMembers] = await Promise.all([
    prisma.card.findMany({
      where: { teamId, isDeleted: false },
      select: cardSelect,
      orderBy: [{ isDefault: "desc" }, { createdAt: "asc" }],
    }),
    prisma.teamMember.findMany({
      where: { teamId, isDeleted: false },
      include: {
        user: { select: { id: true, name: true, avatarUrl: true } },
      },
      orderBy: { joinedAt: "asc" },
    }),
  ]);

  // Team card = owner's first card in this team (isDefault preferred)
  const teamCard = allCards.find((c) => c.userId === team.ownerId) ?? null;

  // Member cards = all non-owner members cross-joined with their cards
  const cardByUserId = new Map(
    allCards
      .filter((c) => c.userId !== team.ownerId)
      .map((c) => [c.userId, c]),
  );
  const nonOwnerMembers = allMembers.filter((m) => m.userId !== team.ownerId);
  const memberCards: TeamCardEntry[] = nonOwnerMembers.map((m) => ({
    member: m.user,
    role: m.role as "OWNER" | "ADMIN" | "MEMBER",
    card: cardByUserId.get(m.userId) ?? null,
  }));

  return { teamCard, memberCards };
}
```

- [ ] **Step 2: Create the controller file**

Create `crelyzor-backend/src/controllers/teamCardController.ts`:

```typescript
import type { Request, Response } from "express";
import { AppError } from "../utils/errors/AppError";
import { apiResponse } from "../utils/globalResponseHandler";
import { teamIdParamSchema } from "../validators/teamSchema";
import * as teamCardService from "../services/teamCardService";

export const getCards = async (req: Request, res: Response) => {
  const actorId = req.user!.userId;
  const params = teamIdParamSchema.safeParse(req.params);
  if (!params.success) throw new AppError("Invalid team id", 400);

  const data = await teamCardService.getTeamCards(
    params.data.teamId,
    actorId,
  );

  return apiResponse(res, {
    statusCode: 200,
    message: "Team cards fetched",
    data,
  });
};
```

- [ ] **Step 3: Wire the route in `teamRoutes.ts`**

Open `crelyzor-backend/src/routes/teamRoutes.ts`. After the existing imports block at the top, add:

```typescript
import * as teamCardController from "../controllers/teamCardController";
```

Then add this route after the `/:teamId/usage` line (around line 81):

```typescript
// ── Cards (Phase 6 P17) ───────────────────────────────────────────────────────
router.get("/:teamId/cards", readLimiter, teamCardController.getCards);
```

- [ ] **Step 4: TypeScript check**

```bash
docker compose exec backend pnpm tsc --noEmit
```

Expected: no errors.

- [ ] **Step 5: Smoke test the endpoint**

With Docker running and a valid JWT + teamId in your database:

```bash
curl -s -H "Authorization: Bearer <token>" \
  http://localhost:4000/api/v1/teams/<teamId>/cards | jq .
```

Expected: `{ "status": "success", "data": { "teamCard": null | {...}, "memberCards": [...] } }`

- [ ] **Step 6: Commit**

```bash
git add crelyzor-backend/src/services/teamCardService.ts \
        crelyzor-backend/src/controllers/teamCardController.ts \
        crelyzor-backend/src/routes/teamRoutes.ts
git commit -m "feat(teams): GET /teams/:teamId/cards endpoint"
```

---

## Task 2: Frontend — types, query key, service function, React Query hook

**Files:**
- Modify: `crelyzor-frontend/src/types/card.ts`
- Modify: `crelyzor-frontend/src/lib/queryKeys.ts`
- Modify: `crelyzor-frontend/src/services/teamService.ts`
- Modify: `crelyzor-frontend/src/hooks/queries/useTeamQueries.ts`

- [ ] **Step 1: Add `teamId` to the `Card` interface**

In `crelyzor-frontend/src/types/card.ts`, find the `Card` interface (line 24). Add `teamId` after `userId`:

```typescript
export interface Card {
  id: string;
  userId: string;
  teamId: string | null;   // ← add this line
  slug: string;
  // ... rest unchanged
```

- [ ] **Step 2: Add `teams.cards` query key**

In `crelyzor-frontend/src/lib/queryKeys.ts`, find the `teams` block (around line 196). Add `cards` after `inviteLink`:

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
    cards: (teamId: string) =>
      [...queryKeys.teams.all, 'cards', teamId] as const,
  },
```

- [ ] **Step 3: Add types and service function to `teamService.ts`**

In `crelyzor-frontend/src/services/teamService.ts`, add the following types and function. Place them at the end of the existing type declarations block (before the `teamService` object) and add the function inside the `teamService` object.

Add these types (after the existing `TeamMemberRow` interface, around line 66):

```typescript
export interface TeamCardRow {
  id: string;
  userId: string;
  teamId: string | null;
  slug: string;
  displayName: string;
  title: string | null;
  bio: string | null;
  avatarUrl: string | null;
  coverUrl: string | null;
  links: import('@/types').CardLink[];
  contactFields: import('@/types').CardContactFields;
  theme: import('@/types').CardTheme;
  templateId: string;
  showQr: boolean;
  htmlContent: string | null;
  htmlBackContent: string | null;
  isDefault: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  _count?: { contacts: number; views: number };
}

export interface TeamCardEntry {
  member: { id: string; name: string | null; avatarUrl: string | null };
  role: TeamRole;
  card: TeamCardRow | null;
}

export interface TeamCardsResponse {
  teamCard: TeamCardRow | null;
  memberCards: TeamCardEntry[];
}
```

Then add this function inside the `teamService` object (at the end, before the closing `}`):

```typescript
  getTeamCards: (teamId: string) =>
    apiClient.get<TeamCardsResponse>(`/teams/${teamId}/cards`),
```

- [ ] **Step 4: Add `useTeamCards` hook**

In `crelyzor-frontend/src/hooks/queries/useTeamQueries.ts`, add at the end of the file:

```typescript
export const useTeamCards = (teamId: string) =>
  useQuery({
    queryKey: queryKeys.teams.cards(teamId),
    queryFn: () => teamService.getTeamCards(teamId),
    staleTime: 60_000,
    enabled: !!teamId,
  });
```

Make sure `useQuery` is already imported at the top (it is, from the existing hooks).

- [ ] **Step 5: TypeScript check**

```bash
docker compose exec frontend pnpm tsc --noEmit
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add crelyzor-frontend/src/types/card.ts \
        crelyzor-frontend/src/lib/queryKeys.ts \
        crelyzor-frontend/src/services/teamService.ts \
        crelyzor-frontend/src/hooks/queries/useTeamQueries.ts
git commit -m "feat(teams): team cards query key, service, and hook"
```

---

## Task 3: Frontend — CardsSection component

**Files:**
- Create: `crelyzor-frontend/src/pages/team-settings/sections/CardsSection.tsx`

This component follows the same flip-panel pattern as `src/pages/cards/Cards.tsx`. Read that file before implementing to match the exact panel markup and animation classes (`card-spring-in`, `card-spring-out`).

- [ ] **Step 1: Create the file**

Create `crelyzor-frontend/src/pages/team-settings/sections/CardsSection.tsx`:

```typescript
import { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  CreditCard,
  ArrowUpRight,
  ExternalLink,
  Copy,
  QrCode,
  RotateCcw,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { CardPreview } from '@/components/cards/CardPreview';
import { QRCodeDialog } from '@/components/cards/QRCodeDialog';
import { useTeamCards } from '@/hooks/queries/useTeamQueries';
import { useCurrentUser } from '@/hooks/queries/useAuthQueries';
import { toast } from 'sonner';
import { CARDS_PUBLIC_URL } from '@/lib/publicUrl';
import type {
  TeamRole,
  TeamCardRow,
  TeamCardEntry,
  TeamSummary,
} from '@/services/teamService';

interface Props {
  teamId: string;
  role: TeamRole;
  team: TeamSummary;
}

function getCardUrl(card: TeamCardRow, teamSlug: string): string {
  return `${CARDS_PUBLIC_URL}/t/${teamSlug}/${card.slug}`;
}

function CardTile({
  card,
  canEdit,
  onOpen,
}: {
  card: TeamCardRow;
  canEdit: boolean;
  onOpen: (card: TeamCardRow) => void;
}) {
  return (
    <div className="relative group">
      <div
        className="cursor-pointer rounded-2xl overflow-hidden active:scale-[0.97] transition-transform duration-150 ease-out"
        style={{
          boxShadow: '0 4px 24px rgba(0,0,0,0.28), 0 0 0 1px rgba(255,255,255,0.06)',
        }}
        onClick={() => onOpen(card)}
      >
        <CardPreview
          displayName={card.displayName}
          title={card.title ?? undefined}
          bio={card.bio ?? undefined}
          avatarUrl={card.avatarUrl}
          coverUrl={card.coverUrl}
          links={card.links}
          contactFields={card.contactFields}
          theme={card.theme}
          htmlContent={card.htmlContent}
          htmlBackContent={card.htmlBackContent}
        />
      </div>
      <div className="mt-2 px-1 flex items-center justify-between">
        <p className="text-xs font-medium text-neutral-700 dark:text-neutral-300 truncate">
          {card.displayName}
        </p>
        {canEdit && (
          <span className="text-[10px] text-neutral-400 dark:text-neutral-500">
            yours
          </span>
        )}
      </div>
    </div>
  );
}

function NoCardPlaceholder({
  member,
}: {
  member: TeamCardEntry['member'];
}) {
  return (
    <div className="relative">
      <div
        className="rounded-2xl bg-neutral-100 dark:bg-neutral-800/60 border border-dashed border-neutral-200 dark:border-neutral-700 flex flex-col items-center justify-center"
        style={{ aspectRatio: '1.586 / 1' }}
      >
        <CreditCard className="w-5 h-5 text-neutral-300 dark:text-neutral-600" />
      </div>
      <div className="mt-2 px-1">
        <p className="text-xs font-medium text-neutral-500 dark:text-neutral-400 truncate">
          {member.name ?? 'Team member'}
        </p>
        <p className="text-[10px] text-neutral-400 dark:text-neutral-500">No card yet</p>
      </div>
    </div>
  );
}

export function CardsSection({ teamId, role, team }: Props) {
  const navigate = useNavigate();
  const { data: currentUser } = useCurrentUser();
  const { data, isLoading, isError } = useTeamCards(teamId);

  const [selectedCard, setSelectedCard] = useState<TeamCardRow | null>(null);
  const [flipped, setFlipped] = useState(false);
  const [closing, setClosing] = useState(false);
  const [qrDialogCard, setQrDialogCard] = useState<TeamCardRow | null>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const actionTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (closeTimerRef.current) clearTimeout(closeTimerRef.current);
      if (actionTimerRef.current) clearTimeout(actionTimerRef.current);
    };
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && selectedCard) closeCard();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [selectedCard]);

  const openCard = (card: TeamCardRow) => {
    setClosing(false);
    setFlipped(false);
    setSelectedCard(card);
  };

  const closeCard = () => {
    setClosing(true);
    closeTimerRef.current = setTimeout(() => {
      setSelectedCard(null);
      setClosing(false);
      closeTimerRef.current = null;
    }, 180);
  };

  const isAdminOrOwner = role === 'OWNER' || role === 'ADMIN';
  const myId = currentUser?.id;

  const canEditCard = (card: TeamCardRow) => card.userId === myId;

  if (isLoading) {
    return (
      <div className="space-y-8 animate-pulse">
        <div className="h-4 w-24 bg-neutral-100 dark:bg-neutral-800 rounded" />
        <div
          className="rounded-2xl bg-neutral-100 dark:bg-neutral-800 w-full"
          style={{ aspectRatio: '1.586 / 1' }}
        />
        <div className="h-4 w-28 bg-neutral-100 dark:bg-neutral-800 rounded mt-6" />
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="rounded-2xl bg-neutral-100 dark:bg-neutral-800"
              style={{ aspectRatio: '1.586 / 1' }}
            />
          ))}
        </div>
      </div>
    );
  }

  if (isError) {
    return (
      <p className="text-sm text-neutral-400 dark:text-neutral-500 py-8 text-center">
        Failed to load cards
      </p>
    );
  }

  const { teamCard, memberCards } = data!;

  return (
    <>
      <div className="space-y-8">
        {/* ── Team Card ── */}
        <section>
          <h2 className="text-xs font-semibold text-neutral-400 dark:text-neutral-500 uppercase tracking-wider mb-3">
            Team Card
          </h2>
          {teamCard ? (
            <div className="max-w-xs">
              <CardTile
                card={teamCard}
                canEdit={isAdminOrOwner}
                onOpen={openCard}
              />
            </div>
          ) : isAdminOrOwner ? (
            <div
              className="rounded-2xl bg-neutral-50 dark:bg-neutral-800/40 border border-dashed border-neutral-200 dark:border-neutral-700 flex flex-col items-center justify-center gap-2 max-w-xs cursor-pointer hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
              style={{ aspectRatio: '1.586 / 1' }}
              onClick={() => navigate('/cards/create')}
            >
              <CreditCard className="w-6 h-6 text-neutral-300 dark:text-neutral-600" />
              <p className="text-xs text-neutral-400 dark:text-neutral-500">
                Create team card
              </p>
            </div>
          ) : (
            <div
              className="rounded-2xl bg-neutral-50 dark:bg-neutral-800/40 border border-dashed border-neutral-200 dark:border-neutral-700 flex items-center justify-center max-w-xs"
              style={{ aspectRatio: '1.586 / 1' }}
            >
              <p className="text-xs text-neutral-400 dark:text-neutral-500">
                No team card yet
              </p>
            </div>
          )}
        </section>

        {/* ── Member Cards ── */}
        <section>
          <h2 className="text-xs font-semibold text-neutral-400 dark:text-neutral-500 uppercase tracking-wider mb-3">
            Member Cards · {memberCards.length}
          </h2>
          {memberCards.length === 0 ? (
            <p className="text-sm text-neutral-400 dark:text-neutral-500">
              No other members yet
            </p>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              {memberCards.map(({ member, card }) =>
                card ? (
                  <CardTile
                    key={member.id}
                    card={card}
                    canEdit={canEditCard(card)}
                    onOpen={openCard}
                  />
                ) : (
                  <NoCardPlaceholder key={member.id} member={member} />
                ),
              )}
            </div>
          )}
        </section>
      </div>

      {/* ── Card flip panel overlay ── */}
      {selectedCard && (
        <>
          {/* Backdrop */}
          <div
            className="fixed inset-0 z-40 bg-black/20 backdrop-blur-[2px]"
            onClick={closeCard}
          />

          {/* Panel */}
          <div
            className={`fixed z-50 inset-x-4 sm:inset-x-auto sm:left-1/2 sm:-translate-x-1/2 top-[10%] sm:top-[8%] sm:w-[480px]
              bg-white dark:bg-neutral-900
              ring-1 ring-neutral-200/80 dark:ring-neutral-700/60
              shadow-2xl shadow-neutral-900/30 dark:shadow-neutral-950/80
              rounded-2xl overflow-hidden
              ${closing ? 'card-spring-out' : 'card-spring-in'}`}
          >
            {/* Card preview — click to flip */}
            <div
              className="p-4 bg-neutral-950 cursor-pointer relative select-none"
              onClick={() => setFlipped((f) => !f)}
              title={flipped ? 'Click to see front' : 'Click to flip'}
            >
              <div style={{ perspective: '1200px' }}>
                <div
                  style={{
                    position: 'relative',
                    transformStyle: 'preserve-3d',
                    transform: flipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
                    transition: 'transform 0.55s cubic-bezier(0.4, 0, 0.2, 1)',
                  }}
                >
                  <div style={{ backfaceVisibility: 'hidden' }}>
                    <CardPreview
                      displayName={selectedCard.displayName}
                      title={selectedCard.title ?? undefined}
                      bio={selectedCard.bio ?? undefined}
                      avatarUrl={selectedCard.avatarUrl}
                      coverUrl={selectedCard.coverUrl}
                      links={selectedCard.links}
                      contactFields={selectedCard.contactFields}
                      theme={selectedCard.theme}
                      htmlContent={selectedCard.htmlContent}
                      htmlBackContent={selectedCard.htmlBackContent}
                      face="front"
                    />
                  </div>
                  <div
                    style={{
                      backfaceVisibility: 'hidden',
                      transform: 'rotateY(180deg)',
                      position: 'absolute',
                      inset: 0,
                    }}
                  >
                    <CardPreview
                      displayName={selectedCard.displayName}
                      title={selectedCard.title ?? undefined}
                      bio={selectedCard.bio ?? undefined}
                      avatarUrl={selectedCard.avatarUrl}
                      coverUrl={selectedCard.coverUrl}
                      links={selectedCard.links}
                      contactFields={selectedCard.contactFields}
                      theme={selectedCard.theme}
                      htmlContent={selectedCard.htmlContent}
                      htmlBackContent={selectedCard.htmlBackContent}
                      face="back"
                    />
                  </div>
                </div>
              </div>
              <div className="absolute bottom-6 right-6 pointer-events-none">
                <RotateCcw className="w-3 h-3 text-white/25" />
              </div>
            </div>

            {/* Card info + actions */}
            <div className="px-5 py-4">
              <div className="mb-4">
                <h2 className="text-sm font-semibold text-neutral-950 dark:text-neutral-50 truncate">
                  {selectedCard.displayName}
                </h2>
                {selectedCard.title && (
                  <p className="text-xs text-neutral-500 dark:text-neutral-400 mt-0.5 truncate">
                    {selectedCard.title}
                  </p>
                )}
                <p className="text-[11px] text-neutral-400 dark:text-neutral-600 mt-1 font-mono">
                  /t/{team.slug}/{selectedCard.slug}
                </p>
              </div>

              <div className="flex items-center gap-2">
                {canEditCard(selectedCard) && (
                  <Button
                    size="sm"
                    className="flex-1 h-9 rounded-xl text-xs font-medium bg-neutral-950 dark:bg-neutral-50 text-white dark:text-neutral-900 hover:bg-neutral-800 dark:hover:bg-neutral-200 gap-1.5"
                    onClick={() => {
                      closeCard();
                      if (actionTimerRef.current)
                        clearTimeout(actionTimerRef.current);
                      actionTimerRef.current = setTimeout(
                        () => navigate(`/cards/${selectedCard.id}`),
                        200,
                      );
                    }}
                  >
                    <ArrowUpRight className="w-3.5 h-3.5" />
                    Edit card
                  </Button>
                )}
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-9 w-9 rounded-xl p-0 text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-200"
                  title="Open public card"
                  onClick={() =>
                    window.open(
                      getCardUrl(selectedCard, team.slug),
                      '_blank',
                      'noopener,noreferrer',
                    )
                  }
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-9 w-9 rounded-xl p-0 text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-200"
                  onClick={() => {
                    navigator.clipboard.writeText(
                      getCardUrl(selectedCard, team.slug),
                    );
                    toast.success('Link copied');
                  }}
                >
                  <Copy className="w-3.5 h-3.5" />
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-9 w-9 rounded-xl p-0 text-neutral-500 hover:text-neutral-700 dark:hover:text-neutral-200"
                  onClick={() => {
                    closeCard();
                    if (actionTimerRef.current)
                      clearTimeout(actionTimerRef.current);
                    actionTimerRef.current = setTimeout(
                      () => setQrDialogCard(selectedCard),
                      200,
                    );
                  }}
                >
                  <QrCode className="w-3.5 h-3.5" />
                </Button>
              </div>
            </div>
          </div>
        </>
      )}

      {/* QR dialog */}
      {qrDialogCard && (
        <QRCodeDialog
          open={!!qrDialogCard}
          onOpenChange={(open) => !open && setQrDialogCard(null)}
          cardUrl={getCardUrl(qrDialogCard, team.slug)}
          cardName={qrDialogCard.displayName}
        />
      )}
    </>
  );
}
```

- [ ] **Step 2: TypeScript check**

```bash
docker compose exec frontend pnpm tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add crelyzor-frontend/src/pages/team-settings/sections/CardsSection.tsx
git commit -m "feat(teams): CardsSection component"
```

---

## Task 4: Frontend — Wire CardsSection into TeamSettings

**Files:**
- Modify: `crelyzor-frontend/src/pages/team-settings/TeamSettings.tsx`
- Modify: `crelyzor-frontend/src/pages/team-settings/index.ts`

- [ ] **Step 1: Add `CardsSection` import to `TeamSettings.tsx`**

In `crelyzor-frontend/src/pages/team-settings/TeamSettings.tsx`, add to the imports block (around line 23–28 where other sections are imported):

```typescript
import { CardsSection } from './sections/CardsSection';
```

- [ ] **Step 2: Add `'cards'` to the `TeamSettingsSection` type**

Find (line 30):
```typescript
type TeamSettingsSection =
  | 'general'
  | 'members'
  | 'invites'
  | 'usage'
  | 'billing'
  | 'danger';
```

Replace with:
```typescript
type TeamSettingsSection =
  | 'general'
  | 'members'
  | 'invites'
  | 'cards'
  | 'usage'
  | 'billing'
  | 'danger';
```

- [ ] **Step 3: Add `CreditCard` icon to the Lucide import**

Find the Lucide import at the top (line 18):
```typescript
import {
  Settings as SettingsIcon,
  Users,
  Mail,
  BarChart3,
  CreditCard,
  TriangleAlert,
} from 'lucide-react';
```

`CreditCard` is already imported (used for billing). We'll reuse it for the cards tab.

- [ ] **Step 4: Add 'cards' to the SECTIONS array**

Find the `SECTIONS` array (line 38). Add the cards entry after `invites`:

```typescript
const SECTIONS: Array<{
  id: TeamSettingsSection;
  label: string;
  icon: React.ElementType;
}> = [
  { id: 'general', label: 'General', icon: SettingsIcon },
  { id: 'members', label: 'Members', icon: Users },
  { id: 'invites', label: 'Invites', icon: Mail },
  { id: 'cards', label: 'Cards', icon: CreditCard },
  { id: 'usage', label: 'Usage', icon: BarChart3 },
  { id: 'billing', label: 'Billing', icon: CreditCard },
  { id: 'danger', label: 'Danger zone', icon: TriangleAlert },
];
```

Note: Both 'cards' and 'billing' use `CreditCard`. That's fine visually — they share the same icon.

- [ ] **Step 5: Render the CardsSection in the content area**

Find the content area block (around line 151–178). Add `CardsSection` after the `InvitesSection` block:

```typescript
{activeSection === 'invites' && (
  <InvitesSection teamId={teamId} role={membership.role} />
)}
{activeSection === 'cards' && (
  <CardsSection
    teamId={teamId}
    role={membership.role}
    team={membership.team}
  />
)}
{activeSection === 'usage' && (
  <UsageSection teamId={teamId} role={membership.role} />
)}
```

- [ ] **Step 6: Export from `index.ts`**

Open `crelyzor-frontend/src/pages/team-settings/index.ts` and add the export:

```typescript
export { CardsSection } from './sections/CardsSection';
```

- [ ] **Step 7: TypeScript check**

```bash
docker compose exec frontend pnpm tsc --noEmit
```

Expected: no errors.

- [ ] **Step 8: Visual test**

Open `http://localhost:5173`, navigate to Team Settings for a team you're a member of, click the "Cards" tab. Verify:
- Loading skeleton shows briefly
- Team card section renders (or shows "Create team card" CTA if owner hasn't made one)
- Member cards grid shows members with/without cards
- Clicking a card tile opens the flip panel
- Flip animation works (click the card area)
- "Edit card" button is shown only for your own card
- External link, copy, QR buttons work

- [ ] **Step 9: Commit**

```bash
git add crelyzor-frontend/src/pages/team-settings/TeamSettings.tsx \
        crelyzor-frontend/src/pages/team-settings/index.ts
git commit -m "feat(teams): wire Cards tab into TeamSettings"
```

---

## Task 5: Card editor URL preview fix

When editing a team-scoped card, the slug preview should show `/t/{teamSlug}/{slug}` instead of `/username/{slug}`.

**Files:**
- Modify: `crelyzor-backend/src/services/cardService.ts`
- Modify: `crelyzor-frontend/src/pages/card-editor/CardEditor.tsx`

- [ ] **Step 1: Include team relation in `getCardById`**

In `crelyzor-backend/src/services/cardService.ts`, find `getCardById` (around line 429). The current query is:

```typescript
const card = await prisma.card.findUnique({
  where: { id: cardId },
  include: {
    _count: { select: { contacts: true, views: true } },
  },
});
```

Replace the `include` block to add the team relation:

```typescript
const card = await prisma.card.findUnique({
  where: { id: cardId },
  include: {
    _count: { select: { contacts: true, views: true } },
    team: { select: { id: true, slug: true } },
  },
});
```

- [ ] **Step 2: TypeScript check on backend**

```bash
docker compose exec backend pnpm tsc --noEmit
```

Expected: no errors. (Prisma knows about the `team` relation on Card.)

- [ ] **Step 3: Add `team` to the frontend `Card` interface**

In `crelyzor-frontend/src/types/card.ts`, in the `Card` interface, add the `team` field after `teamId`:

```typescript
export interface Card {
  id: string;
  userId: string;
  teamId: string | null;
  team?: { id: string; slug: string } | null;  // ← add this line
  slug: string;
  // ... rest unchanged
```

- [ ] **Step 4: Fix the URL preview in `CardEditor.tsx`**

In `crelyzor-frontend/src/pages/card-editor/CardEditor.tsx`, find the slug preview text (around line 505–508):

```tsx
<p className="text-xs text-neutral-400">
  Your card will be accessible at /username/
  {slug || 'default'}
</p>
```

Replace with:

```tsx
<p className="text-xs text-neutral-400">
  {existingCard?.teamId && existingCard?.team?.slug
    ? `Your card will be accessible at /t/${existingCard.team.slug}/${slug || 'default'}`
    : `Your card will be accessible at /username/${slug || 'default'}`}
</p>
```

Note: `existingCard` is the card loaded from the query when editing. When creating a new card this is `undefined`, so it falls back to the personal URL format — correct behavior.

- [ ] **Step 5: TypeScript check on frontend**

```bash
docker compose exec frontend pnpm tsc --noEmit
```

Expected: no errors.

- [ ] **Step 6: Visual test**

1. In Team Settings → Cards tab, open your member card and click "Edit card"
2. In the card editor, find the "Card Slug" field — the preview text should show `/t/{teamSlug}/{slug}` not `/username/{slug}`
3. Change the slug input and verify the preview updates live

- [ ] **Step 7: Commit**

```bash
git add crelyzor-backend/src/services/cardService.ts \
        crelyzor-frontend/src/types/card.ts \
        crelyzor-frontend/src/pages/card-editor/CardEditor.tsx
git commit -m "feat(teams): card editor shows team URL preview for team-scoped cards"
```
