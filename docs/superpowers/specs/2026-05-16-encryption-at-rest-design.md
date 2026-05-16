# Encryption at Rest — Design Spec

**Date:** 2026-05-16
**Phase:** 5

---

## Problem

Every sensitive user-facing string in Crelyzor is stored as plaintext in Postgres today:

- Meeting transcripts (`MeetingTranscript.fullText`, `TranscriptSegment.text`)
- Meeting notes (`MeetingNote.content`)
- AI summaries and AI content (`MeetingAISummary`, `MeetingAIContent`)
- Ask AI conversation history (`AskAIConversation`)
- Tasks (`Task.title`, `Task.description`)
- Private card contacts (`CardContact.name`, `email`, `phone`, `notes`)
- Booking PII for non-Crelyzor guests (`Booking.guestEmail`, `guestNotes`)

A DB dump, a leaked backup, a compromised admin tool, or any third-party reader (Prisma Studio in prod, future BI tools) reveals everything verbatim. From a user trust standpoint this is the gap — a "we take privacy seriously" product cannot have an honest answer of "yes, our DB has every word of your meetings in plain text."

## Goals

1. Encrypt all in-scope content at rest in Postgres
2. Encrypt recording objects in GCS using customer-managed keys
3. Keep every server-side AI feature working unchanged (Summary, Ask AI, AI Content, future Big Brain)
4. Per-user blast radius — one compromised key affects one user, not all users
5. Enable crypto-shredding for GDPR right-to-erasure (destroy DEK → ciphertext becomes unrecoverable, even in backups)
6. Zero change to public/auth/wire protocol — encryption is invisible above the Prisma layer

## Non-goals

- **End-to-end encryption (E2EE).** Server holds keys. This is server-side encryption at rest, not E2EE. Explicitly evaluated and ruled out: would kill all AI features, break Big Brain (Phase 8), require passphrase recovery UX, and produce permanent data loss when users forget passphrases.
- **Searchable encryption.** No blind indexes, no order-preserving encryption. Encrypted columns cannot be searched server-side.
- **Encrypting public profile data.** `Card.*` (public profile fields rendered to the open web) stays plaintext.
- **Encrypting metadata.** IDs, FKs, timestamps, soft-delete flags, indexed columns (`speaker`, `startTime`), `Meeting.title`, `Tag.name`, `EventType.*`, `UserSettings` all stay plaintext.

---

## Scope

### Encrypted columns (change `String` → `Bytes`)

| Model | Column(s) |
|---|---|
| `MeetingTranscript` | `fullText` |
| `TranscriptSegment` | `text` |
| `MeetingNote` | `content` |
| `MeetingAISummary` | `summary`, `keyPoints` (each element) |
| `MeetingAIContent` | `content` |
| `AskAIConversation` | message contents (whatever field stores them — JSON or relation) |
| `Task` | `title`, `description` |
| `CardContact` | `name`, `email`, `phone`, `notes` |
| `Booking` | `guestEmail`, `guestNotes` |

### Encrypted storage (infrastructure layer)

| Resource | Mechanism |
|---|---|
| GCS recordings bucket | Customer-Managed Encryption Keys (CMEK) using the same KMS key |

### Plaintext (explicitly unchanged)

- All `id`, FK, `createdAt`, `updatedAt`, `deletedAt`, `isDeleted` fields
- `Meeting.title`, `Meeting.startTime`, `Meeting.endTime`
- `TranscriptSegment.speaker`, `startTime`, `endTime` (indexed)
- `Tag.*`, `EventType.*`, `UserSettings.*`, `Card.*` (public profile)
- `Task.status`, `Task.dueDate`, `Task.source`
- All booking metadata except guest PII

---

## Architecture

### Key hierarchy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Google Cloud KMS                                │
│                                                                         │
│    ┌──────────────────────────────────────────────────────────────┐     │
│    │  KEK — Key Encryption Key                                    │     │
│    │  • Never leaves KMS                                          │     │
│    │  • 1 per environment (dev / staging / prod)                  │     │
│    │  • Auto-rotated annually by Google                           │     │
│    │  • IAM: only backend service account can wrap/unwrap         │     │
│    │  • Every wrap/unwrap call → Cloud Audit Log                  │     │
│    └──────────────────────────────────────────────────────────────┘     │
└──────────────────────┬──────────────────────────────────────────┬───────┘
                       │                                          │
              wrap/unwrap DEK                          transparent CMEK
              (~15ms per request)                      (no app code)
                       │                                          │
                       ▼                                          ▼
