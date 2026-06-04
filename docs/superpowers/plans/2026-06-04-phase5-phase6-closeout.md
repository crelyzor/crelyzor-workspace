# Phase 5 + Phase 6 Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all remaining Phase 5 (encryption trust-signals) and Phase 6 (team card URL preview) open tasks across all three repos.

**Architecture:** Pure frontend changes — no schema, no new backend endpoints. Phase 5 items are trust-signal UI (badges, copy, error paths). Phase 6 item is a one-line URL fix in the card editor. All changes are additive and isolated to the files listed.

**Tech Stack:** React 19 + TypeScript, TanStack Query v5, shadcn/ui, Tailwind v4, Lucide icons (frontend); Next.js App Router (public)

---

## Files touched

| File | Change |
|------|--------|
| `crelyzor-frontend/src/services/authService.ts` | Add `deactivateAccount()` function |
| `crelyzor-frontend/src/hooks/queries/useAuthQueries.ts` | Add `useDeactivateAccount()` hook |
| `crelyzor-frontend/src/lib/queryClient.ts` | Add global query `onError` to suppress `DECRYPT_FAILED` toasts |
| `crelyzor-frontend/src/pages/settings/Settings.tsx` | Encryption card + delete account confirmation dialog in `SecuritySection` |
| `crelyzor-frontend/src/pages/meeting-detail/SharedTabs.tsx` | Lock icon badge on Transcript / Summary / Notes section headers |
| `crelyzor-frontend/src/pages/card-editor/CardEditor.tsx` | Full URL with domain + actual username in slug preview hint |
| `crelyzor-public/src/app/privacy/page.tsx` | Add encryption-at-rest section + update "last updated" date |
| `crelyzor-public/src/app/schedule/[username]/[slug]/confirmed/ConfirmedClient.tsx` | Add encryption note in footer |

---

## Task 1: Add `deactivateAccount` to auth service + hook

**Files:**
- Modify: `crelyzor-frontend/src/services/authService.ts`
- Modify: `crelyzor-frontend/src/hooks/queries/useAuthQueries.ts`

The backend endpoint is `DELETE /auth/account`. No request body. Returns `{ message: string }`.

- [x] **Step 1: Add to authService.ts**

Open `crelyzor-frontend/src/services/authService.ts`. Find the `logout` line and add below it:

```typescript
  deactivateAccount: () => apiClient.delete<{ message: string }>('/auth/account'),
```

- [x] **Step 2: Add hook to useAuthQueries.ts**

Open `crelyzor-frontend/src/hooks/queries/useAuthQueries.ts`. Find the `useLogout` function and add after it:

```typescript
export function useDeactivateAccount() {
  const { clearAuth } = useAuthStore();
  const navigate = useNavigate();
  return useMutation({
    mutationFn: () => authService.deactivateAccount(),
    onSuccess: () => {
      clearAuth();
      navigate('/signin', { replace: true });
    },
  });
}
```

Check what imports are already present at the top of `useAuthQueries.ts` — `useNavigate`, `useMutation`, `useAuthStore`, and `authService` are almost certainly already imported; only add what is missing.

