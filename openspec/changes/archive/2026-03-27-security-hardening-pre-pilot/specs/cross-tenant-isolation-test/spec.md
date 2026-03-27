## cross-tenant-isolation-test

Concurrent virtual thread multi-tenant data isolation verification.

### Requirements

- REQ-ISO-1: Tenant A shelters MUST never appear in Tenant B API responses under concurrent load
- REQ-ISO-2: Test MUST use genuine concurrency with virtual threads (not sequential execution)
- REQ-ISO-3: Test MUST fire at least 50 requests per tenant simultaneously
- REQ-ISO-4: Test MUST cover `/api/v1/shelters` (list) and `/api/v1/shelters/{id}` (direct object reference)
- REQ-ISO-5: Direct access to Tenant A's shelter by Tenant B MUST return 404 (not 403 — do not confirm existence)
- REQ-ISO-6: Test MUST cover bed search endpoint (`/api/v1/queries/beds`) — DV shelters must not leak across tenants
- REQ-ISO-7: Test MUST run in CI on every PR that touches TenantContext, RlsDataSourceConfig, or auth filters
- REQ-ISO-8: Test class MUST be named `CrossTenantIsolationTest`

### Scenarios

```gherkin
Scenario: Concurrent shelter list isolation
  Given Tenant A has shelters ["Safe Haven A1", "Safe Haven A2"]
  And Tenant B has shelters ["Harbor House B1"]
  When 50 concurrent requests from Tenant A and 50 from Tenant B hit /api/v1/shelters
  Then no Tenant A response contains "Harbor House B1"
  And no Tenant B response contains "Safe Haven A1" or "Safe Haven A2"

Scenario: Direct object reference returns 404 across tenants
  Given Tenant A shelter has ID {shelterAId}
  When Tenant B user requests GET /api/v1/shelters/{shelterAId}
  Then the response is 404 Not Found

Scenario: DV shelter isolation under concurrent load
  Given Tenant A has a DV shelter
  When 50 concurrent bed search requests from Tenant A (dvAccess=false) execute
  Then no response contains the DV shelter ID or name

Scenario: Connection pool does not leak dvAccess across requests
  Given a request with dvAccess=true completes and returns connection to pool
  When the next request has dvAccess=false
  Then the second request does not see DV shelters
  And this is verified over 100 sequential iterations
```
