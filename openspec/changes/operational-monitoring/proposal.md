## Why

The platform has application-level observability (structured logging, Micrometer metrics, health probes) but no operational monitoring for domain-specific failure modes: shelters going dark (no availability updates in 8+ hours), DV shelter data leaking into public queries post-deploy, or severe weather without an active surge event. These are the failure modes that a shelter coordinator won't report and an outreach worker won't notice until it's too late. Additionally, the ALB has no access logging — the primary forensic record for any security incident is missing.

## What Changes

- New Terraform module `modules/monitoring/main.tf` for CloudWatch alarms and metrics
- **Monitor 1**: Stale shelter data — scheduled query publishes custom metric, CloudWatch alarm + SNS for shelters not updated in 8+ hours (non-paging)
- **Monitor 2**: DV shelter misclassification canary — post-deploy Lambda asserts zero DV shelters in public query results, CloudWatch alarm on failure (PAGING)
- **Monitor 3**: Temperature/surge gap alert — Lambda checks NOAA API + active surge events, alerts on cold weather without active surge (non-paging). Stub until `surge-mode` is complete.
- ALB access logging to S3 with 90-day lifecycle
- Operational runbook (`docs/runbook.md`) covering all alert types

## Capabilities

### New Capabilities

- `operational-monitoring`: Three behavioral monitors (stale data, DV canary, temperature/surge gap) + ALB access logging

### Modified Capabilities

- `deployment-profiles`: Terraform modules extended with monitoring module

## Impact

- **New files**: `infra/terraform/modules/monitoring/main.tf`, Lambda function code, `docs/runbook.md`
- **Modified files**: `infra/terraform/modules/app/main.tf` (ALB access logs)
- **AWS resources**: CloudWatch alarms, SNS topics, Lambda functions, S3 bucket for ALB logs
- **Monitor 3 blocked on**: `surge-mode` change (stub the Lambda, implement after surge-mode)