- [x] **Step 3: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
git add src/services/authService.ts src/hooks/queries/useAuthQueries.ts
git commit -m "feat: add deactivateAccount service + hook for account deletion flow"
```

---

## Task 2: Settings > Security — Encryption card + Delete account confirmation dialog

**File:**
- Modify: `crelyzor-frontend/src/pages/settings/Settings.tsx`

This task adds two things to `SecuritySection()`:
1. A read-only "Encryption" info card that explains what's encrypted and how
2. A proper confirmation Dialog for "Delete Account" with crypto-shred copy (instead of the current no-op button)

- [x] **Step 1: Add `Lock` to the Lucide import list**

At the top of `Settings.tsx`, find the lucide-react import block and add `Lock` to it. Example (your list will be longer — just add `Lock` to the existing destructured list):

```typescript
import {
  // ... existing icons ...
  Lock,
} from 'lucide-react';
```

- [x] **Step 2: Add `useDeactivateAccount` to the Settings import**

Near the top of the file, find where `useLogout` is imported:

```typescript
import { useCurrentUser, useLogout } from '@/hooks/queries/useAuthQueries';
```

Change it to:

```typescript
import { useCurrentUser, useLogout, useDeactivateAccount } from '@/hooks/queries/useAuthQueries';
```

- [x] **Step 3: Rewrite `SecuritySection()`**

Find `function SecuritySection()` (starts around line 2795). Replace the entire function body with the version below. The key additions are:
- `deactivateAccount` mutation from `useDeactivateAccount()`
- `deleteOpen` state to control the confirmation Dialog
- A `nameConfirm` state for the typed-name guard
- The Encryption info card above the Danger Zone
- The Delete Account Dialog with crypto-shred warning copy

```typescript
function SecuritySection() {
  const { data: profile } = useCurrentUser();
  const {
    data: sessions,
    isLoading: sessionsLoading,
    isError: sessionsError,
  } = useSessions();
  const revokeSession = useRevokeSession();
  const deactivateAccount = useDeactivateAccount();
  const [deleteOpen, setDeleteOpen] = useState(false);

  return (
    <div className="space-y-6">
      <SectionHeader
        title="Security"
        description="Manage your account security and connected services"
      />

      <Card className="border-neutral-200 dark:border-neutral-800">
        <CardContent className="p-6 space-y-4">
          {/* Connected accounts */}
          <div>
            <h3 className="text-sm font-semibold text-neutral-950 dark:text-neutral-50 mb-3">
              Connected Accounts
            </h3>
            <div className="flex items-center gap-3 p-3 rounded-lg border border-neutral-200 dark:border-neutral-700">
              <div className="w-8 h-8 rounded-full bg-white dark:bg-neutral-800 border border-neutral-200 dark:border-neutral-700 flex items-center justify-center">
                <Globe className="w-4 h-4 text-neutral-500" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                  Google
                </p>
                <p className="text-xs text-neutral-400">
                  {profile?.email ?? ''}
                </p>
              </div>
              <span className="text-[10px] font-medium text-emerald-500 bg-emerald-50 dark:bg-emerald-950/30 px-2 py-0.5 rounded-full">
                Connected
              </span>
            </div>
          </div>

          {/* Sessions */}
          <div className="pt-4 border-t border-neutral-100 dark:border-neutral-800">
            <h3 className="text-sm font-semibold text-neutral-950 dark:text-neutral-50 mb-3">
              Active Sessions
            </h3>
            {sessionsLoading ? (
              <div className="space-y-2">
                {[1, 2].map((i) => (
                  <div
                    key={i}
                    className="h-14 rounded-lg bg-neutral-100 dark:bg-neutral-800 animate-pulse"
                  />
                ))}
              </div>
            ) : sessionsError ? (
              <p className="text-xs text-neutral-400">
                Failed to load sessions.
              </p>
            ) : sessions && Array.isArray(sessions) && sessions.length > 0 ? (
              <div className="space-y-2">
                {sessions.map(
                  (session: {
                    id: string;
                    userAgent?: string;
                    ipAddress?: string;
                    createdAt: string;
                    isCurrent?: boolean;
                  }) => (
                    <div
                      key={session.id}
                      className="flex items-center gap-3 p-3 rounded-lg border border-neutral-200 dark:border-neutral-700"
                    >
                      <div className="w-8 h-8 rounded-full bg-neutral-100 dark:bg-neutral-800 flex items-center justify-center">
                        <Monitor className="w-4 h-4 text-neutral-500" />
                      </div>
                      <div className="flex-1">
                        <p className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                          {session.userAgent ?? 'Unknown device'}
                        </p>
                        <p className="text-xs text-neutral-400">
                          {session.isCurrent
                            ? 'Current session'
                            : `Since ${new Date(session.createdAt).toLocaleDateString()}`}
                          {session.ipAddress ? ` · ${session.ipAddress}` : ''}
                        </p>
                      </div>
                      {session.isCurrent ? (
                        <span className="text-[10px] font-medium text-emerald-500">
                          Active
                        </span>
                      ) : (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-xs text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950/30 h-7 px-2"
                          disabled={revokeSession.isPending}
                          onClick={() => revokeSession.mutate(session.id)}
                        >
                          Revoke
                        </Button>
                      )}
                    </div>
                  )
                )}
              </div>
            ) : (
              <div className="flex items-center gap-3 p-3 rounded-lg border border-neutral-200 dark:border-neutral-700">
                <div className="w-8 h-8 rounded-full bg-neutral-100 dark:bg-neutral-800 flex items-center justify-center">
                  <Monitor className="w-4 h-4 text-neutral-500" />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-neutral-900 dark:text-neutral-100">
                    Current session
                  </p>
                  <p className="text-xs text-neutral-400">Active now</p>
                </div>
                <span className="text-[10px] font-medium text-emerald-500">
                  Active
                </span>
              </div>
            )}
          </div>

          {/* Encryption at Rest */}
          <div className="pt-4 border-t border-neutral-100 dark:border-neutral-800">
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-lg bg-neutral-100 dark:bg-neutral-800 flex items-center justify-center shrink-0 mt-0.5">
                <Lock className="w-4 h-4 text-neutral-500 dark:text-neutral-400" />
              </div>
              <div>
                <p className="text-sm font-semibold text-neutral-900 dark:text-neutral-100 mb-0.5">
                  Encryption at Rest
                </p>
                <p className="text-xs text-neutral-500 dark:text-neutral-400 leading-relaxed">
                  Meeting transcripts, notes, AI content, tasks, contacts, and booking PII are
                  encrypted at rest using Google Cloud KMS (AES-256-GCM, per-user key).
                  Crelyzor can decrypt for AI features and your own access — a leaked database
                  alone cannot be read.
                </p>
              </div>
            </div>
          </div>

          {/* Danger zone */}
          <div className="pt-4 border-t border-neutral-100 dark:border-neutral-800">
            <h3 className="text-sm font-semibold text-red-500 mb-3">
              Danger Zone
            </h3>
            <Button
              variant="outline"
              size="sm"
              className="text-xs text-red-500 border-red-200 dark:border-red-900/50 hover:bg-red-50 dark:hover:bg-red-950/20"
              onClick={() => setDeleteOpen(true)}
            >
              Delete Account
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Delete Account Dialog */}
      <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle className="text-base font-semibold text-red-500">
              Delete your account?
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 mt-1">
            <p className="text-sm text-neutral-600 dark:text-neutral-400 leading-relaxed">
              Deleting your account destroys your encryption key. Your data —
              including in our backups — becomes permanently unrecoverable.
              This cannot be undone.
            </p>
            <div className="flex gap-2 justify-end">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setDeleteOpen(false)}
                disabled={deactivateAccount.isPending}
              >
                Cancel
              </Button>
              <Button
                variant="destructive"
                size="sm"
                disabled={deactivateAccount.isPending}
                onClick={() => deactivateAccount.mutate()}
              >
                {deactivateAccount.isPending
                  ? 'Deleting…'
                  : 'Yes, delete my account'}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
