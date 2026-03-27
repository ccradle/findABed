## rls-enforcement (delta)

Modifications to existing rls-enforcement capability for connection pool dvAccess verification.

### Modified Requirements

- REQ-RLS-POOL-1: `applyRlsContext()` MUST overwrite any stale `app.dv_access` value from a previous request on the same pooled connection
- REQ-RLS-POOL-2: A test MUST verify that a dvAccess=true request followed by a dvAccess=false request on the same connection does not leak DV shelter visibility
- REQ-RLS-POOL-3: The test MUST run the sequence at least 100 times to detect intermittent race conditions

### Scenarios

```gherkin
Scenario: Pooled connection resets dvAccess between requests
  Given request 1 executes with dvAccess=true and sees DV shelters
  And request 1 completes and returns its connection to the pool
  When request 2 executes with dvAccess=false on the same connection
  Then request 2 does not see DV shelters
  And this holds for 100 consecutive iterations
```
