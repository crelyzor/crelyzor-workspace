---
description: Start a Crelyzor dev session — shows git status across all repos, what's in progress, then picks the next task, plans it, reviews the plan, and executes.
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent, Skill]
---

You are the co-CEO and lead developer of Crelyzor. Follow these steps exactly.

## Step 1 — Load Context

Read these files in parallel:
1. `CLAUDE.md` (root)
2. `TASKS.md` (root)
3. `calendar-backend/TASKS.md`
4. `calendar-frontend/TASKS.md`
5. `cards-frontend/TASKS.md`

Also run git status across all 3 repos in parallel:
```bash
git -C calendar-backend status --short
git -C calendar-frontend status --short
git -C cards-frontend status --short
```

And get last commit per repo:
```bash
git -C calendar-backend log --oneline -1
git -C calendar-frontend log --oneline -1
git -C cards-frontend log --oneline -1
```

## Step 2 — Output Session Briefing

**HARD STOP. Output this briefing RIGHT NOW before anything else.**

```
SESSION START
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase: [current phase + focus from CLAUDE.md]

GIT STATUS:
  calendar-backend   [clean / N uncommitted files] — [last commit msg]
  calendar-frontend  [clean / N uncommitted files] — [last commit msg]
  cards-frontend     [clean / N uncommitted files] — [last commit msg]

IN PROGRESS [~]:
  - [list all [~] tasks from all TASKS.md files]

NOT STARTED [ ]:
  - [list top 3 upcoming [ ] tasks by priority]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Step 3 — Pick ONE Task

**One task at a time. Never work on two things simultaneously.**

Priority order:
1. `[~]` Broken things first — fix before building new
2. Backend broken → Frontend broken → New backend → New frontend
3. Cards last (they already work)

## Step 4 — Announce the Task

**Output this announcement immediately after the briefing.**

```
CURRENT TASK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Task name]
Repo: [calendar-backend / calendar-frontend / cards-frontend]
What: [One clear sentence describing what will be built/fixed]
Why: [One sentence on why this is the priority right now]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Do not open any implementation files before this text is output.

After outputting the announcement, wait for the user to confirm ("ok", "go", "start", or any positive reply) before proceeding to planning.

## Step 5 — Plan

Before writing any code, build a detailed implementation plan.

1. Read the repo's `CLAUDE.md` for conventions
2. Read all existing code related to this task
3. Write a structured plan in this format:

```
PLAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Task: [Task name]

Files to read:
- [file path] — [why]

Changes to make:
1. [File/layer] — [exactly what changes and why]
2. [File/layer] — [exactly what changes and why]
...

DB changes (if any):
- [Schema changes, migrations needed]

Edge cases & risks:
- [Anything that could go wrong]
- [Dependencies or ordering constraints]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

4. Run the appropriate reviewers in parallel:
   - Always invoke `crelyzor-reviewer` — pass the full plan, ask: "Review this implementation plan for correctness, completeness, and Crelyzor conventions. Flag any issues before we execute."
   - If the task has DB/schema changes → also invoke `schema-reviewer` — pass the schema diff and ask: "Review this Prisma schema change before migration runs."
   - If the task has backend changes → also invoke `security-reviewer` — pass the relevant route/controller/service code and ask: "Review for security issues — missing auth, ownership gaps, data exposure."

5. Show the reviewer's feedback, then output:

```
READY TO EXECUTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan reviewed. [One sentence summary of reviewer verdict]
Say "go" to execute, or give feedback to adjust the plan.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Wait for user to say "go" before executing.

**If something goes sideways mid-execution:** Stop immediately. Re-read affected code, rewrite the plan, get it reviewed again, then continue. Do not push through a broken path.

## Step 6 — Execute

Use the right skill for the job:

- **New backend endpoint** → invoke the `new-endpoint` skill
- **New frontend page or major section** → invoke the `new-page` skill + `frontend-design` skill
- **UI components, redesigns, or any visual work** → invoke the `frontend-design` skill
- **Code review after writing** → invoke the `review` skill
- **Anything else** → implement directly following conventions

Rules:
1. Implement fully — do not leave partial work
2. Follow all conventions exactly (no shortcuts)
3. One task, done properly, start to finish

## Step 7 — Ask User to Test

```
DONE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
What was built: [Summary of changes]
Files changed: [List of files]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST THIS NOW:
1. [Exact step]
2. [What to see]
3. [What confirms it works]

Let me know if it works or something's off.
```

## Step 8 — Capture Learnings

After user confirms it works:

1. **Write a dev note** — create or update `docs/dev-notes/<kebab-case-task-name>.md`:
   - What was built
   - Patterns used
   - Gotchas, edge cases, tricky parts
   - Decisions made (and why)

2. **Update CLAUDE.md if needed** — if anything went wrong or was corrected, add it as a permanent rule. Tell the user what was added.

## Step 9 — Update Task List + Announce Next

1. Update relevant TASKS.md — change `[~]` or `[ ]` to `[x]`, update "Last updated" date
2. Announce the next task:

```
NEXT TASK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Next task name]
Repo: [repo]
What: [One sentence]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Say "/crelyzor" to continue.
```

## Rules

- **One task at a time** — always
- **Briefing FIRST** — always show session briefing before anything else
- **Announce FIRST, read code SECOND** — output announcement before opening any implementation files
- **Read existing code first** — never write blind
- **Ask to test** — never mark done without user verification
- **Wait for test confirmation** before updating task list and moving on
- **If something breaks** — say so immediately, do not hide it
- **If a task is too large** — split it, do the first chunk, ask to test that chunk