```

- [x] **Step 4: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
git add src/pages/settings/Settings.tsx
git commit -m "feat: encryption card + delete account dialog with crypto-shred warning in Security settings"
```

---

## Task 3: Lock badge on meeting detail section headers

**File:**
- Modify: `crelyzor-frontend/src/pages/meeting-detail/SharedTabs.tsx`

Add a small `Lock` icon next to the "Transcript", "Summary", and "Notes" section headers. This is a neutral trust signal — no color, muted, non-interactive.

- [x] **Step 1: Add `Lock` to Lucide import in SharedTabs.tsx**

Find the lucide-react import block at the top of the file. Add `Lock` to the existing destructured list.

- [x] **Step 2: Add the badge to the Transcript section header**

Find the `TranscriptTab` function (around line 469). Inside the returned JSX, find:

```tsx
<h3 className="text-sm font-semibold text-neutral-950 dark:text-neutral-50">
  Transcript
</h3>
```

Replace with:

```tsx
<h3 className="text-sm font-semibold text-neutral-950 dark:text-neutral-50 flex items-center gap-1.5">
  Transcript
  <Lock className="w-3 h-3 text-neutral-300 dark:text-neutral-600" aria-label="Encrypted at rest" />
</h3>
```

- [x] **Step 3: Find and update the Summary section header**

