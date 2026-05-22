# Encryption at Rest — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encrypt all sensitive user content in Postgres at rest using per-user AES-256-GCM envelope encryption, with blind indexes preserving existing searches, and a two-migration zero-downtime rollout.

**Architecture:** A `cryptoService` module exposes four functions — `encrypt`, `decrypt`, `blindIndex`, `initDekForNewUser`. Each user has a DEK stored wrapped by a KEK in Google Cloud KMS (or a local key in dev). DEKs are cached in an in-process LRU cache so both HTTP handlers and Bull workers share the same code path. Encrypted columns are added as shadow `_encrypted` columns alongside the originals, backfilled, then the originals dropped.

**Tech Stack:** Node.js `crypto` (built-in), `@google-cloud/kms`, `node-cache` (already installed), `vitest` (to be installed), Prisma 6, TypeScript 5.

---

## File Map

**Create:**
- `src/utils/security/types.ts` — shared types for the crypto module
- `src/utils/security/dekCache.ts` — in-process LRU DEK cache (node-cache wrapper)
- `src/utils/security/kmsProviders.ts` — GcpKmsProvider + LocalKmsProvider
- `src/utils/security/crypto.ts` — public API: encrypt, decrypt, blindIndex, initDekForNewUser
- `src/utils/security/__tests__/crypto.test.ts` — unit tests
- `vitest.config.ts` — test runner config
- `src/scripts/backfill-encryption.ts` — standalone backfill script

**Modify:**
- `package.json` — add @google-cloud/kms, vitest
- `src/config/environment.ts` — add KMS_PROVIDER, LOCAL_KMS_KEY, HMAC_BLIND_INDEX_KEY, GCP_KMS_KEY_NAME, GCP_KMS_PROJECT, GCP_KMS_LOCATION, GCP_KMS_KEYRING, ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN
- `prisma/schema.prisma` — add wrappedDek/dekVersion/UserDekHistory; add shadow _encrypted columns; add _bidx blind index columns
- `src/controllers/googleController.ts` — call initDekForNewUser inside isNewUser block
- `src/services/transcription/transcriptionService.ts` — encrypt fullText + segment text on write, decrypt on read
- `src/worker/jobProcessor.ts` — no code change needed; LRU cache makes getDek work in workers automatically
- `src/services/ai/aiService.ts` — encrypt summary + keyPoints on write, decrypt before passing to AI
- `src/services/ai/askAIConversationService.ts` — encrypt AskAIMessage.content on write, decrypt on read
- `src/services/smaEditService.ts` — encrypt on manual summary update
- `src/controllers/taskController.ts` — encrypt title + description on write, decrypt on read
- `src/services/cardService.ts` — encrypt CardContact fields + write blind indexes
- `src/services/scheduling/bookingService.ts` — encrypt Booking PII + write blind indexes

---

## Task 1: Test framework + dependencies

**Files:**
- Modify: `package.json`
- Create: `vitest.config.ts`

- [ ] **Install dependencies**

```bash
cd crelyzor-backend
pnpm add @google-cloud/kms
pnpm add -D vitest
```

- [ ] **Create vitest config**

Create `crelyzor-backend/vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/__tests__/**/*.test.ts'],
  },
});
```

- [ ] **Add test script to package.json**

In `crelyzor-backend/package.json`, add under `"scripts"`:
```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Verify vitest works**

```bash
pnpm test
```
Expected: `No test files found` (no tests yet — that's fine).

---

## Task 2: Types

**Files:**
- Create: `src/utils/security/types.ts`

- [ ] **Write types file**

```typescript
export interface KmsProvider {
  wrapKey(plainDek: Buffer): Promise<Buffer>;
  unwrapKey(wrappedDek: Buffer): Promise<Buffer>;
}
```

- [ ] **Commit**

```bash
git add src/utils/security/types.ts vitest.config.ts package.json pnpm-lock.yaml
git commit -m "chore: add vitest + @google-cloud/kms, define KmsProvider interface"
```

---

## Task 3: DEK cache

**Files:**
- Create: `src/utils/security/dekCache.ts`
- Create: `src/utils/security/__tests__/crypto.test.ts` (initial file)

- [ ] **Write failing test**

Create `src/utils/security/__tests__/crypto.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { DekCache } from '../dekCache';

describe('DekCache', () => {
  let cache: DekCache;

  beforeEach(() => {
    cache = new DekCache({ ttlSeconds: 1, maxKeys: 10 });
  });

  it('returns undefined for a cache miss', () => {
    expect(cache.get('user-1', 1)).toBeUndefined();
  });

  it('returns the stored DEK on cache hit', () => {
    const dek = Buffer.from('a'.repeat(32));
    cache.set('user-1', 1, dek);
    const result = cache.get('user-1', 1);
    expect(result).toEqual(dek);
  });

  it('returns undefined after TTL expires', async () => {
    const dek = Buffer.from('a'.repeat(32));
    cache.set('user-1', 1, dek);
    await new Promise(r => setTimeout(r, 1200));
    expect(cache.get('user-1', 1)).toBeUndefined();
  });

  it('scopes by version — version 1 and version 2 are separate entries', () => {
    const dek1 = Buffer.from('a'.repeat(32));
    const dek2 = Buffer.from('b'.repeat(32));
    cache.set('user-1', 1, dek1);
    cache.set('user-1', 2, dek2);
    expect(cache.get('user-1', 1)).toEqual(dek1);
    expect(cache.get('user-1', 2)).toEqual(dek2);
  });
});
```

- [ ] **Run test — expect failure**

```bash
pnpm test
```
Expected: `Cannot find module '../dekCache'`

- [ ] **Implement DekCache**

Create `src/utils/security/dekCache.ts`:

```typescript
import NodeCache from 'node-cache';

export class DekCache {
  private cache: NodeCache;

  constructor({ ttlSeconds = 60, maxKeys = 200 } = {}) {
    this.cache = new NodeCache({ stdTTL: ttlSeconds, maxKeys, useClones: false });
  }

  private key(userId: string, version: number): string {
    return `${userId}:${version}`;
  }

  get(userId: string, version: number): Buffer | undefined {
    return this.cache.get<Buffer>(this.key(userId, version));
  }

  set(userId: string, version: number, dek: Buffer): void {
    this.cache.set(this.key(userId, version), dek);
  }

  delete(userId: string): void {
    const keys = this.cache.keys().filter(k => k.startsWith(`${userId}:`));
    this.cache.del(keys);
  }
}

