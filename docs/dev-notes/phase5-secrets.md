# Phase 5 — Secrets & KMS Setup

Per-env reference for the encryption-at-rest secrets and the one-time GCP KMS
provisioning needed for staging and prod. Pair with the migration runbook in
`crelyzor-backend/prisma/migrations/20260522000001_phase5_encryption_swap/README.md`.

---

## The three secrets

| Var | Purpose | Where it lives |
|---|---|---|
| `KMS_PROVIDER` | Which KEK provider wraps each user's DEK | `local` for dev, `gcp` for staging/prod |
| `LOCAL_KMS_KEY` | 256-bit master key — wraps DEKs when `KMS_PROVIDER=local` | dev `.env.local` only |
| `GCP_KMS_KEY_NAME` | Full resource path of the Cloud KMS key | staging/prod env secrets |
| `HMAC_BLIND_INDEX_KEY` | 256-bit HMAC key — used to compute deterministic blind indexes for searchable encrypted fields (email, phone) | all envs, fresh per env |

> `LOCAL_KMS_KEY` and `GCP_KMS_KEY_NAME` are mutually exclusive — set whichever
> matches `KMS_PROVIDER`. `HMAC_BLIND_INDEX_KEY` is always required.

---

## Per-env values

### Local

```env
KMS_PROVIDER=local
LOCAL_KMS_KEY=<openssl rand -hex 32>
HMAC_BLIND_INDEX_KEY=<openssl rand -hex 32>
```

Both keys can be regenerated freely — the local DB is disposable. Just remember
that resetting `HMAC_BLIND_INDEX_KEY` invalidates every blind index already in
that DB, so run `pnpm prisma migrate reset` afterwards.

### Staging / Prod

```env
KMS_PROVIDER=gcp
GCP_KMS_KEY_NAME=projects/<project>/locations/<region>/keyRings/<keyring>/cryptoKeys/<key>
HMAC_BLIND_INDEX_KEY=<openssl rand -hex 32 — fresh per env>
```

Don't set `LOCAL_KMS_KEY` in staging/prod — the local provider isn't loaded.

Authentication for the KMS client uses the same GCP service account already
configured for GCS (`GCS_KEY_FILE` / `GOOGLE_APPLICATION_CREDENTIALS`). That
service account needs one extra IAM role, granted below.

---

## One-time GCP KMS provisioning (per env)

Run once per environment (staging, prod). Pick a region close to your DB region.

```bash
PROJECT=<your-gcp-project>
REGION=asia-south1                 # or us-central1 etc — co-locate with DB
KEYRING=crelyzor-staging           # name per env: -staging vs -prod
KEY=user-dek-kek

# 1. Create the keyring + key
gcloud kms keyrings create $KEYRING \
  --location $REGION --project $PROJECT

gcloud kms keys create $KEY \
  --location $REGION --keyring $KEYRING --project $PROJECT \
  --purpose encryption \
  --default-algorithm google-symmetric-encryption \
  --rotation-period 365d --next-rotation-time +365d

# 2. Grant the backend's service account permission to wrap/unwrap DEKs
SA_EMAIL=$(jq -r '.client_email' "$GCS_KEY_FILE")   # or look it up in IAM console
gcloud kms keys add-iam-policy-binding $KEY \
  --location $REGION --keyring $KEYRING --project $PROJECT \
  --member "serviceAccount:$SA_EMAIL" \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter

# 3. Print the full resource name → paste into GCP_KMS_KEY_NAME
echo "projects/$PROJECT/locations/$REGION/keyRings/$KEYRING/cryptoKeys/$KEY"
```

Notes:
- The `roles/cloudkms.cryptoKeyEncrypterDecrypter` role is enough — the backend
  never lists/creates/destroys keys at runtime.
- `--rotation-period 365d` rotates the underlying KEK material yearly. Cloud
  KMS handles this transparently — `decrypt` continues to work against older
  versions, `encrypt` always uses the current version. No app changes required.

---

## Generating `HMAC_BLIND_INDEX_KEY`

```bash
openssl rand -hex 32   # 32 random bytes, hex-encoded — 64 chars total
```