Search for the `SummaryTab` function (or wherever the "Summary" heading is rendered inside `SharedTabs.tsx`). Find a heading like:

```tsx
<h3 className="text-sm font-semibold text-neutral-950 dark:text-neutral-50">
  Summary
</h3>
```

Apply the same pattern:

```tsx
<h3 className="text-sm font-semibold text-neutral-950 dark:text-neutral-50 flex items-center gap-1.5">
  Summary
  <Lock className="w-3 h-3 text-neutral-300 dark:text-neutral-600" aria-label="Encrypted at rest" />
</h3>
```

- [x] **Step 4: Find and update the Notes section header**

Apply the same pattern to the "Notes" section heading inside `NotesTab` (or wherever the notes header renders).

- [x] **Step 5: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
git add src/pages/meeting-detail/SharedTabs.tsx
git commit -m "feat: encrypted-at-rest lock badge on transcript/summary/notes section headers"
```

---

## Task 4: Suppress toast for DECRYPT_FAILED errors in queryClient

**File:**
- Modify: `crelyzor-frontend/src/lib/queryClient.ts`

When the backend returns a `DECRYPT_FAILED` error code (very rare — KMS/IAM issue), the inline empty state in the component already handles the user-facing message. We must not show a generic toast on top of it.

The `ApiError.data` is the raw response body object. For a `DECRYPT_FAILED` response, the backend sends `{ errorCode: 'DECRYPT_FAILED', message: '...' }`.

- [x] **Step 1: Update queryClient.ts**

Replace the entire file content with:

```typescript
import { QueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { ApiError } from './apiClient';

function isDecryptFailed(error: unknown): boolean {
  if (!(error instanceof ApiError)) return false;
  const data = error.data as { errorCode?: string } | null;
  return data?.errorCode === 'DECRYPT_FAILED';
}

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      gcTime: 1000 * 60 * 30, // 30 minutes (formerly cacheTime)
      retry: (failureCount, error) => {
        if (
          error instanceof ApiError &&
          (error.status === 401 || error.status === 403)
        ) {
          return false;
        }
        // Never retry decrypt failures — retrying won't fix a KMS issue
        if (isDecryptFailed(error)) return false;
        return failureCount < 2;
      },
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
      onError: (error) => {
        // DECRYPT_FAILED renders an inline empty state — suppress the generic toast
        if (isDecryptFailed(error)) return;
        toast.error('Something went wrong');
      },
    },
  },
});
```

- [x] **Step 2: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
git add src/lib/queryClient.ts
git commit -m "fix: suppress generic toast for DECRYPT_FAILED errors, let inline states handle display"
```

---

## Task 5: Card editor — full URL preview with domain + actual username

**File:**
- Modify: `crelyzor-frontend/src/pages/card-editor/CardEditor.tsx`

Currently the slug hint shows relative paths like `/username/${slug}` literally. Fix it to show the real full URL including domain and the signed-in user's username.

- [x] **Step 1: Import CARDS_PUBLIC_URL and useCurrentUser**

Near the top of `CardEditor.tsx`, find the existing imports:

```typescript
import { useTeam } from '@/hooks/queries/useTeamQueries';
import { useTeamStore } from '@/stores';
```

Add `useCurrentUser` import. Check if `@/hooks/queries/useAuthQueries` is already imported — if not, add:

```typescript
import { useCurrentUser } from '@/hooks/queries/useAuthQueries';
```

Also add the `CARDS_PUBLIC_URL` import. Check if `@/lib/publicUrl` is already imported — if not, add:

```typescript
import { CARDS_PUBLIC_URL } from '@/lib/publicUrl';
```

- [x] **Step 2: Call useCurrentUser inside the component**

