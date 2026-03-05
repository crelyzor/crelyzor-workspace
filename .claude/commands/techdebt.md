---
description: Scan all 3 Crelyzor repos for tech debt — any types, console.log, hardcoded strings, unused imports, and convention violations.
allowed-tools: [Read, Glob, Grep, Bash]
---

Scan all 3 Crelyzor repos for tech debt. Run all searches in parallel.

## Scan 1 — calendar-backend

Search for:
- `console.log` — must use `logger`
- `: any` or `as any` — no any types
- `res.json(` or `res.send(` — must use `globalResponseHandler`
- `throw new Error(` — must use `throw new AppError(`
- Hardcoded strings that should be env vars (API keys, URLs)
- Missing `isDeleted: false` in Prisma queries that return user data

## Scan 2 — calendar-frontend

Search for:
- `console.log`
- `useEffect` used for data fetching (should be React Query)
- `fetch(` used directly (should use apiClient)
- `alert(` — must use toast
- Hardcoded hex colors (e.g. `#`) in className strings
- `<button` (plain HTML — should be `<Button>` from shadcn)
- `useState` used for data that should be in React Query or Zustand

## Scan 3 — cards-frontend

Search for:
- `console.log`
- Any auth logic (`useAuthStore`, `verifyJWT`, JWT tokens)
- `DM Sans` font reference (should use Inter)
- Dashboard features imported or referenced

## Output Format

```
TECH DEBT REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
calendar-backend
  CRITICAL (fix now):
  - [file:line] console.log found — replace with logger
  - [file:line] res.json() used — replace with globalResponseHandler

  WARNING (fix soon):
  - [file:line] : any type — add proper type

calendar-frontend
  CRITICAL:
  - [file:line] useEffect + fetch — migrate to React Query

  WARNING:
  - [file:line] hardcoded color #1a1a1a — use CSS variable

cards-frontend
  Clean ✓

SUMMARY: X critical issues · Y warnings
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Fix all CRITICAL issues immediately. List WARNING items for the user to prioritize.
