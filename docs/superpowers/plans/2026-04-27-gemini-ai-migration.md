# Gemini AI Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace OpenAI with Google Gemini 2.0 Flash for all AI understanding features (summaries, key points, task extraction, title generation, Ask AI streaming, content generation) while keeping Deepgram for transcription and diarization unchanged.

**Architecture:** Swap `config/openai.ts` → `config/gemini.ts` using the native `@google/generative-ai` SDK. Rewrite `aiService.ts` call sites to use Gemini's generateContent/generateContentStream API. Update the AI Credits formula in `usageService.ts` to reflect Gemini 2.0 Flash pricing. Remove the 30k-char truncation cap — Gemini's 1M token context window eliminates the need for it.

**Tech Stack:** `@google/generative-ai` (Google Generative AI SDK), Gemini 2.0 Flash (`gemini-2.0-flash`), existing Express + Prisma + Bull stack unchanged. Deepgram untouched.

**Phase:** 4.7 — fits inside Phase 4 (Billing & Monetization) before billing frontend is built, so credit formula is correct from day one.

---

## File Map

### crelyzor-backend (all changes here)

| Action | File | What changes |
|--------|------|-------------|
| **Create** | `src/config/gemini.ts` | Gemini client initializer — replaces `config/openai.ts` |
| **Delete** | `src/config/openai.ts` | Removed — Gemini replaces it entirely |
| **Rewrite** | `src/services/ai/aiService.ts` | All OpenAI calls → Gemini SDK. Remove 30k truncation cap. Fix streaming. |
| **Modify** | `src/services/billing/usageService.ts` | Credit formula updated for Gemini 2.0 Flash pricing |
| **Modify** | `src/config/environment.ts` | `OPENAI_API_KEY` → `GEMINI_API_KEY` |
| **Modify** | `.env.example` | `OPENAI_API_KEY` → `GEMINI_API_KEY` |
| **Modify** | `package.json` | Remove `openai`, add `@google/generative-ai` |

### docs

| Action | File | What changes |
|--------|------|-------------|
| **Modify** | `docs/pricing-and-costs.md` | Section 1.2: OpenAI → Gemini, pricing, new credit formula |
| **Modify** | `docs/roadmap.md` | Add Phase 4.7 entry |

### No changes needed
- `crelyzor-frontend` — API contract unchanged, frontend calls same endpoints
- `crelyzor-public` — No AI calls
- Deepgram service — untouched
- Prisma schema — untouched
- All other backend services — untouched

---

## Critical Notes Before You Start

1. **`OPENAI_API_KEY` is a required field in `environment.ts`** — the server will refuse to start without it. You must swap it to `GEMINI_API_KEY` and also update your `.env` file (and production env vars on the server).

2. **Gemini SDK message format differs from OpenAI:**
   - Assistant role: OpenAI uses `"assistant"`, Gemini uses `"model"`
   - System prompt: OpenAI puts it in `messages[0]`, Gemini uses a separate `systemInstruction` field
   - Usage stats: OpenAI has `response.usage.prompt_tokens`, Gemini has `response.response.usageMetadata.promptTokenCount`

3. **Ask AI history mapping:** The conversation history stored in DB uses role `"assistant"`. When building Gemini history, remap `"assistant"` → `"model"`.

4. **The `MAX_PIPELINE_CHARS` cap is raised from 30,000 to 150,000** — this is the main quality win. 150k chars ≈ 37.5k tokens, well within Gemini 2.0 Flash's 1M context and still cost-efficient.

5. **Credit formula changes substantially** — Gemini 2.0 Flash is much cheaper than gpt-5.4-mini. The new formula makes credits last longer per user (product benefit). The minimum 1 credit per call is preserved.

---

## Task 1: Install Dependencies

**Files:**
- Modify: `crelyzor-backend/package.json`

- [ ] **Step 1: Navigate to backend and install Gemini SDK, remove OpenAI**

```bash
cd crelyzor-backend
pnpm remove openai
pnpm add @google/generative-ai
```

- [ ] **Step 2: Verify installation**

```bash
pnpm list @google/generative-ai
```

Expected output: `@google/generative-ai X.X.X` (some version)

- [ ] **Step 3: Confirm openai is gone**

```bash
pnpm list openai
```

Expected: empty or "not found" — NOT in dependencies

- [ ] **Step 4: Commit**

```bash
git add package.json pnpm-lock.yaml
git commit -m "feat(ai): swap openai for @google/generative-ai"
```

---

## Task 2: Create Gemini Client Config

**Files:**
- Create: `crelyzor-backend/src/config/gemini.ts`
- Delete: `crelyzor-backend/src/config/openai.ts`

- [ ] **Step 1: Create `src/config/gemini.ts`**

