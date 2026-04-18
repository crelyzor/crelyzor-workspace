# Crelyzor — Service Costs & Pricing Architecture

> Last updated: 2026-04-19
> All prices are Pay As You Go unless noted. Update this doc whenever models or plans change.

---

## 1. Services We Use & Their Pricing

### 1.1 Deepgram — Transcription

**Current model:** `nova-2`
**Planned model:** `nova-3` (multilingual) — upgrade at Phase 4 start

| Model | Pre-Recorded (PAYG) | Pre-Recorded (Growth) |
|-------|--------------------|-----------------------|
| Nova-2 | $0.26/hr | $0.21/hr |
| **Nova-3 Multilingual** | **$0.31/hr** | **$0.26/hr** |

**Add-ons we use:**
| Feature | Cost | Notes |
|---------|------|-------|
| Smart Formatting | Free | Always on |
| Speaker Diarization | Included in pre-recorded | Multi-speaker detection |

**Cost per 30-min meeting (Nova-3 Multi):** ~$0.155
**Cost per hour:** $0.31

---

### 1.2 OpenAI — AI Processing

**Current model:** `gpt-4o-mini`
**Planned model:** `gpt-5.4-mini` — upgrade at Phase 4 start

| Model | Input | Cached Input | Output |
|-------|-------|--------------|--------|
| gpt-4o-mini (current) | $0.15/1M | $0.075/1M | $0.60/1M |
| **gpt-5.4-mini (planned)** | **$0.75/1M** | **$0.075/1M** | **$4.50/1M** |

**What we call OpenAI for:**
| Feature | Approx tokens per call | Cost/call (gpt-5.4-mini) |
|---------|----------------------|--------------------------|
| Summary + key points | 20k input + 1.3k output | $0.021 |
| Task extraction | 7k input + 500 output | $0.007 |
| Meeting title | 6.5k input + 30 output | $0.005 |
| Ask AI (per question) | 4k–8k input + 500–900 output | $0.005–$0.010 |
| Content generation | 6.5k–8k input + 100–1.5k output | $0.007–$0.013 |

**Total OpenAI cost per 30-min meeting processed (pipeline):** ~$0.033
**Meeting processing does NOT consume AI Credits** — it is included in the transcription flow.
**Ask AI and content generation consume AI Credits** — see Section 4.

---

### 1.3 Recall.ai — Online Meeting Bot

**Plan:** Pay As You Go

| What | Cost |
|------|------|
| Recording | $0.50/hr |
| Recording storage | Free for 7 days (audio lands in GCS immediately — we never need more) |
| Transcription routing | Not applicable — we call Deepgram directly |

**Cost per 30-min online meeting:** $0.25 (Recall) + $0.155 (Deepgram) = **$0.405**
**Cost per hour:** $0.50

> Note: Recall bot joins the meeting, records audio, sends it to us. We store in GCS and transcribe via Deepgram ourselves. We do NOT use Recall's transcription or long-term storage.

---

### 1.4 Google Cloud Storage (GCS) — Audio & File Storage

**Bucket:** Standard, us-central1

| What | Cost |
|------|------|
| Storage | $0.020/GB/month |
| Class A ops (writes) | $0.05/10k ops |
| Class B ops (reads) | $0.004/10k ops |
| Egress (internet) | $0.12/GB |

**Typical storage per user per month:** ~25 MB/meeting
**Cost per GB stored:** $0.020/month (accumulates over time)

---

### 1.5 GCP Infrastructure — Backend + Frontend

**Backend (crelyzor-backend):** Dockerised Node.js API, deployed on **GCP Cloud Run**

| Resource | Spec | Estimated Cost |
|----------|------|----------------|
| Cloud Run — backend | 1 vCPU, 512 MB RAM, min 0 instances | ~$5–15/mo at low traffic |
| Cloud Run — backend (scaled) | 2 vCPU, 1 GB RAM, min 1 instance (always on) | ~$30–50/mo |
| Cloud Run requests | $0.40/million requests | negligible at early stage |

**Frontend (crelyzor-frontend):** React + Vite — deployed on **Vercel**
**Public (crelyzor-public):** Next.js — deployed on **Vercel**

| Service | Cost |
|---------|------|
| Vercel (both frontends) | Free tier → $20/mo Pro when traffic scales |
| Cloud Run backend | ~$15/mo (early) → ~$50/mo (scaled) |

---