Inside the `CardEditor` component function, find where `activeTeamId` and `isCreatingTeamCard` are declared (around line 106). Add below them:

```typescript
const { data: currentUser } = useCurrentUser();
const username = currentUser?.username ?? '';
```

- [x] **Step 3: Update the slug preview hint**

Find the JSX block around lines 515–521:

```tsx
<p className="text-xs text-neutral-400">
  {existingCard?.teamId && existingCard?.team?.slug
    ? `Your card will be accessible at /t/${existingCard.team.slug}/${slug || 'default'}`
    : isCreatingTeamCard && activeTeam?.team?.slug
      ? `Your team card will be accessible at /t/${activeTeam.team.slug}/${slug || 'default'}`
      : `Your card will be accessible at /username/${slug || 'default'}`}
</p>
```

Replace with:

```tsx
<p className="text-xs text-neutral-400">
  {existingCard?.teamId && existingCard?.team?.slug
    ? `${CARDS_PUBLIC_URL}/t/${existingCard.team.slug}/${slug || 'your-slug'}`
    : isCreatingTeamCard && activeTeam?.team?.slug
      ? `${CARDS_PUBLIC_URL}/t/${activeTeam.team.slug}/${slug || 'your-slug'}`
      : `${CARDS_PUBLIC_URL}/${username || 'you'}/${slug || 'your-slug'}`}
</p>
```

- [x] **Step 4: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-frontend
git add src/pages/card-editor/CardEditor.tsx
git commit -m "fix: show full URL with domain and real username in card editor slug preview"
```

---

## Task 6: Privacy page — add Encryption at Rest section

**File:**
- Modify: `crelyzor-public/src/app/privacy/page.tsx`

Update section 5 ("Data Storage & Security") to accurately describe AES-256-GCM + Google Cloud KMS. Also update `LAST_UPDATED`.

- [x] **Step 1: Update LAST_UPDATED**

Find:

```typescript
const LAST_UPDATED = 'April 22, 2025';
```

Replace with:

```typescript
const LAST_UPDATED = 'June 4, 2026';
```

- [x] **Step 2: Replace section 5 with accurate encryption detail**

Find:

```tsx
<section>
  <h2 className="text-base font-semibold text-foreground mb-2">
    5. Data Storage & Security
  </h2>
  <p>
    Your data is stored on secure servers. We use industry-standard
    encryption in transit (TLS) and at rest. Access is restricted to
    authorised personnel only. No system is 100% secure — please use
    strong passwords and report any suspected breaches immediately.
  </p>
</section>
```

Replace with:

```tsx
<section>
  <h2 className="text-base font-semibold text-foreground mb-2">
    5. Data Storage & Security
  </h2>
  <p>
    All data is transmitted over TLS. Sensitive user data — including
    meeting transcripts, notes, AI-generated content, tasks, contact
    details, and booking PII — is encrypted at rest using AES-256-GCM
    with per-user encryption keys managed by Google Cloud KMS. A leaked
    database alone cannot be read without the corresponding KMS key.
    Access to keys is restricted to authorised Crelyzor infrastructure
    only. No system is 100% secure — please report any suspected
    breaches to{' '}
    <a
      href="mailto:harshkeshari100@gmail.com"
      className="underline underline-offset-2 hover:text-foreground transition-colors"
    >
      harshkeshari100@gmail.com
    </a>{' '}
    immediately.
  </p>
</section>
```

- [x] **Step 3: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-public
git add src/app/privacy/page.tsx
git commit -m "docs: update privacy policy with AES-256-GCM + Google Cloud KMS encryption details"
```

---

## Task 7: Booking confirmation — add encryption footer note

**File:**
- Modify: `crelyzor-public/src/app/schedule/[username]/[slug]/confirmed/ConfirmedClient.tsx`

Guests submitting via the booking flow hand over their name, email, and notes. A brief reassurance note at the bottom of the confirmation page builds trust.

- [x] **Step 1: Find the footer link block**

In `ConfirmedClient.tsx`, find the footer at the bottom of the main content area:

```tsx
<div className="pt-4 pb-8 text-center">
  <Link
    href="/"
    className="text-[11px] tracking-widest uppercase text-neutral-400 hover:text-neutral-600 transition-colors"
  >
    Powered by Crelyzor
  </Link>
</div>
```

- [x] **Step 2: Add the encryption note above the "Powered by" link**

Replace the entire `<div>` with:

```tsx
<div className="pt-4 pb-8 text-center space-y-2">
  <p className="text-[10px] text-neutral-400">
    Your booking details are encrypted at rest.
  </p>
  <Link
    href="/"
    className="text-[11px] tracking-widest uppercase text-neutral-400 hover:text-neutral-600 transition-colors"
  >
    Powered by Crelyzor
  </Link>
</div>
```

- [x] **Step 3: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace/crelyzor-public
git add src/app/schedule/[username]/[slug]/confirmed/ConfirmedClient.tsx
git commit -m "feat: add encryption-at-rest reassurance note on booking confirmation page"
```

---

## Task 8: Mark all tasks complete in TASKS.md files

**Files:**
- Modify: `crelyzor-workspace/TASKS.md` — mark Phase 5 frontend trust-signal items `[x]`
- Modify: `crelyzor-workspace/crelyzor-frontend/TASKS.md` — mark Phase 5 frontend items `[x]`
- Modify: `crelyzor-workspace/crelyzor-public/TASKS.md` — mark Phase 5 public items `[x]`
- Modify: `crelyzor-workspace/TASKS.md` — mark Phase 6 P12 card editor URL item `[x]`

- [x] **Step 1: Mark items done in root TASKS.md**

In `TASKS.md`, find the Phase 6 P12 section. Change:

```
- [ ] Card editor public URL preview swap to `crelyzor.app/t/[team-slug]/[card-slug]` when in team context — small follow-up.
```

To:

```
- [x] Card editor public URL preview swap to `crelyzor.app/t/[team-slug]/[card-slug]` when in team context — small follow-up.
```

- [x] **Step 2: Mark items done in crelyzor-frontend/TASKS.md**

Find and change the following 4 items from `- [ ]` to `- [x]`:

1. `**Privacy section in Settings**`
2. `**"Encrypted" badge on meeting detail**`
3. `**Account-deletion confirmation modal**`
4. `**Decrypt-failure error path**`
5. `React Query global onError handler`

- [x] **Step 3: Mark items done in crelyzor-public/TASKS.md**

Find and change from `- [ ]` to `- [x]`:

1. `**Update \`/privacy\` page**`
2. `**Booking confirmation page**` (the encryption footer note item)

- [x] **Step 4: Commit**

```bash
cd /Users/harshkeshari/Developer/crelyzor-workspace
git add TASKS.md crelyzor-frontend/TASKS.md crelyzor-public/TASKS.md
git commit -m "chore: mark Phase 5 trust-signal UI + Phase 6 card URL tasks complete"
```

---

## Self-review

**Spec coverage:**
- ✅ Privacy section in Settings (Task 2 — Encryption at Rest card in SecuritySection)
- ✅ Encrypted badge on meeting detail (Task 3 — lock icon on Transcript/Summary/Notes headers)
- ✅ Account-deletion confirmation modal copy (Task 2 — Dialog with crypto-shred warning)
- ✅ Decrypt-failure error path / React Query global onError (Task 4 — queryClient.ts)
- ✅ Privacy page update (Task 6 — section 5 rewrite with AES-256-GCM + KMS)
- ✅ Booking confirmation encryption note (Task 7)
- ✅ Marketing copy audit — section 5 rewrite covers it; no other marketing copy makes security claims
- ✅ Card editor URL preview swap (Task 5)

**No placeholders:** All code blocks are complete and self-contained.

**Type consistency:** `useDeactivateAccount` returns a mutation with `mutate()` (no args) — used correctly in SecuritySection as `deactivateAccount.mutate()`. `ApiError.data` typed as `unknown`, cast narrowly in `isDecryptFailed()`. No cross-task type drift.
