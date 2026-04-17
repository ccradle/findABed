## ADDED Requirements

### Requirement: jwt-per-tenant-signing-keys
The system SHALL derive per-tenant JWT signing keys via HKDF from a single platform KEK with context string `fabt:v1:<tenant-uuid>:jwt-sign` (per A1, D2). JWT headers SHALL carry an opaque random-UUID `kid` (NOT `kid=tenant:<uuid>`, per D1) that resolves server-side via a bounded cache to `(tenant_id, key_generation)`.

#### Scenario: Tenant A login issues JWT signed with tenant A key
- **WHEN** a user authenticates as tenant A and `JwtService.sign` runs
- **THEN** the signing key is HKDF-derived with context `fabt:v1:<tenantA-uuid>:jwt-sign`
- **AND** the JWT header `kid` is a random opaque UUID (not `tenant:<uuid>`)
- **AND** the `kid_to_tenant_key` row links that `kid` to `(tenantA, key_generation=1)`

#### Scenario: Captured JWT does not leak tenant UUID in kid
- **WHEN** an attacker inspects a captured JWT header from the wire or log aggregation
- **THEN** the `kid` value is a random UUID with no extractable tenant identifier
- **AND** the attacker cannot map `kid` to a tenant without access to the server-side `kid_to_tenant_key` table

#### Scenario: kid resolves to tenant signing key on validate
- **WHEN** `JwtService.validate` receives a JWT with a known `kid`
- **THEN** the bounded cache returns `(tenant_id, key_generation)` in sub-microsecond time
- **AND** the signature is verified against the HKDF-derived key for that tuple

#### Scenario: Unknown kid rejected
- **WHEN** `JwtService.validate` receives a JWT with a `kid` that does not appear in `kid_to_tenant_key`
- **THEN** validation fails with a 401 Unauthorized response
- **AND** no side-channel is exposed (same response shape as a signature-mismatch failure)

### Requirement: jwt-revocation-and-suspend
The system SHALL support atomic JWT invalidation for a tenant by bumping `tenant.jwt_key_generation` (per A2), invalidating all tokens issued under the prior generation. A fast-path `jwt_revocations(kid, expires_at)` list SHALL be consulted on every validate and pruned daily.

#### Scenario: Suspend bumps key generation and invalidates outstanding tokens
- **GIVEN** tenant A has `jwt_key_generation=1` and 100 active JWTs issued under generation 1
- **WHEN** an operator suspends tenant A via `TenantLifecycleService.suspend`
- **THEN** `jwt_key_generation` is bumped to 2 atomically
- **AND** every JWT whose `kid` resolves to `(tenantA, 1)` fails validation with 401

#### Scenario: New tokens after rotation validate successfully
- **GIVEN** tenant A's key generation was bumped from 1 to 2
- **WHEN** tenant A un-suspends and a user logs in
- **THEN** the new JWT carries a fresh `kid` mapping to `(tenantA, 2)`
- **AND** the new JWT validates successfully

#### Scenario: Explicit single-token revocation via jwt_revocations
- **WHEN** an admin revokes a single JWT by `kid`
- **THEN** a row `(kid, expires_at)` is inserted into `jwt_revocations`
- **AND** subsequent validate of that kid returns 401

#### Scenario: Daily prune removes expired revocations
- **WHEN** the daily revocation-prune scheduled task runs
- **THEN** every `jwt_revocations` row where `expires_at < now()` is deleted
- **AND** the validate fast-path lookup remains bounded in size

### Requirement: per-tenant-encryption-deks
The system SHALL derive per-tenant data encryption keys (DEKs) via HKDF with context string `fabt:v1:<tenant-uuid>:<purpose>` where purpose ∈ {totp, webhook-secret, oauth2-client-secret, hmis-api-key} (per A3, D2). Ciphertexts SHALL be prefixed with a `kid` binding tenant + DEK version to permit in-place rotation with an old-key decrypt grace window.

