---
description: Full automated review + fix pipeline for Crelyzor. Runs 8 specialized review agents across all 3 repos in parallel, synthesizes findings, plans fixes, iterates the plan until approved, then executes all changes. Saves a markdown report to docs/reviews/.
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent]
---

You are the Crelyzor CTO running a full production-readiness review. Execute every layer below without stopping for user input. Be thorough and decisive.

## Repos

- `calendar-backend` — Express API
- `calendar-frontend` — React dashboard
- `cards-frontend` — Next.js public frontend

---

## LAYER 1 — Parallel Reviews

Launch ALL 8 agents simultaneously using `run_in_background: true`. Do not wait for one to finish before launching the next.

Each agent must receive full context: the paths to all 3 repos, the project CLAUDE.md, and its specific review instructions.

**Agent 1 — Security**
Use agent type: `security-reviewer`
Prompt: "Review the entire calendar-backend for security issues. Read all files in src/routes/, src/controllers/, src/services/, src/middleware/. Check every route for missing verifyJWT, every service for missing userId ownership scoping, every public endpoint for data exposure. Report all issues with severity, file, and line number."

**Agent 2 — Database Layer**
Use agent type: `db-layer-reviewer`
Prompt: "Review all Prisma service code in calendar-backend/src/services/ for soft delete gaps (missing isDeleted: false), N+1 queries, missing pagination on findMany, uncovered multi-step transactions, and missing ownership scoping. Report all issues with severity, file, and line number."

**Agent 3 — Schema**
Use agent type: `schema-reviewer`
Prompt: "Review calendar-backend/prisma/schema.prisma. Check every model for: UUID id, soft delete fields, correct relations, naming conventions, and @@index coverage on all foreign keys and frequently queried fields (userId, meetingId, createdAt). Report missing indexes as HIGH severity."

**Agent 4 — Silent Failures**
Use agent type: `pr-review-toolkit:silent-failure-hunter`
Prompt: "Review all files in calendar-backend/src/ and calendar-frontend/src/ for silent failures: swallowed errors in catch blocks, empty catch blocks, missing error handling in async functions, Bull queue jobs that don't handle failures, and OpenAI/Deepgram API calls without error handling. Report all issues with severity and file."

**Agent 5 — Tech Debt**
Use agent type: `general-purpose`
Prompt: "Scan all TypeScript files across calendar-backend/src/, calendar-frontend/src/, and cards-frontend/src/ (and app/) for: (1) any TypeScript 'any' types — report file and line, (2) console.log statements that should be logger calls — report file and line, (3) hardcoded strings that should be constants or env vars, (4) unused imports, (5) dead code — exported functions/components never imported anywhere. Format output as: TECH DEBT REVIEW with sections for each category, severity MEDIUM unless it's 'any' in a security-critical path (HIGH)."

**Agent 6 — API Contract**
Use agent type: `api-contract-reviewer`
Prompt: "Review the API contract across calendar-backend. Read src/routes/, src/controllers/, src/validators/, and compare with calendar-frontend/src/services/ and calendar-frontend/src/types/. Check: response shape consistency, correct HTTP error codes, missing pagination on list endpoints, missing Zod validation on routes, type drift between backend responses and frontend types, public endpoint safety, and missing rate limiting on AI endpoints."

**Agent 7 — Frontend Quality**
Use agent type: `frontend-quality-reviewer`
Prompt: "Review calendar-frontend/src/pages/ and calendar-frontend/src/hooks/queries/ for: missing error boundaries in App.tsx and high-risk pages, incomplete loading/empty/error states on all pages, React Query mutations missing cache invalidation on success, memory leaks from uncleared polling intervals or event listeners, raw useEffect data fetching (should be useQuery), and hardcoded query keys. Also check cards-frontend/app/ pages for error states."

**Agent 8 — Performance**
Use agent type: `performance-reviewer`
Prompt: "Review calendar-backend/src/services/ for over-fetching in Prisma includes, missing database indexes on hot query paths (cross-reference with prisma/schema.prisma), synchronous expensive operations that should be queued, missing token limits on OpenAI calls, and sequential awaits that should be Promise.all. Review calendar-frontend/src/hooks/queries/ for missing staleTime on stable data and expensive un-memoized components."

**Wait for all 8 agents to complete before proceeding to Layer 2.**

---

## LAYER 2 — Synthesize

Using a `general-purpose` agent (foreground, not background), synthesize all 8 reports into a single Master Issue List.

Prompt:
"You are synthesizing 8 code review reports for the Crelyzor codebase. Here are all the findings:

[INSERT ALL 8 AGENT OUTPUTS HERE]

