## ADDED Requirements

### Requirement: Domain setup guide documents full registration-to-deployment process
A guide SHALL be produced documenting every step from domain registration through Cloudflare configuration to Oracle VM cutover. The guide SHALL be written as a reproducible runbook, not just a narrative — any CoC deploying FABT can follow it to set up their own domain.

#### Scenario: New CoC deployer follows guide
- **WHEN** a new CoC deployment follows the domain setup guide from start to finish
- **THEN** they achieve a working custom domain with Cloudflare CDN/WAF in front of their FABT instance

### Requirement: Guide includes lessons learned from initial setup
The guide SHALL include a "Lessons Learned" section documenting gotchas, mistakes, and non-obvious steps encountered during the initial `findabed.org` setup. This section SHALL be populated during task execution, not written speculatively.

#### Scenario: Gotcha documented
- **WHEN** a non-obvious issue is encountered during setup (e.g., DNS propagation delay, Certbot challenge through proxy)
- **THEN** the issue, root cause, and resolution are added to the Lessons Learned section

### Requirement: Guide covers Cloudflare SSE configuration
The guide SHALL document the SSE-specific Cloudflare configuration: the `X-Accel-Buffering: no` header requirement, heartbeat interval rationale (20s < 100s Cloudflare timeout), and how to verify SSE works through the proxy.

#### Scenario: SSE troubleshooting documented
- **WHEN** a deployer experiences SSE buffering or timeout issues
- **THEN** the guide provides diagnosis steps and the correct header/heartbeat configuration

### Requirement: Guide covers origin security lockdown
The guide SHALL document how to restrict origin server access to Cloudflare IP ranges, including the current IP ranges, where to configure them (Oracle Cloud security lists or iptables), and how to update them.

#### Scenario: Security lockdown reproducible
- **WHEN** a deployer follows the origin lockdown section
- **THEN** their origin server accepts HTTP/HTTPS only from Cloudflare IPs

### Requirement: Guide stored in docs repo
The guide SHALL be stored in the docs repo at a location accessible to deployers (e.g., alongside the Oracle demo runbook).

#### Scenario: Guide accessible
- **WHEN** a deployer looks for domain setup documentation
- **THEN** the guide is findable in the expected documentation location