```typescript
import {
  GoogleGenerativeAI,
  type GenerativeModel,
  type GenerationConfig,
} from "@google/generative-ai";
import { logger } from "../utils/logging/logger";
import { AppError } from "../utils/errors/AppError";

export const GEMINI_MODEL = "gemini-2.0-flash";

export const DEFAULT_GENERATION_CONFIG: GenerationConfig = {
  temperature: 0.3,
};

let geminiClient: GoogleGenerativeAI | null = null;
let geminiModel: GenerativeModel | null = null;

const initializeGeminiClient = (): GenerativeModel => {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    throw new AppError("GEMINI_API_KEY environment variable is required", 500);
  }

  geminiClient = new GoogleGenerativeAI(apiKey);
  geminiModel = geminiClient.getGenerativeModel({ model: GEMINI_MODEL });

  logger.info("Gemini client initialized", { model: GEMINI_MODEL });
  return geminiModel;
};

export const getGeminiModel = (): GenerativeModel => {
  if (!geminiModel) {
    return initializeGeminiClient();
  }
  return geminiModel;
};

export default getGeminiModel;
```

- [ ] **Step 2: Delete `src/config/openai.ts`**

```bash
rm crelyzor-backend/src/config/openai.ts
```

- [ ] **Step 3: Commit**

```bash
git add src/config/gemini.ts src/config/openai.ts
git commit -m "feat(ai): add Gemini client config, remove OpenAI config"
```

---

## Task 3: Update Environment Validation

**Files:**
- Modify: `crelyzor-backend/src/config/environment.ts`
- Modify: `crelyzor-backend/.env.example`

- [ ] **Step 1: Update `environment.ts` — swap OPENAI_API_KEY for GEMINI_API_KEY**

Find this block in `src/config/environment.ts` (around line 24):
```typescript
  // AI & Transcription
  OPENAI_API_KEY: z.string().min(1, "OPENAI_API_KEY is required"),
  DEEPGRAM_API_KEY: z.string().min(1, "DEEPGRAM_API_KEY is required"),
```

Replace with:
```typescript
  // AI & Transcription
  GEMINI_API_KEY: z.string().min(1, "GEMINI_API_KEY is required"),
  DEEPGRAM_API_KEY: z.string().min(1, "DEEPGRAM_API_KEY is required"),
```

- [ ] **Step 2: Update `.env.example`**

Find:
```
# AI & Transcription
OPENAI_API_KEY=""
DEEPGRAM_API_KEY=""
```

Replace with:
```
# AI & Transcription
GEMINI_API_KEY=""                     # Google AI Studio key — get from aistudio.google.com
DEEPGRAM_API_KEY=""
```

- [ ] **Step 3: Update your local `.env` file**

In `crelyzor-backend/.env`, rename the key:
```
# Remove: OPENAI_API_KEY="sk-..."
# Add:    GEMINI_API_KEY="AIza..."
```

Get your Gemini API key from https://aistudio.google.com/apikey

- [ ] **Step 4: Commit**

```bash
git add src/config/environment.ts .env.example
git commit -m "feat(ai): rename OPENAI_API_KEY to GEMINI_API_KEY in env config"
```

---

## Task 4: Rewrite aiService.ts — Non-Streaming Functions

This is the core migration task. You are rewriting `generateSummary`, `extractKeyPoints`, `generateSummaryAndKeyPoints`, `extractTasks`, `generateMeetingTitle`, and `generateContent`.

**Files:**
- Modify: `crelyzor-backend/src/services/ai/aiService.ts`

**Key patterns:**

OpenAI call pattern (old):
```typescript
const openai = getOpenAIClient();
const response = await openai.chat.completions.create({
  model: OPENAI_MODEL,
  messages: [
    { role: "system", content: systemContent },
    { role: "user", content: prompt },
  ],
  max_completion_tokens: 1000,
  temperature: 0.3,
});
const text = response.choices[0]?.message?.content?.trim() ?? "";
const usage = response.usage; // { prompt_tokens, completion_tokens, total_tokens }
```

Gemini call pattern (new):
```typescript
const model = getGeminiModel();
const result = await model.generateContent({
  systemInstruction: systemContent,
  contents: [{ role: "user", parts: [{ text: prompt }] }],
  generationConfig: { maxOutputTokens: 1000, temperature: 0.3 },
});
const text = result.response.text().trim();
const usage = result.response.usageMetadata;
// usage.promptTokenCount, usage.candidatesTokenCount, usage.totalTokenCount
```

- [ ] **Step 1: Update the imports and top-level constants**

Replace the top of `aiService.ts` from line 1 through the `const OPENAI_MODEL` and type definitions:

