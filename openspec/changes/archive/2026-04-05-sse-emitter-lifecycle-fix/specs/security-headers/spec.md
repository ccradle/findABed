## ADDED Requirements

### Requirement: Async dispatch permitAll for SSE endpoint
The SecurityFilterChain SHALL allow `DispatcherType.ASYNC` dispatches through without re-authentication for the SSE notification stream endpoint.

#### Scenario: Async dispatch does not trigger 401
- **WHEN** an SSE emitter errors and Tomcat performs an async dispatch
- **THEN** Spring Security SHALL NOT re-challenge with 401/403
- **AND** no "Unable to handle the Spring Security Exception because the response has already been committed" error SHALL occur

#### Scenario: Initial SSE connection still requires authentication
- **WHEN** a client connects to `/api/v1/notifications/stream` for the first time
- **THEN** the request SHALL still require a valid JWT token
- **AND** unauthenticated requests SHALL receive 401

#### Scenario: Async permitAll scoped to SSE endpoint only
- **WHEN** the SecurityFilterChain is configured
- **THEN** `DispatcherType.ASYNC` permitAll SHALL apply only to `/api/v1/notifications/**`
- **AND** all other endpoints SHALL retain normal authentication requirements for async dispatches
