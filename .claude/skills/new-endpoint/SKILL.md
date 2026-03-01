---
name: new-endpoint
description: Scaffold a complete new API endpoint for Crelyzor following all backend conventions. Creates route, controller method, service method, Zod validator, and TypeScript types. Use when adding any new backend feature.
---

You are scaffolding a new API endpoint for Crelyzor's backend (`calendar-backend`).

## Step 1 — Gather Info

Ask the user (if not already provided):
1. What does this endpoint do? (one sentence)
2. HTTP method + path (e.g., `POST /sma/meetings/:meetingId/ask`)
3. Is it authenticated? (default: yes, use `verifyJWT`)
4. What does the request body / params look like?
5. What does it return?

## Step 2 — Read Existing Patterns

Before writing anything, read:
- The relevant routes file (e.g., `src/routes/smaRoutes.ts`)
- The relevant controller (e.g., `src/controllers/aiController.ts`)
- The relevant service (e.g., `src/services/ai/aiService.ts`)
- The relevant validator file (e.g., `src/validators/meetingSchema.ts`)

Understand the existing patterns before adding to them.

## Step 3 — Scaffold All Files

Create/update these files in order:

### 1. Zod Schema (in `src/validators/`)
```typescript
// src/validators/[domain]Schema.ts
export const [actionName]Schema = z.object({
  // fields with proper validation
});
export type [ActionName]Input = z.infer<typeof [actionName]Schema>;
```

### 2. TypeScript Types (in `src/types/` if needed)
```typescript
// Only if complex return types needed
export interface [ActionName]Result {
  // typed return shape
}
```

### 3. Service Method (in `src/services/[domain]/`)
```typescript
// Full business logic here
// - Verify ownership/permissions first
// - Use prisma.$transaction if multiple DB ops
// - Throw AppError for errors
// - Use logger for logging
// - Return typed result
async function [actionName](params): Promise<[ActionName]Result> {
  // implementation
}
```

### 4. Controller Method (in `src/controllers/[domain]Controller.ts`)
```typescript
export const [actionName] = async (req: Request, res: Response) => {
  const validated = [actionName]Schema.safeParse(req.body);
  if (!validated.success) throw new AppError("Validation failed", 400);

  const result = await [domain]Service.[actionName]({
    ...validated.data,
    userId: req.user.id,
  });

  return globalResponseHandler(res, 200, "[Success message]", result);
};
```

### 5. Route (in `src/routes/[domain]Routes.ts`)
```typescript
router.[method]("[path]", verifyJWT, [domain]Controller.[actionName]);
```

## Step 4 — Verify

After scaffolding:
- Check TypeScript compiles: `cd calendar-backend && npx tsc --noEmit`
- Confirm route is registered in `src/routes/indexRouter.ts` if it's a new route file
- Update `calendar-backend/TASKS.md` — mark the endpoint as done

## Conventions (Never Break These)

- Controller → Service → Prisma (never skip)
- `AppError` for all errors
- `globalResponseHandler` for all responses
- `logger` not `console.log`
- Zod validation on ALL inputs
- `verifyJWT` on ALL protected routes
- `prisma.$transaction` with `{ timeout: 15000 }` for multi-step ops
- No `any` types
