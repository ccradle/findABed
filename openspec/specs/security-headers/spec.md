## security-headers

Security response headers on nginx reverse proxy to pass automated security scans.

### Requirements

- REQ-HDR-1: All responses MUST include `X-Content-Type-Options: nosniff`
- REQ-HDR-2: All responses MUST include `X-Frame-Options: DENY`
- REQ-HDR-3: All responses MUST include `Referrer-Policy: strict-origin-when-cross-origin`
- REQ-HDR-4: All responses MUST include `Permissions-Policy: geolocation=(), microphone=(), camera=()`
- REQ-HDR-5: Content-Security-Policy is intentionally deferred — requires PWA/service worker analysis
- REQ-HDR-6: Headers MUST be added with `always` directive to apply to all response codes

### Scenarios

```gherkin
Scenario: Security headers present on API response
  Given the application is running behind nginx
  When a client makes any HTTP request
  Then the response includes X-Content-Type-Options: nosniff
  And the response includes X-Frame-Options: DENY
  And the response includes Referrer-Policy: strict-origin-when-cross-origin
  And the response includes Permissions-Policy header

Scenario: Async dispatch does not trigger 401 on SSE
  Given an SSE emitter errors and Tomcat performs an async dispatch
  Then Spring Security does not re-challenge with 401/403
  And no "response already committed" error occurs

Scenario: Initial SSE connection still requires authentication
  Given a client connects to /api/v1/notifications/stream without a JWT token
  Then the request receives 401 Unauthorized

Scenario: Headers present on error responses
  Given the application is running behind nginx
  When a client makes a request that returns 404
  Then all 4 security headers are still present
```
