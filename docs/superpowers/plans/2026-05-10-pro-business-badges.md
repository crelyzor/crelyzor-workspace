# PRO & Business Plan Badges + Celebration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface PRO/BUSINESS plan status through a one-time celebration overlay and persistent badges in the dashboard sidebar, settings page, and public card.

**Architecture:** `user.plan` (already on JWT/auth store) drives all badge rendering. A `PlanBadge` component handles display in both crelyzor-frontend and crelyzor-public. A `PlanCelebrationOverlay` mounts once at the app root, fires on first post-upgrade visit, and is gated by `localStorage.plan_celebrated`.

**Tech Stack:** React 19, TypeScript, Tailwind CSS, shadcn/ui, canvas-confetti, Zustand authStore, Next.js (App Router for crelyzor-public)

---

### Task 1: Install canvas-confetti in crelyzor-frontend

**Files:**
- Modify: `crelyzor-frontend/package.json` (via pnpm)

- [ ] **Step 1: Install the package**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
pnpm add canvas-confetti
pnpm add -D @types/canvas-confetti
```

- [ ] **Step 2: Verify installation**

Run: `grep canvas-confetti package.json`
Expected: `"canvas-confetti": "^x.x.x"` in dependencies

---

### Task 2: Create PlanBadge component in crelyzor-frontend

**Files:**
- Create: `src/components/PlanBadge.tsx`

- [ ] **Step 1: Create the component**

```tsx
// src/components/PlanBadge.tsx
type Plan = 'FREE' | 'PRO' | 'BUSINESS';

const BADGE_CONFIG = {
  PRO: {
    label: 'PRO',
    className: 'border-[#d4af61] text-[#d4af61]',
  },
  BUSINESS: {
    label: 'BUSINESS',
    className: 'border-[#6366f1] text-[#6366f1]',
  },
} as const;

export function PlanBadge({ plan }: { plan: Plan }) {
  if (plan === 'FREE') return null;
  const config = BADGE_CONFIG[plan];
  return (
    <span
      className={`inline-flex items-center rounded-full border px-1.5 py-0.5 text-[9px] font-semibold tracking-wider uppercase ${config.className}`}
    >
      {config.label}
    </span>
  );
}
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend && pnpm tsc --noEmit`
Expected: no errors related to PlanBadge.tsx

---

### Task 3: Add PlanBadge to Sidebar user section

**Files:**
- Modify: `src/layout/Sidebar.tsx` (find where user name is rendered in the bottom section)

- [ ] **Step 1: Read the current Sidebar**

Read `src/layout/Sidebar.tsx` to find the user section — look for where `user.name` or the avatar/name block is rendered at the bottom.

- [ ] **Step 2: Import and render PlanBadge**

Add import at top:
```tsx
import { PlanBadge } from '@/components/PlanBadge';
```

In the user name block, add the badge after the name:
```tsx
<span className="text-sm font-medium truncate">{user.name}</span>
<PlanBadge plan={user.plan ?? 'FREE'} />
```

Wrap both in a flex container if not already:
```tsx
<div className="flex items-center gap-1.5 min-w-0">
  <span className="text-sm font-medium truncate">{user.name}</span>
  <PlanBadge plan={user.plan ?? 'FREE'} />
</div>
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `pnpm tsc --noEmit`
Expected: no errors

---

### Task 4: Add PlanBadge to Settings profile section

**Files:**
- Modify: `src/pages/settings/SettingsPage.tsx` (or the profile sub-section if split)

- [ ] **Step 1: Read the current Settings page structure**

Read `src/pages/settings/SettingsPage.tsx`. If it imports a profile component, read that too.

- [ ] **Step 2: Import and render PlanBadge**

Add import:
```tsx
import { PlanBadge } from '@/components/PlanBadge';
```

In the avatar/profile section, add badge below the name and above the email:
```tsx
<div className="flex flex-col items-center gap-1">
  <Avatar ... />
  <p className="text-sm font-semibold">{user.name}</p>
  <PlanBadge plan={user.plan ?? 'FREE'} />
  <p className="text-xs text-muted-foreground">{user.email}</p>
</div>
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `pnpm tsc --noEmit`
Expected: no errors

---

### Task 5: Create PlanCelebrationOverlay component

**Files:**
- Create: `src/components/PlanCelebrationOverlay.tsx`

- [ ] **Step 1: Create the overlay component**

```tsx
// src/components/PlanCelebrationOverlay.tsx
import { useEffect, useRef, useState } from 'react';
import confetti from 'canvas-confetti';
import { useAuthStore } from '@/stores/authStore';
import { PlanBadge } from '@/components/PlanBadge';

const MESSAGES = {
  PRO: "You're on Pro. Everything just got smarter.",
  BUSINESS: "Welcome to Business. Built for how serious teams work.",
} as const;