export const dekCache = new DekCache();
```

- [ ] **Run test — expect pass**

```bash
pnpm test
```
Expected: all 4 DEK cache tests pass.

- [ ] **Commit**

```bash
git add src/utils/security/dekCache.ts src/utils/security/__tests__/crypto.test.ts
git commit -m "feat: add DekCache — in-process LRU keyed by userId:version"
```

---

## Task 4: KMS providers

**Files:**
- Create: `src/utils/security/kmsProviders.ts`

- [ ] **Write failing tests** (add to `__tests__/crypto.test.ts`)

```typescript
import { LocalKmsProvider } from '../kmsProviders';

describe('LocalKmsProvider', () => {
  const provider = new LocalKmsProvider(Buffer.from('a'.repeat(32)));

  it('round-trips a DEK: wrap then unwrap returns original', async () => {
    const dek = Buffer.from('b'.repeat(32));
    const wrapped = await provider.wrapKey(dek);
    const unwrapped = await provider.unwrapKey(wrapped);
    expect(unwrapped).toEqual(dek);
  });

  it('wrapped output is not equal to the original DEK', async () => {
    const dek = Buffer.from('c'.repeat(32));
    const wrapped = await provider.wrapKey(dek);
    expect(wrapped).not.toEqual(dek);
  });
});
```

- [ ] **Run test — expect failure**

```bash
pnpm test
```
Expected: `Cannot find module '../kmsProviders'`

- [ ] **Implement KMS providers**

Create `src/utils/security/kmsProviders.ts`:

```typescript
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';
import type { KmsProvider } from './types';

// LocalKmsProvider: wraps/unwraps DEKs using a local AES-256-GCM key.
// Used when KMS_PROVIDER=local (development). Same code path as GCP — no bypass.
export class LocalKmsProvider implements KmsProvider {
  constructor(private readonly localKey: Buffer) {
    if (localKey.length !== 32) throw new Error('LOCAL_KMS_KEY must be 32 bytes (64 hex chars)');
  }

  async wrapKey(plainDek: Buffer): Promise<Buffer> {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.localKey, iv);
    const ct = Buffer.concat([cipher.update(plainDek), cipher.final()]);
    const tag = cipher.getAuthTag();
    return Buffer.concat([iv, ct, tag]);
  }

  async unwrapKey(wrapped: Buffer): Promise<Buffer> {
    const iv = wrapped.subarray(0, 12);
    const tag = wrapped.subarray(wrapped.length - 16);
    const ct = wrapped.subarray(12, wrapped.length - 16);
    const decipher = createDecipheriv('aes-256-gcm', this.localKey, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(ct), decipher.final()]);
  }
}

// GcpKmsProvider: wraps/unwraps DEKs using Google Cloud KMS.
// Used when KMS_PROVIDER=gcp (staging / prod).
export class GcpKmsProvider implements KmsProvider {
  private client: import('@google-cloud/kms').KeyManagementServiceClient | null = null;
  private readonly keyName: string;

  constructor(keyName: string) {
    this.keyName = keyName;
  }

  private async getClient() {
    if (!this.client) {
      const { KeyManagementServiceClient } = await import('@google-cloud/kms');
      this.client = new KeyManagementServiceClient();
    }
    return this.client;
  }

  async wrapKey(plainDek: Buffer): Promise<Buffer> {
    const client = await this.getClient();
    const [result] = await client.encrypt({
      name: this.keyName,
      plaintext: plainDek,
    });
    return Buffer.from(result.ciphertext as Uint8Array);
  }

  async unwrapKey(wrapped: Buffer): Promise<Buffer> {
    const client = await this.getClient();
    const [result] = await client.decrypt({
      name: this.keyName,
      ciphertext: wrapped,
    });
    return Buffer.from(result.plaintext as Uint8Array);
  }
}
```

- [ ] **Run tests — expect pass**

```bash
pnpm test
```
Expected: all 6 tests pass (4 cache + 2 provider).

- [ ] **Commit**

```bash
git add src/utils/security/kmsProviders.ts src/utils/security/__tests__/crypto.test.ts
git commit -m "feat: add LocalKmsProvider + GcpKmsProvider"
```

---

## Task 5: AES-256-GCM encrypt / decrypt with version byte

**Files:**
- Create: `src/utils/security/crypto.ts` (initial)

- [ ] **Write failing tests** (add to `__tests__/crypto.test.ts`)

```typescript
import { encryptBuffer, decryptBuffer } from '../crypto';

describe('encryptBuffer / decryptBuffer', () => {
  const dek = Buffer.from('d'.repeat(32));

  it('round-trips plaintext through encrypt then decrypt', async () => {
    const plain = 'hello, world';
    const ct = await encryptBuffer(plain, dek, 1);
    const result = await decryptBuffer(ct, (v) => v === 1 ? Promise.resolve(dek) : Promise.reject(new Error('unknown version')));
    expect(result).toBe(plain);
  });

  it('ciphertext starts with version byte 1', async () => {
    const ct = await encryptBuffer('test', dek, 1);
    expect(ct[0]).toBe(1);
  });

  it('ciphertext is different each call (random IV)', async () => {
    const ct1 = await encryptBuffer('same', dek, 1);
    const ct2 = await encryptBuffer('same', dek, 1);
    expect(ct1).not.toEqual(ct2);
  });

  it('throws on authTag mismatch (tampered ciphertext)', async () => {
    const ct = await encryptBuffer('secret', dek, 1);
    ct[ct.length - 1] ^= 0xff; // flip last byte of authTag
    await expect(
      decryptBuffer(ct, () => Promise.resolve(dek))
    ).rejects.toThrow();
  });
});
```

- [ ] **Run test — expect failure**

```bash
pnpm test
```
Expected: `Cannot find module '../crypto'`

- [ ] **Implement encrypt/decrypt internals**

Create `src/utils/security/crypto.ts`:

```typescript
import { createCipheriv, createDecipheriv, randomBytes, createHmac } from 'crypto';
import prisma from '../../db/prismaClient';
import { dekCache } from './dekCache';
import { LocalKmsProvider, GcpKmsProvider } from './kmsProviders';
import type { KmsProvider } from './types';
import { AppError } from '../errors/AppError';

// ── Provider factory ───────────────────────────────────────────────────────

