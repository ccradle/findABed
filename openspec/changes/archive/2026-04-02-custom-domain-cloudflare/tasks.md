## 0. Configuration & Domain Selection

All tasks use these variables. Set once, used everywhere:

```bash
# Primary choice — change ONLY this line if domain unavailable
export DOMAIN="findabed.org"

# Fallback order (if primary is taken):
#   1. findabed.org
#   2. findingabed.org
#   3. findabedtonight.org

# Infrastructure (known)
export ORIGIN_IP="150.136.221.232"
export SSH_KEY="~/.ssh/fabt-oracle"
export SSH_CMD="ssh -i $SSH_KEY ubuntu@$ORIGIN_IP"

# Set after account creation (tasks 1.3, 1.7)
export CF_API_TOKEN=""   # Cloudflare API token (Edit zone DNS + Zone Settings: Edit — see task 1.7)
export CF_ZONE_ID=""     # Cloudflare zone ID (shown on domain Overview page after adding zone)
```

- [x] 0.1 Verify primary domain availability: `nslookup $DOMAIN` — "Non-existent domain" means available; if it resolves, change `$DOMAIN` to next fallback and re-run
- [x] 0.2 Confirm domain choice with stakeholders before purchasing (this is a brand decision — Simone's lens)

## 1. Account Setup & Domain Registration

**Manual steps** (first-time only — cannot be automated):

- [x] 1.1 Create Namecheap account at `https://www.namecheap.com/myaccount/signup/` — use a durable project email (not a throwaway), as this controls domain ownership (Casey's lens)
- [x] 1.2 Search for `$DOMAIN` at `https://www.namecheap.com/domains/registration/results/?domain=$DOMAIN` — verify it's available and note the price
- [x] 1.3 Register `$DOMAIN` on Namecheap: 1-year minimum, WhoisGuard enabled (free), auto-renewal ON
- [x] 1.4 Create Cloudflare free-tier account at `https://dash.cloudflare.com/sign-up`
- [x] 1.5 Add `$DOMAIN` as a zone in Cloudflare dashboard (Websites → Add a site → select Free plan); note the assigned nameserver pair
- [x] 1.6 In Namecheap dashboard (Domain List → Manage → Domain tab → Nameservers), change from "Namecheap BasicDNS" to "Custom DNS" and enter the Cloudflare nameserver pair
- [x] 1.7 Create Cloudflare API token: My Profile → API Tokens → Create Token → start from "Edit zone DNS" template, then **add permissions**: Zone Settings: Edit (needed for SSL and HTTPS settings in tasks 2.2–2.4). Scope to zone `$DOMAIN` only. **Do NOT use the Global API Key** — minimum privilege (Marcus Webb's lens). Save the token as `$CF_API_TOKEN`
- [x] 1.8 Copy the Zone ID from Cloudflare domain Overview page → save as `$CF_ZONE_ID`
- [x] 1.9 Wait for Cloudflare dashboard to show zone status as "Active" — verify:

```bash
dig NS $DOMAIN +short
# Expected: Cloudflare nameservers (e.g., ada.ns.cloudflare.com, bob.ns.cloudflare.com)
```

## 2. Cloudflare DNS & SSL Configuration (scripted via API)

- [x] 2.1 Create proxied A record via Cloudflare API:

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$ORIGIN_IP\",\"ttl\":1,\"proxied\":true,\"comment\":\"FABT Oracle VM origin\"}" \
  | python3 -m json.tool
# Verify: "success": true
```

- [x] 2.2 Set SSL mode to Full (strict) via API:

```bash
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value":"strict"}' \
  | python3 -m json.tool
# Verify: "value": "strict"
```

- [x] 2.3 Enable "Always Use HTTPS" via API:

```bash
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/always_use_https" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value":"on"}' \
  | python3 -m json.tool
# Verify: "value": "on"
```

- [x] 2.4 Verify Universal SSL certificate is provisioning (may take up to 24 hours):

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/ssl/verification" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  | python3 -m json.tool
# Look for "certificate_status": "active"
```

- [x] 2.5 Create proxied CNAME for `www` subdomain via API:

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"CNAME\",\"name\":\"www\",\"content\":\"$DOMAIN\",\"ttl\":1,\"proxied\":true,\"comment\":\"WWW redirect to apex\"}" \
  | python3 -m json.tool
# Verify: "success": true
```

- [x] 2.6 Create Cloudflare redirect rule to 301 `www.$DOMAIN` → `https://$DOMAIN`:

```bash
# Create a Single Redirect rule via API
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/rulesets/phases/http_request_dynamic_redirect/entrypoint" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"rules\":[{\"expression\":\"(http.host eq \\\"www.$DOMAIN\\\")\",\"action\":\"redirect\",\"action_parameters\":{\"from_value\":{\"status_code\":301,\"target_url\":{\"expression\":\"concat(\\\"https://$DOMAIN\\\", http.request.uri.path)\"}}},\"description\":\"WWW to apex redirect\"}]}" \
  | python3 -m json.tool
# Verify: "success": true
# Fallback: use Cloudflare dashboard → Rules → Redirect Rules if API payload is rejected
```

- [x] 2.7 Verify DNS resolution returns Cloudflare edge IPs (not origin):

```bash
dig A $DOMAIN +short
# Expected: Cloudflare edge IPs (NOT 150.136.221.232)
nslookup $DOMAIN
# Same verification from a different resolver
```

- [x] 2.8 Verify HTTP→HTTPS redirect:

```bash
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://$DOMAIN
# Expected: 301 https://findabed.org/

curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://www.$DOMAIN
# Expected: 301 https://findabed.org/
```

- [x] 2.9 Verify API responses are not cached by Cloudflare (requires DNS to be live — run after 2.7 confirms resolution):

```bash
curl -s -I "https://$DOMAIN/api/v1/version" | grep -i "cf-cache-status"
# Expected: CF-Cache-Status: DYNAMIC
# If it shows HIT or MISS, create a cache bypass rule:
# curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/rulesets/phases/http_request_cache_settings/entrypoint" \
#   -H "Authorization: Bearer $CF_API_TOKEN" \
#   -H "Content-Type: application/json" \
#   -d '{"rules":[{"expression":"starts_with(http.request.uri.path, \"/api/\")","action":"set_cache_settings","action_parameters":{"cache":false},"description":"Bypass cache for API"}]}'
```

## 3. Oracle VM Domain Cutover

**Pre-flight:** Before modifying the VM, test the new domain against the origin using `--resolve` (bypasses DNS):

```bash
curl -s --resolve "$DOMAIN:443:$ORIGIN_IP" -k "https://$DOMAIN/api/v1/version"
# This sends the request directly to the origin with the new Host header
# Expected: version JSON (proves nginx will accept the new server_name once configured)
```

**Rollback procedure** (if cutover fails): revert `server_name` to the nip.io value, restore old CORS, restart containers. The old Certbot cert is not deleted until task 8.5.

- [x] 3.1 SSH to Oracle VM and update host nginx `server_name`:

```bash
$SSH_CMD "sudo sed -i 's/server_name .*/server_name $DOMAIN;/' /etc/nginx/sites-available/fabt"
$SSH_CMD "sudo nginx -t"  # Verify config syntax
```

- [x] 3.2 Issue Let's Encrypt certificate for `$DOMAIN`:

```bash
$SSH_CMD "sudo certbot certonly --nginx -d $DOMAIN --non-interactive --agree-tos"
```

- [x] 3.3 Update nginx SSL certificate paths (if Certbot doesn't auto-configure):

```bash
$SSH_CMD "sudo sed -i 's|ssl_certificate .*/live/.*/|ssl_certificate /etc/letsencrypt/live/$DOMAIN/|g' /etc/nginx/sites-available/fabt"
$SSH_CMD "sudo nginx -t && sudo systemctl reload nginx"
```

- [x] 3.4 Verify Certbot auto-renewal will work through Cloudflare proxy:

```bash
$SSH_CMD "sudo certbot renew --dry-run"
# Expected: "Congratulations, all simulated renewals succeeded"
# If it fails: HTTP-01 challenge is being blocked — check Cloudflare "Always Use HTTPS" isn't
# redirecting the ACME challenge. May need a Cloudflare page rule to exclude /.well-known/acme-challenge/*

# Also verify the Certbot systemd timer is active:
$SSH_CMD "systemctl list-timers certbot.timer --no-pager"
# Expected: certbot.timer listed with next trigger time
```

- [x] 3.5 Update CORS origin in production env:

```bash
$SSH_CMD "sed -i 's|FABT_CORS_ALLOWED_ORIGINS=.*|FABT_CORS_ALLOWED_ORIGINS=https://$DOMAIN|' ~/fabt-secrets/.env.prod"
$SSH_CMD "grep FABT_CORS ~/fabt-secrets/.env.prod"  # Verify
```

- [x] 3.6 Restart app containers to pick up new CORS:

```bash
$SSH_CMD "cd ~/finding-a-bed-tonight && docker compose --env-file ~/fabt-secrets/.env.prod -f docker-compose.yml -f ~/fabt-secrets/docker-compose.prod.yml up -d"
```

- [x] 3.7 Verify HTTPS works end-to-end:

```bash
# Through Cloudflare
curl -s -o /dev/null -w "%{http_code} %{ssl_verify_result}" https://$DOMAIN
# Expected: 200 0 (200 OK, SSL verified)

# Check certificate chain
echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -subject -issuer
# Expected: subject with findabed.org, issuer from Cloudflare or Let's Encrypt
```

- [x] 3.8 Verify CORS headers:

```bash
curl -s -I -H "Origin: https://$DOMAIN" "https://$DOMAIN/api/v1/version"
# Expected: Access-Control-Allow-Origin: https://findabed.org
```

- [x] 3.9 Check for OAuth2 provider registrations that need redirect URI updates:

```bash
# Query the database for any configured OAuth2 providers
$SSH_CMD "docker exec fabt-postgres psql -U fabt_app -d fabt -c \"SELECT provider_name, redirect_uri FROM tenant_oauth2_provider;\""
# If any rows exist with nip.io redirect URIs:
#   1. Update the FABT database: UPDATE tenant_oauth2_provider SET redirect_uri = 'https://findabed.org/oauth2/callback/' || provider_name WHERE redirect_uri LIKE '%nip.io%';
#   2. Update the external provider console (Google Cloud Console, Azure AD, etc.) with the new redirect URI
# If no rows: no action needed — OAuth2 is not configured on this deployment
```

- [x] 3.10 Verify login flow works — open `https://$DOMAIN` in browser, log in as outreach worker (OAuth2 redirect URIs use `{baseUrl}` so should resolve automatically)

## 4. SSE Cloudflare Compatibility

- [x] 4.1 Add `X-Accel-Buffering: no` response header to SSE endpoint — either in `NotificationController` (Java: `response.setHeader("X-Accel-Buffering", "no")`) or via container nginx location block for `/api/v1/notifications/stream`:

```nginx
location /api/v1/notifications/stream {
    proxy_pass http://backend:8080;
    proxy_set_header X-Accel-Buffering no;
    proxy_buffering off;
    # ... existing proxy headers
}
```

- [x] 4.2 Rebuild and redeploy the affected container (frontend nginx or backend depending on where the header was added)
- [x] 4.3 Verify SSE works through Cloudflare — test with curl:

```bash
# Get an auth token first (login)
TOKEN=$(curl -s -X POST "https://$DOMAIN/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"outreach1","password":"admin123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Connect to SSE stream — should see heartbeats every 20s
curl -N -H "Authorization: Bearer $TOKEN" "https://$DOMAIN/api/v1/notifications/stream"
# Expected: events arriving in real-time, no 100s disconnect
```

- [x] 4.4 Verify SSE connection survives > 100 seconds (let the curl from 4.3 run for 2+ minutes — should see at least 6 heartbeat events without disconnection)

## 5. Static Site Consolidation

- [x] 5.1 On Oracle VM, create directory for static site:

```bash
$SSH_CMD "sudo mkdir -p /var/www/findabed-docs && sudo chown ubuntu:ubuntu /var/www/findabed-docs"
```

- [x] 5.2 Prepare static site locally — copy docs repo content to a build directory, strip `/findABed/` path prefix:

```bash
# Copy to a working directory
cp -r . ./static-site-build/
cd ./static-site-build/

# Replace all /findABed/ path references with / in HTML files
grep -rl '/findABed/' --include='*.html' . | xargs sed -i 's|/findABed/|/|g'

# Verify no references remain
grep -r '/findABed/' --include='*.html' .
# Expected: no output
```
- [x] 5.3 Update all `og:url` meta tags from `https://ccradle.github.io/findABed/` to `https://$DOMAIN/`
- [x] 5.4 Update all `og:image` meta tags to reference `https://$DOMAIN/` paths
- [x] 5.5 Deploy static site to Oracle VM:

```bash
rsync -avz --delete \
  -e "ssh -i $SSH_KEY" \
  ./static-site-build/ \
  ubuntu@$ORIGIN_IP:/var/www/findabed-docs/
```

- [x] 5.6 Configure host nginx routing — decide URL structure and add location blocks. Recommended layout:

```nginx
# Static landing/about pages
location / {
    root /var/www/findabed-docs;
    try_files $uri $uri/ @app;
}

# Fallthrough to React SPA (app)
location @app {
    proxy_pass http://127.0.0.1:8081;
    # ... existing proxy headers
}
```

- [x] 5.7 Reload nginx and verify:

```bash
$SSH_CMD "sudo nginx -t && sudo systemctl reload nginx"

# Test static page
curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN/
# Expected: 200

# Test app routes still work
curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN/api/v1/version
# Expected: 200
```

- [x] 5.8 Verify in browser: static pages load with correct styling/images, app login works, API calls succeed
- [x] 5.9 Leave GitHub Pages at `ccradle.github.io/findABed/` unchanged (no CNAME file added)

## 6. Origin Security Lockdown (scripted)

- [x] 6.1 Fetch current Cloudflare IP ranges and generate security list JSON:

```bash
# Fetch ranges
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4/)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6/)

echo "=== Cloudflare IPv4 ranges ==="
echo "$CF_IPV4"
echo "=== Cloudflare IPv6 ranges ==="
echo "$CF_IPV6"

# Save for documentation
echo "$CF_IPV4" > cloudflare-ipv4-ranges.txt
echo "$CF_IPV6" > cloudflare-ipv6-ranges.txt
date >> cloudflare-ipv4-ranges.txt
```

- [x] 6.2 **Preferred: Oracle Cloud security list** (cloud-level firewall, survives VM reboot, no iptables risk). If OCI CLI is available:

```bash
# Get security list OCID
oci network security-list list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[0].id' --raw-output

# Generate ingress rules template
oci network security-list update --generate-param-json-input ingress-security-rules > ingress-rules-template.json

# Edit to include: one rule per Cloudflare CIDR for ports 80+443, plus SSH rule for admin IP
# WARNING: this REPLACES all ingress rules — include SSH rule or you lose access
# Apply:
oci network security-list update \
  --security-list-id $SECURITY_LIST_ID \
  --ingress-security-rules file://ingress-rules.json \
  --force
```

If OCI CLI is unavailable, use Oracle Cloud Console: Networking → VCN → Security Lists → edit ingress rules manually.

**Fallback only: iptables** (CAUTION — do NOT flush the INPUT chain, it will lock you out):

```bash
# FIRST: check for existing broad ACCEPT rules on 80/443 that would override new DROPs
$SSH_CMD "sudo iptables -L INPUT -n --line-numbers | grep -E '(80|443)'"
# If a broad ACCEPT like "0.0.0.0/0 tcp dpt:443 ACCEPT" exists, delete it first:
# $SSH_CMD "sudo iptables -D INPUT <line-number>"

# Safe approach: insert DROP rules AFTER existing ACCEPT rules for SSH, loopback, established
$SSH_CMD 'bash -s' << 'SCRIPT'
# Preserve existing rules — only add Cloudflare restrictions for 80/443
for cidr in $(curl -s https://www.cloudflare.com/ips-v4/); do
    sudo iptables -I INPUT -p tcp --dport 80 -s $cidr -j ACCEPT
    sudo iptables -I INPUT -p tcp --dport 443 -s $cidr -j ACCEPT
done
# Drop non-Cloudflare HTTP/HTTPS ONLY (does not affect SSH, loopback, or established connections)
sudo iptables -A INPUT -p tcp --dport 80 -j DROP
sudo iptables -A INPUT -p tcp --dport 443 -j DROP
sudo netfilter-persistent save
SCRIPT
```

- [x] 6.3 Verify SSH still works after lockdown:

```bash
$SSH_CMD "echo 'SSH OK: $(hostname) $(uptime)'"
```

- [x] 6.4 Verify Cloudflare-proxied traffic still works:

```bash
curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN
# Expected: 200
```

- [x] 6.5 Verify direct-to-origin is blocked (run from a non-Cloudflare, non-admin IP):

```bash
curl -s --connect-timeout 5 -k https://$ORIGIN_IP
# Expected: connection timeout or refused
```

## 7. Documentation Updates

- [x] 7.1 Update `oracle-demo-runbook-v0.21.0.md`: replace all `YOUR_IP.nip.io` references with `$DOMAIN` pattern and add Cloudflare setup section
- [x] 7.2 Update `launch-fabt.sh` line 57 — change demo URL output:

```bash
# From: echo "Demo URL:     https://${PUBLIC_IP}.nip.io"
# To:   echo "Demo URL:     https://findabed.org"
```

- [x] 7.3 Update `finding-a-bed-tonight/docs/oracle-update-notes-v0.27.0.md`: replace nip.io verification URLs with `$DOMAIN`
- [x] 7.4 Update project memory file `project_live_deployment_status.md`: change URL to `https://$DOMAIN`
- [x] 7.5 Clean up stale files from docs repo root: remove `150.136.221.232.nip.io.har` and related `.log` files

## 8. Verification & Decommission (Riley's lens)

- [x] 8.1 Automated infrastructure verification:

```bash
echo "=== 1. Version endpoint ===" 
curl -s https://$DOMAIN/api/v1/version | python3 -m json.tool
# PASS: returns {"version":"0.27"} or current version

echo "=== 2. Cloudflare proxy active ==="
curl -s -I https://$DOMAIN | grep -i "cf-ray\|server: cloudflare"
# PASS: "server: cloudflare" and "cf-ray:" header present

echo "=== 3. SSL certificate chain ==="
echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -subject -issuer -dates
# PASS: valid dates, issuer is Cloudflare Inc or Let's Encrypt

echo "=== 4. CORS ==="
curl -s -I -H "Origin: https://$DOMAIN" "https://$DOMAIN/api/v1/shelters" | grep -i access-control
# PASS: Access-Control-Allow-Origin: https://findabed.org

echo "=== 5. HTTP→HTTPS redirect ==="
curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN
# PASS: 301

echo "=== 6. WWW redirect ==="
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://www.$DOMAIN
# PASS: 301 to https://findabed.org

echo "=== 7. API not cached by Cloudflare ==="
curl -s -I "https://$DOMAIN/api/v1/version" | grep -i "cf-cache-status"
# PASS: CF-Cache-Status: DYNAMIC

echo "=== 8. Origin lockdown ==="
curl -s --connect-timeout 5 -k "https://$ORIGIN_IP" 2>&1
# PASS: connection timeout or refused

echo "=== 9. Static asset cached at edge ==="
# Request twice — first primes cache, second should be HIT
curl -s -o /dev/null "https://$DOMAIN/favicon.svg"
curl -s -I "https://$DOMAIN/favicon.svg" | grep -i "cf-cache-status"
# PASS: CF-Cache-Status: HIT (or REVALIDATED)
```

- [x] 8.2 DV canary test at new domain — verify DV shelter data is invisible to non-DV users:

```bash
# Login as regular outreach worker (no DV access)
TOKEN=$(curl -s -X POST "https://$DOMAIN/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"outreach1","password":"admin123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Search shelters — DV shelters must NOT appear
curl -s -H "Authorization: Bearer $TOKEN" "https://$DOMAIN/api/v1/shelters" | python3 -c "
import sys, json
shelters = json.load(sys.stdin)
dv = [s for s in shelters if s.get('isDomesticViolence')]
print(f'DV shelters visible: {len(dv)} — {\"FAIL\" if dv else \"PASS\"}')"
```

- [x] 8.3 PWA service worker verification:

```bash
# Check that SW registers on new domain
curl -s "https://$DOMAIN/sw.js" -o /dev/null -w "%{http_code}"
# PASS: 200 (service worker file exists and is served)

# Check manifest
curl -s "https://$DOMAIN/manifest.webmanifest" | python3 -m json.tool
# PASS: start_url is "/" or relative (not an absolute nip.io URL)
```

- [x] 8.4 Latency baseline through Cloudflare (Sam's lens) — compare with pre-Cloudflare baseline:

```bash
# Run 10 requests, report timing
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "%{time_total}\n" "https://$DOMAIN/api/v1/shelters"
done
# Compare with direct-to-origin baseline (before lockdown blocks it)
# Flag if p95 exceeds 500ms SLO threshold
```

- [x] 8.5 Manual browser testing at `https://$DOMAIN` — covers visual/UX checks that Playwright cannot automate (rendering quality, dark mode appearance, Spanish label accuracy). Automated functional coverage is in 8.6. Pass/fail checklist:
  - Login as outreach worker → search beds → hold a bed → confirm hold timer visible → cancel hold
  - Login as coordinator → update bed count → verify success confirmation → verify hold count read-only
  - Login as admin → admin panel loads → user management → shelter management
  - SSE: trigger a bed update from coordinator, verify outreach worker sees real-time notification
  - Dark mode toggle → all pages render correctly
  - Spanish language toggle → labels switch to Spanish
  - DV referral flow (login as dv-outreach) → referral request → coordinator screening

- [x] 8.6 Run Playwright E2E suite against new domain (if BASE_URL is configurable):

```bash
cd finding-a-bed-tonight && BASE_URL=https://$DOMAIN npx playwright test --trace on 2>&1 | tee logs/playwright-domain-migration.log
```

- [x] 8.7 Verify Grafana and observability stack still receive metrics (management port 9091 is separate from HTTP):

```bash
$SSH_CMD "curl -s localhost:9091/actuator/prometheus | head -5"
# PASS: Prometheus metrics returned (management port unaffected by Cloudflare/firewall changes)
```

- [x] 8.8 Verify Cloudflare analytics (dashboard → Analytics): confirm traffic flowing through proxy
- [x] 8.9 Verify Cloudflare SSL report (dashboard → SSL/TLS → Overview): Full (strict), valid origin cert
- [x] 8.10 **SECURITY:** Rotate Cloudflare API token — the token was exposed in this conversation. Go to Cloudflare → My Profile → API Tokens → Roll the `findabed.org` token. Update your local `$CF_API_TOKEN` if you plan to reuse it.
- [x] 8.11 Decide: decommission nip.io URL or keep as fallback. If decommissioning:

```bash
$SSH_CMD "sudo certbot delete --cert-name $ORIGIN_IP.nip.io"
# Remove old server block if separate from the updated one
```

## 9. Domain Setup Guide

- [x] 9.1 Create `domain-setup-guide.md` in docs repo — structure: Prerequisites → Account Setup → Cloudflare API Configuration → VM Cutover → SSE Configuration → Origin Lockdown → Verification Checklist
- [x] 9.2 Document Namecheap registration steps with specific UI navigation paths
- [x] 9.3 Document Cloudflare setup: zone creation, API token creation, all API commands from tasks 2.1–2.4 as a runnable script
- [x] 9.4 Document Oracle VM cutover steps as a runnable script (tasks 3.1–3.8)
- [x] 9.5 Document SSE Cloudflare configuration: header requirement, heartbeat rationale (20s < 100s), verification commands
- [x] 9.6 Document origin lockdown: Cloudflare IP ranges, iptables/OCI CLI commands, update process
- [x] 9.7 Add "Lessons Learned" section — populated with gotchas encountered during tasks 1–8 (do NOT write speculatively; only document what actually happened)
- [x] 9.8 Review guide for accuracy — re-run every scripted command in the guide against the live setup and verify outputs match
