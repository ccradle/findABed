## ADDED Requirements

### Requirement: Public version API endpoint

`GET /api/v1/version` SHALL return the application version from `pom.xml` without requiring authentication, returning only major.minor to reduce fingerprinting value.

**Acceptance criteria:**
- Returns `{"version": "X.Y"}` with 200 status (major.minor only, no patch)
- No authentication required (public endpoint in SecurityConfig `permitAll`)
- `@ConditionalOnResource(resources = "classpath:META-INF/build-info.properties")` — endpoint does not register if build-info unavailable (ConditionalOnBean fails due to bean ordering — component scan runs before auto-configuration)
- Backend integration test verifies endpoint returns version or is not auth-gated

### Requirement: Nginx rate limiting on version endpoint

The `/api/v1/version` endpoint SHALL be rate-limited at the nginx layer to prevent abuse and avoid security scan findings (OWASP WSTG-INFO-02 mitigation).

**Acceptance criteria:**
- `limit_req_zone` defined for public API endpoints (10 req/min/IP, 1m shared memory zone)
- `/api/v1/version` location block applies `limit_req` with burst=5 nodelay
- Excess requests receive HTTP 429 (`limit_req_status 429`)
- Rate limiting verified through nginx dev proxy (:8081) before Oracle deploy
- `rate-limit.conf` mounted alongside `default.conf` in Docker nginx

### Requirement: Version on login page

The login page SHALL display the application version in a footer.

**Acceptance criteria:**
- Version fetched from `/api/v1/version` once on page mount
- Displayed as `"vX.Y"` in small gray text below the login form
- If fetch fails, no version shown (no error, no broken layout)
- `data-testid="app-version"` on the version element
- Playwright test verifies version is visible on login page

### Requirement: Version in app layout

The Layout component SHALL display the version in a footer for all authenticated users.

**Acceptance criteria:**
- Version fetched from `/api/v1/version` once on layout mount
- Displayed as `"Finding A Bed Tonight vX.Y"` in footer area
- If fetch fails, footer shows nothing
- `data-testid="app-version"` on the version element
- Playwright test verifies version is visible in admin panel

### Requirement: BuildProperties Maven configuration

The `spring-boot-maven-plugin` SHALL include the `build-info` goal to ensure `BuildProperties` is populated at build time.

**Acceptance criteria:**
- `pom.xml` includes `<goal>build-info</goal>` in spring-boot-maven-plugin execution
- `BuildProperties` bean is injectable in controllers
- Version reflects the actual pom.xml version at build time
