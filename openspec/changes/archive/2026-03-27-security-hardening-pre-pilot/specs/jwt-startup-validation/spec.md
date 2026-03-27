## jwt-startup-validation

Explicit startup assertion for JWT secret presence, strength, and non-default value.

### Requirements

- REQ-JWT-1: Application MUST fail to start with `IllegalStateException` if `fabt.jwt.secret` is null, blank, or empty
- REQ-JWT-2: Application MUST fail to start if `fabt.jwt.secret` equals the hardcoded dev default (`"default-dev-secret-change-in-production"`) and the active Spring profile includes `prod`
- REQ-JWT-3: Application MUST fail to start if `fabt.jwt.secret` is shorter than 32 characters (256 bits)
- REQ-JWT-4: Error message MUST include actionable guidance: `"Generate with: openssl rand -base64 64"`
- REQ-JWT-5: Validation MUST run via `@PostConstruct` — not deferred to first request

### Scenarios

```gherkin
Scenario: Empty JWT secret prevents startup
  Given FABT_JWT_SECRET is set to ""
  When the application starts
  Then startup fails with IllegalStateException
  And the error message contains "FABT_JWT_SECRET"
  And the error message contains "openssl rand -base64 64"

Scenario: Default dev secret prevents startup in prod profile
  Given FABT_JWT_SECRET is not set (uses default)
  And the active profile is "prod"
  When the application starts
  Then startup fails with IllegalStateException

Scenario: Short secret prevents startup
  Given FABT_JWT_SECRET is set to "tooshort"
  When the application starts
  Then startup fails with IllegalStateException
  And the error message contains "Minimum 32 characters"

Scenario: Valid secret allows startup
  Given FABT_JWT_SECRET is a 64-character base64 string
  When the application starts
  Then startup succeeds
```
