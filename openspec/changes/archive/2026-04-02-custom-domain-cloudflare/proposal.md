## Why

The live demo at `${FABT_VM_IP}.nip.io` lacks a professional, memorable URL for stakeholder demos, grant conversations, and city adoption discussions. A proper domain (`findabed.org`) signals permanence and credibility — Simone's "hallway pitch" test fails with an IP-based URL, Teresa's procurement team won't evaluate a nip.io address, and Priya can't put it in a grant narrative. Additionally, the Oracle VM is currently exposed directly to the internet with no CDN, DDoS protection, or WAF — gaps Marcus Webb flagged. The GitHub Pages static site at `ccradle.github.io/findABed/` is separate from the app, creating a split brand presence.

## What Changes

- Register `findabed.org` domain on Namecheap with free WhoisGuard privacy
- Create Cloudflare free account and configure as DNS/CDN/WAF proxy for the domain
- Consolidate the GitHub Pages static site onto the Oracle VM nginx, serving everything from one domain
- Configure Cloudflare SSL (Full strict) with existing Let's Encrypt origin certificate
- Add SSE compatibility headers (`X-Accel-Buffering: no`) to prevent Cloudflare proxy buffering on bed availability SSE streams (existing 20-second heartbeat already satisfies the 100-second idle timeout)
- Lock down Oracle Cloud security lists to accept HTTP/HTTPS traffic only from Cloudflare IP ranges (plus SSH from admin IP)
- Configure `www.findabed.org` redirect to apex domain
- Update Oracle VM configuration: nginx `server_name`, Certbot certificate, CORS env var
- Update runbook and deployment documentation for the new domain
- Produce a domain setup guide documenting lessons learned during execution

## Capabilities

### New Capabilities
- `custom-domain-dns`: Namecheap domain registration, Cloudflare DNS/CDN/WAF configuration, SSL setup, and Oracle VM domain cutover
- `static-site-consolidation`: Migrate GitHub Pages static content to Oracle VM nginx, serving docs/landing page and app from one domain
- `origin-security-lockdown`: Restrict Oracle Cloud ingress to Cloudflare IP ranges only, hiding origin IP from direct access
- `domain-setup-guide`: Lessons-learned guide produced during execution, documenting the full domain registration + Cloudflare + deployment process for reproducibility

### Modified Capabilities
- `sse-notifications`: Add `X-Accel-Buffering: no` response header to SSE endpoints for Cloudflare proxy compatibility (existing 20-second heartbeat is already sufficient)

## Impact

- **Infrastructure (Oracle VM):** Host nginx config, Certbot cert, CORS env var, Oracle Cloud security lists
- **Backend code:** SSE controller — add response header and heartbeat interval
- **Frontend/static site:** GitHub Pages content copied to Oracle VM; `og:url` meta tags updated; `/findABed/` path prefix removed since content moves to domain root
- **Documentation:** Runbook, update notes, launch script — all `nip.io` references updated
- **DNS/External:** Namecheap account, Cloudflare account, DNS propagation, `www` subdomain redirect, API cache bypass verification
- **No breaking changes to API contracts, database schema, or authentication flows** — the codebase is fully environment-driven for domain configuration
