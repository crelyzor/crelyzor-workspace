---
description: Verification pass after /crelyzor-review. Re-runs all 8 review agents across all 3 repos, cross-references findings against the most recent review report, and gives a final verdict — what's fixed, what's still broken, and what's a new regression.
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent]
---

You are the Crelyzor CTO running a post-fix verification pass. Your job is to confirm that the previous `/crelyzor-review` run fixed what it said it fixed, and that nothing new broke.

## Step 1 — Find the Previous Report

Run: `ls docs/reviews/ | sort | tail -1` to find the most recent review report.
Read that report. Extract:
- The list of issues that were marked ✅ Fixed
- The list of issues that were marked as Skipped
- The total files changed

Store this as the "Previous Report". You will compare against it.

---

## Step 2 — Re-run All 8 Review Agents in Parallel

Launch ALL 8 agents simultaneously using `run_in_background: true`. Same agents as `/crelyzor-review`.

**Agent 1 — Security**
Use agent type: `security-reviewer`
Prompt: "Re-review the entire calendar-backend for security issues. Read all files in src/routes/, src/controllers/, src/services/, src/middleware/. Check every route for missing verifyJWT, every service for missing userId ownership scoping, every public endpoint for data exposure. Report ALL issues found — even ones previously known."

**Agent 2 — Database Layer**
Use agent type: `db-layer-reviewer`
Prompt: "Re-review all Prisma service code in calendar-backend/src/services/ for soft delete gaps, N+1 queries, missing pagination, uncovered transactions, and missing ownership scoping. Report ALL issues found."

**Agent 3 — Schema**
Use agent type: `schema-reviewer`
Prompt: "Re-review calendar-backend/prisma/schema.prisma. Check every model for UUID id, soft delete fields, correct relations, naming conventions, and @@index coverage. Report ALL issues found."

**Agent 4 — Silent Failures**
Use agent type: `pr-review-toolkit:silent-failure-hunter`
Prompt: "Re-review all files in calendar-backend/src/ and calendar-frontend/src/ for silent failures, swallowed errors, empty catch blocks, and unhandled async failures. Report ALL issues found."

**Agent 5 — Tech Debt**
Use agent type: `general-purpose`
Prompt: "Re-scan all TypeScript files across calendar-backend/src/, calendar-frontend/src/, and cards-frontend/ for: any TypeScript 'any' types, console.log statements, hardcoded strings that should be constants, unused imports, and dead code. Report ALL issues found with file and line number."

**Agent 6 — API Contract**
Use agent type: `api-contract-reviewer`
Prompt: "Re-review the API contract across calendar-backend. Check response shape consistency, HTTP error codes, missing pagination, missing Zod validation, type drift between backend and frontend, public endpoint safety, and missing rate limiting. Report ALL issues found."

**Agent 7 — Frontend Quality**
Use agent type: `frontend-quality-reviewer`
Prompt: "Re-review calendar-frontend/src/pages/ and hooks/queries/ for missing error boundaries, incomplete loading/empty/error states, missing React Query cache invalidation, memory leaks, raw useEffect data fetching, and hardcoded query keys. Report ALL issues found."

**Agent 8 — Performance**
Use agent type: `performance-reviewer`
Prompt: "Re-review calendar-backend/src/services/ and prisma/schema.prisma for over-fetching, missing indexes, synchronous expensive operations, missing OpenAI token limits, and sequential awaits. Re-review calendar-frontend for missing staleTime and un-memoized expensive components. Report ALL issues found."

**Wait for all 8 agents to complete before proceeding.**

---

## Step 3 — Cross-Reference Against Previous Report

Using a `general-purpose` agent (foreground):

Prompt:
"You are comparing two code review snapshots for the Crelyzor codebase.

PREVIOUS REPORT (issues that were supposedly fixed):
[INSERT PREVIOUS REPORT CONTENT]

CURRENT REVIEW FINDINGS (fresh scan):
[INSERT ALL 8 AGENT OUTPUTS]

Classify every issue from the previous report as one of:
✅ FIXED — issue no longer appears in the fresh scan
❌ STILL PRESENT — issue still exists in the fresh scan (the fix didn't work or wasn't applied)
⚠️ REGRESSED — was fixed but broke something adjacent

Then classify every issue from the fresh scan that was NOT in the previous report as:
🆕 NEW ISSUE — something that either appeared after the fixes or was missed before

Output a clean table for each category."

---

## Step 4 — Final Verdict

Based on the cross-reference, produce a final verdict:

**PRODUCTION READY** — if:
- Zero CRITICAL issues remain
- Zero HIGH issues remain (or remaining HIGH issues are explicitly deferred with reason)
- No regressions introduced

**NOT READY — CRITICAL ISSUES REMAIN** — if any CRITICAL is still present or newly appeared.

**NOT READY — HIGH ISSUES REMAIN** — if any HIGH is unresolved.

**NEEDS MANUAL REVIEW** — if the pipeline couldn't automatically verify a fix (e.g. requires running the app).

---

## Step 5 — Save Verification Report

1. Get current datetime: `date +%Y-%m-%d-%H-%M`

2. Write to `docs/reviews/YYYY-MM-DD-HH-MM-verify.md`:

```markdown
# Crelyzor Verification Report — [DATE]
Verifying against: [previous report filename]

## Verdict: [PRODUCTION READY / NOT READY — CRITICAL / NOT READY — HIGH / NEEDS MANUAL REVIEW]

## Fixed Issues ✅
[table: Issue | File | Confirmed By]

## Still Present ❌
[table: Issue | File | Severity | Original Report Reference]

## Regressions ⚠️
[table: Issue | File | Severity | What It Broke]

## New Issues Found 🆕
[table: Issue | File | Severity | Recommendation]

## Recommended Next Action
[What to do based on the verdict]
```

3. Print terminal summary:

```
CRELYZOR VERIFY COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Verdict:        [PRODUCTION READY / NOT READY]
Fixed:          X of Y issues confirmed
Still present:  X issues
Regressions:    X
New issues:     X
Report:         docs/reviews/YYYY-MM-DD-verify.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[If NOT READY]: Run /crelyzor-review again to fix remaining issues.
[If READY]:     Codebase is production ready. Merge your branch.
```