export function PlanCelebrationOverlay() {
  const user = useAuthStore((s) => s.user);
  const [visible, setVisible] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!user) return;
    if (user.plan === 'FREE') return;
    if (localStorage.getItem('plan_celebrated')) return;

    setVisible(true);

    confetti({
      particleCount: 120,
      spread: 80,
      origin: { y: 0.55 },
      colors: user.plan === 'PRO'
        ? ['#d4af61', '#f0d080', '#b8923a']
        : ['#6366f1', '#818cf8', '#4338ca'],
    });

    timerRef.current = setTimeout(() => dismiss(), 3000);

    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [user]);

  function dismiss() {
    if (timerRef.current) clearTimeout(timerRef.current);
    localStorage.setItem('plan_celebrated', 'true');
    setVisible(false);
  }

  if (!visible || !user || user.plan === 'FREE') return null;

  const message = MESSAGES[user.plan as keyof typeof MESSAGES];

  return (
    <div
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 backdrop-blur-sm"
      onClick={dismiss}
    >
      <div
        className="flex flex-col items-center gap-4 rounded-2xl bg-white dark:bg-neutral-900 px-10 py-10 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <PlanBadge plan={user.plan} />
        <p className="text-lg font-semibold text-center max-w-xs text-neutral-900 dark:text-neutral-100">
          {message}
        </p>
        <button
          onClick={dismiss}
          className="mt-2 text-xs text-muted-foreground hover:text-foreground transition-colors"
        >
          Dismiss
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `pnpm tsc --noEmit`
Expected: no errors

---

### Task 6: Mount PlanCelebrationOverlay in App.tsx

**Files:**
- Modify: `src/App.tsx`

- [ ] **Step 1: Read App.tsx**

Read `src/App.tsx` to find the right place to mount the overlay (top-level, inside auth context).

- [ ] **Step 2: Add import and mount**

Add import:
```tsx
import { PlanCelebrationOverlay } from '@/components/PlanCelebrationOverlay';
```

Mount once inside the auth-aware root (after auth providers, before or alongside routes):
```tsx
<PlanCelebrationOverlay />
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `pnpm tsc --noEmit`
Expected: no errors

---

### Task 7: Expose plan on public card API response (crelyzor-backend)

**Files:**
- Modify: `src/services/cardService.ts` — `getPublicCard` function, add `plan: true` to the user select

- [ ] **Step 1: Read cardService.ts getPublicCard**

Find the `getPublicCard` function. Look for the Prisma `select` on the `user` relation.

- [ ] **Step 2: Add plan to user select**

In the user select block, add:
```typescript
plan: true,
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-backend
pnpm tsc --noEmit
```
Expected: no errors

---

### Task 8: Add plan to CardUser type in crelyzor-public

**Files:**
- Modify: the type file in `crelyzor-public/src/` that defines the public card user shape (find via grep for `CardUser` or `PublicCard`)

- [ ] **Step 1: Find the type**

Run: `grep -r "CardUser\|PublicCard\|cardUser" /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-public/src/ --include="*.ts" --include="*.tsx" -l`

- [ ] **Step 2: Add plan field**

In the user type:
```typescript
plan: 'FREE' | 'PRO' | 'BUSINESS';
```

---

### Task 9: Create PlanBadge component in crelyzor-public

**Files:**
- Create: `src/components/PlanBadge.tsx` in crelyzor-public

- [ ] **Step 1: Create the component (server component — no 'use client' needed)**

```tsx
// crelyzor-public/src/components/PlanBadge.tsx
type Plan = 'FREE' | 'PRO' | 'BUSINESS';

const BADGE_CONFIG = {
  PRO: { label: 'PRO', className: 'border-[#d4af61] text-[#d4af61]' },
  BUSINESS: { label: 'BUSINESS', className: 'border-[#6366f1] text-[#6366f1]' },
} as const;

export function PlanBadge({ plan }: { plan: Plan }) {
  if (plan === 'FREE') return null;
  const config = BADGE_CONFIG[plan];
  return (
    <span
      className={`inline-flex items-center rounded-full border px-1.5 py-0.5 text-[9px] font-semibold tracking-wider uppercase ${config.className}`}
    >
      {config.label}
    </span>
  );
}
```

---

### Task 10: Render PlanBadge on public card page

**Files:**
- Modify: `src/app/[username]/page.tsx` or the `CardView` component inside it

- [ ] **Step 1: Find where the card is rendered**

Read `src/app/[username]/page.tsx`. Find where the user's title/role is rendered.

- [ ] **Step 2: Import and render badge below title**

```tsx
import { PlanBadge } from '@/components/PlanBadge';
```

Below the title/role element:
```tsx
<PlanBadge plan={card.user.plan ?? 'FREE'} />
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-public
pnpm tsc --noEmit
```
Expected: no errors

---

### Task 11: End-to-end smoke test

- [ ] **Step 1: Verify badge renders in sidebar**

Open `http://localhost:5173`. If logged in as a PRO/BUSINESS user, gold/indigo badge should appear next to name in sidebar bottom section.

- [ ] **Step 2: Verify badge renders in settings**

Navigate to Settings. Badge should appear below avatar, above email.

- [ ] **Step 3: Test celebration overlay (dev shortcut)**

In browser console: `localStorage.removeItem('plan_celebrated')`. Reload. If user.plan is PRO or BUSINESS, overlay should appear with confetti.

- [ ] **Step 4: Verify one-time guard**

After overlay dismisses, reload. Overlay should NOT appear again. `localStorage.getItem('plan_celebrated')` should return `'true'`.

- [ ] **Step 5: Verify public card badge**

Open `http://localhost:5174/<username>` for a PRO/BUSINESS user. Badge should appear below title.