function buildProvider(): KmsProvider {
  const provider = process.env.KMS_PROVIDER ?? 'local';
  if (provider === 'gcp') {
    const keyName = [
      'projects', process.env.GCP_KMS_PROJECT,
      'locations', process.env.GCP_KMS_LOCATION,
      'keyRings', process.env.GCP_KMS_KEYRING,
      'cryptoKeys', process.env.GCP_KMS_KEY_NAME,
    ].join('/');
    return new GcpKmsProvider(keyName);
  }
  const hex = process.env.LOCAL_KMS_KEY ?? '';
  if (hex.length !== 64) throw new Error('LOCAL_KMS_KEY must be 64 hex chars (32 bytes)');
  return new LocalKmsProvider(Buffer.from(hex, 'hex'));
}

const kmsProvider = buildProvider();

// ── Low-level AES-256-GCM (exported for tests) ────────────────────────────

// Format: version(1) | iv(12) | ciphertext | authTag(16)
export async function encryptBuffer(plaintext: string, dek: Buffer, version: number): Promise<Buffer> {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', dek, iv);
  const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  const versionByte = Buffer.alloc(1);
  versionByte[0] = version;
  return Buffer.concat([versionByte, iv, ct, tag]);
}

export async function decryptBuffer(
  ciphertext: Buffer,
  getDekByVersion: (version: number) => Promise<Buffer>,
): Promise<string> {
  const version = ciphertext[0];
  const iv = ciphertext.subarray(1, 13);
  const tag = ciphertext.subarray(ciphertext.length - 16);
  const ct = ciphertext.subarray(13, ciphertext.length - 16);
  const dek = await getDekByVersion(version);
  const decipher = createDecipheriv('aes-256-gcm', dek, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ct), decipher.final()]).toString('utf8');
}

// ── DEK management ────────────────────────────────────────────────────────

async function getDek(userId: string, version: number): Promise<Buffer> {
  const cached = dekCache.get(userId, version);
  if (cached) return cached;

  // Fetch the wrapped DEK for this version
  let wrappedDek: Buffer | null = null;

  if (version === await getCurrentVersion(userId)) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { wrappedDek: true, dekVersion: true },
    });
    if (!user?.wrappedDek) throw new AppError('DEK not found for user', 500);
    wrappedDek = user.wrappedDek;
  } else {
    const history = await prisma.userDekHistory.findUnique({
      where: { userId_version: { userId, version } },
      select: { wrappedDek: true },
    });
    if (!history) throw new AppError(`DEK version ${version} not found for user`, 500);
    wrappedDek = history.wrappedDek;
  }

  const dek = await kmsProvider.unwrapKey(wrappedDek);
  dekCache.set(userId, version, dek);
  return dek;
}

async function getCurrentVersion(userId: string): Promise<number> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { dekVersion: true },
  });
  return user?.dekVersion ?? 1;
}

// ── Public API ─────────────────────────────────────────────────────────────

export async function encrypt(plaintext: string, userId: string): Promise<Buffer> {
  const version = await getCurrentVersion(userId);
  const dek = await getDek(userId, version);
  return encryptBuffer(plaintext, dek, version);
}

export async function decrypt(ciphertext: Buffer, userId: string): Promise<string> {
  return decryptBuffer(ciphertext, (v) => getDek(userId, v));
}

// HMAC-SHA256 of normalized value — for blind index columns.
// Synchronous. Uses HMAC_BLIND_INDEX_KEY from env (not the DEK).
export function blindIndex(value: string): Buffer {
  const key = process.env.HMAC_BLIND_INDEX_KEY ?? '';
  if (!key) throw new AppError('HMAC_BLIND_INDEX_KEY is not set', 500);
  const normalized = value.trim().toLowerCase();
  return Buffer.from(createHmac('sha256', key).update(normalized).digest());
}

// Called once at user registration — generates + stores the user's first DEK.
export async function initDekForNewUser(userId: string): Promise<void> {
  const plainDek = randomBytes(32);
  const wrappedDek = await kmsProvider.wrapKey(plainDek);
  await prisma.user.update({
    where: { id: userId },
    data: { wrappedDek, dekVersion: 1 },
  });
  dekCache.set(userId, 1, plainDek);
}
```

- [ ] **Run tests — expect pass**

```bash
pnpm test
```
Expected: all 10 tests pass.

- [ ] **Commit**

```bash
git add src/utils/security/crypto.ts src/utils/security/__tests__/crypto.test.ts
git commit -m "feat: implement encrypt/decrypt/blindIndex/initDekForNewUser in cryptoService"
```

---

## Task 6: Environment variables

**Files:**
- Modify: `src/config/environment.ts`

- [ ] **Add crypto env vars to the Zod schema**

In `src/config/environment.ts`, add inside the `envSchema` object (after the existing `REDIS_URL` entry):

```typescript
  // Encryption at Rest (Phase 5)
  KMS_PROVIDER: z.enum(['local', 'gcp']).default('local'),
  LOCAL_KMS_KEY: z.string().length(64).optional(), // 32 bytes as hex — required when KMS_PROVIDER=local
  HMAC_BLIND_INDEX_KEY: z.string().min(32).optional(), // required when encryption is enabled
  GCP_KMS_PROJECT: z.string().optional(),
  GCP_KMS_LOCATION: z.string().optional(),
  GCP_KMS_KEYRING: z.string().optional(),
  GCP_KMS_KEY_NAME: z.string().optional(),
  ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN: z
    .string()
    .transform(v => v === 'true')
    .default('false'),
```

- [ ] **Add to `.env.example`** (in `crelyzor-backend/`)

Append:
```bash
# Encryption at Rest (Phase 5)
KMS_PROVIDER=local
LOCAL_KMS_KEY=  # generate: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
HMAC_BLIND_INDEX_KEY=  # generate: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
GCP_KMS_PROJECT=
GCP_KMS_LOCATION=
GCP_KMS_KEYRING=
GCP_KMS_KEY_NAME=
ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN=false
```

- [ ] **Generate local keys for your `.env`**

```bash
node -e "console.log('LOCAL_KMS_KEY=' + require('crypto').randomBytes(32).toString('hex'))"
node -e "console.log('HMAC_BLIND_INDEX_KEY=' + require('crypto').randomBytes(32).toString('hex'))"
```

Copy the output into `crelyzor-backend/.env`.

- [ ] **Commit**

```bash
git add src/config/environment.ts .env.example
git commit -m "feat: add encryption env vars to environment schema"
```

---

## Task 7: Schema migration 1 — add all encryption columns

**Files:**
- Modify: `prisma/schema.prisma`

- [ ] **Add `wrappedDek`, `dekVersion`, and `UserDekHistory` to schema**

In `prisma/schema.prisma`, on the `User` model add (after existing fields):
```prisma
  wrappedDek  Bytes?
  dekVersion  Int     @default(1)
  dekHistory  UserDekHistory[]
