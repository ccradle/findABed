## 1. Stale Shelter Monitor

- [ ] 1.1 Create `infra/terraform/modules/monitoring/main.tf` with CloudWatch metric filter for shelter data age
- [ ] 1.2 Create scheduled Lambda or ECS task that queries for shelters with no snapshot in 8+ hours, publishes `fabt/shelter_stale_count` custom metric
- [ ] 1.3 Create CloudWatch alarm on `fabt/shelter_stale_count > 0` with SNS notification (non-paging)

## 2. DV Canary Monitor

- [ ] 2.1 Create Lambda function: POST `/api/v1/queries/beds` as non-DV user, assert zero DV shelters in results
- [ ] 2.2 Configure Lambda trigger: post-deploy hook + scheduled (every 15 minutes)
- [ ] 2.3 Create CloudWatch alarm on `fabt/dv_canary_pass = 0` with SNS notification (PAGING)

## 3. Temperature / Surge Gap Monitor

- [ ] 3.1 Create Lambda function stub: query NOAA API for pilot city temperature, query for active surge events (TODO: surge event query after surge-mode)
- [ ] 3.2 Configure hourly cron schedule (winter months)
- [ ] 3.3 Create CloudWatch alarm on temperature/surge mismatch with SNS notification (non-paging)

## 4. ALB Access Logging

- [ ] 4.1 Create S3 bucket for ALB logs with 90-day lifecycle policy in `modules/monitoring/main.tf`
- [ ] 4.2 Add `access_logs` block to ALB resource in `modules/app/main.tf`

## 5. SNS Topics

- [ ] 5.1 Create SNS topic `fabt-ops-alerts` for non-paging alerts (stale data, temperature gap)
- [ ] 5.2 Create SNS topic `fabt-critical-alerts` for PAGING alerts (DV canary)
- [ ] 5.3 Add email subscription placeholders (configured per-deployment)

## 6. Documentation

- [ ] 6.1 Create `docs/runbook.md` — operational runbook covering all three alert types: investigation steps, escalation paths, resolution actions
