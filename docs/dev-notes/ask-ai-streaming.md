# Ask AI — Streaming SSE — Dev Notes

## What was built
`POST /sma/meetings/:meetingId/ask` streaming endpoint + chat panel UI in all 3 MeetingDetail layouts.

## Backend pattern
- SSE (Server-Sent Events) — `Content-Type: text/event-stream`
- Verify meeting belongs to user before fetching transcript.
- Build prompt: system message + full transcript (use `displayName` if set, else `speakerLabel`) + user question.
- Rate limit: max 20 req/user/hour.
- Zod: `{ question: z.string().min(1).max(1000) }`

## Frontend streaming pattern
```typescript
// Use fetch ReadableStream — not axios (axios doesn't stream)
const response = await fetch(url, { method: 'POST', body: ... });
const reader = response.body.getReader();
const decoder = new TextDecoder();

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  const chunk = decoder.decode(value);
  // append chunk to message state
}
```

## UI
- Suggestion chips pre-loaded: "Summarize decisions", "List tasks", "What were the blockers?"
- Conversation history within session (not persisted to DB).
- Chat panel only available when transcript exists (`transcriptionStatus === 'COMPLETED'`).

## Gotchas
- Axios cannot consume SSE/streaming responses — must use native `fetch` with `ReadableStream`.
- Always abort the stream on component unmount (`AbortController`).
- Do not show chat panel if transcript doesn't exist — guard on `transcriptionStatus`.