### 1.6 Neon — PostgreSQL Database

| Plan | Cost | What it covers |
|------|------|----------------|
| Free | $0 | 0.5 GB storage, 1 compute hour/month |
| Launch | $19/mo | 10 GB storage, autoscaling compute |
| Scale | $69/mo | 50 GB storage, more compute |

**Current:** Free tier works for early users.
**Switch to Launch ($19/mo) when:** hitting compute limits or > 500 active users.

---

### 1.7 Upstash Redis — Job Queues & Rate Limiting

| Plan | Cost | What it covers |
|------|------|----------------|
| Free | $0 | 10,000 commands/day |
| Pay As You Go | $0.20/100k commands | scales with usage |

**What we use Redis for:** Bull job queues (transcription, AI, emails), AI Credits rate limiting, GCal event cache.
**Cost at early scale:** ~$0 (within free tier) → ~$5/mo at 1,000+ active users.

---

### 1.8 Resend — Transactional Email

| Plan | Cost | Emails included |
|------|------|-----------------|
| Free | $0 | 3,000/month |
| Pro | $20/mo | 50,000/month |

**Emails per active user/month:** ~20–60 (booking confirmations, reminders, AI ready, daily digest)
**Break-even:** ~50 active users → upgrade to Pro ($20/mo)

---

## 2. AI Credits System

AI Credits are the unit for all OpenAI-powered interactive features — Ask AI and content generation. They replace per-question or per-generation counting, which is not fair because cost varies with meeting length and question complexity.

**1 AI Credit = $0.001 (0.1 cent)**

### How credits are calculated

Credits are deducted based on actual token usage per call:

```
credits_used = (input_tokens × 0.00075) + (output_tokens × 0.0045)
             = cost_in_dollars × 1000
```

This maps 1:1 to real cost so you never lose money on a heavy user.

### Typical credit cost per action (gpt-5.4-mini)

| Action | Context | Credits used |
|--------|---------|-------------|
| Ask AI — short meeting (30 min) | 4k in + 500 out | **5 credits** |
| Ask AI — long meeting (2 hr) | 8k in + 900 out | **10 credits** |
| Content gen — Tweet | 6.5k in + 100 out | **7 credits** |
| Content gen — Follow-up email | 6.5k in + 1k out | **10 credits** |
| Content gen — Meeting report | 8k in + 1.5k output | **13 credits** |

### What does NOT consume AI Credits
Meeting processing (summary, task extraction, title generation) fires automatically after transcription and is included in the transcription flow — no credits deducted. Credits only apply to user-initiated AI interactions.

### Credits per plan

| | **Free** | **Pro** $19/mo | **Business** Custom |
|--|--|--|--|
| AI Credits/month | **50** | **1,000** | Custom |
| Rollover | ❌ | ❌ | Custom |

**What 50 credits gets you (Free):**
- ~7 Ask AI questions on average meetings, or
- ~5 content generations, or
- any mix

**What 1,000 credits gets you (Pro):**
- ~130 Ask AI questions on average meetings, or
- ~90 content generations, or
- any mix

### Credit cost to us vs. revenue

| Plan | Credits given | Max OpenAI cost | Revenue from credits |
|------|--------------|-----------------|----------------------|
| Free | 50 | $0.05 | $0 |
| Pro | 1,000 | $1.00 | included in $19 |

Credits are cheap — the real cost driver is transcription and Recall, not AI Credits.

---

## 3. Cost Per User Per Month

### Assumptions
- Average meeting: 30 min
- Models: Nova-3 Multilingual + gpt-5.4-mini (planned)

### Free User — Maxed Out
*(120 min transcription, 50 AI Credits used)*

| Service | Cost |
|---------|------|
| Deepgram (120 min) | $0.62 |
| OpenAI — meeting processing (4 meetings, not credits) | $0.09 |
| OpenAI — AI Credits (50 credits = $0.05) | $0.05 |
| GCS storage | $0.01 |
| **Total** | **$0.77** |

### Pro User — Maxed Out
*(600 min transcription + 5 hrs Recall + 1,000 AI Credits)*

| Service | Cost |
|---------|------|
| Deepgram — manual (600 min) | $3.10 |
| Deepgram — Recall (5 hrs) | $1.55 |
| Recall.ai bot (5 hrs) | $2.50 |
| OpenAI — meeting processing (30 meetings, not credits) | $0.99 |
| OpenAI — AI Credits (1,000 credits = $1.00) | $1.00 |
| GCS (20 GB) | $0.40 |
| **Total** | **~$9.54** |