```

Add the new model after the `User` model:
```prisma
model UserDekHistory {
  id         String   @id @default(uuid()) @db.Uuid
  userId     String   @db.Uuid
  version    Int
  wrappedDek Bytes
  createdAt  DateTime @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, version])
  @@index([userId])
}
```

- [ ] **Add shadow `_encrypted` columns to all in-scope models**

Add to each model (these are additive nullable columns — no data loss):

On `MeetingTranscript`: `fullText_encrypted Bytes?`
On `TranscriptSegment`: `text_encrypted Bytes?`
On `MeetingNote`: `content_encrypted Bytes?`
On `MeetingAISummary`: `summary_encrypted Bytes?` and `keyPoints_encrypted Bytes[] @default([])`
On `MeetingAIContent`: `content_encrypted Bytes?`
On `AskAIMessage`: `content_encrypted Bytes?`
On `Task`: `title_encrypted Bytes?` and `description_encrypted Bytes?`

- [ ] **Add shadow columns + blind index columns to PII models**

On `CardContact`:
```prisma
  name_encrypted    Bytes?
  email_encrypted   Bytes?
  email_bidx        Bytes?
  phone_encrypted   Bytes?
  phone_bidx        Bytes?
  company_encrypted Bytes?
  note_encrypted    Bytes?
```
Also add indexes (alongside existing ones):
```prisma
  @@index([email_bidx])
  @@index([phone_bidx])
```

On `Booking`:
```prisma
  guestName_encrypted  Bytes?
  guestEmail_encrypted Bytes?
  guestEmail_bidx      Bytes?
  guestNote_encrypted  Bytes?
```
Add: `@@index([guestEmail_bidx])`

On `MeetingParticipant`:
```prisma
  guestEmail_encrypted Bytes?
  guestEmail_bidx      Bytes?
```
Add: `@@index([guestEmail_bidx])`

- [ ] **Run migration**

```bash
cd crelyzor-backend
pnpm db:migrate
```

When prompted for migration name: `add_encryption_columns`

Expected: migration runs without error, DB updated.

- [ ] **Verify with Prisma Studio**

```bash
pnpm db:studio
```

Check that `User` has `wrappedDek` and `dekVersion`. Check that `CardContact` has `email_encrypted` and `email_bidx`. Close Studio.

- [ ] **Commit**

```bash
git add prisma/schema.prisma prisma/migrations/
git commit -m "feat(schema): add encryption shadow columns, blind indexes, and UserDekHistory"
```

---

## Task 8: Wire DEK init into user registration

**Files:**
- Modify: `src/controllers/googleController.ts`

- [ ] **Import initDekForNewUser**

At the top of `src/controllers/googleController.ts`, add:
```typescript
import { initDekForNewUser } from '../utils/security/crypto';
```

- [ ] **Call initDekForNewUser after user creation**

Find the `if (isNewUser)` block (around line 196). It currently creates `userSettings`, a default schedule, and availability slots. Add `initDekForNewUser` as the first call inside that block:

```typescript
if (isNewUser) {
  await initDekForNewUser(u.id);   // ← add this line first

  await tx.userSettings.create({ data: { userId: u.id } });
  // ... rest of existing isNewUser block unchanged
}
```

> Note: `initDekForNewUser` calls `prisma.user.update` internally, which is fine inside a transaction because it uses the global prisma client — but since the user was just created in the same `tx`, we need to pass `tx` to avoid a deadlock. Update `initDekForNewUser` to accept an optional `tx` parameter:

- [ ] **Update `initDekForNewUser` to accept optional transaction client**

In `src/utils/security/crypto.ts`, change the signature:

```typescript
import type { Prisma } from '@prisma/client';

export async function initDekForNewUser(
  userId: string,
  tx?: Prisma.TransactionClient,
): Promise<void> {
  const plainDek = randomBytes(32);
  const wrappedDek = await kmsProvider.wrapKey(plainDek);
  const db = tx ?? prisma;
  await db.user.update({
    where: { id: userId },
    data: { wrappedDek, dekVersion: 1 },
  });
  dekCache.set(userId, 1, plainDek);
}
```

- [ ] **Update the call in googleController.ts to pass `tx`**

```typescript
if (isNewUser) {
  await initDekForNewUser(u.id, tx);
  // ... rest unchanged
}
```

- [ ] **Commit**

```bash
git add src/controllers/googleController.ts src/utils/security/crypto.ts
git commit -m "feat: generate DEK for new users on Google OAuth registration"
```

---

## Task 9: Service patches — Transcription

**Files:**
- Modify: `src/services/transcription/transcriptionService.ts`

This is the most critical service — it runs inside the Bull worker and encrypts the transcript on save.

- [ ] **Import crypto functions**

At the top of `src/services/transcription/transcriptionService.ts`, add:
```typescript
import { encrypt, decrypt } from '../../utils/security/crypto';
import { env } from '../../config/environment';
```

- [ ] **Encrypt on write — transcript create (inside transaction)**

Find the `tx.meetingTranscript.create` call (around line 153). It writes `fullText`. Change it to dual-write:

```typescript
const fullText = alternatives.transcript || '';
const fullText_encrypted = fullText
  ? await encrypt(fullText, recording.meeting.createdById)
  : null;

const created = await tx.meetingTranscript.create({
  data: {
    meetingId: recording.meetingId,
    fullText,                    // keep plaintext during transition
    fullText_encrypted,          // write encrypted shadow column
    segments: {
      create: await Promise.all(segments.map(async (seg) => {
        const text = seg.text ?? '';
        return {
          speaker: seg.speaker,
          startTime: seg.startTime,
          endTime: seg.endTime,
          text,
          text_encrypted: text
            ? await encrypt(text, recording.meeting.createdById)
            : null,
        };
      })),
    },
  },
});
```

- [ ] **Decrypt on read — getTranscript**

Find the `prisma.meetingTranscript.findFirst` in the read path. After fetching, add a decrypt step:

```typescript
const transcript = await prisma.meetingTranscript.findFirst({
  where: { meetingId, isDeleted: false },
  select: {
    id: true, fullText: true, fullText_encrypted: true,
    createdAt: true, updatedAt: true,
    segments: {
      select: {
        id: true, speaker: true, startTime: true, endTime: true,
        text: true, text_encrypted: true,
      },
    },
  },
});

