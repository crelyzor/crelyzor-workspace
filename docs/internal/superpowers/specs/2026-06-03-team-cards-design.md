# Team Cards Implementation Design

## Goal

Surface team card and member cards inside Team Settings, with role-aware edit permissions and the existing card flip interaction for view actions.

## Architecture

```
TeamSettings
└── Cards tab (new)
      │
      ├── useTeamCards(teamId)
      │     └── GET /teams/:teamId/cards
      │           └── { teamCard: Card | null, memberCards: CardWithUser[] }
      │
      ├── Team Card block  — edit if OWNER/ADMIN, flip-view otherwise
      │
      └── Member Cards grid — edit if card.userId === me, flip-view for others
```

Permission rendering is fully client-side. The backend returns plain card data; the frontend derives `canEdit` from the actor's role (already in store) and userId comparison.

## Permission Matrix

| Role | Team Card | Own Member Card | Others' Member Cards |
|------|-----------|-----------------|----------------------|
| Owner / Admin | Edit | Edit | View (flip) |
| Member | View (flip) | Edit | View (flip) |

"View" = card flip interaction — same QR, copy link, open in new tab back face already used for personal cards.

---

## Backend

### New endpoint

```
GET /teams/:teamId/cards
├── verifyJWT
├── validate teamId (UUID Zod schema)
├── assert actor is a non-deleted TeamMember (any role)
└── teamCardService.getTeamCards(teamId, actorId)
```

### New service method: `getTeamCards`

```typescript
async function getTeamCards(teamId: string) {
  const team = await prisma.team.findFirst({
    where: { id: teamId, isDeleted: false },
    select: { ownerId: true },
  });

  const teamCard = await prisma.card.findFirst({
    where: { teamId, userId: team.ownerId, isDeleted: false },
    include: { /* standard card includes */ },
  });

  const allCards = await prisma.card.findMany({
    where: { teamId, isDeleted: false },
    include: { user: { select: { id: true, name: true, avatarUrl: true } } },
  });

  const allMembers = await prisma.teamMember.findMany({
    where: { teamId, isDeleted: false },
    include: { user: { select: { id: true, name: true, avatarUrl: true } } },
  });

  // Left-join members against cards — members with no card get a placeholder
  const memberCards = allMembers.map((m) => ({
    member: m.user,
    role: m.role,
    card: allCards.find((c) => c.userId === m.userId) ?? null,
  }));

  return { teamCard, memberCards };
}
```

### Response shape

```typescript
{
  teamCard: Card | null,
  memberCards: Array<{
    member: { id: string; name: string; avatarUrl: string | null };
    role: TeamRole;
    card: Card | null;  // null = member joined before auto-create or create failed
  }>
}
```

---

## Frontend

### New files

- `src/pages/team-settings/tabs/TeamCardsTab.tsx` — the Cards tab component
- `src/hooks/queries/useTeamCards.ts` — React Query hook for `GET /teams/:teamId/cards`
- `src/services/teamCardsService.ts` — API call function

### Query hook

```typescript
export function useTeamCards(teamId: string) {
  return useQuery({
    queryKey: queryKeys.teams.cards(teamId),
    queryFn: () => teamCardsService.getTeamCards(teamId),
  });
}
```

Add `cards: (teamId: string) => [...teams.detail(teamId), 'cards']` to `queryKeys.ts`.

### Tab layout

```tsx
<div className="space-y-8">
  <section>
    <h2 className="text-sm font-medium text-foreground mb-3">Team Card</h2>
    {teamCard
      ? <CardTile card={teamCard} canEdit={isAdminOrOwner} teamSlug={teamSlug} />
      : isAdminOrOwner
        ? <EmptyTeamCardCTA />
        : <EmptyTeamCardPlaceholder />
    }
  </section>

  <section>
    <h2 className="text-sm font-medium text-foreground mb-3">
      Member Cards · {memberCards.length}
    </h2>
    <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
      {memberCards.map(({ member, card }) =>
        card
          ? <CardTile
              key={member.id}
              card={card}
              canEdit={member.id === myId}
              teamSlug={teamSlug}
            />
          : <NoCardPlaceholder key={member.id} member={member} />
      )}
    </div>
  </section>
</div>
```

`CardTile` reuses the existing card flip component for view. `canEdit={true}` shows an **Edit** button on the card front face that navigates to the card editor.

### Wire into TeamSettings

Add "Cards" to the existing tabs array in `TeamSettingsPage` / `TeamSettingsTabs`. No new route needed — it's a tab, not a page.

---

## Card Editor URL Preview Fix

When `card.teamId` is set, the public URL preview in the card editor should show `/t/{teamSlug}/{cardSlug}` instead of `/{cardSlug}`.

```typescript
// In card editor public URL derivation
const publicUrl = card.teamId && card.team?.slug
  ? `/t/${card.team.slug}/${card.slug}`
  : `/${card.slug}`;
```

Requires the card editor query to include `team: { select: { slug: true } }` when fetching the card. This relation is already on the Card model.

---

## Edge Cases

- **Member with no card** — shown as a greyed-out placeholder tile with member name/avatar. No action button.
- **Team card missing** — admin/owner sees "Create team card" CTA that opens card creator with `teamId` pre-set. Members see a neutral placeholder.
- **Team card `include`** — the team card's `user` is the team owner, so `card.user` gives owner info as expected.

---

## What Is NOT in Scope

- Creating additional cards per member within a team (one member = one team card)
- Admins editing member cards
- Card ordering or pinning within the grid
