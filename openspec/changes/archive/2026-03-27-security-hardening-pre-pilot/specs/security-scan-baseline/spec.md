## security-scan-baseline

OWASP ZAP active scan against demo environment with documented baseline.

### Requirements

- REQ-ZAP-1: Run OWASP ZAP API scan against the running application via OpenAPI spec. Phase 1: local development environment (HTTP, covers application-level vulnerabilities). Phase 2 (deferred): deployed environment with TLS for infrastructure-level scanning.
- REQ-ZAP-2: Run authenticated scan as outreach worker role (exercises bed search, reservations). Deferred to Phase 2 — requires ZAP authentication context configuration against deployed environment.
- REQ-ZAP-3: All HIGH and CRITICAL findings MUST be resolved before city IT engagement
- REQ-ZAP-4: All MEDIUM findings MUST be documented with justification (accept or fix)
- REQ-ZAP-5: Baseline report MUST be stored in `docs/security/zap-baseline.md` (summary, not raw HTML)
- REQ-ZAP-6: Scan MUST be repeatable — document the exact docker command and auth setup

### Scenarios

```gherkin
Scenario: ZAP scan produces zero HIGH/CRITICAL findings
  Given the demo environment is running with all security fixes applied
  When OWASP ZAP full scan completes
  Then there are zero HIGH findings
  And there are zero CRITICAL findings

Scenario: ZAP authenticated scan covers protected endpoints
  Given ZAP is configured with outreach worker credentials
  When the authenticated scan completes
  Then the scan report includes coverage of /api/v1/queries/beds
  And the scan report includes coverage of /api/v1/reservations
```