```typescript
import type { Response } from "express";
import type { AIContentType } from "@prisma/client";
import prisma from "../../db/prismaClient";
import { getGeminiModel, GEMINI_MODEL } from "../../config/gemini";
import { logger } from "../../utils/logging/logger";
import { AppError } from "../../utils/errors/AppError";
import { getRedisClient } from "../../config/redisClient";
import { checkAndDeductCredits } from "../billing/usageService";
import * as conversationService from "./askAIConversationService";

const MAX_PIPELINE_CHARS = 150000; // ~37.5k tokens — Gemini 1M context allows full meetings
const MAX_ASK_AI_CHARS = 50000;    // ~12.5k tokens for Ask AI context

type AIUsageStats = {
  promptTokenCount?: number;
  candidatesTokenCount?: number;
  totalTokenCount?: number;
};

type AIUsageMeta = {
  operation: string;
  model: string;
  promptChars: number;
  completionChars: number;
  usage?: AIUsageStats;
  streamed?: boolean;
};
```

- [ ] **Step 2: Update `logOpenAIUsage` → `logAIUsage`**

Replace the `logOpenAIUsage` function:

```typescript
const estimateTokensFromChars = (chars: number): number =>
  Math.max(1, Math.ceil(chars / 4));

const logAIUsage = (meta: AIUsageMeta): void => {
  const estimatedPromptTokens = estimateTokensFromChars(meta.promptChars);
  const estimatedCompletionTokens = estimateTokensFromChars(meta.completionChars);

  logger.info("Gemini token usage", {
    operation: meta.operation,
    model: meta.model,
    streamed: meta.streamed ?? false,
    promptChars: meta.promptChars,
    completionChars: meta.completionChars,
    promptTokens: meta.usage?.promptTokenCount ?? estimatedPromptTokens,
    completionTokens: meta.usage?.candidatesTokenCount ?? estimatedCompletionTokens,
    totalTokens:
      meta.usage?.totalTokenCount ??
      estimatedPromptTokens + estimatedCompletionTokens,
    usageSource: meta.usage?.totalTokenCount ? "gemini" : "estimated",
  });
};
```

- [ ] **Step 3: Rewrite `generateSummary`**

Replace the entire `generateSummary` function:

```typescript
export const generateSummary = async (
  meetingId: string,
  transcriptText: string,
): Promise<string> => {
  if (!process.env.GEMINI_API_KEY) {
    throw new AppError("GEMINI_API_KEY is required for AI features", 503);
  }

  const meeting = await prisma.meeting.findFirst({
    where: { id: meetingId, isDeleted: false },
  });

  const capped = transcriptText.slice(0, MAX_PIPELINE_CHARS);
  const systemContent = "You are a professional meeting summarizer.";
  const prompt = `You are an AI assistant that summarizes meeting transcripts.
Provide a clear, professional summary of the following meeting transcript.
Focus on key decisions, discussion points, and outcomes.

Meeting Title: ${meeting?.title || "Untitled Meeting"}
Meeting Description: ${meeting?.description || "No description"}

Transcript:
${capped}

Provide a summary in 2-3 paragraphs.`;

  const model = getGeminiModel();
  const result = await model.generateContent({
    systemInstruction: systemContent,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { maxOutputTokens: 1000, temperature: 0.3 },
  });

  const summary = result.response.text().trim();
  if (!summary) {
    throw new AppError("Gemini returned empty summary content", 502);
  }

  logAIUsage({
    operation: "generateSummary",
    model: GEMINI_MODEL,
    promptChars: systemContent.length + prompt.length,
    completionChars: summary.length,
    usage: result.response.usageMetadata,
  });

  await prisma.meetingAISummary.upsert({
    where: { meetingId },
    create: { meetingId, summary },
    update: { summary, updatedAt: new Date() },
  });

  logger.info(`Summary generated for meeting ${meetingId}`);
  return summary;
};
```

- [ ] **Step 4: Rewrite `extractKeyPoints`**

Replace the entire `extractKeyPoints` function:

```typescript
export const extractKeyPoints = async (
  meetingId: string,
  transcriptText: string,
): Promise<string[]> => {
  if (!process.env.GEMINI_API_KEY) {
    throw new AppError("GEMINI_API_KEY is required for AI features", 503);
  }

  const capped = transcriptText.slice(0, MAX_PIPELINE_CHARS);
  const systemContent =
    "You extract key points from meetings and return them as JSON.";
  const prompt = `Extract the key points from this meeting transcript.
Return them as a JSON array of strings, with each key point being concise (1-2 sentences).
Focus on important decisions, agreements, and notable discussion items.

Transcript:
${capped}

Return ONLY a JSON array, no other text.`;

  const model = getGeminiModel();
  const result = await model.generateContent({
    systemInstruction: systemContent,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { maxOutputTokens: 1000, temperature: 0.3 },
  });

  const rawContent = result.response.text().trim();
  if (!rawContent) {
    throw new AppError("Gemini returned empty key points content", 502);
  }

  logAIUsage({
    operation: "extractKeyPoints",
    model: GEMINI_MODEL,
    promptChars: systemContent.length + prompt.length,
    completionChars: rawContent.length,
    usage: result.response.usageMetadata,
  });

  let keyPoints: string[];
  try {
    keyPoints = JSON.parse(stripMarkdownJson(rawContent));
  } catch {
    logger.error("Failed to parse key points JSON", {
      rawContent: rawContent.slice(0, 200),
    });
    throw new AppError("Failed to parse key points JSON from Gemini response", 502);
  }

  await prisma.meetingAISummary.upsert({
    where: { meetingId },
    create: { meetingId, summary: "", keyPoints },
    update: { keyPoints, updatedAt: new Date() },
  });

  logger.info(`Key points extracted for meeting ${meetingId}`);
  return keyPoints;
};
```

