## Context

The FABT demo runs at `150.136.221.232.nip.io` on an Oracle Always Free ARM64 VM (4 OCPU, 24GB RAM). The static project site lives separately at `ccradle.github.io/findABed/`. This creates two problems: (1) the IP-based URL is unprofessional for stakeholder demos, grant conversations, and city adoption discussions, and (2) the Oracle VM is exposed directly to the internet with no CDN, DDoS protection, or WAF.

The codebase is fully environment-driven for domain configuration — zero hardcoded domains in source code. Domain migration is purely an ops-side change. The Oracle VM uses a two-layer nginx architecture: host nginx (TLS termination via Let's Encrypt) → container nginx (SPA routing, API proxy, security headers) → Spring Boot backend.

## Goals / Non-Goals

**Goals:**
- Register `findabed.org` and make the live demo accessible at `https://findabed.org`
- Add Cloudflare as CDN/DNS/WAF/DDoS proxy in front of the Oracle VM
- Consolidate GitHub Pages static content onto the Oracle VM, serving everything from one domain
- Lock down the Oracle VM to accept HTTP/HTTPS only from Cloudflare IP ranges
- Ensure SSE bed availability streams work correctly through Cloudflare's proxy
- Document the entire process as a reproducible guide with lessons learned

**Non-Goals:**
- Migrating to a different hosting provider (Oracle Always Free is the target)
- Setting up a staging/test environment (separate concern)
- Changing the project name or branding beyond the domain (Simone's naming exploration is separate)
- Email hosting on the domain (future consideration)
- Multi-domain or multi-environment DNS (only production domain for now)
- Modifying the GitHub Pages site to continue working at `ccradle.github.io/findABed/` — GitHub will auto-redirect if a CNAME is set, but we're consolidating to Oracle instead

## Decisions

### D1: Domain name — `findabed.org`

**Decision:** Register `findabed.org` as the primary domain.

**Alternatives considered:**
- `findabedtonight.org` — exact project name match, but too long for URLs, email, printed materials
- `findingabed.org` — available but less punchy; `findabed` is the natural abbreviation
- `findabed.com` — taken (resolves to Linode IPs behind Cloudflare)

**Rationale:** Short, memorable, speakable. `.org` signals nonprofit/civic mission — aligned with Teresa's procurement expectations and Priya's funding positioning. Passes Simone's hallway pitch test.

**Fallback order:** If `findabed.org` is taken at registration time: `findingabed.org` → `findabedtonight.org`. All tasks are parameterized via a single `$DOMAIN` variable — changing the domain requires updating one line, not find-and-replace across 40+ tasks.

### D2: Consolidated architecture — everything on Oracle VM

**Decision:** Serve both the static site (currently GitHub Pages) and the app from the Oracle VM behind a single nginx instance and Cloudflare proxy.

**Alternatives considered:**
- Split: GitHub Pages for docs (`docs.findabed.org`) + Oracle for app (`findabed.org`) — requires gray-cloud DNS for GitHub Pages to avoid TLS chicken-and-egg with Cloudflare, which leaks a DNS record outside Cloudflare proxy
- Subdomain split: `findabed.org` → docs, `app.findabed.org` → app — confusing for users

**Rationale:** One server, one nginx, one SSL config, one Cloudflare proxy setup. The Oracle VM has ample headroom (4 OCPU, 24GB) for serving static HTML alongside the app. Avoids the Cloudflare + GitHub Pages TLS provisioning complexity. Marcus Webb prefers everything proxied consistently — no gray-cloud records leaking the origin IP.

### D3: SSL strategy — Cloudflare Full (Strict) + Let's Encrypt origin cert

**Decision:** Use Cloudflare's Full (Strict) SSL mode. Keep Let's Encrypt/Certbot on the origin for the origin certificate. Cloudflare provides the edge certificate to visitors.

**Alternatives considered:**
- Cloudflare Origin CA certificate — free, 15-year validity, but only trusted by Cloudflare (not direct visitors). Would break direct-to-origin access for SSH-tunneled debugging.
- Full (not strict) — works but doesn't validate the origin certificate, weaker security posture

**Rationale:** Full (Strict) validates the origin cert end-to-end. Let's Encrypt is already configured and auto-renews via Certbot. No reason to change what works.

### D4: SSE through Cloudflare — header fix, not gray-cloud bypass

**Decision:** Add `X-Accel-Buffering: no` response header on SSE endpoints. Keep SSE traffic proxied through Cloudflare (orange cloud).

**Alternatives considered:**
- Gray-cloud (DNS-only) for an SSE-specific subdomain (e.g., `sse.findabed.org`) — exposes the origin IP, undermining origin lockdown
- Cloudflare Tunnel — adds operational complexity (cloudflared daemon), overkill for this use case

**Rationale:** The existing 20-second heartbeat already satisfies Cloudflare's 100-second idle timeout requirement. Adding the `X-Accel-Buffering: no` header prevents Cloudflare's internal nginx from buffering SSE chunks. Marcus Webb confirmed: keeping everything behind the proxy is the correct security posture.

### D4b: WWW subdomain — CNAME redirect to apex

**Decision:** Add a proxied CNAME record `www.findabed.org` → `findabed.org` with a Cloudflare redirect rule to 301 all `www` traffic to the apex domain.

**Rationale:** Users habitually type `www.` — Simone flags this as a brand baseline. Marcus Webb notes that unresolved subdomains can be hijacked for phishing. Costs nothing, prevents confusion.

### D5: Origin lockdown — Oracle Cloud security list rules

**Decision:** Modify the Oracle Cloud security list (or use iptables on the VM) to restrict ingress on ports 80/443 to Cloudflare's published IP ranges only. SSH (port 22) restricted to the admin's IP.

**Alternatives considered:**
- Cloudflare Tunnel — eliminates public IP entirely, but requires cloudflared daemon and adds operational complexity
- Authenticated Origin Pulls (mTLS) — Cloudflare presents a client cert, origin validates. More secure but more complex to configure with the existing host nginx setup.

**Rationale:** IP-based restriction is the simplest effective approach. Cloudflare publishes their IP ranges and they rarely change. This prevents direct-to-origin attacks that bypass Cloudflare's WAF/DDoS protection. Can be upgraded to Authenticated Origin Pulls later if needed.

### D6: Static site deployment — rsync from local build

**Decision:** Copy the built static site (HTML, CSS, JS, images) from the docs repo to the Oracle VM via rsync/scp. Nginx serves it from a directory (e.g., `/var/www/findabed-docs/`). The app frontend continues to be served by the container nginx on port 8081.

**Alternatives considered:**
- CI/CD pipeline (GitHub Actions → VM) — overkill for a docs site that changes infrequently
- Git clone on VM — adds git dependency and SSH key management on the server

**Rationale:** The static site changes rarely. Manual rsync is simple and sufficient. The host nginx routes: `/` → static site, `/app` or root SPA → container nginx (port 8081), `/api` → proxied through container nginx to backend.

**URL structure decision:** The app frontend (React SPA) is the primary product. Static site content (about, screenshots, demo) serves as landing/marketing pages. Two options:
- `findabed.org/` → static landing, `findabed.org/app/` → React SPA
- `findabed.org/` → React SPA (login), `findabed.org/about/` → static pages

This will be finalized during implementation based on what feels right for the demo flow.

## Risks / Trade-offs

**[Risk] DNS propagation delay** → Mitigation: Keep nip.io working in parallel until DNS fully propagates (up to 48 hours). Test with `curl --resolve` before switching.

**[Risk] SSE buffering despite header** → Mitigation: Cloudflare community reports confirm `X-Accel-Buffering: no` works. Test with a real SSE connection through Cloudflare immediately after setup. Fallback: gray-cloud a dedicated SSE subdomain if header approach fails.

**[Risk] Cloudflare IP ranges change** → Mitigation: Ranges change infrequently and are published in advance. Add a periodic check (manual or scripted) to verify security list rules match current ranges. Document the update process in the guide.

**[Risk] Oracle VM downtime takes down both app and docs** → Mitigation: Acceptable for a demo/portfolio project. Cloudflare's "Always Online" feature (free tier) can serve cached static pages during brief outages.

**[Risk] Let's Encrypt renewal through Cloudflare proxy** → Mitigation: Certbot HTTP-01 challenge goes through Cloudflare. With Full (Strict) mode enabled, the challenge should pass since Cloudflare forwards HTTP requests to origin. If renewal fails, temporarily pause Cloudflare proxy (gray-cloud) for the renewal. Document in the guide.

**[Risk] Origin IP historically exposed** → Mitigation: The IP `150.136.221.232` is baked into the `nip.io` domain name, HAR files, log files, and public DNS history. It cannot be "hidden." Origin lockdown (Cloudflare IP restriction) makes it unreachable on HTTP/HTTPS even if known. This is a "known and mitigated" risk, not an unaddressed gap. Marcus Webb confirms: IP-based firewall is sufficient when combined with the existing security posture.

**[Risk] iptables flush locks out SSH** → Mitigation: The iptables script MUST NOT use `iptables -F INPUT` (flushes all rules). Must preserve established connections, loopback, and ICMP. Use Oracle Cloud security lists (cloud-level firewall) as primary approach — iptables only as fallback, with careful rule insertion rather than chain flush.

**[Risk] PWA service worker stale on domain change** → Mitigation: Service workers are scoped to their origin. The nip.io SW is orphaned and does not affect the new domain. Users accessing the new domain get a fresh SW registration. No action needed — just verify during testing.

**[Risk] GitHub Pages path prefix breakage** → Mitigation: Not applicable — we're not keeping GitHub Pages with a custom domain. The static content is being copied to the VM. The original `ccradle.github.io/findABed/` URL can remain as-is or be updated later.

### D7: Automation strategy — Cloudflare API + scripted verification

**Decision:** Use the Cloudflare REST API (curl + API token) for all DNS and SSL configuration after initial account creation. Use scripted `curl`/`dig`/`openssl` commands for all verification steps. Use OCI CLI or iptables scripts for origin lockdown.

**Alternatives considered:**
- Dashboard-only (clicking through UI) — not repeatable, not documentable as a runbook for other CoC deployments
- Terraform Cloudflare provider — overkill for a single-zone free-tier setup; adds a dependency
- `flarectl` CLI — less widely documented than raw API; adds a binary dependency

**Rationale:** Raw API calls via curl are universally available, copy-pasteable into the domain setup guide, and require no additional tooling. Every automated step is both an execution step and documentation for the guide (task group 9). Manual steps are limited to: account creation (payment), Namecheap nameserver delegation (no API for first-time), and browser-based smoke testing.