#### Scenario: TOTP secret encrypted with tenant-scoped DEK
- **WHEN** a user in tenant A enrolls TOTP and `SecretEncryptionService.encrypt` stores the seed
- **THEN** the ciphertext is produced with the DEK derived from `fabt:v1:<tenantA-uuid>:totp`
- **AND** the ciphertext is prefixed with a `kid` encoding `(tenantA, dek_version=1)`

#### Scenario: Cross-tenant DEK cannot decrypt
- **GIVEN** a webhook secret ciphertext written for tenant A
- **WHEN** a reconstruction attempt uses the tenant B DEK
- **THEN** decryption fails (AEAD tag mismatch) and the failure is logged

#### Scenario: DEK rotation with grace window
- **GIVEN** tenant A has DEK version 1 in use
- **WHEN** the rotation runbook bumps tenant A to DEK version 2
- **THEN** new writes use DEK version 2 (ciphertext `kid` reflects v2)
- **AND** reads of existing ciphertexts with `kid=(tenantA, 1)` continue to decrypt during the grace window

### Requirement: oauth2-hmis-credential-encryption
The system SHALL encrypt `TenantOAuth2Provider.clientSecretEncrypted` and `HmisVendorConfig.apiKeyEncrypted` at rest (per A4 LATENT fix). A Flyway migration SHALL re-encrypt existing rows that are currently stored as plaintext despite the column names. This SHALL ship as the first PR of the change, before per-tenant DEKs (A3) are required.

#### Scenario: OAuth2 client secret is ciphertext in database
- **WHEN** a platform admin creates a `TenantOAuth2Provider` with `clientSecret="abc123"`
- **THEN** `SecretEncryptionService.encrypt` is invoked before the row is persisted
- **AND** a direct `SELECT client_secret_encrypted FROM tenant_oauth2_provider` shows ciphertext, not `abc123`

#### Scenario: HMIS API key is ciphertext in database
- **WHEN** a platform admin creates an `HmisVendorConfig` with an API key
- **THEN** the stored `api_key_encrypted` column contains ciphertext
- **AND** read-path code decrypts via `SecretEncryptionService.decrypt` before use

#### Scenario: V74 migration re-encrypts pre-existing plaintext rows
- **GIVEN** the pre-deploy DB has rows where `client_secret_encrypted` and `api_key_encrypted` are plaintext
- **WHEN** Flyway migration V74 runs
- **THEN** every such row is re-written with ciphertext
- **AND** post-migration, no plaintext credential remains in either column

### Requirement: master-kek-storage
The system SHALL support two deployment tiers for master KEK storage (per A5, D3): standard tier uses `FABT_KEK_MASTER` env var sourced from a permissions-400 file with prod-profile guard; regulated tier uses HashiCorp Vault Transit engine with `derived=true` keys.

#### Scenario: Standard tier rejects dev key in prod profile
- **GIVEN** `FABT_KEK_MASTER` is set to a documented dev value
- **WHEN** the application starts with `spring.profiles.active=prod`
- **THEN** startup fails with a non-zero exit code and an error message identifying the dev-key guard
- **AND** no HTTP port is opened

#### Scenario: Standard tier loads key from permissioned file
- **GIVEN** `~/fabt-secrets/.env.prod` is owned `root:fabt` mode 400 and contains `FABT_KEK_MASTER=<production-value>`
- **WHEN** the application starts in prod profile
- **THEN** the key loads successfully and is held in kernel keyring for memory hygiene
- **AND** `SecretEncryptionService` can derive per-tenant DEKs on demand

#### Scenario: Regulated tier proxies through Vault Transit
- **GIVEN** the deploy sets `FABT_KEK_VAULT_TOKEN` + `FABT_KEK_VAULT_ADDR` and unsets `FABT_KEK_MASTER`
- **WHEN** `SecretEncryptionService` derives a per-tenant DEK
- **THEN** the derivation call proxies through Vault Transit with a per-tenant context
- **AND** the master KEK never leaves the Vault container