### Business — Custom pricing per deal, cost calculated per agreement.

---

## 4. Pricing Architecture

### Plans

| Feature | **Free** | **Pro** $19/mo | **Business** Custom |
|---------|----------|----------------|---------------------|
| Transcription | 120 min/mo | 600 min/mo | Custom |
| Max single recording | 60 min | 3 hrs | Custom |
| Recall.ai (online meetings) | ❌ | 5 hrs/mo | Custom |
| **AI Credits** | **50/mo** | **1,000/mo** | Custom |
| AI content generation | ❌ (no credits for this) | ✅ | ✅ |
| Storage | 2 GB | 20 GB | Custom |
| Cards | Unlimited | Unlimited | Unlimited |
| Scheduling | Unlimited | Unlimited | Unlimited |
| Tasks & Calendar | Unlimited | Unlimited | Unlimited |
| Email support | ❌ | ✅ | ✅ |
| SLA | ❌ | ❌ | ✅ |
| Dedicated support | ❌ | ❌ | ✅ |

> Note: Content generation is gated to Pro not by credits alone — Free users cannot access it even if they had credits. It's a plan-level feature gate.

### Why Cards / Scheduling / Tasks are free on all plans
These features cost us effectively $0 per user — no AI, no transcription, no storage. Gating them hurts adoption without protecting margin. They stay unlimited forever.

### What drives cost (and what we gate)

| Cost driver | Gated by |
|-------------|----------|
| Deepgram | Transcription minutes cap |
| Recall.ai | Recall hours cap |
| OpenAI — Ask AI | AI Credits |
| OpenAI — Content gen | AI Credits + plan tier gate |
| OpenAI — Meeting pipeline | Not gated (included in transcription) |
| GCS | Storage quota |

---

## 5. Margins

| Plan | Variable cost (maxed) | Fixed cost share | Total cost | Revenue | **Margin** |
|------|-----------------------|------------------|------------|---------|------------|
| Free | $0.77 | ~$0.15 | ~$0.92 | $0 | **-$0.92** |
| Pro | $9.54 | ~$0.15 | ~$9.69 | $19 | **$9.31 (49%)** |
| Business | cost-based | negotiated | negotiated | custom | **you control** |

### Free tier math
At 1,000 free users: ~$920/mo in costs with $0 revenue.
Need ~5% free → Pro conversion = 50 Pro users = $950/mo revenue.
**Target: 5% conversion to break even on free tier. 10% = healthy profit.**

---

## 6. Planned Model Upgrades (Phase 4)

Do these two changes at the start of Phase 4, before any AI work begins.

### Deepgram: nova-2 → nova-3 (multilingual)
- **File:** `crelyzor-backend/src/services/transcription/transcriptionService.ts`
- **Change:** `const DEEPGRAM_MODEL = "nova-2"` → `"nova-3"`
- **Cost impact:** $0.26/hr → $0.31/hr (+$0.05/hr)
- **Why:** Better accuracy, 45+ languages, supports diarization fully

### OpenAI: gpt-4o-mini → gpt-5.4-mini
- **File:** `crelyzor-backend/src/services/ai/aiService.ts`
- **Change:** `const OPENAI_MODEL = "gpt-4o-mini"` → `"gpt-5.4-mini"`
- **Cost impact:** Input 5x ($0.15→$0.75/1M), Output 7.5x ($0.60→$4.50/1M)
- **Net increase per Pro user/month:** ~$1.30
- **Why:** Significantly better summaries, task extraction, and Ask AI quality

---

## 7. Payment Infrastructure (To Build)

- **Stripe** — subscription billing, plan management
- **Webhook:** Stripe → backend → update `user.plan` in DB
- **`UserUsage` model** — tracks per user per month:
  - `transcriptionMinutesUsed`
  - `recallHoursUsed`
  - `aiCreditsUsed`
  - `storageGbUsed`
  - `resetAt` — first day of next month
- **Credit deduction:** calculated from actual token counts returned by OpenAI API response (`usage.prompt_tokens`, `usage.completion_tokens`)
- **Enforcement:** check limits before every billable action, return `402` with upgrade prompt if over limit
- **Credit formula:** `credits = (prompt_tokens × 0.00075) + (completion_tokens × 0.0045)` rounded up to nearest integer