if (!transcript) return null;

// Decrypt if encrypted column is available and flag is on
const fullText = (env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN && transcript.fullText_encrypted)
  ? await decrypt(transcript.fullText_encrypted, userId)
  : transcript.fullText;

const segments = await Promise.all(transcript.segments.map(async (seg) => ({
  ...seg,
  text: (env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN && seg.text_encrypted)
    ? await decrypt(seg.text_encrypted, userId)
    : seg.text,
})));

return { ...transcript, fullText, segments };
```

- [ ] **Commit**

```bash
git add src/services/transcription/transcriptionService.ts
git commit -m "feat: dual-write encrypted transcript + segments; decrypt on read behind flag"
```

---

## Task 10: Service patches — AI summary

**Files:**
- Modify: `src/services/ai/aiService.ts`

- [ ] **Import crypto functions**

```typescript
import { encrypt, decrypt } from '../../utils/security/crypto';
import { env } from '../../config/environment';
```

- [ ] **Encrypt summary + keyPoints on write**

Find where `meetingAISummary.upsert` or `create` writes `summary` and `keyPoints`. Add dual-write:

```typescript
const summary_encrypted = await encrypt(summaryText, userId);
const keyPoints_encrypted = await Promise.all(keyPointsArray.map(kp => encrypt(kp, userId)));

await prisma.meetingAISummary.upsert({
  where: { meetingId },
  update: {
    summary: summaryText,
    summary_encrypted,
    keyPoints: keyPointsArray,
    keyPoints_encrypted,
  },
  create: {
    meetingId,
    userId,
    summary: summaryText,
    summary_encrypted,
    keyPoints: keyPointsArray,
    keyPoints_encrypted,
  },
});
```

- [ ] **Decrypt on read before passing to AI**

Wherever `meetingAISummary` is fetched and its `summary` is passed to OpenAI/Gemini, add decrypt:

```typescript
const summaryText = (env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN && summary.summary_encrypted)
  ? await decrypt(summary.summary_encrypted, userId)
  : summary.summary;
```

- [ ] **Commit**

```bash
git add src/services/ai/aiService.ts
git commit -m "feat: dual-write encrypted AI summary and keyPoints; decrypt before AI calls"
```

---

## Task 11: Service patches — Ask AI messages

**Files:**
- Modify: `src/services/ai/askAIConversationService.ts`

- [ ] **Import crypto functions**

```typescript
import { encrypt, decrypt } from '../../utils/security/crypto';
import { env } from '../../config/environment';
```

- [ ] **Encrypt on write — saveMessage**

Find the `prisma.askAIMessage.create` call (around line 48):

```typescript
export const saveMessage = async (
  conversationId: string,
  role: string,
  content: string,
  userId: string,
): Promise<void> => {
  const content_encrypted = await encrypt(content, userId);
  await prisma.askAIMessage.create({
    data: {
      conversationId,
      role,
      content,                // keep plaintext during transition
      content_encrypted,
    },
  });
};
```

- [ ] **Decrypt on read — getMessages**

Find the messages query (around line 26):

```typescript
export const getMessages = async (
  conversationId: string,
  userId: string,
): Promise<{ role: string; content: string; createdAt: Date }[]> => {
  const rows = await prisma.askAIMessage.findMany({
    where: { conversationId },
    select: { role: true, content: true, content_encrypted: true, createdAt: true },
    orderBy: { createdAt: 'asc' },
  });

  return Promise.all(rows.map(async (row) => ({
    role: row.role,
    createdAt: row.createdAt,
    content: (env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN && row.content_encrypted)
      ? await decrypt(row.content_encrypted, userId)
      : row.content,
  })));
};
```

> Note: `userId` is not currently a parameter of `getMessages` — add it to the signature and update all callers.

- [ ] **Commit**

```bash
git add src/services/ai/askAIConversationService.ts
git commit -m "feat: dual-write encrypted Ask AI messages; decrypt on read"
```

---

## Task 12: Service patches — Tasks

**Files:**
- Modify: `src/controllers/taskController.ts`

Tasks are managed directly in the controller. There are multiple `prisma.task.create` and `prisma.task.update` call sites.

- [ ] **Import crypto functions**

```typescript
import { encrypt, decrypt } from '../utils/security/crypto';
import { env } from '../config/environment';
```

- [ ] **Helper function — add at top of controller file (below imports)**

```typescript
async function encryptTaskFields(
  data: { title?: string; description?: string | null },
  userId: string,
): Promise<{ title_encrypted?: Buffer; description_encrypted?: Buffer | null }> {
  const result: { title_encrypted?: Buffer; description_encrypted?: Buffer | null } = {};
  if (data.title !== undefined) {
    result.title_encrypted = await encrypt(data.title, userId);
  }
  if (data.description !== undefined) {
    result.description_encrypted = data.description
      ? await encrypt(data.description, userId)
      : null;
  }
  return result;
}

async function decryptTaskFields(
  task: { title: string; description?: string | null; title_encrypted?: Buffer | null; description_encrypted?: Buffer | null },
  userId: string,
): Promise<{ title: string; description?: string | null }> {
  return {
    title: (env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN && task.title_encrypted)
      ? await decrypt(task.title_encrypted, userId)
      : task.title,
    description: (env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN && task.description_encrypted)
      ? await decrypt(task.description_encrypted, userId)
      : task.description ?? null,
  };
}
```

- [ ] **Update every `prisma.task.create` call to dual-write**

Each `prisma.task.create({ data: { ..., title, description } })` becomes:

```typescript
const encFields = await encryptTaskFields({ title, description }, userId);
await prisma.task.create({
  data: { ..., title, description, ...encFields },
});
```

(Apply this pattern to all create/update call sites in the file — there are approximately 6.)

- [ ] **Update read paths to decrypt**

Wherever a task is returned to the client, pipe it through `decryptTaskFields`:

```typescript
const plain = await decryptTaskFields(task, userId);
return { ...task, ...plain };
```

For list endpoints returning multiple tasks, map over the array:
```typescript
const plainTasks = await Promise.all(tasks.map(t => decryptTaskFields(t, userId)));
return plainTasks.map((plain, i) => ({ ...tasks[i], ...plain }));
```

- [ ] **Commit**

```bash
git add src/controllers/taskController.ts
git commit -m "feat: dual-write encrypted task title/description; decrypt on read"
```

---

## Task 13: Service patches — Card contacts

**Files:**
- Modify: `src/services/cardService.ts`

- [ ] **Import crypto functions**

```typescript
import { encrypt, decrypt, blindIndex } from './security/crypto';
// adjust relative path to: '../../utils/security/crypto' or similar based on location
import { env } from '../config/environment';
```

(Actual relative path from `src/services/cardService.ts` → `src/utils/security/crypto.ts` is `'../utils/security/crypto'`)

- [ ] **Helper — encrypt ContactCard fields**

Add near the top of the service:

```typescript
async function encryptContact(
  data: {
    name?: string;
    email?: string | null;
    phone?: string | null;
    company?: string | null;
    note?: string | null;
  },
  userId: string,
) {
  const result: Record<string, Buffer | null | undefined> = {};
  if (data.name !== undefined)
    result.name_encrypted = await encrypt(data.name, userId);
  if (data.email !== undefined) {
    result.email_encrypted = data.email ? await encrypt(data.email, userId) : null;
    result.email_bidx = data.email ? blindIndex(data.email) : null;
  }
  if (data.phone !== undefined) {
    result.phone_encrypted = data.phone ? await encrypt(data.phone, userId) : null;
    result.phone_bidx = data.phone ? blindIndex(data.phone) : null;
  }
  if (data.company !== undefined)
    result.company_encrypted = data.company ? await encrypt(data.company, userId) : null;
  if (data.note !== undefined)
    result.note_encrypted = data.note ? await encrypt(data.note, userId) : null;
  return result;
}

