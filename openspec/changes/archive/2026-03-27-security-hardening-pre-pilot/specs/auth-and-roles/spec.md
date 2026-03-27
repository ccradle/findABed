## auth-and-roles (delta)

Modifications to existing auth-and-roles capability for universal exception handling.

### Modified Requirements

- REQ-AUTH-ERR-1: `GlobalExceptionHandler` MUST include a catch-all `@ExceptionHandler(Exception.class)` that returns structured `ErrorResponse` with generic message
- REQ-AUTH-ERR-2: No exception response MUST contain Java class names, stack traces, or Spring Boot version information
- REQ-AUTH-ERR-3: `server.error.include-stacktrace` MUST be set to `never` in all profiles
- REQ-AUTH-ERR-4: `server.error.include-message` MUST be set to `never` in all profiles
- REQ-AUTH-ERR-5: Unhandled exceptions MUST be logged at ERROR level server-side with full stack trace
- REQ-AUTH-ERR-6: The `/error` fallback endpoint MUST NOT expose implementation details
- REQ-AUTH-PERMIT-1: Every `permitAll()` path in SecurityConfig MUST be documented with justification and verified to not disclose sensitive information when accessed with a cleared security context

### Scenarios

```gherkin
Scenario: Unhandled exception returns generic error
  Given an endpoint throws an unexpected NullPointerException
  When the client receives the response
  Then the status is 500
  And the body contains "An unexpected error occurred"
  And the body does not contain "NullPointerException"
  And the body does not contain "at org.fabt"
  And the body does not contain "at java."

Scenario: Malformed JSON does not expose stack trace
  Given a client POSTs invalid JSON to /api/v1/auth/login
  When the response is received
  Then the body does not contain "Exception"
  And the body does not contain "stack"

Scenario: Swagger disabled in prod profile
  Given the application is running with the prod profile active
  When a client requests GET /api/v1/docs
  Then the response is 404
```
