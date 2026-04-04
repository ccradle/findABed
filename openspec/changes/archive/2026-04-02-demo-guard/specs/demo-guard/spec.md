## ADDED Requirements

### Requirement: DemoGuardFilter blocks destructive operations in demo mode
A `DemoGuardFilter` (`OncePerRequestFilter`) SHALL be activated by the `demo` Spring profile. When active, it SHALL block all POST/PUT/PATCH/DELETE requests except those on the safe mutation allowlist, returning HTTP 403 with a structured JSON error body.

#### Scenario: Destructive operation blocked
- **WHEN** a public visitor sends `POST /api/v1/users` (create user) through the demo site
- **THEN** the filter returns 403 with `{"error": "demo_restricted", "message": "User creation is disabled in the demo environment."}`

#### Scenario: Destructive operation on DV flag blocked
- **WHEN** a public visitor sends `PUT /api/v1/shelters/{id}` with `dvShelter: true` change
- **THEN** the filter returns 403 with `{"error": "demo_restricted", "message": "Shelter modification is disabled in the demo environment."}`

#### Scenario: Password change blocked
- **WHEN** a public visitor sends `PUT /api/v1/auth/password` to change a demo account's password
- **THEN** the filter returns 403 with `{"error": "demo_restricted", "message": "Password changes are disabled in the demo environment."}`

#### Scenario: GET requests always pass through
- **WHEN** a public visitor sends `GET /api/v1/users` (list users) or `GET /api/v1/shelters` (list shelters)
- **THEN** the filter allows the request and the full data is returned

### Requirement: Safe mutations are allowlisted
The following mutations SHALL be allowed in demo mode because they are core to the demo experience and have limited blast radius:

- Authentication: login, token refresh, TOTP verify, TOTP enroll/confirm
- Bed operations: bed search (POST), hold, confirm, cancel
- DV referrals: request, accept, reject
- Availability: coordinator bed count update
- Webhooks: subscribe, unsubscribe

#### Scenario: Bed hold works in demo
- **WHEN** a public visitor sends `POST /api/v1/reservations` to hold a bed
- **THEN** the filter allows the request and the reservation is created

#### Scenario: Login works in demo
- **WHEN** a public visitor sends `POST /api/v1/auth/login` with demo credentials
- **THEN** the filter allows the request and a JWT is returned

#### Scenario: Coordinator availability update works in demo
- **WHEN** a public visitor logged in as coordinator sends `PATCH /api/v1/shelters/{id}/availability`
- **THEN** the filter allows the request and the availability is updated

### Requirement: SSH tunnel traffic bypasses the demo guard
Requests arriving via SSH tunnel SHALL bypass the demo guard entirely, allowing full admin operations. The filter SHALL use a two-layer detection:
1. `request.getRemoteAddr()` is `127.0.0.1` or `::1` → bypass (direct backend tunnel via :8080)
2. `X-Forwarded-For` header is absent AND remote address is a private network IP → bypass (container nginx tunnel via :8081)

Public traffic always has `X-Forwarded-For` set by host nginx/Cloudflare, so it is never exempt.

#### Scenario: SSH tunnel to :8080 admin creates a user
- **WHEN** an admin connects via SSH tunnel (`ssh -L 8080:localhost:8080`) and sends `POST /api/v1/users` from `http://localhost:8080`
- **THEN** the filter detects `remoteAddr=127.0.0.1` and allows the request

#### Scenario: SSH tunnel to :8081 admin creates a user via browser UI
- **WHEN** an admin connects via SSH tunnel (`ssh -L 8081:localhost:8081`) and sends `POST /api/v1/users` from `http://localhost:8081`
- **THEN** the filter detects private IP with no `X-Forwarded-For` header and allows the request

#### Scenario: Public traffic is not mistaken for tunnel traffic
- **WHEN** a public visitor sends a request through Cloudflare → host nginx → container nginx → backend
- **THEN** the request has `X-Forwarded-For` set by host nginx, so the filter applies the demo guard

### Requirement: Filter only active with demo profile
The `DemoGuardFilter` SHALL be annotated with `@Profile("demo")` so it is completely absent in production, dev, and test profiles.

#### Scenario: Production deployment has no guard
- **WHEN** the backend starts with `SPRING_PROFILES_ACTIVE=lite` (no `demo`)
- **THEN** the `DemoGuardFilter` bean is not created and all operations work normally

#### Scenario: Demo deployment has guard active
- **WHEN** the backend starts with `SPRING_PROFILES_ACTIVE=lite,demo`
- **THEN** the `DemoGuardFilter` bean is created and intercepts requests

### Requirement: Allowlist is fail-secure
Any new endpoint added to the backend SHALL be blocked by default in demo mode. Only endpoints explicitly listed in the allowlist pass through.

#### Scenario: New endpoint automatically blocked
- **WHEN** a developer adds `POST /api/v1/new-feature` to a controller
- **THEN** the demo guard blocks it without any configuration change (because it's not in the allowlist)
