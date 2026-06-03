# Team Card Dashboard Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user is in a team workspace, replace the personal card widget on the dashboard home page with the team's digital card widget.

**Architecture:** Read `activeTeamId` from `useTeamStore` in `Home.tsx`. When set, render a new `TeamCardWidget` component instead of `DefaultCardWidget`. `TeamCardWidget` fetches the team's card via the existing `useTeamCards` hook and renders it with the same `CardPreview` + 3D flip modal pattern as `DefaultCardWidget`.

**Tech Stack:** React 19, TypeScript, TanStack Query v5, Zustand (`useTeamStore`), `CardPreview` component, `useTeamCards` hook, `useTeamStore` store.

---

## Files

| File | Action |
|---|---|
| `src/pages/home/TeamCardWidget.tsx` | Create — new widget component |
| `src/pages/home/Home.tsx` | Modify — import store + conditional render |

---

### Task 1: Create `TeamCardWidget`

**Files:**
- Create: `src/pages/home/TeamCardWidget.tsx`

- [ ] **Step 1: Create the component**

Create `src/pages/home/TeamCardWidget.tsx` with the full implementation:

```tsx
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CreditCard, ArrowUpRight, Pencil, X, RotateCcw } from 'lucide-react';
import { useTeamCards } from '@/hooks/queries/useTeamQueries';
import { CardPreview } from '@/components/cards/CardPreview';

interface Props {
  teamId: string;
}

export function TeamCardWidget({ teamId }: Props) {
  const navigate = useNavigate();
  const { data, isLoading } = useTeamCards(teamId);
  const [show3D, setShow3D] = useState(false);
  const [flipped, setFlipped] = useState(false);

  const teamCard = data?.teamCard ?? null;

  if (isLoading) {
    return (
      <div className="rounded-2xl border border-neutral-200 dark:border-neutral-800 bg-white dark:bg-neutral-900 p-4 animate-pulse">
        <div className="h-2.5 w-20 bg-neutral-100 dark:bg-neutral-800 rounded mb-3" />
        <div className="aspect-[1.586/1] rounded-xl bg-neutral-100 dark:bg-neutral-800" />
      </div>
    );
  }

  if (!teamCard) {
    return (
      <button
        onClick={() => navigate(`/teams/${teamId}/settings?tab=cards`)}
        className="w-full rounded-2xl border border-dashed border-neutral-200 dark:border-neutral-700 bg-white dark:bg-neutral-900
                   p-6 flex flex-col items-center text-center cursor-pointer hover:border-neutral-300 dark:hover:border-neutral-600 transition-colors group"
      >
        <div className="w-9 h-9 rounded-xl bg-neutral-100 dark:bg-neutral-800 flex items-center justify-center mb-3">
          <CreditCard className="w-4.5 h-4.5 text-neutral-400" />
        </div>
        <p className="text-[13px] font-medium text-neutral-700 dark:text-neutral-300 mb-1">
          Set a team card
        </p>
        <p className="text-[11px] text-neutral-400 dark:text-neutral-500 leading-relaxed">
          Add a shared card that represents your team
        </p>
      </button>
    );
  }

  const hasFront = !!teamCard.htmlContent;
  const hasBack = !!teamCard.htmlBackContent;

  return (
    <>
      <div className="rounded-2xl border border-neutral-200 dark:border-neutral-800 bg-white dark:bg-neutral-900 overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-neutral-100 dark:border-neutral-800">
          <div className="flex items-center gap-2">
            <CreditCard className="w-3.5 h-3.5 text-neutral-400" />
            <span className="text-[10px] tracking-[0.18em] text-neutral-400 dark:text-neutral-500 uppercase font-medium">
              Team Card
            </span>
          </div>
          <div className="flex items-center gap-1">
            <button
              onClick={() => navigate(`/teams/${teamId}/settings?tab=cards`)}
              className="p-1.5 rounded-lg text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-200 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
              aria-label="Edit team card"
            >
              <Pencil className="w-3 h-3" />
            </button>
            <button
              onClick={() => navigate(`/teams/${teamId}/settings?tab=cards`)}
              className="p-1.5 rounded-lg text-neutral-400 hover:text-neutral-700 dark:hover:text-neutral-200 hover:bg-neutral-100 dark:hover:bg-neutral-800 transition-colors"
              aria-label="Team cards"
            >
              <ArrowUpRight className="w-3 h-3" />
            </button>
          </div>
        </div>
        <div
          className="px-3 py-3 cursor-pointer"
          onClick={() => {
            setFlipped(false);
            setShow3D(true);
          }}
        >
          <div className="rounded-xl overflow-hidden ring-1 ring-neutral-200 dark:ring-neutral-700 transition-transform hover:scale-[1.01] duration-200">
            <CardPreview
              displayName={teamCard.displayName}
              title={teamCard.title ?? undefined}
              bio={teamCard.bio ?? undefined}
              avatarUrl={teamCard.avatarUrl}
              coverUrl={teamCard.coverUrl}
              links={teamCard.links}
              contactFields={teamCard.contactFields}
              theme={teamCard.theme}
              htmlContent={teamCard.htmlContent}
              htmlBackContent={teamCard.htmlBackContent}
            />
          </div>
          <p className="text-[9px] text-neutral-300 dark:text-neutral-700 text-center mt-2">
            Click to preview in 3D
          </p>
        </div>
      </div>

      {show3D && (hasFront || hasBack) && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
          onClick={() => setShow3D(false)}
        >
          <div className="relative" onClick={(e) => e.stopPropagation()}>
            <button
              onClick={() => setShow3D(false)}
              className="absolute -top-10 right-0 p-1.5 rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
            {hasBack && (
              <button
                onClick={() => setFlipped(!flipped)}
                className="absolute -top-10 left-0 flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 text-white text-xs transition-colors"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                Flip
              </button>
            )}
            <div style={{ perspective: '1200px' }}>
              <div
                className="w-[340px] sm:w-[480px] transition-transform duration-700 cursor-pointer"
                onClick={() => hasBack && setFlipped(!flipped)}
                style={{
                  transformStyle: 'preserve-3d',
                  transform: flipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
                }}
              >
                <div
                  style={{
                    backfaceVisibility: 'hidden',
                    WebkitBackfaceVisibility: 'hidden',
                  }}
                >
                  <div
                    className="rounded-2xl overflow-hidden"
                    style={{
                      aspectRatio: '1.586 / 1',
                      boxShadow:
                        '0 0 0 1px rgba(255,255,255,0.08), 0 8px 30px rgba(0,0,0,0.4)',
                    }}
                    dangerouslySetInnerHTML={{
                      __html: teamCard.htmlContent || '',
                    }}
                  />
                </div>
                {hasBack && (
                  <div
                    className="absolute inset-0"
                    style={{
                      backfaceVisibility: 'hidden',
                      WebkitBackfaceVisibility: 'hidden',
                      transform: 'rotateY(180deg)',
                    }}
                  >
                    <div
                      className="rounded-2xl overflow-hidden"
                      style={{
                        aspectRatio: '1.586 / 1',
                        boxShadow:
                          '0 0 0 1px rgba(255,255,255,0.08), 0 8px 30px rgba(0,0,0,0.4)',
                      }}
                      dangerouslySetInnerHTML={{
                        __html: teamCard.htmlBackContent || '',
                      }}
                    />
                  </div>
                )}
              </div>
            </div>
            <p className="text-center text-white/40 text-[10px] mt-4">
              {hasBack
                ? 'Click the card or "Flip" to rotate'
                : 'Click anywhere to close'}
            </p>
          </div>
        </div>
      )}
    </>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/home/TeamCardWidget.tsx
git commit -m "feat: add TeamCardWidget for team workspace dashboard"
```

---

### Task 2: Wire into `Home.tsx`

**Files:**
- Modify: `src/pages/home/Home.tsx`

- [ ] **Step 1: Add import for `useTeamStore` and `TeamCardWidget`**

In `src/pages/home/Home.tsx`, add two imports alongside the existing ones:

```tsx
import { useTeamStore } from '@/stores/teamStore';
import { TeamCardWidget } from './TeamCardWidget';
```

- [ ] **Step 2: Read `activeTeamId` in the component body**

Inside the `Home` component function, after the existing hooks, add:

```tsx
const activeTeamId = useTeamStore((s) => s.activeTeamId);
```

- [ ] **Step 3: Swap the widget in the right column**

Find this line in the JSX (right column, around line 275):

```tsx
<DefaultCardWidget />
```

Replace it with:

```tsx
{activeTeamId ? (
  <TeamCardWidget teamId={activeTeamId} />
) : (
  <DefaultCardWidget />
)}
```

- [ ] **Step 4: Verify TypeScript passes**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
pnpm tsc --noEmit
```

Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
git add src/pages/home/Home.tsx
git commit -m "feat: show TeamCardWidget on dashboard when in team workspace"
```
