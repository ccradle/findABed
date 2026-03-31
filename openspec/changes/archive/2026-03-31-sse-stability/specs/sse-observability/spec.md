## ADDED Requirements

### Requirement: SSE Micrometer metrics

The `NotificationService` SHALL register 4 custom Micrometer metrics for SSE connection health.

**Metrics:**
| Metric | Type | Description |
|--------|------|-------------|
| `sse.connections.active` | Gauge | Current number of active SSE connections |
| `sse.reconnections.total` | Counter | Total reconnections (detected by `Last-Event-ID` header presence) |
| `sse.event.delivery.duration` | Timer (p50/p95/p99) | Time to send an event to all connected clients |
| `sse.send.failures.total` | Counter | Failed sends (dead connection detection) |

**Acceptance criteria:**
- All 4 metrics visible at `/actuator/prometheus`
- `sse.connections.active` increments on connect, decrements on disconnect/error/timeout
- `sse.reconnections.total` increments when `Last-Event-ID` header is present
- `sse.send.failures.total` increments on `IOException` during heartbeat or event send
- Backend integration test verifies metrics are registered and update correctly

### Requirement: Grafana SSE health dashboard panel

The FABT Operations Grafana dashboard SHALL include an "SSE Health" row with 3 panels.

**Panels:**
1. `sse.connections.active` — gauge chart, should be flat (not sawtooth)
2. `rate(sse.reconnections.total[5m])` — should be near-zero in steady state
3. `rate(sse.send.failures.total[5m])` — dead connection detection rate

**Acceptance criteria:**
- Panels added to `grafana/dashboards/fabt-operations.json`
- Panels render data when the stack is running with observability
- A sawtooth pattern in `sse.connections.active` indicates a timeout/reconnect loop (the bug we're fixing)