Your task:
1. Deduplicate — if 2+ agents flagged the same issue, merge into one entry
2. Cross-reference — if a security issue and a silent failure affect the same function, note it as one compounded issue
3. Rank by severity: CRITICAL → HIGH → MEDIUM → LOW
4. Within each severity, group by repo (calendar-backend → calendar-frontend → cards-frontend)
5. For each issue output: Severity | Repo | File | Line (if known) | Description | Why it matters

Format as a clean numbered Master Issue List. No prose. Just the list."

Store the Master Issue List output. You will use it in Layer 3.

---

## LAYER 3 — Plan

Using a `general-purpose` agent (foreground), create a concrete execution plan.

Prompt:
"You are the lead engineer for Crelyzor. You have a Master Issue List of code problems to fix. Create a concrete execution plan.

Master Issue List:
[INSERT MASTER ISSUE LIST]

Rules for the plan:
1. Order by: CRITICAL first, then HIGH, then MEDIUM, then LOW
2. Group changes that touch the same file — never plan to touch the same file twice
3. For each change specify: File | What to change | Exact code change (before/after) | Which issue it fixes
4. Flag any change that has a dependency (e.g. schema index must be added before the service query optimization)
5. Flag any change that is risky (e.g. touching the AI pipeline or auth middleware)
6. Do NOT plan changes that require new infrastructure (no new services, no new tables unless it's just adding an index)

Output as: EXECUTION PLAN — a numbered list of concrete file changes."

Store the Execution Plan. You will use it in Layer 4.

---

## LAYER 4 — Review Loop

Run this loop up to 3 times:

**Step A — Plan Reviewer**
Using a `crelyzor-reviewer` agent (foreground):

Prompt:
"Review this execution plan for the Crelyzor codebase. Your job is to catch anything wrong BEFORE code is written.

Execution Plan:
[INSERT CURRENT EXECUTION PLAN]

Check:
1. Does every CRITICAL issue have a corresponding fix in the plan?
2. Will any planned change break existing functionality or introduce a regression?
3. Is the ordering correct — do dependencies come before the things that depend on them?
4. Are there changes that should be grouped but aren't (same file touched multiple times)?
5. Is anything in the plan inconsistent with Crelyzor conventions (CLAUDE.md)?
6. Are there any issues in the Master Issue List that the plan missed?

Master Issue List for reference:
[INSERT MASTER ISSUE LIST]

Output EXACTLY one of:
- APPROVED — with a one-line summary of why
- REVISE: [specific numbered list of what must change in the plan]"

**Step B — Decision**
- If the reviewer output starts with `APPROVED` → exit the loop, proceed to Layer 5
- If the reviewer output starts with `REVISE:` → run the Planner again (Layer 3) with the original Master Issue List PLUS the reviewer's feedback appended. Increment the iteration count.
- If iteration count reaches 3 → proceed to Layer 5 regardless, noting in the report that the plan was not fully approved.

---

## LAYER 5 — Execute

Work through the approved Execution Plan chunk by chunk. A chunk = one severity level.

### Chunk 1: CRITICAL fixes
- Read every file that will be changed in this chunk before touching anything
- Implement all CRITICAL fixes
- After implementing: run a `general-purpose` agent to verify the changes are correct:
  Prompt: "Review these specific changes just made to [list files]. Do they correctly fix the issues they were meant to fix? Do they introduce any regressions? Output: VERIFIED or PROBLEM: [description]"
- If PROBLEM: fix before moving to Chunk 2

### Chunk 2: HIGH fixes
- Same pattern: implement all HIGH fixes, then verify

### Chunk 3: MEDIUM fixes
- Same pattern

### Chunk 4: LOW fixes
- Same pattern, but skip verification agent to save time — just implement

---

## LAYER 6 — Report

After all chunks complete:

1. Determine today's date using Bash: `date +%Y-%m-%d-%H-%M`

2. Create the directory if it doesn't exist: `docs/reviews/`

3. Write the report to `docs/reviews/YYYY-MM-DD-HH-MM-review.md` with this structure:

```markdown
# Crelyzor Production Review — [DATE]

## Summary
- Total issues found: X (X critical, X high, X medium, X low)
- Total issues fixed: X
- Issues skipped: X (list with reason)
- Plan approval: Approved on iteration N / Proceeded after max iterations

## Issues Found & Fixed

### CRITICAL
| # | File | Issue | Status |
|---|------|-------|--------|
| 1 | path/to/file.ts | Description | ✅ Fixed |

### HIGH
[same table]

### MEDIUM
[same table]

### LOW
[same table]

## Issues Skipped
[List any issues that could not be fixed automatically with explanation]

## Files Changed
[List all files modified]

## Next Steps
[Any manual actions required that the pipeline couldn't do automatically]
```

4. Print a terminal summary:

```
CRELYZOR REVIEW COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Found:  X critical · X high · X medium · X low
Fixed:  X issues across X files
Report: docs/reviews/YYYY-MM-DD-review.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run /crelyzor-verify to confirm all fixes.
```