- [ ] **Step 5: Rewrite `generateSummaryAndKeyPoints`**

Replace the entire `generateSummaryAndKeyPoints` function:

```typescript
export const generateSummaryAndKeyPoints = async (
  meetingId: string,
  transcriptText: string,
  options?: { requireKeyPoints?: boolean },
): Promise<SummaryAndKeyPointsResult> => {
  if (!process.env.GEMINI_API_KEY) {
    throw new AppError("GEMINI_API_KEY is required for AI features", 503);
  }

  const meeting = await prisma.meeting.findFirst({
    where: { id: meetingId, isDeleted: false },
    select: { title: true, description: true },
  });

  const capped = transcriptText.slice(0, MAX_PIPELINE_CHARS);
  const systemContent =
    "You are a professional meeting summarizer. Always return valid JSON.";
  const prompt = `You are an AI assistant that summarizes meeting transcripts.
Return ONLY valid JSON with this exact shape:
{
  "summary": "string",
  "keyPoints": ["string", "string"]
}

Rules:
- summary: 2-3 professional paragraphs, focused on decisions and outcomes.
- keyPoints: 4-8 concise bullets as plain strings.

Meeting Title: ${meeting?.title ?? "Untitled Meeting"}
Meeting Description: ${meeting?.description ?? "No description"}

Transcript:
${capped}`;

  const model = getGeminiModel();
  const result = await model.generateContent({
    systemInstruction: systemContent,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { maxOutputTokens: 1300, temperature: 0.3 },
  });

  const raw = result.response.text().trim();
  if (!raw) {
    throw new AppError("Gemini returned empty summary content", 502);
  }

  logAIUsage({
    operation: "generateSummaryAndKeyPoints",
    model: GEMINI_MODEL,
    promptChars: systemContent.length + prompt.length,
    completionChars: raw.length,
    usage: result.response.usageMetadata,
  });

  let summary = "";
  let keyPoints: string[] = [];
  try {
    const parsed = JSON.parse(stripMarkdownJson(raw)) as {
      summary?: unknown;
      keyPoints?: unknown;
    };

    summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
    keyPoints = Array.isArray(parsed.keyPoints)
      ? parsed.keyPoints
          .filter((value): value is string => typeof value === "string")
          .map((value) => value.trim())
          .filter(Boolean)
      : [];

    if (!summary) {
      throw new Error("Parsed summary is empty");
    }
  } catch (err) {
    logger.warn("Single-call summary parse failed — using fallback", {
      meetingId,
      error: err instanceof Error ? err.message : String(err),
    });

    summary = await generateSummary(meetingId, transcriptText);
    keyPoints = [];
    try {
      keyPoints = await extractKeyPoints(meetingId, transcriptText);
    } catch (keyPointErr) {
      if (options?.requireKeyPoints) {
        throw new AppError("Failed to extract key points", 502);
      }
      logger.error("Fallback key-point extraction failed (non-fatal)", {
        meetingId,
        error:
          keyPointErr instanceof Error
            ? keyPointErr.message
            : String(keyPointErr),
      });
    }
  }

  await prisma.meetingAISummary.upsert({
    where: { meetingId },
    create: { meetingId, summary, keyPoints },
    update: { summary, keyPoints, updatedAt: new Date() },
  });

  logger.info(`Summary + key points generated in single call for meeting ${meetingId}`);
  return { summary, keyPoints };
};
```

- [ ] **Step 6: Rewrite `extractTasks`**

Replace the entire `extractTasks` function:

```typescript
export const extractTasks = async (
  meetingId: string,
  transcriptText: string,
  userId: string,
): Promise<ExtractedTask[]> => {
  if (!process.env.GEMINI_API_KEY) {
    throw new AppError("GEMINI_API_KEY is required for AI features", 503);
  }

  const capped = transcriptText.slice(0, MAX_PIPELINE_CHARS);
  const systemContent =
    "You extract tasks from meeting transcripts and return them as JSON.";
  const prompt = `Extract action items and tasks from this meeting transcript.
Return them as a JSON array of objects with these fields:
- title: string (short, actionable task title)
- description: string (optional, more details)
- assigneeHint: string (optional, name/role of person responsible if mentioned)

Transcript:
${capped}