async function decryptContact(
  contact: {
    name: string; email?: string | null; phone?: string | null;
    company?: string | null; note?: string | null;
    name_encrypted?: Buffer | null; email_encrypted?: Buffer | null;
    phone_encrypted?: Buffer | null; company_encrypted?: Buffer | null;
    note_encrypted?: Buffer | null;
  },
  userId: string,
) {
  if (!env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN) return contact;
  return {
    ...contact,
    name: contact.name_encrypted ? await decrypt(contact.name_encrypted, userId) : contact.name,
    email: contact.email_encrypted ? await decrypt(contact.email_encrypted, userId) : contact.email,
    phone: contact.phone_encrypted ? await decrypt(contact.phone_encrypted, userId) : contact.phone,
    company: contact.company_encrypted ? await decrypt(contact.company_encrypted, userId) : contact.company,
    note: contact.note_encrypted ? await decrypt(contact.note_encrypted, userId) : contact.note,
  };
}
```

- [ ] **Update `prisma.cardContact.create` (around line 534)**

```typescript
const encFields = await encryptContact({ name, email, phone, company, note }, userId);
return prisma.cardContact.create({
  data: { cardId, userId, name, email, phone, company, note, ...encFields, scannedAt, savedByScanner },
});
```

- [ ] **Update `prisma.cardContact.update` (around line 682)**

Apply the same pattern — dual-write all encrypted fields + blind indexes.

- [ ] **Update `prisma.cardContact.createMany` (around line 886)**

Map over the data array to add encrypted fields before calling createMany:
```typescript
const encryptedData = await Promise.all(
  toCreate.map(async (c) => ({
    ...c,
    ...(await encryptContact({ name: c.name, email: c.email, phone: c.phone, company: c.company, note: c.note }, userId)),
  }))
);
await tx.cardContact.createMany({ data: encryptedData });
```

- [ ] **Update email/phone lookups to use blind index**

Any `where: { email: value }` query becomes `where: { email_bidx: blindIndex(value) }`.

- [ ] **Decrypt all read paths**

For every `findFirst` / `findMany` returning contacts, pipe results through `decryptContact`.

- [ ] **Commit**

```bash
git add src/services/cardService.ts
git commit -m "feat: dual-write encrypted CardContact fields + blind indexes; decrypt on read"
```

---

## Task 14: Service patches — Booking + MeetingParticipant

**Files:**
- Modify: `src/services/scheduling/bookingService.ts`
- Modify: `src/services/meetings/meetingService.ts`

- [ ] **Import crypto in bookingService.ts**

```typescript
import { encrypt, decrypt, blindIndex } from '../../utils/security/crypto';
import { env } from '../../config/environment';
```

- [ ] **Encrypt Booking PII on create (around line 304)**

Find the `booking.create` call inside the transaction. Change to dual-write:

```typescript
const [guestName_encrypted, guestEmail_encrypted, guestNote_encrypted] = await Promise.all([
  encrypt(data.guestName, hostUserId),
  encrypt(data.guestEmail, hostUserId),
  data.guestNote ? encrypt(data.guestNote, hostUserId) : Promise.resolve(null),
]);
const guestEmail_bidx = blindIndex(data.guestEmail);

await tx.booking.create({
  data: {
    ...data,
    guestName_encrypted,
    guestEmail_encrypted,
    guestEmail_bidx,
    guestNote_encrypted,
    // plaintext fields unchanged (dual-write)
  },
});
```

- [ ] **Decrypt Booking on read**

For any `booking.findFirst` or `booking.findMany` returning guest PII fields, add decrypt step:

```typescript
async function decryptBooking(booking: any, userId: string) {
  if (!env.ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN) return booking;
  return {
    ...booking,
    guestName: booking.guestName_encrypted
      ? await decrypt(booking.guestName_encrypted, userId)
      : booking.guestName,
    guestEmail: booking.guestEmail_encrypted
      ? await decrypt(booking.guestEmail_encrypted, userId)
      : booking.guestEmail,
    guestNote: booking.guestNote_encrypted
      ? await decrypt(booking.guestNote_encrypted, userId)
      : booking.guestNote,
  };
}
```

- [ ] **Update guestEmail lookup to use blind index**

The `getBookingByGuestEmail` call (around line 87) becomes:
```typescript
where: { guestEmail_bidx: blindIndex(guestEmail), userId, isDeleted: false }
```

- [ ] **Commit**

```bash
git add src/services/scheduling/bookingService.ts
git commit -m "feat: dual-write encrypted Booking PII + blind index; decrypt on read"
```

- [ ] **Encrypt MeetingParticipant.guestEmail in meetingService.ts**

Find any `meetingParticipant.create` or `upsert` that writes `guestEmail`. Add:

```typescript
const guestEmail_encrypted = guestEmail ? await encrypt(guestEmail, userId) : null;
const guestEmail_bidx = guestEmail ? blindIndex(guestEmail) : null;

