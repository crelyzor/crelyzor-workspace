---
description: Structured debugging for Crelyzor. Paste an error and this traces it through route → controller → service → DB and suggests a fix.
allowed-tools: [Read, Glob, Grep, Bash]
---

You are debugging a Crelyzor issue. Follow this process exactly.

## Step 1 — Understand the Error

Read the error message the user provided. Identify:
- Which repo is failing (backend / calendar-frontend / cards-frontend)
- What type of error (runtime crash / wrong data / 4xx/5xx response / TypeScript error / build failure)
- The exact file and line if available in the stack trace

## Step 2 — Trace the Stack

For **backend errors**, trace the full chain:
1. Read the relevant route file — is the route registered correctly?
2. Read the controller — is req/res handled correctly? Is validation correct?
3. Read the service — is the business logic correct? Are Prisma queries right?
4. Check the Prisma schema if DB-related — do field names match?
5. Check env config if external service failing (GCS, Deepgram, OpenAI)

For **frontend errors**, trace:
1. Read the component — is the query/mutation set up correctly?
2. Read the React Query hook — is the queryFn correct?
3. Read the service function — is the API call correct?
4. Check the backend response shape matches what frontend expects

For **build/TypeScript errors**:
1. Read the file with the error
2. Check the type definition it's failing against
3. Find the mismatch

## Step 3 — Check Dev Notes

Read `docs/dev-notes/` — there may be a documented gotcha for this exact area.

## Step 4 — Output the Fix

```
DEBUG REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Error: [error message]
Location: [file:line]

Root cause: [one clear sentence]

Trace:
→ [Route/Component] — [what's happening here]
→ [Controller/Hook] — [what's happening here]
→ [Service/Query] — [root cause here]

Fix:
[corrected code snippet]

Also check: [any related things that might have the same issue]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Apply the fix immediately after showing it.