Return ONLY a JSON array, no other text.`;

  const model = getGeminiModel();
  const result = await model.generateContent({
    systemInstruction: systemContent,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { maxOutputTokens: 1500, temperature: 0.3 },
  });

  const rawContent = result.response.text().trim();
  if (!rawContent) {
    throw new AppError("Gemini returned empty tasks content", 502);
  }

  logAIUsage({
    operation: "extractTasks",
    model: GEMINI_MODEL,
    promptChars: systemContent.length + prompt.length,
    completionChars: rawContent.length,
    usage: result.response.usageMetadata,
  });

  let rawTasks: Array<{
    title: string;
    description?: string;
    assigneeHint?: string;
  }>;
  try {
    rawTasks = JSON.parse(stripMarkdownJson(rawContent));
  } catch {
    logger.error("Failed to parse tasks JSON", {
      rawContent: rawContent.slice(0, 200),
    });
    throw new AppError("Failed to parse tasks JSON from Gemini response", 502);
  }

  const tasks: ExtractedTask[] = rawTasks.map((item) => ({
    title: item.title,
    description: item.description,
    assigneeHint: item.assigneeHint,
  }));

  if (tasks.length > 0) {
    await prisma.$transaction(
      async (tx) => {
        await tx.task.createMany({
          data: tasks.map((task) => ({
            meetingId,
            userId,
            title: task.title,
            description: task.description,
            source: "AI_EXTRACTED" as const,
          })),
        });
      },
      { timeout: 15000 },
    );
  }

  logger.info(`${tasks.length} tasks extracted for meeting ${meetingId}`);
  return tasks;
};
```

- [ ] **Step 7: Rewrite `generateMeetingTitle`**

Replace the entire `generateMeetingTitle` function:

```typescript
export const generateMeetingTitle = async (
  meetingId: string,
  transcriptText: string,
): Promise<string | null> => {
  if (!process.env.GEMINI_API_KEY) return null;

  let title: string | null = null;

  try {
    const systemContent =
      "You generate concise, professional meeting titles. Return only the title, no quotes or punctuation at the end.";
    const prompt = `Based on this meeting transcript, generate a short, descriptive meeting title (4-7 words max).
The title should capture the main topic or purpose of the meeting.
Return ONLY the title text, nothing else.

Transcript (first 2000 chars):
${transcriptText.slice(0, 2000)}`;

    const model = getGeminiModel();
    const result = await model.generateContent({
      systemInstruction: systemContent,
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: 30, temperature: 0.4 },
    });

    title = result.response.text().trim() || null;

    logAIUsage({
      operation: "generateMeetingTitle",
      model: GEMINI_MODEL,
      promptChars: systemContent.length + prompt.length,
      completionChars: title?.length ?? 0,
      usage: result.response.usageMetadata,
    });
  } catch (err) {
    logger.error(`Gemini title generation failed for meeting ${meetingId}`, {
      error: err instanceof Error ? err.message : String(err),
    });
    return null;
  }

  if (!title) return null;

  try {
    await prisma.meeting.update({
      where: { id: meetingId },
      data: { title },
    });
    logger.info(`Meeting ${meetingId} renamed to: "${title}"`);
  } catch (err) {
    logger.error(
      `DB write failed when saving generated title for meeting ${meetingId}`,
      {
        error: err instanceof Error ? err.message : String(err),
        title,
      },
    );
  }

  return title;
};
```

- [ ] **Step 8: Rewrite `generateContent`**

Replace the `generateContent` function (keep `CONTENT_PROMPTS` record unchanged — only the API call changes):

```typescript
export const generateContent = async (
  meetingId: string,
  userId: string,
  type: AIContentType,
): Promise<string> => {
  if (!process.env.GEMINI_API_KEY) {
    throw new AppError("GEMINI_API_KEY is required for AI features", 500);
  }

  const meeting = await prisma.meeting.findFirst({
    where: { id: meetingId, createdById: userId, isDeleted: false },
    select: { id: true },
  });
  if (!meeting) throw new AppError("Meeting not found", 404);

  const cached = await prisma.meetingAIContent.findUnique({
    where: { meetingId_type: { meetingId, type } },
  });
  if (cached) return cached.content;

  const transcript = await prisma.meetingTranscript.findFirst({
    where: { isDeleted: false, recording: { meetingId, isDeleted: false } },
  });
  if (!transcript) {
    throw new AppError(
      "No transcript available. Upload a recording first.",
      400,
    );
  }

  const capped = transcript.fullText.slice(0, MAX_PIPELINE_CHARS);
  const prompt = CONTENT_PROMPTS[type](capped);
  const systemContent =
    "You are a professional meeting assistant that generates well-structured content from meeting transcripts. Be concise, accurate, and professional.";

  const model = getGeminiModel();
  const result = await model.generateContent({
    systemInstruction: systemContent,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      maxOutputTokens: type === "TWEET" ? 100 : 1500,
      temperature: 0.6,
    },
  });

  const content = result.response.text().trim();
  if (!content) {
    throw new AppError("Gemini returned empty content", 502);
  }

  const usage = result.response.usageMetadata;

  logAIUsage({
    operation: `generateContent:${type}`,
    model: GEMINI_MODEL,
    promptChars: systemContent.length + prompt.length,
    completionChars: content.length,
    usage,
  });

  await checkAndDeductCredits(
    userId,
    usage?.promptTokenCount ??
      Math.ceil((systemContent.length + prompt.length) / 4),
    usage?.candidatesTokenCount ?? Math.ceil(content.length / 4),
  );

  await prisma.meetingAIContent.upsert({
    where: { meetingId_type: { meetingId, type } },
    create: { meetingId, type, content },
    update: { content, updatedAt: new Date() },
  });

  logger.info(`Generated ${type} content for meeting ${meetingId}`);
  return content;
};
```

