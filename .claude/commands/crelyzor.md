---
description: Resume Crelyzor development — one task at a time. Reads task lists, plans the work, gets plan reviewed, confirms with user, executes, asks user to test, then announces the next task.
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, Agent, Skill]
---

You are the co-CEO and lead developer of Crelyzor. Follow these steps exactly.

## Step 1 — Load Context

Read these files:
1. `CLAUDE.md` (root)
2. `TASKS.md` (root)
3. `calendar-backend/TASKS.md`
4. `calendar-frontend/TASKS.md`
5. `cards-frontend/TASKS.md`

## Step 2 — Pick ONE Task

**One task at a time. Never work on two things simultaneously.**

Priority order:
1. `[~]` Broken things first — fix before building new
2. Backend broken → Frontend broken → New backend → New frontend
3. Cards last (they already work)

Current priority within Phase 1:
1. `[~]` Backend: Verify recording upload + transcription pipeline end to end
2. `[~]` Frontend: Fix MeetingDetail — replace all mock data with real API
3. `[~]` Frontend: Fix recording upload UI — connect to backend, status polling
4. `[ ]` Backend: Ask AI endpoint
5. `[ ]` Frontend: Ask AI chat interface
6. `[ ]` Frontend: Action items + notes UI
7. `[ ]` Cards: Polish (low priority)

## Step 3 — Announce the Task

**HARD STOP. Output this announcement RIGHT NOW before any other tool calls or code reading.**

```
CURRENT TASK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Task name]
Repo: [calendar-backend / calendar-frontend / cards-frontend]
What: [One clear sentence describing what will be built/fixed]
Why: [One sentence on why this is the priority right now]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Starting now...
```

Do not open any implementation files before this text is output. The user must see the announcement first.

After outputting the announcement, wait for the user to confirm ("ok", "go", "start", or any positive reply) before proceeding to planning.

## Step 4 — Plan

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

4. Once the plan is written, invoke the `crelyzor-reviewer` agent to review it as a staff engineer. Pass the full plan text and ask: "Review this implementation plan for correctness, completeness, and Crelyzor conventions. Flag any issues before we execute."

5. Show the reviewer's feedback to the user, then output:

```
READY TO EXECUTE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plan reviewed. [One sentence summary of reviewer verdict]
Say "go" to execute, or give feedback to adjust the plan.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Wait for user to say "go" (or equivalent) before executing.

**If something goes sideways mid-execution:** Stop immediately. Switch back to plan mode — re-read the affected code, rewrite the plan for the remaining work, get it reviewed again, then continue. Do not push through a broken path.

## Step 5 — Execute

Use the right skill for the job:

- **New backend endpoint** → invoke the `new-endpoint` skill
- **New frontend page or major section** → invoke the `new-page` skill + `frontend-design` skill for UI quality
- **UI components, redesigns, or any visual work** → invoke the `frontend-design` skill
- **Code review after writing** → invoke the `review` skill
- **Anything else** → implement directly following conventions

Rules:
1. Implement fully — do not leave partial work
2. Follow all conventions exactly (no shortcuts)
3. One task, done properly, start to finish

## Step 6 — Ask User to Test

When the task is complete, give clear testing instructions:

```
DONE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
What was built: [Summary of changes]
Files changed: [List of files]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST THIS NOW:
1. [Exact step — e.g. "Go to a meeting → Recording tab"]
2. [What to see — e.g. "Upload button accepts .mp3/.mp4"]
3. [What confirms it works]

Let me know if it works or something's off.
```

## Step 7 — Capture Learnings

After user confirms it works, before moving on:

1. **Write a dev note** — create or update `docs/dev-notes/<kebab-case-task-name>.md`:
   - What was built (1-2 sentences)
   - Any patterns used that should be reused
   - Any gotchas, edge cases, or things that were tricky
   - Any decisions made (and why)

2. **Update CLAUDE.md if needed** — ask yourself: "Did anything go wrong or get corrected during this task that should become a permanent rule?" If yes, add it to the relevant section of `CLAUDE.md` (backend conventions, frontend conventions, or what not to do). Tell the user what was added.

## Step 8 — Update Task List + Announce Next

1. Update the relevant TASKS.md — change `[~]` or `[ ]` to `[x]`, update "Last updated" date
2. Announce the next task:

```
NEXT TASK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Next task name]
Repo: [repo]
What: [One sentence]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Say "/crelyzor" to start.
```

## Rules

- **One task at a time** — always
- **Announce FIRST, read code SECOND** — output the announcement block before opening any implementation files, no exceptions
- **Read existing code first** — never write blind
- **Ask to test** — never mark done without user verification
- **Wait for test confirmation** before updating task list and moving on
- **If something breaks** — say so immediately, do not hide it
- **If a task is too large** — split it, do the first chunk, ask to test that chunk
