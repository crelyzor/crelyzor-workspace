---
name: review
description: Review recent Crelyzor code changes using the crelyzor-reviewer agent. Run this after writing or modifying code to catch issues before moving on.
---

Run an architecture and convention review on recent code changes.

## What to Review

1. Identify which files were recently modified (ask the user if unclear, or check what was just written)
2. Read each modified file completely
3. Apply the crelyzor-reviewer checklist from `.claude/agents/crelyzor-reviewer.md`

## Review Checklist (Quick Reference)

**Backend files:**
- [ ] Controller → Service → Prisma pattern followed
- [ ] AppError for errors, globalResponseHandler for responses
- [ ] logger not console.log
- [ ] Zod validation on inputs
- [ ] verifyJWT on protected routes
- [ ] Transactions for multi-step DB ops
- [ ] No `any` types

**Frontend files:**
- [ ] React Query for data fetching
- [ ] Query keys from queryKeys.ts
- [ ] PageMotion on new pages
- [ ] Dark mode on all elements
- [ ] No hardcoded colors
- [ ] Sonner toasts for user feedback
- [ ] No mock data

**Cards frontend files:**
- [ ] Public only — no auth
- [ ] Inter font, dark card, gold accent
- [ ] No dashboard features

## Output Format

```
REVIEW — [filename(s)]

✓ PASS  Controller → Service → Prisma pattern
✓ PASS  Zod validation present
✗ FAIL  console.log found on line 34 — replace with logger.info(...)
✗ FAIL  Missing dark mode on card component — add dark: prefix classes

VERDICT: NEEDS CHANGES

Fixed code for failures:
[provide corrected snippets]
```

## After Review

- If APPROVED: tell the user what to work on next
- If NEEDS CHANGES: fix the issues immediately, then re-confirm clean