┌──────────────────────────────────────────┐    ┌────────────────────────────┐
│  Backend (Node + Express)                │    │  GCS bucket (CMEK on)      │
│                                          │    │                            │
│  cryptoService                           │    │  Each recording object     │
│  ├─ getDek(userId)                       │    │  encrypted by Google with  │
│  │   • fetch wrappedDek from Postgres    │    │  our KMS key.              │
│  │   • KMS.decrypt → plaintext DEK       │    │                            │
│  │   • cache in AsyncLocalStorage        │    │  Upload/download URLs and  │
│  │     (request-scoped only)             │    │  code path unchanged.      │
│  ├─ encrypt(text, userId) → Bytes        │    │                            │
│  │   AES-256-GCM                         │    │  Audit log on every object │
│  │   format: iv(12) ‖ ct ‖ tag(16)       │    │  read/write.               │
│  └─ decrypt(bytes, userId) → string      │    └────────────────────────────┘
│                                          │
│  Service layer calls encrypt/decrypt     │
│  at the Prisma boundary. AI code never   │
│  touches keys directly.                  │
└────────────────────┬─────────────────────┘
                     │
                     │ encrypted reads/writes
                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            PostgreSQL                                   │
│                                                                         │
│  User                                                                   │
│  ├─ id, email, createdAt, ...   (plaintext — metadata)                  │
│  └─ wrappedDek: Bytes           ◄── this user's DEK, wrapped by KEK     │
│                                                                         │
│  In-scope models — content columns stored as Bytes (ciphertext)         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Two keys, two purposes

- **KEK (Key Encryption Key)** — lives in Google Cloud KMS, never leaves the HSM. Only ever wraps/unwraps DEKs. Never touches user data directly.
- **DEK (Data Encryption Key)** — one per user, 256-bit. Stored in `User.wrappedDek` (wrapped by KEK). Unwrapped to plaintext only in backend memory, only for the duration of a single request. Discarded when the request ends.

### Cipher

- **AES-256-GCM** via Node's built-in `crypto` module
- No third-party crypto libraries
- Authenticated encryption — tampering with ciphertext is detected on decrypt
- Per-record ciphertext format: `iv (12 bytes) ‖ ciphertext ‖ authTag (16 bytes)`, stored as a single `Bytes` column

---

## Request lifecycle

### Write path (creating a meeting note)

```
Client                Backend                  KMS              Postgres
  │                      │                       │                  │
  │ POST /notes          │                       │                  │
  │ { content: "..." }   │                       │                  │
  │─────────────────────►│                       │                  │
  │                      │                       │                  │
  │              verifyJWT → userId              │                  │
  │                      │                       │                  │
  │              cryptoMiddleware                │                  │
  │                      │  SELECT wrappedDek    │                  │
  │                      │──────────────────────────────────────────►
  │                      │◄──────────────────────────────────────────
  │                      │                       │                  │
  │                      │  decrypt(wrappedDek)  │                  │
  │                      │──────────────────────►│                  │
  │                      │◄──── plaintext DEK ───│                  │
  │                      │  (cached in AsyncLocalStorage)           │
  │                      │                       │                  │
  │              notesService.create(...)        │                  │
  │              encrypted = encrypt(content)    │                  │
  │              (AES-256-GCM, in-process)       │                  │
  │                      │                       │                  │
  │                      │  INSERT meetingNote   │                  │
  │                      │  content = <Bytes>    │                  │
  │                      │──────────────────────────────────────────►
  │                      │◄──── { id, createdAt }────────────────────
  │                      │                       │                  │
  │◄─── 201 plaintext ───│                       │                  │
  │      (TLS)           │                       │                  │
  │                      │                       │                  │
  │              request ends → AsyncLocalStorage cleared           │
  │              DEK gone from memory                               │
```

