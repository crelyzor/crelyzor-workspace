# Encryption at Rest — Dev Notes

Phase 5 implementation guide. Read before touching crypto, KMS, or any encrypted column.

---

## Key Model

```
KEK  — Cloud KMS symmetric key (never leaves HSM). One per environment.
DEK  — AES-256-GCM, 32 bytes random. One per user. Wrapped by KEK, stored in User.wrappedDek.
HMAC — App-level HMAC-SHA256 key for blind indexes. Stored in env var HMAC_BLIND_INDEX_KEY.
```

Ciphertext layout per encrypted field:
```
version(1 byte) | iv(12 random bytes) | ciphertext(variable) | authTag(16 bytes)
```
The version byte maps the ciphertext to the DEK version that encrypted it — enables key rotation without re-encrypting existing records.

---

## Environment Variables

| Var | Required | Notes |
|-----|----------|-------|
| `KMS_PROVIDER` | Yes | `local` (dev/test) or `gcp` (staging/prod) |
| `LOCAL_KMS_KEY` | When `KMS_PROVIDER=local` | 32-byte hex — `openssl rand -hex 32` |
| `GCP_KMS_KEY_NAME` | When `KMS_PROVIDER=gcp` | Full resource name: `projects/P/locations/L/keyRings/R/cryptoKeys/K` |
| `HMAC_BLIND_INDEX_KEY` | Always | 32-byte hex — `openssl rand -hex 32`. Never rotate after first deploy (stale indexes). |

---

## GCP KMS Setup (staging / prod)

### 1. Create keyring + key

```bash
# Set variables
PROJECT=your-gcp-project
REGION=asia-south1        # same region as Cloud SQL / app server

# Create keyring
gcloud kms keyrings create crelyzor-kek \
  --location=$REGION --project=$PROJECT

# Create symmetric encryption key (auto-rotation every 365 days)
gcloud kms keys create crelyzor-kek-v1 \
  --location=$REGION \
  --keyring=crelyzor-kek \
  --purpose=encryption \
  --rotation-period=365d \
  --next-rotation-time=$(date -u -d "+365 days" +%Y-%m-%dT%H:%M:%SZ) \
  --project=$PROJECT
```

### 2. Get full key resource name

```bash
gcloud kms keys describe crelyzor-kek-v1 \
  --location=$REGION --keyring=crelyzor-kek --project=$PROJECT
# Copy the "name:" field — this is GCP_KMS_KEY_NAME
```

### 3. IAM — bind backend service account

```bash
SERVICE_ACCOUNT=crelyzor-backend@${PROJECT}.iam.gserviceaccount.com

gcloud kms keys add-iam-policy-binding crelyzor-kek-v1 \
  --location=$REGION \
  --keyring=crelyzor-kek \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role=roles/cloudkms.cryptoKeyEncrypterDecrypter \
  --project=$PROJECT
```

Grant on the specific key only — never on the keyring or project level.

### 4. Key naming conventions

| Environment | Keyring | Key |
|-------------|---------|-----|
| staging | `crelyzor-kek-staging` | `crelyzor-kek-v1` |
| prod | `crelyzor-kek-prod` | `crelyzor-kek-v1` |

Use separate keyrings per environment so a staging key compromise does not reach prod.

---

## GCS CMEK Setup

Recordings bucket must use CMEK with the same KEK.

```bash
BUCKET=your-recordings-bucket
KEY_RESOURCE="projects/P/locations/L/keyRings/R/cryptoKeys/K"

# Grant Cloud Storage service agent access to the KMS key
GCS_SA=$(gsutil kms serviceaccount -p $PROJECT)
gcloud kms keys add-iam-policy-binding crelyzor-kek-v1 \
  --location=$REGION --keyring=crelyzor-kek \
  --member="serviceAccount:${GCS_SA}" \
  --role=roles/cloudkms.cryptoKeyEncrypterDecrypter \
  --project=$PROJECT

# Set CMEK as the default encryption key for the bucket
gsutil kms encryption -k "$KEY_RESOURCE" gs://$BUCKET

# Re-encrypt all existing recording objects (run off-hours, no downtime)
gsutil -m rewrite -k "$KEY_RESOURCE" gs://$BUCKET/**
```

---

## Local Dev Setup

No GCP credentials needed.