### Requirement: ciphertext-reencryption-migration
The system SHALL re-encrypt existing ciphertexts (TOTP secrets, webhook callback secrets) under per-tenant DEKs during the v-next deploy (per A6). Rollout SHALL be zero-downtime via a dual-key-accept grace window in which decrypt tries the new tenant DEK first and falls back to the legacy platform key.

#### Scenario: Existing TOTP ciphertext re-wrapped by V73
- **GIVEN** a user row with `totp_secret_encrypted` written under the single platform key pre-deploy
- **WHEN** Flyway V73 runs
- **THEN** the row is re-encrypted under the tenant's per-tenant DEK
- **AND** the ciphertext `kid` reflects `(tenant_id, dek_version=1)`

#### Scenario: Grace window decrypts legacy ciphertext
- **GIVEN** V73 is mid-migration and a partial set of rows still carry the legacy platform-key ciphertext
- **WHEN** a user attempts TOTP verify during this window
- **THEN** decrypt tries the new tenant DEK first, falls back to the legacy platform key on failure
- **AND** verify succeeds regardless of which side of the migration the row is on

#### Scenario: Grace window closes after 7 days
- **GIVEN** the grace window is configured for 7 days post-migration
- **WHEN** a decrypt attempt uses the legacy platform key 8 days after the migration
- **THEN** the decrypt fallback path is disabled by configuration
- **AND** only the per-tenant DEK path is consulted

### Requirement: jwt-claim-kid-binding
The system SHALL cross-check the `tenantId` claim in the JWT body against the tenant resolved from the `kid` header (per A7, D1). A token signed with tenant A's key but carrying `tenantId=<tenantB>` in the body SHALL be rejected.

#### Scenario: Matching kid tenant and claim tenant validates
- **WHEN** `JwtService.validate` sees `kid` → `(tenantA, 1)` and body claim `tenantId=<tenantA-uuid>`
- **THEN** validation proceeds and the request is authorized for tenant A

#### Scenario: Mismatched claim rejects
- **WHEN** a JWT carries `kid` resolving to tenant A but `tenantId=<tenantB-uuid>` in the body
- **THEN** validation fails with 401 Unauthorized
- **AND** an audit event `JWT_CLAIM_KID_MISMATCH` is emitted with actor, kid, claim-tenant, resolved-tenant

#### Scenario: Missing tenantId claim rejects
- **WHEN** a JWT carries a valid `kid` but omits the `tenantId` body claim
- **THEN** validation fails with 401
- **AND** the failure is logged with the kid for forensic correlation

### Requirement: rotation-runbooks
The project SHALL publish rotation runbooks (per L10, A5) for per-tenant DEK rotation, per-tenant JWT key rotation, and master KEK rotation. Each runbook SHALL document the step sequence, the dual-key-accept grace window duration, and the RTO.

#### Scenario: Per-tenant JWT key rotation runbook exists
- **GIVEN** `docs/security/runbooks/jwt-key-rotation.md` is published
- **WHEN** an operator opens it
- **THEN** it lists the atomic steps (bump `jwt_key_generation`, prune old `kid_to_tenant_key` rows after TTL, coordinated notification)
- **AND** it documents the RTO as ≤ 15 minutes for suspend-class rotations

#### Scenario: Master KEK rotation runbook exists
- **GIVEN** `docs/security/runbooks/master-kek-rotation.md` is published
- **WHEN** an operator opens it
- **THEN** it describes the dual-key-accept window, the re-encrypt-all-per-tenant-DEK sequence, and the operator checkpoints
- **AND** it documents the RTO as zero-downtime with a 14-day rolling grace window

#### Scenario: Per-tenant DEK rotation runbook exists
- **GIVEN** `docs/security/runbooks/per-tenant-dek-rotation.md` is published
- **WHEN** an operator opens it
- **THEN** it documents the bump-DEK-version step, the re-encrypt-all-columns-for-tenant step, and the grace window
- **AND** it includes a verification checklist (ciphertext kid reflects new version, old-kid decrypts fail after grace closes)