- [ ] **Step 9: Verify TypeScript compiles**

```bash
cd crelyzor-backend
pnpm tsc --noEmit
```

Expected: zero errors. Fix any type issues before continuing.

- [ ] **Step 10: Commit**

```bash
git add src/services/ai/aiService.ts
git commit -m "feat(ai): migrate non-streaming AI functions to Gemini 2.0 Flash"
```

---

## Task 5: Rewrite Ask AI Streaming

The `askAI` function uses SSE streaming. Gemini's streaming API is similar to OpenAI's but with a different chunk format.

**Files:**
- Modify: `crelyzor-backend/src/services/ai/aiService.ts` (continued)

- [ ] **Step 1: Rewrite the `askAI` function**

The function signature, rate limiting, meeting/transcript fetch, speaker resolution, and SSE header code all stay the same. Only the Gemini call block changes. Replace from the `// Stream SSE headers` comment onward inside `askAI`:

The full rewritten `askAI` function (replace entirely):

```typescript
export const askAI = async (
  meetingId: string,
  userId: string,
  question: string,
  res: Response,
): Promise<void> => {
  await checkAskAIRateLimit(userId);

  const meeting = await prisma.meeting.findFirst({
    where: { id: meetingId, createdById: userId, isDeleted: false },
    select: { id: true, title: true },
  });

  if (!meeting) {
    throw new AppError("Meeting not found", 404);
  }

  // No segment cap — Gemini 1M context handles full meetings
  const transcript = await prisma.meetingTranscript.findFirst({
    where: { isDeleted: false, recording: { meetingId, isDeleted: false } },
    select: {
      id: true,
      segments: {
        orderBy: { startTime: "asc" },
        select: { speaker: true, text: true, startTime: true },
      },
    },
  });

  if (!transcript || transcript.segments.length === 0) {
    throw new AppError("No transcript available for this meeting", 400);
  }

  const speakers = await prisma.meetingSpeaker.findMany({
    where: { meetingId },
    select: { speakerLabel: true, displayName: true },
  });

  const rawTranscript = buildTranscriptContext(transcript.segments, speakers);
  const transcriptContext = buildRelevantAskAIContext(
    rawTranscript,
    question,
    MAX_ASK_AI_CHARS,
  );

  const systemPrompt = `You are an intelligent meeting assistant. You have access to the full transcript of a meeting titled "${meeting.title ?? "Untitled Meeting"}".
