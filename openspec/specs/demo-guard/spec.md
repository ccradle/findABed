## MODIFIED Requirements

### Requirement: Admin bypass via SSH tunnel
The DemoGuardFilter SHALL allow full admin access for requests arriving via SSH tunnel (port 8081 or 8080), identified by the `X-FABT-Traffic-Source` header set by container nginx or by private-only IP chain for direct access.

#### Scenario: Shelter deactivation blocked in demo mode
- **WHEN** a public user sends `PATCH /api/v1/shelters/{id}/deactivate`
- **THEN** the DemoGuard filter SHALL return 403 with message "Shelter deactivation is disabled in the demo environment — would affect other visitors' bed search results."

#### Scenario: Shelter reactivation blocked in demo mode
- **WHEN** a public user sends `PATCH /api/v1/shelters/{id}/reactivate`
- **THEN** the DemoGuard filter SHALL return 403 with message "Shelter reactivation is disabled in the demo environment."

#### Scenario: Tunnel traffic bypasses DemoGuard via nginx header
- **WHEN** a request arrives with `X-FABT-Traffic-Source: tunnel` (set by container nginx when no incoming XFF exists)
- **THEN** the DemoGuard filter SHALL allow the request through regardless of HTTP method or endpoint
- **AND** a log entry SHALL record the bypass with traffic source

#### Scenario: Public traffic blocked by DemoGuard
- **WHEN** a request arrives with `X-FABT-Traffic-Source: public` (set by container nginx when incoming XFF exists)
- **AND** the request is a destructive mutation not on the safe allowlist
- **THEN** the DemoGuard filter SHALL return 403 with `demo_restricted` error

#### Scenario: Direct backend access (port 8080) bypasses via IP chain
- **WHEN** a request arrives at port 8080 directly (no nginx, no `X-FABT-Traffic-Source` header)
- **AND** `remoteAddr` is localhost and no XFF header exists
- **THEN** the DemoGuard filter SHALL allow the request through via the existing IP-chain fallback

#### Scenario: Forged header rejected for public traffic
- **WHEN** a client sends `X-FABT-Traffic-Source: tunnel` through the public path (Cloudflare → host nginx → container nginx)
- **THEN** container nginx SHALL overwrite the header with `public` (because XFF exists from host nginx)
- **AND** the DemoGuard filter SHALL block destructive mutations

#### Scenario: Browser UI admin operations work through tunnel
- **WHEN** an admin opens SSH tunnel to port 8081 and logs into the browser UI
- **THEN** they SHALL be able to: create/delete users, activate/deactivate surge, edit shelters, run imports, manage API keys
- **AND** the UI SHALL show success responses (not demo_restricted errors)

#### Scenario: Safe mutations still work for public traffic
- **WHEN** a public user performs a safe mutation (bed search, hold, referral, availability update, login)
- **THEN** the request SHALL be allowed regardless of traffic source

#### Scenario: Read access unchanged
- **WHEN** any user makes a GET/HEAD/OPTIONS request
- **THEN** the request SHALL be allowed regardless of traffic source or DemoGuard status

#### Scenario: SSE unaffected by traffic source header
- **WHEN** an SSE connection is established through either public or tunnel path
- **THEN** the SSE stream SHALL function normally (heartbeats, events, reconnection)
- **AND** the `X-FABT-Traffic-Source` header SHALL be present but SHALL NOT affect SSE behavior

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
