---
description: Guided Prisma migration flow for Crelyzor. Validates schema changes, runs schema-reviewer, then executes migration safely.
allowed-tools: [Read, Bash, Agent]
---

You are running a Prisma migration for Crelyzor. Follow these steps exactly — never skip any.

## Step 1 — Read the Schema

Read `calendar-backend/prisma/schema.prisma` in full.

Ask the user: "What changes are you making to the schema?" if not already provided.

## Step 2 — Run Schema Reviewer

Before touching anything, invoke the `schema-reviewer` agent with the proposed changes. Pass the full diff (new models, modified models) and ask: "Review these schema changes before we run the migration."

Show the reviewer's output. If NEEDS CHANGES — fix the schema first. Do not proceed until APPROVED.

## Step 3 — Validate No Breaking Changes

Check:
- Are any existing required fields being removed? (breaks existing rows)
- Are new required fields being added without a default? (fails on existing data)
- Are any field types changing? (may require data migration)

If any breaking change is detected — warn the user and confirm before proceeding.

## Step 4 — Run Migration

```bash
cd calendar-backend && pnpm db:migrate
```

Name the migration descriptively (e.g. `add_meeting_share`, `add_task_model`).

## Step 5 — Regenerate Prisma Client

```bash
cd calendar-backend && pnpm db:generate
```

## Step 6 — Verify TypeScript

```bash
cd calendar-backend && npx tsc --noEmit
```

Fix any TypeScript errors before declaring done.

## Step 7 — Confirm

```
MIGRATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Migration: [migration name]
Models added/changed: [list]
Prisma client: regenerated
TypeScript: clean
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Rules

- Never run `db:push` in production — always use `db:migrate` to create a migration file
- Never skip schema-reviewer — schema mistakes are expensive to undo
- Never proceed if TypeScript check fails after migration
