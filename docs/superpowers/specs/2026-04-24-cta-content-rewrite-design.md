# CTA Content Rewrite — Design Spec

**Date:** 2026-04-24  
**Status:** Approved  
**Scope:** `crelyzor-public` — `src/components/sections/CTA.tsx` only

---

## Problem

The current CTA section positions Crelyzor behind a waitlist ("Join the waitlist before public launch"). This implies the product isn't ready and keeps real users out. Crelyzor is live and usable. The copy should reflect that — and invite users to be collaborators, not spectators.

---

## Goal

Replace the waitlist CTA with two sub-sections:
1. A direct, confident product call-to-action (use it now, free)
2. A short, personal founder note that is honest about being early and opens a direct line of communication

---

## Copy

### Part 1 — Product CTA

**Headline:**
> One tool.  
> Everything connected.

**Subtext:**
> Cards, AI meetings, scheduling, tasks — free to start. No waitlist. No credit card.

**CTA button:** "Get started free →" → links to `process.env.NEXT_PUBLIC_APP_URL/signin`

---

### Part 2 — Founder Note

Separated by a thin `border-t` divider. Slightly smaller visual scale — this is a human moment, not a pitch.

**Body:**
> Crelyzor is young. We know that. We're a small team building something we wish existed — and we'd rather have real people using it and telling us what's wrong than spend months perfecting it in private.
>
> If something breaks, feels off, or you have an idea — I want to hear it directly.

**Signature:** `— Harsh, Co-founder`

**Contact link:** `harsh@crelyzor.app` (mailto link)  
**Secondary link:** `[Report a bug →]` — also mailto to `harsh@crelyzor.app`

---

## What Changes

| Before | After |
|--------|-------|
| Waitlist email input | Removed |
| "Join waitlist" button | "Get started free →" button |
| `submitted` / `loading` / `error` state | Removed (no form, no API call) |
| `POST /api/waitlist` fetch | Removed from component (route kept on backend) |
| No founder presence | Founder note sub-section added |

---

## What Does NOT Change

- Visual design tokens (gold `#d4af61`, backgrounds, motion)
- Section structure (same `<section>` wrapper, same radial gradient bg)
- Hero section copy
- Features section copy
- Any other file

---

## File

`crelyzor-public/src/components/sections/CTA.tsx` — full rewrite of component internals. No other files touched.