// include in data: { guestEmail, guestEmail_encrypted, guestEmail_bidx }
```

For reads, decrypt the same way as Booking above.

- [ ] **Commit**

```bash
git add src/services/meetings/meetingService.ts
git commit -m "feat: dual-write encrypted MeetingParticipant.guestEmail + blind index"
```

---

## Task 15: Backfill script

**Files:**
- Create: `src/scripts/backfill-encryption.ts`

- [ ] **Write the backfill script**

Create `src/scripts/backfill-encryption.ts`:

```typescript
import prisma from '../db/prismaClient';
import { encrypt, blindIndex, initDekForNewUser } from '../utils/security/crypto';

const BATCH_SIZE = 500;
const DRY_RUN = process.argv.includes('--dry-run');

async function log(msg: string) {
  console.log(`[backfill] ${msg}`);
}

// Phase 1: Generate DEKs for users who don't have one
async function backfillDeks() {
  log('Phase 1: DEK generation');
  let offset = 0;
  while (true) {
    const users = await prisma.user.findMany({
      where: { wrappedDek: null },
      select: { id: true },
      take: BATCH_SIZE,
      skip: offset,
    });
    if (users.length === 0) break;
    for (const user of users) {
      if (!DRY_RUN) await initDekForNewUser(user.id);
      else log(`  dry-run: would generate DEK for user ${user.id}`);
    }
    log(`  processed ${offset + users.length} users`);
    offset += users.length;
  }
  log('Phase 1 complete');
}

// Phase 2: Encrypt each in-scope table
async function backfillTable<T extends { id: string }>(
  label: string,
  fetcher: (skip: number) => Promise<T[]>,
  encryptor: (row: T) => Promise<Record<string, unknown>>,
  writer: (id: string, data: Record<string, unknown>) => Promise<void>,
) {
  log(`Phase 2: encrypting ${label}`);
  let skip = 0;
  let total = 0;
  while (true) {
    const rows = await fetcher(skip);
    if (rows.length === 0) break;
    for (const row of rows) {
      const data = await encryptor(row);
      if (!DRY_RUN) await writer(row.id, data);
    }
    total += rows.length;
    log(`  ${label}: ${total} rows processed`);
    skip += rows.length;
  }
}

async function backfillMeetingTranscripts() {
  await backfillTable(
    'MeetingTranscript',
    (skip) => prisma.meetingTranscript.findMany({
      where: { fullText_encrypted: null },
      select: { id: true, fullText: true, meeting: { select: { createdById: true } } },
      take: BATCH_SIZE, skip,
    }),
    async (row) => ({
      fullText_encrypted: row.fullText
        ? await encrypt(row.fullText, row.meeting.createdById)
        : null,
    }),
    (id, data) => prisma.meetingTranscript.update({ where: { id }, data }),
  );
}

async function backfillTranscriptSegments() {
  await backfillTable(
    'TranscriptSegment',
    (skip) => prisma.transcriptSegment.findMany({
      where: { text_encrypted: null },
      select: {
        id: true, text: true,
        transcript: { select: { meeting: { select: { createdById: true } } } },
      },
      take: BATCH_SIZE, skip,
    }),
    async (row) => ({
      text_encrypted: row.text
        ? await encrypt(row.text, row.transcript.meeting.createdById)
        : null,
    }),
    (id, data) => prisma.transcriptSegment.update({ where: { id }, data }),
  );
}

async function backfillAskAIMessages() {
  await backfillTable(
    'AskAIMessage',
    (skip) => prisma.askAIMessage.findMany({
      where: { content_encrypted: null },
      select: {
        id: true, content: true,
        conversation: { select: { userId: true } },
      },
      take: BATCH_SIZE, skip,
    }),
    async (row) => ({
      content_encrypted: await encrypt(row.content, row.conversation.userId),
    }),
    (id, data) => prisma.askAIMessage.update({ where: { id }, data }),
  );
}

async function backfillTasks() {
  await backfillTable(
    'Task',
    (skip) => prisma.task.findMany({
      where: { title_encrypted: null },
      select: { id: true, title: true, description: true, userId: true },
      take: BATCH_SIZE, skip,
    }),
    async (row) => ({
      title_encrypted: await encrypt(row.title, row.userId),
      description_encrypted: row.description
        ? await encrypt(row.description, row.userId)
        : null,
    }),
    (id, data) => prisma.task.update({ where: { id }, data }),
  );
}

async function backfillCardContacts() {
  await backfillTable(
    'CardContact',
    (skip) => prisma.cardContact.findMany({
      where: { name_encrypted: null },
      select: { id: true, name: true, email: true, phone: true, company: true, note: true, userId: true },
      take: BATCH_SIZE, skip,
    }),
    async (row) => ({
      name_encrypted: await encrypt(row.name, row.userId),
      email_encrypted: row.email ? await encrypt(row.email, row.userId) : null,
      email_bidx: row.email ? blindIndex(row.email) : null,
      phone_encrypted: row.phone ? await encrypt(row.phone, row.userId) : null,
      phone_bidx: row.phone ? blindIndex(row.phone) : null,
      company_encrypted: row.company ? await encrypt(row.company, row.userId) : null,
      note_encrypted: row.note ? await encrypt(row.note, row.userId) : null,
    }),
    (id, data) => prisma.cardContact.update({ where: { id }, data }),
  );
}

async function backfillBookings() {
  await backfillTable(
    'Booking',
    (skip) => prisma.booking.findMany({
      where: { guestEmail_encrypted: null },
      select: {
        id: true, guestName: true, guestEmail: true, guestNote: true, userId: true,
      },
      take: BATCH_SIZE, skip,
    }),
    async (row) => ({
      guestName_encrypted: await encrypt(row.guestName, row.userId),
      guestEmail_encrypted: await encrypt(row.guestEmail, row.userId),
      guestEmail_bidx: blindIndex(row.guestEmail),
      guestNote_encrypted: row.guestNote ? await encrypt(row.guestNote, row.userId) : null,
    }),
    (id, data) => prisma.booking.update({ where: { id }, data }),
  );
}

