## ADDED Requirements

### Requirement: HTTP/HTTPS ingress restricted to Cloudflare IP ranges
The Oracle Cloud security list (or VM-level iptables) SHALL restrict ingress on ports 80 and 443 to Cloudflare's published IPv4 and IPv6 ranges only. Direct-to-origin requests from non-Cloudflare IPs SHALL be dropped.

#### Scenario: Request from Cloudflare IP accepted
- **WHEN** a request arrives on port 443 from a Cloudflare edge IP
- **THEN** the request is accepted and proxied to the application

#### Scenario: Direct-to-origin request blocked
- **WHEN** an attacker sends a request directly to `${FABT_VM_IP}:443` from a non-Cloudflare IP
- **THEN** the connection is dropped (no response)

#### Scenario: Origin IP not discoverable
- **WHEN** an attacker resolves `findabed.org`
- **THEN** only Cloudflare edge IPs are returned, not `${FABT_VM_IP}`

### Requirement: SSH access restricted to admin IP
SSH ingress (port 22) SHALL remain restricted to the project administrator's IP address. This is independent of the Cloudflare IP restriction.

#### Scenario: Admin SSH access works
- **WHEN** the admin connects via `ssh -i ~/.ssh/fabt-oracle ubuntu@${FABT_VM_IP}`
- **THEN** the SSH connection is established successfully

#### Scenario: Non-admin SSH blocked
- **WHEN** a connection attempt is made to port 22 from an unauthorized IP
- **THEN** the connection is dropped

### Requirement: Origin IP leakage acknowledged and mitigated
The origin IP (`${FABT_VM_IP}`) is historically exposed via the `nip.io` domain name, public DNS history, HAR files in the repo, and log files. Origin lockdown (Cloudflare IP restriction) is the mitigation — the IP is known but unreachable on HTTP/HTTPS. This SHALL be documented as a known-and-mitigated risk, not an unaddressed gap.

#### Scenario: Direct access blocked despite known IP
- **WHEN** an attacker uses the known origin IP from historical records or the nip.io domain
- **THEN** direct HTTP/HTTPS connections to `${FABT_VM_IP}` are dropped by the firewall

#### Scenario: HAR and log files containing origin IP removed from repo
- **WHEN** stale files (`${FABT_VM_IP}.nip.io.har`, related logs) are cleaned up
- **THEN** the origin IP is no longer present in the current repo tree (though it remains in git history — acceptable)

### Requirement: API responses not cached by Cloudflare CDN
Cloudflare SHALL NOT cache API responses (`/api/*`). Only static assets (images, CSS, JS) SHALL be cached at the edge. The backend already sends appropriate `Cache-Control` headers on API responses; this requirement verifies Cloudflare respects them.

#### Scenario: API response served from origin, not cache
- **WHEN** a client requests `/api/v1/shelters` through Cloudflare
- **THEN** the response header `CF-Cache-Status` is `DYNAMIC` (not `HIT` or `MISS`)

#### Scenario: Static asset cached at edge
- **WHEN** a client requests a static image or CSS file
- **THEN** the response header `CF-Cache-Status` is `HIT` on subsequent requests

### Requirement: Cloudflare IP ranges documented and updatable
The list of allowed Cloudflare IP ranges SHALL be documented in the domain setup guide. The process for updating the ranges if Cloudflare publishes changes SHALL be documented.

#### Scenario: IP range update process exists
- **WHEN** Cloudflare publishes new IP ranges
- **THEN** the guide provides step-by-step instructions to update the security list rules