Generate **independently per env**. The same input value produces the same
HMAC; sharing the key across envs lets one env's data forensically map to
another's.

---

## Storage

| Env | Where to keep the secret |
|---|---|
| Local | `.env.local` (gitignored) |
| Staging | GitHub Actions secrets → injected into `.env.staging` at deploy, OR Cloud Run secrets, OR GCP Secret Manager |
| Prod | Same as staging, separate project / vault scope |

Never commit any of these values to git. Rotate the secret-manager versions
before the first prod deploy if any value has ever been pasted into chat,
issues, PRs, or Slack.

---

## Rotation rules

### `LOCAL_KMS_KEY` (dev only)
- Rotate freely. Resetting the DB is the easiest path after rotation.

### `GCP_KMS_KEY_NAME`
- Rotates automatically via Cloud KMS's `--rotation-period`. No action needed.
- To force a rotation manually: `gcloud kms keys versions create --location ... --keyring ... --key ...`
- To migrate to a different key entirely: re-wrap each user's DEK with the new
  KEK in a one-off script. The DEK itself doesn't change — only the wrapper.

### `HMAC_BLIND_INDEX_KEY` — **DO NOT ROTATE CASUALLY**
- Every blind index column (`emailBidx`, `phoneBidx`, `guestEmailBidx`) was
  computed with the current key. Changing the key silently breaks every
  exact-match lookup against an encrypted field.
- If rotation is truly required (e.g. a leak), the recovery flow is:
  1. Add a new column `*_bidx_v2` BYTEA.
  2. Backfill it by reading-decrypting every encrypted source value, computing
     the new HMAC, writing into `*_bidx_v2`.
  3. Switch all query sites to use `*_bidx_v2`.
  4. Drop the old `*_bidx` column.
- For Crelyzor's current scale a Phase-5-style migration script is the right
  pattern (see `crelyzor-backend/src/scripts/phase5Backfill.ts`).

---

## Per-user DEK rotation

Distinct from the KEK above. Each user's DEK has a `dekVersion` byte in every
ciphertext. To rotate a single user's DEK:

1. Generate a fresh `rawDek = crypto.randomBytes(32)`.
2. `wrappedDek = kms.wrapKey(rawDek)`.
3. Insert a new `UserDekHistory` row with the next `version`.
4. Update `User.wrappedDek` + `User.dekVersion` to point at the new version.
5. Existing ciphertext continues to decrypt — the version byte routes to
   `UserDekHistory` automatically (`crypto.ts` → `getDek()`).
6. New writes use the new version. Re-encrypting old rows is optional and can
   be lazy.

The Phase 5 design supports this; no extra schema changes needed.

---

## Recovery / disaster scenarios

| Scenario | Impact | Recovery |
|---|---|---|
| Lost `HMAC_BLIND_INDEX_KEY` | Email/phone lookups by blind index stop working — encrypted values still decrypt fine | Generate new key + run a bidx re-compute script across all rows |
| Lost `LOCAL_KMS_KEY` (dev) | All DEKs unwrappable → all encrypted columns unreadable | Reset dev DB |
| Lost access to GCP KMS key (prod) | Same as above for prod | Restore the key from Cloud KMS (deleted keys can be recovered for 24h–30d depending on schedule); if permanently gone, restore DB from a backup taken before the loss |
| Compromised service account | Attacker could call decrypt on any user's DEK | Revoke service account, create a new KMS key, rotate every user's DEK (script that decrypts with old key + re-encrypts with new key). DB backup pre-incident is acceptable if the window is short. |

---

## See also

- `crelyzor-backend/CLAUDE.md` — Phase 5 do's and don'ts in the project rules
- `crelyzor-backend/src/utils/security/crypto.ts` — encryption layer
- `crelyzor-backend/src/utils/security/kmsProviders.ts` — local + GCP providers
- `crelyzor-backend/prisma/migrations/20260522000001_phase5_encryption_swap/README.md` — migration runbook
- `docs/internal/superpowers/specs/2026-05-16-encryption-at-rest-design.md` — full design spec
