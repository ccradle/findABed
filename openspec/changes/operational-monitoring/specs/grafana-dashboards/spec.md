## ADDED Requirements

### Requirement: optional-grafana-dashboards
The system SHALL include example Grafana dashboards as provisioned JSON files in `grafana/provisioning/dashboards/`. These are optional — Grafana is not required for deployment. Docker Compose includes Prometheus + Grafana + Jaeger under the `observability` profile.

#### Scenario: Grafana dashboard available when stack includes observability profile
- **WHEN** the stack is started with `docker compose --profile observability up`
- **THEN** Grafana is available at port 3000 with the FABT operations dashboard pre-loaded

#### Scenario: Application works without Grafana
- **WHEN** the stack is started normally without the observability profile
- **THEN** the application functions normally with metrics available only via /actuator/prometheus
