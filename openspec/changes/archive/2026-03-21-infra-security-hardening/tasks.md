## 1. DynamoDB Deletion Protection

- [x] 1.1 Add `deletion_protection_enabled = true` to `aws_dynamodb_table.terraform_locks` in `infra/terraform/bootstrap/main.tf`

## 2. OWASP CVE Gate

- [x] 2.1 Add `dependency-check-maven` plugin to `backend/pom.xml` with `failBuildOnCVSS=7` and `suppressionFile` reference
- [x] 2.2 Create `backend/owasp-suppressions.xml` — triage current 90 mediums: suppress known false-positives with `<notes>` rationale and review dates
- [x] 2.3 Add OWASP dependency-check step to `.github/workflows/ci.yml`: `mvn dependency-check:check -DfailBuildOnCVSS=7`

## 3. Terraform Security Posture

- [x] 3.1 Verify/fix ECS task role vs execution role separation in `modules/app/main.tf` — two distinct IAM roles with minimum permissions
- [x] 3.2 Verify/fix RDS `publicly_accessible = false` and private subnet placement in `modules/postgres/main.tf`
- [x] 3.3 Verify/fix ECS task definition uses `secrets` block (Secrets Manager ARN) for credentials, not plaintext `environment`
- [x] 3.4 Verify/fix security group chain: ALB(443/80 from 0.0.0.0/0) → ECS(8080 from ALB SG) → RDS(5432 from ECS SG) — no other 0.0.0.0/0 ingress

## 4. Validation

- [x] 4.1 Run `terraform validate` on all modules
- [x] 4.2 Run `terraform plan` to confirm no unexpected changes beyond the hardening items
