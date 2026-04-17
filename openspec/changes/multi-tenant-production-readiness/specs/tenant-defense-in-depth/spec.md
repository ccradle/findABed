## ADDED Requirements

### Requirement: timing-attack-mitigation-adr
The project SHALL publish `docs/security/timing-attack-acceptance.md` (per I1, D10) as the ADR accepting that FABT resource UUIDs are not secrets. Cross-tenant 404 timing may distinguish cache miss from DB miss, but this reveals only UUID existence somewhere in the system — not which tenant owns it. Fixed sleep floor + jitter is rejected as adding user-visible latency without mitigating a real attack.

#### Scenario: ADR documents the acceptance decision
- **GIVEN** the ADR is published
- **WHEN** Marcus reviews it
- **THEN** the document names the acceptance (UUID-not-secret) and cites that UUIDs are random 128-bit values
- **AND** the rejected alternative (fixed sleep + jitter) is documented with its latency cost

#### Scenario: No timing mitigation applied in code
- **GIVEN** the ADR decision is to accept
- **WHEN** a cross-tenant 404 path executes
- **THEN** no artificial delay is injected
- **AND** the response is returned at the natural service-layer speed

### Requirement: inbound-webhook-per-tenant-signing
The system SHALL verify inbound webhooks (per I2) — HMIS callback, OAuth2 callback, any inbound webhook — via a per-tenant signing secret derived with `fabt:v1:<tenant-uuid>:webhook-secret` context. Requests with missing or incorrect signatures SHALL be rejected.

#### Scenario: Valid signature accepted
- **GIVEN** tenant A has a per-tenant inbound webhook signing secret derived via A3
- **WHEN** an inbound HMIS callback arrives with a correct HMAC signature header
- **THEN** the signature validates and the handler processes the payload

#### Scenario: Missing signature rejected
- **WHEN** an inbound webhook arrives without the signature header
- **THEN** the request is rejected with 401 Unauthorized
- **AND** an audit event `WEBHOOK_SIGNATURE_MISSING` is emitted with tenant, source, and timestamp

#### Scenario: Incorrect signature rejected
- **WHEN** an inbound webhook arrives with an HMAC computed against tenant B's secret but targets tenant A's endpoint
- **THEN** the signature check fails and the request is rejected with 401
- **AND** an audit event `WEBHOOK_SIGNATURE_MISMATCH` is emitted

### Requirement: actuator-authorization-platform-admin
The system SHALL restrict `/actuator/prometheus` (per I3) to platform-admin callers only. Metrics are tagged by `tenant_id` and therefore represent cross-tenant data. Other actuator endpoints SHALL follow the existing `feedback_actuator_security.md` posture.

#### Scenario: Platform admin can scrape prometheus endpoint
- **GIVEN** a platform-admin JWT
- **WHEN** the caller hits `GET /actuator/prometheus` on the application port
- **THEN** the response is 200 with metrics in Prometheus exposition format

#### Scenario: Non-admin cannot scrape
- **GIVEN** a CoC admin JWT (not platform admin)
- **WHEN** the same endpoint is requested
- **THEN** the response is 403 Forbidden
- **AND** no metrics leak

#### Scenario: Management-port scrape continues to work in dev
- **GIVEN** `management.server.port` is configured in dev --observability mode
- **WHEN** prometheus scrapes the management port
- **THEN** the endpoint is reachable without authentication (management port)
- **AND** the main application port continues to require platform-admin JWT

### Requirement: referral-token-session-binding
The system SHALL bind `referral_token` to the originating session (per I4) via a new `originating_session_id` column. Accept / reject SHALL validate session match to the originator OR require 2FA re-step when session differs.

#### Scenario: Same session accepts without 2FA re-step
- **GIVEN** a referral token was created in session S1
- **WHEN** the original recipient accepts it within the same session
- **THEN** the accept proceeds without 2FA re-step
- **AND** the `originating_session_id` match is logged

#### Scenario: Different session requires 2FA re-step
- **GIVEN** a referral token was created in session S1
- **WHEN** the recipient tries to accept from session S2 (different browser / device)
- **THEN** the system requires a 2FA re-step before accept
- **AND** a `REFERRAL_SESSION_BINDING_MISMATCH` audit event is emitted with prior + new session IDs

#### Scenario: Missing session binding rejected (legacy token from pre-migration)
- **GIVEN** a pre-migration referral_token without `originating_session_id`
- **WHEN** the token is accepted post-migration
- **THEN** the accept path requires 2FA re-step (conservative default)
- **AND** the legacy-token path is documented

### Requirement: egress-proxy-per-tenant-allowlist-regulated
The system SHALL (regulated tier only, per I5) apply a per-tenant destination allowlist for webhook / OAuth2 / HMIS outbound via an egress proxy. Standard tier SHALL continue to rely on `SafeOutboundUrlValidator` IP checks from v0.40.

#### Scenario: Regulated tenant blocks outbound to non-allowlisted destination
- **GIVEN** regulated tenant R has an egress allowlist `[hmis.example.gov]`
- **WHEN** a worker attempts to POST to `evil.example.com`
- **THEN** the egress proxy blocks the request
- **AND** an audit event `EGRESS_BLOCKED` is emitted with tenant, destination, and calling worker

#### Scenario: Standard tier uses SafeOutboundUrlValidator only
- **GIVEN** standard tier tenant S has no egress proxy in path
- **WHEN** an outbound webhook is dispatched
- **THEN** `SafeOutboundUrlValidator` runs on URL pre-flight (v0.40 behavior)
- **AND** the request proceeds if valid

#### Scenario: Allowlist entry added via tenant config audit-events
- **GIVEN** an operator adds an allowlist entry via `TenantConfigController`
- **WHEN** the change is persisted
- **THEN** a `TENANT_EGRESS_ALLOWLIST_CHANGED` audit event is emitted
- **AND** the change takes effect on next outbound attempt

### Requirement: delivery-time-webhook-revalidation
The system SHALL re-run `SafeOutboundUrlValidator.validateForDial` (per I6) on every retry attempt in `WebhookDeliveryService`. This defeats post-creation URL swap attacks where an attacker flips a DNS record or internal address between queue and dispatch.

#### Scenario: URL re-validated on retry
- **GIVEN** a webhook subscription's URL resolves to a safe IP at creation
- **WHEN** a delivery attempt retries after an initial failure and the URL now resolves to `127.0.0.1`
- **THEN** `validateForDial` is re-run pre-dispatch
- **AND** the retry fails validation with an audit event `WEBHOOK_REVALIDATION_FAILED`

#### Scenario: URL stable across retries proceeds
- **WHEN** the URL continues to resolve safely across retries
- **THEN** each retry proceeds to dispatch
- **AND** validation is fast-path (no DNS re-resolution cache beyond the revalidation SLA)

#### Scenario: Revalidation metric emitted per retry
- **WHEN** `WebhookDeliveryService` retries a delivery
- **THEN** `fabt_webhook_revalidation_total{outcome="pass|block"}` increments
- **AND** the metric aids operators in spotting anomalous URL-swap patterns
