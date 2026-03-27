## auth-rate-limiting

Brute force protection on authentication endpoints.

### Requirements

- REQ-RL-1: `/api/v1/auth/login` MUST be rate-limited to 10 requests per 15-minute window per client IP
- REQ-RL-2: `/api/v1/auth/refresh` MUST be rate-limited to 10 requests per 15-minute window per client IP
- REQ-RL-3: Rate-limited requests MUST return HTTP 429 Too Many Requests
- REQ-RL-4: Response MUST include `Retry-After` header with seconds until reset
- REQ-RL-5: Rate-limited attempts MUST be logged at WARN level with client IP
- REQ-RL-6: Rate limiting MUST NOT apply to non-auth endpoints
- REQ-RL-7: Rate limiting MUST use `bucket4j-spring-boot-starter` (purpose-built for per-key HTTP rate limiting). Resilience4J remains for circuit breakers only.

### Scenarios

```gherkin
Scenario: Normal login succeeds
  Given a user has not exceeded the rate limit
  When they POST to /api/v1/auth/login with valid credentials
  Then the response is 200 with JWT tokens

Scenario: Brute force blocked after 10 attempts
  Given a client IP has made 10 login requests in 15 minutes
  When they make an 11th login request
  Then the response is 429 Too Many Requests
  And the response includes a Retry-After header
  And the attempt is logged at WARN level

Scenario: Rate limit resets after window expires
  Given a client IP was rate-limited
  And 15 minutes have passed
  When they make a new login request
  Then the response is not 429

Scenario: Different IPs have independent limits
  Given IP 1.2.3.4 has made 10 login requests
  When IP 5.6.7.8 makes a login request
  Then the response is 200 (not rate-limited)

Scenario: Non-auth endpoints are not rate-limited
  Given a client IP has been rate-limited on /auth/login
  When they GET /api/v1/shelters with a valid token
  Then the response is 200
```
