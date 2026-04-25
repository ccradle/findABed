## ADDED Requirements

### Requirement: All PLATFORM_OPERATOR endpoints remain demo-restricted
The DemoGuardFilter SHALL block any request to a `@PlatformAdminOnly` endpoint when the request originates from public traffic (not localhost, not SSH-tunnel-via-`X-FABT-Traffic-Source: tunnel`). Demo visitors SHALL NOT be able to perform platform-operator actions even if they somehow obtain a platform JWT.

#### Scenario: Demo visitor with forged platform JWT denied at filter
- **WHEN** a public-traffic request bears a JWT with `iss="fabt-platform"` and attempts a `@PlatformAdminOnly` endpoint
- **THEN** DemoGuardFilter returns HTTP 403 with `error: demo_restricted` BEFORE the JWT validation pipeline runs
- **AND** no `platform_admin_access_log` row is written
- **AND** no `audit_events` row is written

#### Scenario: Operator via SSH tunnel can reach platform endpoints
- **WHEN** a request bears `X-FABT-Traffic-Source: tunnel` (set by container nginx for SSH-tunnel traffic)
- **THEN** DemoGuardFilter bypasses the demo-restriction check
- **AND** the request continues to the normal `@PreAuthorize` + `@PlatformAdminOnly` pipeline

### Requirement: DV referral creation rate-limited to 5 per IP per hour
The system SHALL apply a per-IP bucket4j rate limit of 5 requests per hour to `POST /api/v1/dv-referrals`. The rate limit applies to the demo-tenant context; production tenants with real outreach volumes can override per-tenant via tenant config.

#### Scenario: 6th DV referral from same IP within 1h rejected
- **WHEN** a public IP creates 5 DV referrals in 1 hour and attempts a 6th
- **THEN** the response is HTTP 429 with `{"error":"rate_limited","message":"Too many DV referral submissions from this IP. Try again later."}`
- **AND** the 6th request does NOT generate a referral row or audit row

#### Scenario: Counter resets after 1h sliding window
- **WHEN** more than 1 hour has elapsed since the first request in the window
- **THEN** the bucket has tokens available again

### Requirement: Anomaly alert on DV referral burst
The system SHALL emit a Prometheus counter `fabt_dv_referrals_created_total` labeled by `source_ip`. A Prometheus alert rule SHALL fire when `rate(fabt_dv_referrals_created_total[5m]) by (source_ip) > 10` for more than 2 minutes, paging operator via the existing alertmanager pipeline.

#### Scenario: Burst from single IP fires alert
- **WHEN** a single IP causes the per-IP rate to exceed 10 referrals/min sustained for 2 minutes (e.g., a script that bypasses the 5/hour limit by rotating sessions)
- **THEN** Prometheus fires `FabtDvReferralBurstFromSingleIp` alert
- **AND** alertmanager routes to operator-on-call

### Requirement: 48-hour scheduled cleanup of un-acted demo DV referrals
The `BatchJobScheduler` SHALL include a scheduled job `dvReferralDemoCleanup` (cron: every 6 hours) that DELETEs DV referrals from demo tenants (`dev-coc`, `dev-coc-west`, `dev-coc-east`) that have status `PENDING` and were created more than 48 hours ago. Production tenants are excluded.

#### Scenario: Stale demo DV referral purged after 48h
- **WHEN** a DV referral in dev-coc with status `PENDING` is older than 48 hours and the cleanup job runs
- **THEN** the referral row is DELETEd
- **AND** an `audit_events` row is INSERTed under dev-coc with `action = DV_REFERRAL_DEMO_CLEANUP`

#### Scenario: Production tenant DV referrals are NOT purged
- **WHEN** the cleanup job runs against a production tenant (slug NOT in {dev-coc, dev-coc-west, dev-coc-east})
- **THEN** no rows are DELETEd from that tenant

### Requirement: Sec-Fetch-Site header check on DV referral submission
The system SHALL reject `POST /api/v1/dv-referrals` requests with `Sec-Fetch-Site` header value other than `same-origin`, `same-site`, or `none` (browser-direct navigation). Cross-site requests are blocked with HTTP 403.

#### Scenario: Cross-site POST rejected
- **WHEN** a `POST /api/v1/dv-referrals` arrives with `Sec-Fetch-Site: cross-site`
- **THEN** the response is HTTP 403 with `{"error":"cross_site_blocked"}`
- **AND** no referral row is created

#### Scenario: Same-origin POST allowed (normal browser submission)
- **WHEN** a `POST /api/v1/dv-referrals` arrives with `Sec-Fetch-Site: same-origin` (typical browser form submit)
- **THEN** the request continues normal processing

#### Scenario: Missing Sec-Fetch-Site header allowed (legacy browsers / direct navigation)
- **WHEN** a request omits the `Sec-Fetch-Site` header entirely
- **THEN** the request is allowed (we only block when the header IS present and indicates cross-site)

### Requirement: Public monitoring notice on Try-it-Live page
The "Try it Live" public demo page SHALL display a visible notice: "These are real demo credentials in a real environment. The demo is monitored; abuse triggers automated rate-limits and alerts."

#### Scenario: Notice rendered on /try-it-live
- **WHEN** any user loads the Try-it-Live page
- **THEN** the monitoring notice is visible above the user list, in standard body-text size (not hidden in fine-print footer)
