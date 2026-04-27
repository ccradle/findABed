## MODIFIED Requirements

### Requirement: observability-admin-ui
The AdminPanel SHALL include an "Observability" tab accessible to `COC_ADMIN` users that displays and allows editing of observability settings (Prometheus toggle, tracing toggle, tracing endpoint, monitor intervals) without requiring API calls. (Previously: PLATFORM_ADMIN. Observability config is tenant-scoped — each tenant decides its own observability posture — so the gate moves to the tenant top role rather than the platform operator.)

#### Scenario: Admin views current observability config
- **WHEN** a `COC_ADMIN` navigates to the Admin Panel and clicks the "Observability" tab
- **THEN** the current observability settings are displayed (Prometheus enabled, tracing enabled/disabled, endpoint, intervals)

#### Scenario: Admin toggles tracing on
- **WHEN** the admin toggles the tracing switch to ON and clicks Save
- **THEN** `PUT /api/v1/tenants/{id}/observability` is called with `tracing_enabled: true`
- **AND** the UI reflects the updated state

#### Scenario: Non-admin denied
- **WHEN** a `COORDINATOR` or `OUTREACH_WORKER` attempts to navigate to the Observability tab
- **THEN** the tab is not rendered in the navigation
- **AND** direct URL access returns HTTP 403