async function main() {
  log(`Starting backfill${DRY_RUN ? ' (DRY RUN)' : ''}`);
  await backfillDeks();
  await backfillMeetingTranscripts();
  await backfillTranscriptSegments();
  await backfillAskAIMessages();
  await backfillTasks();
  await backfillCardContacts();
  await backfillBookings();
  log('Backfill complete');
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
```

- [ ] **Add script command to package.json**

```json
"backfill:encryption": "tsx src/scripts/backfill-encryption.ts",
"backfill:encryption:dry": "tsx src/scripts/backfill-encryption.ts --dry-run"
```

- [ ] **Run dry-run on dev DB**

```bash
pnpm backfill:encryption:dry
```

Expected: logs `dry-run: would generate DEK for user ...` for each user without a DEK. No DB writes.

- [ ] **Run actual backfill on dev DB**

```bash
pnpm backfill:encryption
```

Expected: all tables processed, no errors.

- [ ] **Verify a sample row was encrypted**

```bash
pnpm db:studio
```

Open `CardContact` table. Confirm `email_encrypted` is populated (shown as `<Buffer ...>`), `email_bidx` is populated.

- [ ] **Commit**

```bash
git add src/scripts/backfill-encryption.ts package.json
git commit -m "feat: add encryption backfill script with dry-run mode"
```

---

## Task 16: Cutover

This task is run after the backfill has been verified in staging and prod.

- [ ] **Run backfill in staging (dry-run first)**

```bash
KMS_PROVIDER=gcp pnpm backfill:encryption:dry
KMS_PROVIDER=gcp pnpm backfill:encryption
```

- [ ] **Verify sample records in staging**

Spot-check 5 random rows across `CardContact`, `Booking`, `AskAIMessage`. Confirm `_encrypted` columns are populated. Decrypt manually in a Node REPL to confirm round-trip.

```bash
node -e "
const { decrypt } = require('./dist/utils/security/crypto');
// paste a userId and fetch a row's encrypted column, then:
decrypt(Buffer.from(row.email_encrypted), userId).then(console.log);
"
```

- [ ] **Flip the feature flag in staging**

In staging `.env`:
```bash
ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN=true
```

Restart staging backend. Run smoke tests — booking lookup by email, Ask AI, transcript view.

- [ ] **After 7 days stable in staging — flip in production**

In production `.env`:
```bash
ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN=true
```

- [ ] **Commit**

No code change — this is an env var flip. Document the cutover date in `docs/dev-notes/phase-5-encryption.md`.

---

## Task 17: GCS CMEK (infrastructure only)

Run these commands in GCP Cloud Shell or locally with `gcloud` authenticated to the prod project.

- [ ] **Grant KMS access to Cloud Storage service agent**

```bash
PROJECT_NUMBER=$(gcloud projects describe $GCP_KMS_PROJECT --format='value(projectNumber)')

gcloud kms keys add-iam-policy-binding $GCP_KMS_KEY_NAME \
  --project=$GCP_KMS_PROJECT \
  --location=$GCP_KMS_LOCATION \
  --keyring=$GCP_KMS_KEYRING \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gs-project-accounts.iam.gserviceaccount.com" \
  --role=roles/cloudkms.cryptoKeyEncrypterDecrypter
```

Expected: `Updated IAM policy for key [...].`

- [ ] **Enable CMEK on recordings bucket**

```bash
KEY_RESOURCE="projects/$GCP_KMS_PROJECT/locations/$GCP_KMS_LOCATION/keyRings/$GCP_KMS_KEYRING/cryptoKeys/$GCP_KMS_KEY_NAME"
gsutil kms encryption -k $KEY_RESOURCE gs://$GCS_BUCKET_NAME
```

Expected: `Setting default KMS key for bucket gs://...`

- [ ] **Rewrite existing objects to pick up CMEK**

```bash
gsutil -m rewrite -k $KEY_RESOURCE gs://$GCS_BUCKET_NAME/**
```

Expected: `Rewriting gs://.../.../recording.webm` for each object. Takes minutes in background.

- [ ] **Verify**

```bash
gsutil kms encryption gs://$GCS_BUCKET_NAME
```

Expected: shows `Default encryption key: projects/.../cryptoKeys/...`

---

## Task 18: Schema migration 2 — drop plaintext columns

**Run only after 7+ days of stable production operation with `ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN=true`.**

- [ ] **Create migration 2 in schema.prisma**

For each encrypted column, remove the plaintext original and rename `_encrypted` → original name. Example on `MeetingTranscript`:

```prisma
// Before migration 2
fullText           String   @db.Text
fullText_encrypted Bytes?

// After migration 2
fullText           Bytes    // formerly fullText_encrypted, renamed
```

Apply this to all in-scope models. Also remove `email_bidx` → keep as `email_bidx` (the blind index stays permanently).

- [ ] **Run migration**

```bash
pnpm db:migrate
```

Migration name: `drop_plaintext_columns`

- [ ] **Update all service code** to remove references to the plaintext columns and `ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN` flag (reads now always come from the renamed column — no flag needed).

- [ ] **Remove the feature flag** from `environment.ts` and `.env`.

- [ ] **Final commit**

```bash
git add prisma/schema.prisma prisma/migrations/ src/
git commit -m "feat: migration 2 — drop plaintext columns, reads from encrypted columns only"
```

---

## Self-review

**Spec coverage check:**

| Spec requirement | Covered by task |
|---|---|
| AES-256-GCM encryption | Task 5 |
| Version byte in ciphertext | Task 5 |
| Per-user DEK, wrapped by KEK | Task 5 + 6 |
| LRU DEK cache (HTTP + workers) | Task 3 |
| GcpKmsProvider + LocalKmsProvider | Task 4 |
| Env var KMS_PROVIDER toggle | Task 4 + 6 |
| Blind indexes for email/phone | Task 5 (blindIndex), Task 13-14 (writes) |
| UserDekHistory for rotation | Task 7 (schema) |
| DEK init at registration | Task 8 |
| Transcription (worker) encryption | Task 9 |
| AI summary encryption | Task 10 |
| Ask AI message encryption | Task 11 |
| Task title/description | Task 12 |
| CardContact PII + blind indexes | Task 13 |
| Booking PII + blind indexes | Task 14 |
| MeetingParticipant.guestEmail | Task 14 |
| Backfill script | Task 15 |
| GCS CMEK | Task 17 |
| Schema migration 1 (additive) | Task 7 |
| Schema migration 2 (drop plaintext) | Task 18 |
| ENCRYPTION_READS_FROM_ENCRYPTED_COLUMN flag | Task 6 |
| MeetingNote.content encryption | Not yet tasked — add to Task 9 (same pattern as transcript, via `smaEditService.ts`) |

> **Gap found:** `MeetingNote.content` and `MeetingAIContent.content` are in scope but not explicitly tasked. They follow the same pattern as Task 10. Apply `encrypt` on write / `decrypt` on read in `smaEditService.ts` for notes, and in `aiService.ts` for AI content generation results.
