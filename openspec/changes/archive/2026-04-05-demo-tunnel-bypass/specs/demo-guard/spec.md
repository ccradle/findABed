## MODIFIED Requirements

### Requirement: Admin bypass via SSH tunnel
The DemoGuardFilter SHALL allow full admin access for requests arriving via SSH tunnel (port 8081 or 8080), identified by the `X-FABT-Traffic-Source` header set by container nginx or by private-only IP chain for direct access.

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