### Read path with AI

```
Client                Backend                                Postgres + OpenAI
  │                      │                                          │
  │ POST /sma/meetings/  │                                          │
  │ :id/ask "summarize   │                                          │
  │  the decisions"      │                                          │
  │─────────────────────►│                                          │
  │                      │                                          │
  │              verifyJWT + cryptoMiddleware                       │
  │              (DEK now in AsyncLocalStorage)                     │
  │                      │                                          │
  │              askAiService.answer(...)                           │
  │                      │  SELECT transcript                       │
  │                      │─────────────────────────────────────────►│
  │                      │◄──── encrypted Bytes ────────────────────│
  │                      │                                          │
  │              plaintext = decrypt(bytes)                         │
  │              (in-memory only, never logged, never persisted)    │
  │                      │                                          │
  │                      │  OpenAI Chat                             │
  │                      │  [system, transcript, question]          │
  │                      │─────────────────────────────────────────►│
  │                      │◄──── streamed tokens ────────────────────│
  │                      │                                          │
  │◄─── SSE stream ──────│                                          │
  │     (plaintext       │                                          │
  │      answer over TLS)│                                          │
  │                      │                                          │
  │              encrypted = encrypt(answer)                        │
  │                      │  UPDATE askAIConversation                │
  │                      │  messages = <encrypted>                  │
  │                      │─────────────────────────────────────────►│
  │                      │                                          │
  │              request ends → DEK + plaintext discarded           │
```

### Performance budget

- **KMS unwrap call:** one per request, ~15ms (cached in-process after first call within a request)
- **AES-GCM:** sub-millisecond per typical transcript (~100KB). Modern CPUs do ~1GB/s.
- **Net request overhead:** ~15–25ms one-time at start of each request that touches encrypted data
- No per-record KMS calls. No per-field KMS calls.

---

## Service-layer integration

A single new module: `src/utils/security/crypto.ts`

```typescript
// Public API — the only thing service code calls
export async function encrypt(plaintext: string, userId: string): Promise<Buffer>
export async function decrypt(ciphertext: Buffer, userId: string): Promise<string>

// Internal — DEK management
async function getDek(userId: string): Promise<Buffer>  // cached per request
async function generateDekForNewUser(userId: string): Promise<void>  // creates + wraps + stores wrappedDek
```

Service code touches encrypt/decrypt at the Prisma boundary only:

```typescript
// Before
await prisma.meetingNote.create({
  data: { meetingId, author: userId, content }
})

// After
await prisma.meetingNote.create({
  data: { meetingId, author: userId, content: await encrypt(content, userId) }
})
```

The AI service code doesn't change at all — it just receives plaintext from the service layer that already decrypted on read.

### Logging discipline

- Never log encrypted-field plaintext
- Logger middleware adds a `__encryptedFields` denylist; lint rule blocks `logger.x({ transcript })`-style passes
- `req.body` for routes accepting encrypted content is redacted in request logs

---

## Schema changes

### New column

```prisma
model User {
  // existing fields
  wrappedDek Bytes? // null only during the backfill window
}
```

### Column type changes (String → Bytes)

All in-scope columns listed in **Scope** above.

- For `keyPoints String[]` on `MeetingAISummary`: encrypt each element individually → store as `Bytes[]`. Order is preserved by Postgres array semantics; no element references another.
- For JSON-style content (e.g., `AskAIConversation.messages` if stored as JSON): serialize to string → encrypt → store as `Bytes`.

### Migrations

Two migrations, run in order:

1. **`add_wrapped_dek_and_bytes_columns`** — add `User.wrappedDek` (nullable). For each encrypted column, add a sibling `_encrypted Bytes?` column (e.g., `fullText_encrypted`). The original String column stays for now.
2. **`drop_plaintext_columns`** — after backfill completes and verification passes, drop the original String columns and rename `_encrypted` → original name.

This dual-column approach lets us run the backfill against live traffic without downtime.

---

## Backfill plan

A standalone script: `src/scripts/backfill-encryption.ts`

### Phases

1. **DEK generation** — for every User without a `wrappedDek`, generate a 256-bit random DEK, wrap it via KMS, store. Idempotent. Resumable. Runs first, completes in seconds for any reasonable user base.

