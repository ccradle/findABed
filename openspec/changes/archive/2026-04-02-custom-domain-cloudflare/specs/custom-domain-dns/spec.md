## ADDED Requirements

### Requirement: Domain registered on Namecheap with privacy protection
The `findabed.org` domain SHALL be registered on Namecheap with WhoisGuard (free WHOIS privacy) enabled. Registration SHALL be for a minimum of 1 year.

#### Scenario: Domain registration complete
- **WHEN** the domain registration is finalized on Namecheap
- **THEN** `findabed.org` is owned by the project registrant with WhoisGuard active and auto-renewal enabled

### Requirement: Cloudflare free account with domain added
A Cloudflare free-tier account SHALL be created and `findabed.org` SHALL be added as a zone. Cloudflare SHALL assign a nameserver pair for the domain.

#### Scenario: Cloudflare zone active
- **WHEN** the domain is added to Cloudflare and nameservers are delegated
- **THEN** Cloudflare dashboard shows the zone as "Active" with DNS resolution working

### Requirement: Namecheap nameservers delegated to Cloudflare
The Namecheap domain configuration SHALL use Custom DNS pointing to the Cloudflare-assigned nameserver pair (e.g., `ada.ns.cloudflare.com`, `bob.ns.cloudflare.com`).

#### Scenario: Nameserver delegation verified
- **WHEN** DNS propagation completes (up to 48 hours)
- **THEN** `dig NS findabed.org` returns Cloudflare nameservers

### Requirement: Cloudflare DNS A record proxied to Oracle VM
A proxied (orange-cloud) A record SHALL exist in Cloudflare DNS: `findabed.org` → `150.136.221.232`.

#### Scenario: DNS resolves through Cloudflare
- **WHEN** a client resolves `findabed.org`
- **THEN** the returned IP is a Cloudflare edge IP (not the origin `150.136.221.232`)

#### Scenario: HTTPS request reaches the app
- **WHEN** a browser navigates to `https://findabed.org`
- **THEN** the request is proxied through Cloudflare to the Oracle VM and the app responds

### Requirement: WWW subdomain redirects to apex domain
A proxied CNAME record SHALL exist in Cloudflare DNS: `www.findabed.org` → `findabed.org`. Cloudflare SHALL redirect `www.findabed.org` to `findabed.org` so users who type `www.` reach the correct site.

#### Scenario: WWW redirects to apex
- **WHEN** a browser navigates to `https://www.findabed.org`
- **THEN** the browser is redirected to `https://findabed.org`

#### Scenario: HTTP www redirects to HTTPS apex
- **WHEN** a browser navigates to `http://www.findabed.org`
- **THEN** the browser is redirected to `https://findabed.org`

### Requirement: HTTP requests redirect to HTTPS
All HTTP requests to `findabed.org` SHALL be redirected to HTTPS via Cloudflare's "Always Use HTTPS" setting.

#### Scenario: HTTP to HTTPS redirect
- **WHEN** a browser navigates to `http://findabed.org`
- **THEN** the browser is redirected to `https://findabed.org` with a 301 status

### Requirement: Cloudflare SSL set to Full (Strict)
Cloudflare SSL/TLS mode SHALL be set to "Full (Strict)" to validate the Let's Encrypt origin certificate end-to-end.

#### Scenario: End-to-end TLS verified
- **WHEN** a client connects to `https://findabed.org`
- **THEN** Cloudflare presents its edge certificate to the client AND validates the origin Let's Encrypt certificate

### Requirement: Oracle VM nginx updated for custom domain
The host nginx `server_name` directive SHALL be changed from `*.nip.io` to `findabed.org`. Certbot SHALL issue a new Let's Encrypt certificate for `findabed.org`.

#### Scenario: Certbot certificate issued
- **WHEN** `certbot certonly -d findabed.org` is run on the Oracle VM
- **THEN** a valid Let's Encrypt certificate for `findabed.org` is stored and nginx is configured to use it

#### Scenario: nginx serves the correct domain
- **WHEN** a request arrives with `Host: findabed.org`
- **THEN** nginx matches the server block and proxies to the container stack

### Requirement: CORS origin updated for custom domain
The `FABT_CORS_ALLOWED_ORIGINS` environment variable on the Oracle VM SHALL be set to `https://findabed.org`.

#### Scenario: CORS headers correct
- **WHEN** the frontend at `https://findabed.org` makes an API request to `/api/v1/shelters`
- **THEN** the response includes `Access-Control-Allow-Origin: https://findabed.org`

### Requirement: Certbot auto-renewal works through Cloudflare proxy
Let's Encrypt certificate auto-renewal via Certbot SHALL continue to function with Cloudflare proxying traffic. The HTTP-01 ACME challenge MUST be able to reach the origin through Cloudflare's proxy.

#### Scenario: Certbot dry-run renewal succeeds
- **WHEN** `sudo certbot renew --dry-run` is executed on the Oracle VM
- **THEN** the renewal simulation completes successfully through the Cloudflare proxy

#### Scenario: Automated renewal does not require manual intervention
- **WHEN** the Certbot renewal timer fires (typically every 12 hours)
- **THEN** the certificate is renewed without needing to pause Cloudflare proxy

### Requirement: Domain registered to durable project identity
The domain SHALL be registered using a durable email address and identity associated with the project, not a temporary or personal throwaway account. This ensures continuity if the registrant changes.

#### Scenario: Registration identity is recoverable
- **WHEN** domain management access is needed in the future
- **THEN** the registration email and Namecheap account are accessible to the project lead

### Requirement: nip.io URL remains functional during transition
The existing `150.136.221.232.nip.io` URL SHALL continue to work until DNS propagation is confirmed complete and all stakeholders are notified of the new URL.

#### Scenario: Parallel access during migration
- **WHEN** DNS is propagating for `findabed.org`
- **THEN** the nip.io URL still resolves and serves the app until explicitly decommissioned
