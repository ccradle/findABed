## MODIFIED Requirements

### Requirement: dynamodb-deletion-protection
The Terraform bootstrap DynamoDB state lock table SHALL have `deletion_protection_enabled = true` to prevent accidental destruction.

#### Scenario: State lock table protected from deletion
- **WHEN** someone runs `terraform destroy` on the bootstrap stack
- **THEN** the DynamoDB table destruction is blocked by AWS deletion protection
- **AND** manual intervention is required to disable protection before deletion

### Requirement: owasp-cve-gate
The CI pipeline SHALL fail the build when any dependency has a CVSS score >= 7.0 (HIGH or CRITICAL). Known false-positives SHALL be documented in an OWASP suppressions file with rationale and review dates.

#### Scenario: Build fails on HIGH CVE
- **WHEN** a dependency has a known vulnerability with CVSS >= 7.0
- **THEN** the Maven build fails with OWASP dependency-check error
- **AND** the CI pipeline reports the failure

#### Scenario: Suppressed CVE does not fail build
- **WHEN** a dependency CVE is listed in `owasp-suppressions.xml` with documented rationale
- **THEN** the build succeeds despite the suppressed CVE
- **AND** the suppression includes a review date for re-evaluation

### Requirement: terraform-security-posture
The Terraform modules SHALL enforce IAM role separation (task vs execution), private RDS placement, Secrets Manager credential injection, and least-privilege security groups.

#### Scenario: ECS task and execution roles are separate
- **WHEN** the ECS task definition is provisioned
- **THEN** the execution role has only ECR, CloudWatch, and Secrets Manager permissions
- **AND** the task role has only RDS access permissions
- **AND** the two roles are distinct IAM resources

#### Scenario: RDS is not publicly accessible
- **WHEN** the RDS instance is provisioned
- **THEN** `publicly_accessible = false` is set
- **AND** the instance is in a private subnet reachable only from ECS task security group

#### Scenario: Credentials injected via Secrets Manager
- **WHEN** the ECS task definition is provisioned
- **THEN** database credentials are injected as ECS `secrets` from Secrets Manager ARNs
- **AND** no plaintext credentials appear in `environment` entries

#### Scenario: Security group chain is least-privilege
- **WHEN** the infrastructure is provisioned
- **THEN** only the ALB security group allows ingress from 0.0.0.0/0 (ports 80, 443)
- **AND** ECS task security group allows ingress only from ALB security group (port 8080)
- **AND** RDS security group allows ingress only from ECS task security group (port 5432)