2. **Content encryption** — for each in-scope table, for each row:
   - Skip if `_encrypted` column already populated
   - Read plaintext column
   - Encrypt with the row owner's DEK (look up `userId` via FK chain — `MeetingNote → Meeting → userId`, etc.)
   - Write to `_encrypted` column
   - Idempotent. Resumable. Batched (1000 rows per transaction).
   - Dry-run mode available for staging validation.

3. **Verification** — re-read random sample, decrypt, compare to original plaintext. Fail loud on any mismatch.

4. **Cutover** — feature flag `ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN` flipped from `false` → `true`. Reads switch to the encrypted column. Old plaintext column kept for 7 days as a rollback safety net.

5. **Plaintext drop** — after 7 days of stable operation, run migration 2 to drop plaintext columns.

### Rollback story

- During steps 1–3: rollback is no-op. Plaintext column still authoritative.
- After step 4 (feature flag flip): flip flag back. Plaintext column still has the data. Cost: 7-day stale window for any new writes (manageable, will document).
- After step 5: not rollback-able. Verified twice on staging snapshots before production.

---

## GCS recordings — CMEK

GCS supports Customer-Managed Encryption Keys via Cloud KMS. Each object encrypted with a per-object DEK; the DEK is wrapped by our KMS KEK.

### Setup

```bash
# 1. Grant Cloud Storage service agent encrypt/decrypt on our KMS key
gcloud kms keys add-iam-policy-binding <key> \
  --location <region> \
  --keyring <ring> \
  --member serviceAccount:service-<PROJECT_NUMBER>@gs-project-accounts.iam.gserviceaccount.com \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter

# 2. Set default key on the recordings bucket
gsutil kms encryption -k <key-resource-name> gs://<recordings-bucket>
```

After step 2, all *new* uploads are encrypted with CMEK transparently. Existing objects need a one-time rewrite to pick up CMEK — done via `gsutil rewrite -k` on the existing bucket contents (runs in the background, no app downtime).

### App code changes

Zero. GCS upload/download URLs, signed URLs, and SDK calls all behave identically. The encryption is invisible to the application.

---

## Operational concerns

### Key rotation

- **KEK rotation:** Google KMS auto-rotates annually. Old wrapped DEKs continue to work (KMS handles versioning internally). New wraps use the new version.
- **DEK rotation per user:** only needed if a specific user's DEK is suspected compromised. Process: generate new DEK, wrap, store as `wrappedDek_new`; re-encrypt all user's content using new DEK; swap `wrappedDek_new` → `wrappedDek`. Runs as a background job per user, not a routine operation.

### Crypto-shredding for GDPR delete

"Delete my account" today soft-deletes content. Post-encryption:
- Destroy the user's `wrappedDek` (set to null or hard-delete the row)
- Every ciphertext for that user in Postgres + every recording object in GCS becomes permanently unrecoverable
- Even if old DB backups still hold the ciphertext, there's no key to decrypt them with

This solves the long-standing "delete requests don't propagate to backups" GDPR pain point as a free side effect.

### Audit logging

- KMS Cloud Audit Logs record every `Decrypt` call with timestamp, service account, KMS key version
- Logs are queryable via Cloud Logging
- Anomaly detection (high unwrap volume, off-hours unwraps) is a future hardening item

### Disaster recovery

- KMS keys are highly available within their region (multi-zone)
- KMS keys are *never* deleted accidentally — Google enforces a 24-hour minimum destruction delay, configurable up to 30 days
- Lost KMS access = lost user data. Documented as the single largest operational risk; mitigated by IAM hygiene + key destruction delays + project-level deletion protection

### Pre-encryption backups (one-time cleanup)

Any DB backup taken *before* the cutover still contains plaintext. Crypto-shredding only protects backups taken *after* encryption is live. Required actions during rollout:

- Inventory all existing prod backups (Cloud SQL automated backups, any manual snapshots)
- After cutover stabilizes, delete or re-import-and-re-encrypt every pre-encryption backup
- Document a backup retention policy going forward — older than retention window means it predates encryption and must be purged

