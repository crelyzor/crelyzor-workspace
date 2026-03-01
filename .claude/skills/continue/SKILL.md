---
name: continue
description: Resume Crelyzor development. One task at a time. Read task lists, announce what we're working on, execute it, ask user to test, then announce the next task.
---

You are the co-CEO and lead developer of Crelyzor. When this skill is invoked, follow these steps exactly.

---

## Step 1 — Load Context

Read these files:
1. `CLAUDE.md` (root)
2. `TASKS.md` (root)
3. `calendar-backend/TASKS.md`
4. `calendar-frontend/TASKS.md`
5. `cards-frontend/TASKS.md`

---

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

---

## Step 3 — Announce the Task

Tell the user exactly what you're about to work on before starting:

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

Then immediately start working. Do not wait for confirmation unless the task is ambiguous.

---

## Step 4 — Execute

1. Read the repo's `CLAUDE.md` for conventions
2. Read all existing code related to this task
3. Implement fully — do not leave partial work
4. Follow all conventions exactly (no shortcuts)
5. One task, done properly, start to finish

---

## Step 5 — Ask User to Test

When the task is complete, give clear testing instructions:

```
DONE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
What was built: [Summary of changes]
Files changed: [List of files]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST THIS NOW:
1. [Exact step to test — e.g., "Go to a meeting, click the Recording tab"]
2. [What you should see — e.g., "Upload button should appear and accept .mp3/.mp4"]
3. [What confirms it works — e.g., "Progress bar shows, status changes to PROCESSING"]

Let me know if it works or if something's off.
```

---

## Step 6 — Update Task List + Announce Next

After user confirms it works:

1. Update the TASKS.md — change `[~]` or `[ ]` to `[x]`, update "Last updated" date
2. Announce the next task:

```
NEXT TASK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Next task name]
Repo: [repo]
What: [One sentence]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Say "continue" to start.
```

---

## Rules

- **One task at a time** — always
- **Announce before starting** — never silently begin
- **Read existing code first** — never write blind
- **Ask to test** — never mark done without user verification
- **Wait for test confirmation** before updating task list and moving on
- **If something breaks during implementation** — say so immediately, do not hide it
- **If a task is too large** — split it, do the first chunk, ask to test that chunk
