---
name: new-page
description: Scaffold a complete new page for Crelyzor's dashboard (calendar-frontend) following all UI conventions. Creates the page component, React Query hook, service function, query keys, and route registration. Use when adding any new frontend page or major section.
---

You are scaffolding a new page for Crelyzor's frontend (`calendar-frontend`).

## Step 1 — Gather Info

Ask the user (if not already provided):
1. What is this page? (one sentence)
2. Route path (e.g., `/meetings/:id/ask`)
3. What data does it need from the API? (which endpoints)
4. What actions can the user take? (mutations)
5. Any special UI requirements?

## Step 2 — Read Existing Patterns

Before writing anything, read:
- `src/routes/routes.ts` — how routes are registered
- `src/lib/queryKeys.ts` — existing query key patterns
- A similar existing page for reference (e.g., `src/pages/meetings/Meetings.tsx`)
- `src/services/meetingsService.ts` — service pattern

## Step 3 — Scaffold All Files

### 1. Service Functions (in `src/services/[domain]Service.ts`)
```typescript
// Add to existing service or create new one
export const [domain]Service = {
  async getX(params): Promise<X> {
    const res = await apiClient.get(`/api/v1/[path]`);
    return res.data.data;
  },
  async doY(params): Promise<Y> {
    const res = await apiClient.post(`/api/v1/[path]`, params);
    return res.data.data;
  },
};
```

### 2. Query Keys (in `src/lib/queryKeys.ts`)
```typescript
// Add to queryKeys object
[domain]: {
  all: () => ["[domain]"] as const,
  byId: (id: string) => ["[domain]", id] as const,
  list: (filters?: object) => ["[domain]", "list", filters] as const,
},
```

### 3. React Query Hook (in `src/hooks/queries/use[Domain].ts`)
```typescript
export function use[Domain]Query(id: string) {
  return useQuery({
    queryKey: queryKeys.[domain].byId(id),
    queryFn: () => [domain]Service.getX({ id }),
    enabled: !!id,
  });
}

export function use[Domain]Mutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: [domain]Service.doY,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.[domain].all() });
      toast.success("[Action] successful");
    },
    onError: () => toast.error("Something went wrong"),
  });
}
```

### 4. Page Component (in `src/pages/[domain]/[PageName].tsx`)
```typescript
import PageMotion from "@/components/PageMotion";

export default function [PageName]() {
  const { data, isLoading } = use[Domain]Query(id);

  // Loading state
  if (isLoading) return <[PageName]Skeleton />;

  // Empty state
  if (!data) return <[PageName]Empty />;

  return (
    <PageMotion>
      <div className="max-w-7xl mx-auto px-8 py-10">
        {/* content */}
      </div>
    </PageMotion>
  );
}

// Always include skeleton
function [PageName]Skeleton() {
  return (
    <PageMotion>
      <div className="max-w-7xl mx-auto px-8 py-10 animate-pulse">
        <div className="h-8 bg-neutral-200 dark:bg-neutral-800 rounded-lg w-1/3 mb-6" />
        <div className="h-4 bg-neutral-200 dark:bg-neutral-800 rounded-lg w-1/2" />
      </div>
    </PageMotion>
  );
}

// Always include empty state
function [PageName]Empty() {
  return (
    <PageMotion>
      <div className="flex flex-col items-center justify-center py-24 text-center">
        <Icon className="h-10 w-10 text-muted-foreground mb-3" />
        <p className="text-sm font-medium">Nothing here yet</p>
        <p className="text-xs text-muted-foreground mt-1">Description of how to get started</p>
      </div>
    </PageMotion>
  );
}
```

### 5. Route Registration (in `src/routes/routes.ts`)
```typescript
{ path: "/[path]", element: <[PageName] /> }
```

## Step 4 — Verify

After scaffolding:
- Check TypeScript: `cd calendar-frontend && npx tsc --noEmit`
- Confirm the page loads without errors
- Confirm dark mode works on all elements
- Update `calendar-frontend/TASKS.md`

## Conventions (Never Break These)

- Every page wrapped in `<PageMotion>`
- Every page has: loading state (skeleton) + empty state + error handling
- Data fetching via React Query only — no `useEffect + fetch`
- All query keys in `queryKeys.ts`
- Toasts via Sonner for all mutations
- Dark mode on every element (`dark:` prefix)
- No colors outside neutral palette
- shadcn/ui components only — no plain HTML elements for UI
- No mock/hardcoded data
