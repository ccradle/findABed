## Context

SRE review identified three behavioral monitors and ALB access logging as missing from the infrastructure. These are domain-specific operational monitors that detect failure modes application metrics don't cover.

## Goals / Non-Goals

**Goals:**
- Stale shelter data detection (non-paging, business hours)
- DV shelter misclassification canary (PAGING, post-deploy)
- Temperature/surge gap alert (non-paging, hourly in winter) — stub until surge-mode
- ALB access logging with 90-day retention
- Operational runbook documenting all alert types and response procedures

**Non-Goals:**
- Application performance monitoring (already have Micrometer + Prometheus)
- Infrastructure uptime monitoring (use AWS built-in)
- Kafka consumer lag monitoring (Full-tier specific, separate concern)

## Decisions

### D1: CloudWatch metrics + alarms for all monitors

All three monitors use the same pattern: Lambda or scheduled query → custom CloudWatch metric → alarm → SNS topic → email/Slack. This keeps alerting infrastructure simple and reusable.

### D2: DV canary is a paging alarm

The DV canary is the only PAGING alarm. A DV shelter appearing in a public query is a data breach condition. The alarm fires immediately on any canary failure. The Lambda runs post-deploy and can also run on a schedule (every 15 minutes).

### D3: Stale data uses 8-hour threshold

Matches the `DataFreshness.STALE` threshold in the application. A shelter not updated in 8+ hours triggers a non-paging alert to the onboarding team. The coordinator may be off-shift, on break, or the device may have lost connectivity.

### D4: Temperature/surge gap is a stub

Monitor 3 requires the `surge-mode` domain model to query for active events. The Lambda is scaffolded with NOAA API integration but the surge-event query is stubbed with a TODO until surge-mode is implemented.

### D5: ALB access logging to S3 with lifecycle

ALB logs go to a dedicated S3 bucket with a 90-day lifecycle policy. Storage cost at pilot scale is negligible (<$1/month). Logs are the primary forensic record for any incident involving the public-facing API.
