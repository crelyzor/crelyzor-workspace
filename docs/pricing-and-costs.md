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
| Ask AI (per question) | 4k input + 900 output | $0.007 |
| Content generation | 6.5k input + 1.5k output | $0.012 |

**Total OpenAI cost per 30-min meeting processed:** ~$0.033
**Total OpenAI cost per Ask AI question:** ~$0.007

---

### 1.3 Recall.ai — Online Meeting Bot

**Plan:** Pay As You Go

| What | Cost |
|------|------|
| Recording | $0.50/hr |
| Recording storage | Free for 7 days (we don't need more — audio lands in GCS immediately) |
| Transcription routing | Not applicable — we call Deepgram directly |

**Cost per 30-min online meeting:** $0.25 (Recall) + $0.155 (Deepgram) = **$0.405**
**Cost per hour:** $0.50

> Note: Recall bot joins the meeting, records audio, sends it to us. We store in GCS and transcribe via Deepgram ourselves. We do NOT use Recall's transcription or storage beyond the free 7-day window.

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

**Frontend (crelyzor-frontend):** React + Vite — deploy on **Vercel** (free tier covers early stage)
**Public (crelyzor-public):** Next.js — deploy on **Vercel** (free tier covers early stage)

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

**What we use Redis for:** Bull job queues (transcription, AI, emails), Ask AI rate limiting, GCal event cache.
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

## 2. Cost Per User Per Month

### Assumptions
- Average meeting: 30 min
- Models: Nova-3 Multilingual + gpt-5.4-mini (planned)

### Free User — Maxed Out
*(120 min transcription, 20 Ask AI questions)*

| Service | Cost |
|---------|------|
| Deepgram (120 min) | $0.62 |
| OpenAI — meeting processing (4 meetings) | $0.09 |
| OpenAI — Ask AI (20 questions) | $0.51 |
| GCS storage | $0.01 |
| **Total** | **$1.23** |

### Pro User — Maxed Out
*(600 min transcription + 5 hrs Recall + 100 Ask AI + 50 content generations)*

| Service | Cost |
|---------|------|
| Deepgram — manual (600 min) | $3.10 |
| Deepgram — Recall (5 hrs) | $1.55 |
| Recall.ai bot (5 hrs) | $2.50 |
| OpenAI — meeting processing (30 meetings) | $0.99 |
| OpenAI — Ask AI (100 questions) | $0.70 |
| OpenAI — content generation (50) | $0.60 |
| GCS (20 GB) | $0.40 |
| **Total** | **~$9.84** |

### Business — Custom pricing per deal, cost calculated per agreement.

---

## 3. Infrastructure Fixed Costs (Monthly)

| Service | Early Stage | At Scale (1k+ users) |
|---------|-------------|----------------------|
| GCP Cloud Run (backend) | $15 | $50 |
| Vercel (2 frontends) | $0 | $20 |
| Neon PostgreSQL | $0 | $19 |
| Upstash Redis | $0 | $5 |
| Resend | $0 | $20 |
| **Total fixed** | **~$15/mo** | **~$114/mo** |

---

## 4. Pricing Architecture

### Plans

| Feature | **Free** | **Pro** $19/mo | **Business** Custom |
|---------|----------|----------------|---------------------|
| Transcription | 120 min/mo | 600 min/mo | Custom |
| Max single recording | 60 min | 3 hrs | Custom |
| Recall.ai (online meetings) | ❌ | 5 hrs/mo | Custom |
| Ask AI | 20 questions/mo | 100 questions/mo | Custom |
| AI content generation | ❌ | ✅ | ✅ |
| Storage | 2 GB | 20 GB | Custom |
| Cards | Unlimited | Unlimited | Unlimited |
| Scheduling | Unlimited | Unlimited | Unlimited |
| Tasks & Calendar | Unlimited | Unlimited | Unlimited |
| Email support | ❌ | ✅ | ✅ |
| SLA | ❌ | ❌ | ✅ |
| Dedicated support | ❌ | ❌ | ✅ |

### Why Cards / Scheduling / Tasks are free on all plans
These features cost us effectively $0 per user — no AI, no transcription, no storage. Gating them hurts adoption without protecting margin. They stay unlimited forever.

### What drives cost (and what we gate)
| Cost driver | Gated by |
|-------------|----------|
| Deepgram | Transcription minutes cap |
| Recall.ai | Recall hours cap |
| OpenAI (Ask AI) | Ask AI questions cap |
| OpenAI (content gen) | Plan tier gate |
| GCS | Storage quota |

---

## 5. Margins

| Plan | Variable cost (maxed) | Fixed cost share | Total cost | Revenue | **Margin** |
|------|-----------------------|------------------|------------|---------|------------|
| Free | $1.23 | ~$0.15 | ~$1.38 | $0 | **-$1.38** |
| Pro | $9.84 | ~$0.15 | ~$10.00 | $19 | **$9 (47%)** |
| Business | cost-based | negotiated | negotiated | custom | **you control** |

### Free tier math
At 1,000 free users: ~$1,380/mo in costs with $0 revenue.
Need ~5% free → Pro conversion = 50 Pro users = $950/mo.
**Target: 10% conversion to break even on free tier.**

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

- **Stripe** — subscription billing, plan management, usage-based add-ons
- **Webhook:** Stripe → backend → update `user.plan` in DB
- **Usage tracking:** `UserUsage` model — transcription minutes, Recall hours, Ask AI count, reset monthly
- **Enforcement:** check usage before every billable action, return 402 with upgrade prompt if over limit
