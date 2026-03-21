## 1. DynamoDB Deletion Protection

- [ ] 1.1 Add `deletion_protection_enabled = true` to `aws_dynamodb_table.terraform_locks` in `infra/terraform/bootstrap/main.tf`

## 2. OWASP CVE Gate

- [ ] 2.1 Add `dependency-check-maven` plugin to `backend/pom.xml` with `failBuildOnCVSS=7` and `suppressionFile` reference
- [ ] 2.2 Create `backend/owasp-suppressions.xml` — triage current 90 mediums: suppress known false-positives with `<notes>` rationale and review dates
- [ ] 2.3 Add OWASP dependency-check step to `.github/workflows/ci.yml`: `mvn dependency-check:check -DfailBuildOnCVSS=7`

## 3. Terraform Security Posture

- [ ] 3.1 Verify/fix ECS task role vs execution role separation in `modules/app/main.tf` — two distinct IAM roles with minimum permissions
- [ ] 3.2 Verify/fix RDS `publicly_accessible = false` and private subnet placement in `modules/postgres/main.tf`
- [ ] 3.3 Verify/fix ECS task definition uses `secrets` block (Secrets Manager ARN) for credentials, not plaintext `environment`
- [ ] 3.4 Verify/fix security group chain: ALB(443/80 from 0.0.0.0/0) → ECS(8080 from ALB SG) → RDS(5432 from ECS SG) — no other 0.0.0.0/0 ingress

## 4. Validation

- [ ] 4.1 Run `terraform validate` on all modules
- [ ] 4.2 Run `terraform plan` to confirm no unexpected changes beyond the hardening items