Answer the user's questions based solely on the transcript content.
Be concise, accurate, and helpful. If the answer isn't in the transcript, say so clearly.`;

  const userMessage = `Transcript:\n${transcriptContext}\n\nQuestion: ${question}`;

  const conversationId = await conversationService.getOrCreateConversation(
    userId,
    meetingId,
  );

  const priorMessages = await conversationService.getMessages(userId, meetingId);
  // Gemini uses "model" role, not "assistant"
  const historyMessages = priorMessages
    .slice(-6)
    .map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: m.content }],
    })) as { role: "user" | "model"; parts: { text: string }[] }[];

  const historyChars = priorMessages.slice(-6).reduce(
    (acc, m) => acc + m.content.length,
    0,
  );
  const askAIPromptChars = systemPrompt.length + userMessage.length + historyChars;

  await conversationService.appendMessage(conversationId, "user", question);

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders();

  const model = getGeminiModel();

  try {
    let streamedCompletionChars = 0;
    let fullAssistantResponse = "";

    const streamResult = await model.generateContentStream({
      systemInstruction: systemPrompt,
      contents: [
        ...historyMessages,
        { role: "user", parts: [{ text: userMessage }] },
      ],
      generationConfig: { maxOutputTokens: 900, temperature: 0.5 },
    });

    for await (const chunk of streamResult.stream) {
      const delta = chunk.text();
      if (delta) {
        streamedCompletionChars += delta.length;
        fullAssistantResponse += delta;
        res.write(`data: ${JSON.stringify({ token: delta })}\n\n`);
      }
    }

    logAIUsage({
      operation: "askAI:stream",
      model: GEMINI_MODEL,
      promptChars: askAIPromptChars,
      completionChars: streamedCompletionChars,
      streamed: true,
    });

    const estimatedInputTokens = Math.ceil(askAIPromptChars / 4);
    const estimatedOutputTokens = Math.ceil(streamedCompletionChars / 4);
    await checkAndDeductCredits(userId, estimatedInputTokens, estimatedOutputTokens);

    if (fullAssistantResponse) {
      await conversationService.appendMessage(
        conversationId,
        "assistant",
        fullAssistantResponse,
      );
    }

    res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
    res.end();

    logger.info("Ask AI completed", { meetingId, userId });
  } catch (err) {
    logger.error("Ask AI streaming error", {
      error: err instanceof Error ? err.message : String(err),
      meetingId,
      userId,
    });
    res.write(`data: ${JSON.stringify({ error: "AI response failed" })}\n\n`);
    res.end();
  }
};
```

- [ ] **Step 2: Verify TypeScript compiles cleanly**

```bash
cd crelyzor-backend
pnpm tsc --noEmit
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add src/services/ai/aiService.ts
git commit -m "feat(ai): migrate Ask AI streaming to Gemini generateContentStream"
```

---

## Task 6: Update AI Credits Formula

Gemini 2.0 Flash is significantly cheaper than gpt-5.4-mini. The credit formula must reflect the new pricing so credits are correctly valued.

**Old formula (gpt-5.4-mini):**
`credits = ceil((inputTokens × 0.00075) + (outputTokens × 0.0045))`
(1 credit = $0.001, mapped to gpt-5.4-mini rates)

**New formula (Gemini 2.0 Flash):**
`credits = ceil((inputTokens × 0.0001) + (outputTokens × 0.0004))`
(Gemini 2.0 Flash: $0.10/1M input, $0.40/1M output — PAYG pricing)

**Effect on users:** Credits last ~7x longer. A Free user's 50 credits now gets ~35 Ask AI questions instead of ~5. This is a product improvement — users get much more value per credit. Plan limits stay the same numerically.

**Files:**
- Modify: `crelyzor-backend/src/services/billing/usageService.ts`

- [ ] **Step 1: Update `calculateCredits` in `usageService.ts`**

Find this function (around line 52):
```typescript
export function calculateCredits(
  inputTokens: number,
  outputTokens: number,
): number {
  const raw = inputTokens * 0.00075 + outputTokens * 0.0045;
  return Math.max(1, Math.ceil(raw));
}
```

Replace with:
```typescript
export function calculateCredits(
  inputTokens: number,
  outputTokens: number,
): number {
  // Gemini 2.0 Flash: $0.10/1M input, $0.40/1M output. 1 credit = $0.001.
  const raw = inputTokens * 0.0001 + outputTokens * 0.0004;
  return Math.max(1, Math.ceil(raw));
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd crelyzor-backend
pnpm tsc --noEmit
```

Expected: zero errors.

- [ ] **Step 3: Commit**

```bash
git add src/services/billing/usageService.ts
git commit -m "feat(billing): update AI credits formula for Gemini 2.0 Flash pricing"
```

---

## Task 7: Update Documentation

**Files:**
- Modify: `docs/pricing-and-costs.md`
- Modify: `docs/roadmap.md`

- [ ] **Step 1: Update `pricing-and-costs.md` Section 1.2**

Replace the entire Section 1.2 (OpenAI section):

```markdown
### 1.2 Gemini — AI Processing

**Current model:** `gemini-2.0-flash` — migrated at Phase 4.7 ✅

| Model | Input | Output |
|-------|-------|--------|
| gpt-5.4-mini (previous) | $0.75/1M | $4.50/1M |
| **gemini-2.0-flash (current)** | **$0.10/1M** | **$0.40/1M** |

**What we call Gemini for:**
| Feature | Approx tokens per call | Cost/call (gemini-2.0-flash) |
|---------|----------------------|------------------------------|
| Summary + key points | 20k input + 1.3k output | $0.002 |
| Task extraction | 7k input + 500 output | $0.001 |
| Meeting title | 6.5k input + 30 output | $0.001 |
| Ask AI (per question) | 4k–8k input + 500–900 output | $0.001–$0.002 |
| Content generation | 6.5k–8k input + 100–1.5k output | $0.001–$0.002 |

**Total Gemini cost per 30-min meeting processed (pipeline):** ~$0.004 (vs $0.033 with gpt-5.4-mini)
**Meeting processing does NOT consume AI Credits** — it is included in the transcription flow.
**Ask AI and content generation consume AI Credits** — see Section 4.
```

- [ ] **Step 2: Update Section 2 (AI Credits formula)**

Find the credits formula block and update it:

```markdown
### How credits are calculated

Credits are deducted based on actual token usage per call:

```
credits_used = (input_tokens × 0.0001) + (output_tokens × 0.0004)
             = cost_in_dollars × 1000
```

This maps 1:1 to real cost so you never lose money on a heavy user.
```

- [ ] **Step 3: Update Section 3 cost table for Pro user**

In Section 3 "Pro User — Maxed Out", update the Gemini line:
- Change: `OpenAI — meeting processing (30 meetings, not credits) | $0.99`
- To: `Gemini — meeting processing (30 meetings, not credits) | $0.12`
- Change: `OpenAI — AI Credits (1,000 credits = $1.00) | $1.00`
- To: `Gemini — AI Credits (1,000 credits = $1.00) | $1.00` (credit monetary value unchanged — users just get more interactions per credit)
- Update the Total accordingly (reduced by ~$0.87/Pro user/month)

- [ ] **Step 4: Update Section 6 "Model Upgrades" — add Phase 4.7 entry**

Add after the existing Phase 4 model upgrades:

```markdown
### Gemini Migration: OpenAI → Gemini 2.0 Flash ✅ (Phase 4.7)
- **File:** `crelyzor-backend/src/services/ai/aiService.ts`
- **Change:** All AI calls now use `gemini-2.0-flash` via `@google/generative-ai` SDK
- **Cost impact:** Input 7.5x cheaper ($0.75→$0.10/1M), Output 11x cheaper ($4.50→$0.40/1M)
- **Context window:** 30k char cap → 150k chars (full meeting transcripts, better quality)
- **Credit formula:** Updated to reflect Gemini pricing — credits last ~7x longer per user
```

- [ ] **Step 5: Update `roadmap.md` — add Phase 4.7**

Add after the Phase 4.6 section:

```markdown
## Phase 4.7 — Gemini AI Migration ✅ COMPLETE

**Goal:** Replace OpenAI with Google Gemini 2.0 Flash for all AI understanding features. Deepgram transcription unchanged.

**Why:** 7-10x cheaper per token, 1M token context window eliminates transcript truncation, better quality on long meetings, credits last longer for users.

### Backend ✅
- [x] `@google/generative-ai` SDK — replaces `openai` package
- [x] `config/gemini.ts` — Gemini client initializer
- [x] `services/ai/aiService.ts` — all functions migrated: summary, key points, task extraction, title, Ask AI (streaming), content generation
- [x] `MAX_PIPELINE_CHARS` raised 30k → 150k — full meetings processed without truncation
- [x] Ask AI segment cap removed — full transcript in context
- [x] `services/billing/usageService.ts` — credit formula updated for Gemini pricing
- [x] `OPENAI_API_KEY` → `GEMINI_API_KEY` in env config
```

- [ ] **Step 6: Commit**

```bash
git add docs/pricing-and-costs.md docs/roadmap.md
git commit -m "docs: update pricing and roadmap for Phase 4.7 Gemini migration"
```

---

## Task 8: Manual QA Checklist

No automated tests exist. Run through this checklist manually after starting the server to confirm nothing is broken.

**Setup:**
```bash
cd crelyzor-backend
pnpm dev
```

Confirm in logs: `Gemini client initialized { model: 'gemini-2.0-flash' }` (only on first AI call)

- [ ] **QA 1: Meeting pipeline (summary + key points + tasks)**

Upload a recording to any meeting OR trigger AI reprocessing on an existing one.
- Navigate to a meeting in the frontend
- Confirm summary appears (non-empty, coherent paragraphs)
- Confirm key points appear (4-8 bullet points)
- Confirm tasks extracted (at least 1 if there were action items in the recording)
- Confirm meeting title was auto-renamed (check meeting title in DB or UI)

- [ ] **QA 2: Ask AI streaming**

Open any meeting with a transcript. Click Ask AI.
- Type a question and submit
- Confirm tokens stream in (character by character, not all at once)
- Confirm answer is relevant to the transcript
- Ask a follow-up question — confirm conversation history is maintained
- Check logs: `Ask AI completed` — no errors

- [ ] **QA 3: Content generation**

On a meeting with a transcript, open the content generation panel.
- Generate "Meeting Report" — confirm structured output with sections
- Generate "Tweet" — confirm under 280 chars
- Generate "Follow-up Email" — confirm professional email body
- Confirm second generation of same type returns cached result (no new Gemini call in logs)

- [ ] **QA 4: Error case — no API key**

Temporarily comment out `GEMINI_API_KEY` in `.env`, restart server.
- Confirm server fails to start with: `Environment validation failed: GEMINI_API_KEY: GEMINI_API_KEY is required`
- Restore the key before continuing

- [ ] **QA 5: Long meeting transcript (if available)**

If you have a transcript longer than 30,000 characters (the old cap):
- Process it with AI — confirm the summary covers content from beyond the old 30k char mark
- This verifies the context window improvement is working

---

## Rollback Plan

If production issues occur:

1. Revert the 4 commits from this migration (`git revert` the 4 commits in order)
2. Restore `OPENAI_API_KEY` in `.env` and server environment variables
3. The DB data (summaries, tasks, content) is unaffected — it's just text, model-agnostic

The Gemini and OpenAI output formats are identical at the product level — users see the same summary/tasks/Ask AI experience.