```bash
# Generate keys
echo "LOCAL_KMS_KEY=$(openssl rand -hex 32)"
echo "HMAC_BLIND_INDEX_KEY=$(openssl rand -hex 32)"
```

Add to `crelyzor-backend/.env`. `KMS_PROVIDER=local` is the default.

---

## Backfill (after migrating existing DB)

Run after the P1 schema migration deploys:

```bash
# Dry run first — reads + encrypts in memory, writes nothing
npx tsx src/scripts/phase5Backfill.ts --dry-run

# Apply for real (off-hours)
npx tsx src/scripts/phase5Backfill.ts
```

The script is idempotent — safe to re-run.

---

## Crypto-Shredding (account delete)

`authService.deactivateAccount` destroys:
1. All `UserDekHistory` rows for the user
2. `User.wrappedDek` set to `null`

Both happen inside the same `$transaction`. After commit, `evictDek(userId)` clears the in-process cache.

Result: every ciphertext stored for that user is permanently unrecoverable — including in old DB backups. GDPR deletion is satisfied as a free side effect.

---

## Observability

### Cloud Logging alert — anomalous KMS unwrap volume

Alert fires when KMS `CryptoKeyVersion.asymmetricDecrypt` or `decrypt` operations exceed 5× the hourly baseline, which can indicate credential theft or runaway decryption loop.

```
# Alert condition (Cloud Monitoring)
resource.type="cloudkms_key_version"
protoPayload.methodName="google.cloud.kms.v1.KeyManagementService.Decrypt"

# Threshold: 5× 7-day rolling hourly average
# Notification channel: oncall PagerDuty
```

---

## Disaster Recovery Runbook

### Scenario 1 — KMS key accidentally destroyed

GCP KMS key destruction has a **30-day scheduled deletion window** by default. Keys in the scheduled-deletion state cannot be used for encryption but can still be restored.

```bash
# Restore a key scheduled for deletion (within 30-day window)
gcloud kms keys versions restore KEY_VERSION \
  --location=$REGION --keyring=crelyzor-kek --key=crelyzor-kek-v1 --project=$PROJECT
```

To prevent accidental destruction, enable key destruction protection:
```bash
gcloud kms keys update crelyzor-kek-v1 \
  --location=$REGION --keyring=crelyzor-kek \
  --prevent-destroy --project=$PROJECT
```

### Scenario 2 — HMAC_BLIND_INDEX_KEY lost or changed

All blind indexes become invalid — email lookups, contact search by email, guest email matching all break silently.

Recovery: re-run the backfill script (recomputes all `*_bidx` columns from the current key). But if the old key is truly gone, the bidx values cannot be recovered — you must null out all bidx columns and rebuild from plaintext (requires temporarily decrypting all rows).

**Prevention:** Store `HMAC_BLIND_INDEX_KEY` in GCP Secret Manager, not just `.env`. Never rotate it post-launch.

### Scenario 3 — Leaked DEK (single user)

1. Rotate the affected user's DEK via key rotation endpoint (admin only).
2. `UserDekHistory` retains the old wrapped DEK — old ciphertext (version byte = old version) is still decryptable during the migration window.
3. Re-encrypt all of that user's rows under the new DEK version.
4. Delete the old `UserDekHistory` row once re-encryption is confirmed.

### Scenario 4 — Leaked wrapped DEK in DB dump

A leaked `User.wrappedDek` (wrapped by KEK) is safe as long as the KEK is not also compromised. The attacker would need access to Cloud KMS to unwrap the DEK.

Rotate the KEK immediately if the KMS key is also suspected leaked:
```bash
gcloud kms keys versions create \
  --location=$REGION --keyring=crelyzor-kek --key=crelyzor-kek-v1 \
  --primary --project=$PROJECT
```

Then re-wrap all `User.wrappedDek` values under the new key version.

---

## IAM Hygiene Checklist

- [ ] Backend service account has `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the KEK only
- [ ] No human user has `roles/cloudkms.admin` in production
- [ ] Cloud Audit Logs enabled for all KMS operations
- [ ] Key destruction protection (`--prevent-destroy`) enabled on all prod keys
- [ ] `HMAC_BLIND_INDEX_KEY` stored in GCP Secret Manager with version history
- [ ] Separate keyrings for staging vs prod
- [ ] KMS key access reviewed quarterly