### What gets harder

- **No server-side search on encrypted columns.** Currently there is no full-text search on transcripts/notes (no `tsvector`, no `pg_trgm` indexes). If we want search later, options are: client-side decrypt-then-search, or blind indexes (separate column with HMAC(token, key)). Not blocked, just deferred.
- **No SQL aggregation on encrypted content.** No `COUNT WHERE description LIKE '%urgent%'`. Same caveat — not used today.
- **Prisma Studio in production becomes useless for inspecting content.** Acceptable — Prisma Studio in prod is itself a bad practice we want to discourage.

---

## Big Brain (Phase 8) compatibility

Server-side encryption is fully compatible with Big Brain because the server can decrypt any user's content on demand:

```
1. embed(question) → query vector
2. pgvector cosine search → top-K chunk IDs (rows still ciphertext)
3. fetch + decrypt those K chunks (DEK already in memory)
4. RAG: [chunks, question] → OpenAI → answer
5. encrypt(answer) on the way back into AskAIConversation
```

### One design call deferred to Phase 8

Embeddings are mathematically derived from plaintext and *do leak some semantic information*. Two ways to handle when Big Brain ships:

1. **Leave embeddings plaintext, treat vector storage as sensitive** — IAM-restricted, same trust zone as the unwrapped DEK. Pragmatic, standard industry approach.
2. **Encrypt embeddings** — would break similarity search (research-grade homomorphic schemes only). Not viable.

We will ship #1 when Big Brain lands. Phase 5 (this spec) does not decide this; we just need to record that the encryption layer doesn't constrain the choice.

---

## What we explicitly are not building

- **End-to-end encryption.** Server holds keys. Crelyzor can decrypt for AI features, support investigations (rare, audited), and Big Brain. The honest user-facing pitch is "your data is encrypted at rest, decrypted only by your authenticated session and by AI features you trigger." We are not claiming "even Crelyzor cannot read your meetings."
- **Per-meeting Private Mode (Hybrid option).** Considered, deferred. If users start requesting "even Crelyzor can't read this specific meeting," we can add it later as an opt-in flag that excludes the meeting from AI and Big Brain. Not in Phase 5.
- **Passphrase / recovery code UX.** Not needed — keys are KMS-managed.
- **Customer-Managed Keys for enterprise tier.** Not needed — KMS already provides this for us.

---

## Rollout

| Step | Detail | Risk |
|---|---|---|
| 1. Provision KMS | Create keyring + KEK in GCP. IAM bind backend SA. | None — no app impact |
| 2. Build `cryptoService` | KMS client, DEK cache, AES-GCM helpers, unit tests | None — not wired in |
| 3. Schema migration 1 | Add `User.wrappedDek` + `_encrypted` shadow columns | None — additive |
| 4. Backfill | Run script in staging, verify; then prod (off-hours) | Medium — dry-run mandatory |
| 5. Service-layer patches | Find/replace 30–50 call sites; dual-write to both columns behind a flag | Medium — needs careful testing |
| 6. Cutover flag | Reads flip to encrypted column | Low — 7-day rollback window |
| 7. CMEK on GCS bucket | One `gsutil` command + rewrite existing objects | Low — transparent |
| 8. Schema migration 2 | Drop plaintext columns after 7 days stable | None — non-rollbackable, validated first |

**Total effort estimate:** ~1.5 weeks for one focused engineer. Most of the time is in steps 4 (backfill correctness, retry-safety) and 5 (mechanical but wide find-and-replace + tests).

## Acceptance criteria

- [ ] Every in-scope column stores `Bytes` in production
- [ ] `User.wrappedDek` is populated for 100% of active users
- [ ] Sample integration test: create meeting → upload recording → transcribe → summarize → ask AI → all steps work end-to-end with encryption on
- [ ] KMS audit log shows expected unwrap volume (~1 per authenticated request)
- [ ] Account delete destroys `wrappedDek` and the user's data becomes unrecoverable in a follow-up read attempt
- [ ] GCS recordings bucket reports CMEK-enabled in `gsutil kms encryption`
- [ ] Zero plaintext content in DB dumps (verified by spot-grep on a staging dump)
