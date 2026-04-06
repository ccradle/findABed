# FABT Domain Setup Guide — Namecheap + Cloudflare + Oracle Cloud

**Version:** April 2026
**Applies to:** Any FABT deployment on Oracle Cloud (or similar VPS) behind Cloudflare
**Reference deployment:** `findabed.org` on Oracle Always Free ARM64

---

## Prerequisites

- A running FABT deployment on a VPS with a public IP address
- SSH access to the server
- nginx as the host reverse proxy with Let's Encrypt/Certbot
- The FABT container stack running (backend, frontend, postgres)
- A credit/debit card for domain registration (~$7–15/year for .org)

## Variables

Set these once — every command in this guide uses them:

```bash
export DOMAIN="findabed.org"          # Your chosen domain
export ORIGIN_IP="${FABT_VM_IP}"    # Your server's public IP
export SSH_KEY="~/.ssh/fabt-oracle"   # Path to your SSH key
export SSH_CMD="ssh -i $SSH_KEY ubuntu@$ORIGIN_IP"

# Set after Cloudflare account creation (Section 2):
export CF_API_TOKEN=""                # Cloudflare API token (Edit zone DNS + Zone Settings: Edit)
export CF_ZONE_ID=""                  # Cloudflare zone ID (hex string from Overview page)
```

---

## 1. Domain Registration (Namecheap)

### 1.1 Verify domain availability

```bash
nslookup $DOMAIN
# "Non-existent domain" = available
# If it resolves, the domain is taken — choose another
```

### 1.2 Create Namecheap account

1. Go to `https://www.namecheap.com/myaccount/signup/`
2. Use a **durable email** (not a throwaway) — this controls domain ownership
3. Add a payment method

### 1.3 Register the domain

1. Search for your domain at `https://www.namecheap.com/domains/registration/results/?domain=YOUR_DOMAIN`
2. Add to cart, checkout with:
   - **Registration period:** 1 year minimum
   - **WhoisGuard:** Enabled (free — hides personal info from WHOIS)
   - **Auto-renewal:** ON

---

## 2. Cloudflare Setup

### 2.1 Create Cloudflare account

1. Go to `https://dash.cloudflare.com/sign-up`
2. Free tier — no payment required
3. Skip any onboarding wizards to reach the main dashboard

### 2.2 Add domain to Cloudflare

1. Dashboard → **Add a site** (or "Onboard a domain")
2. Enter your domain name
3. Select **"Import DNS automatically"** (it may find default records from your registrar)
4. Select the **Free** plan
5. Cloudflare assigns a **nameserver pair** (e.g., `dell.ns.cloudflare.com`, `matt.ns.cloudflare.com`)

### 2.3 Delegate nameservers from Namecheap

1. In Namecheap: **Domain List → Manage → Domain tab → Nameservers**
2. Change from "Namecheap BasicDNS" to **"Custom DNS"**
3. Enter the two Cloudflare nameservers
4. Save (green checkmark)
5. Back in Cloudflare, click "Done, check nameservers"
6. Wait for zone status to show **"Active"** (minutes to hours)

Verify:
```bash
nslookup $DOMAIN 1.1.1.1
# Should return Cloudflare edge IPs (not your origin IP)
```

### 2.4 Create Cloudflare API token

1. My Profile → API Tokens → **Create Token**
2. Start from **"Edit zone DNS"** template
3. **Add permission:** Zone Settings → Edit (needed for SSL/HTTPS settings)
4. Scope to: **Specific zone → your domain only**
5. **Do NOT use the Global API Key** — minimum privilege
6. Save the token as `$CF_API_TOKEN`
7. Copy the Zone ID from the domain Overview page → save as `$CF_ZONE_ID`

### 2.5 Clean up default DNS records

Cloudflare may import default records from your registrar (parking pages, email forwarding). List them:

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for r in data.get('result', []):
    print(f\"{r['type']:6} {r['name']:30} -> {r['content']:40} id={r['id']}\")
"
```

Delete any parking/default A records that point to your registrar (not your origin IP):

```bash
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/RECORD_ID_HERE" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

### 2.6 Configure DNS records via API

**A record** (proxied — routes traffic through Cloudflare):
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$ORIGIN_IP\",\"ttl\":1,\"proxied\":true,\"comment\":\"FABT origin\"}" \
  | python3 -m json.tool
```

**WWW CNAME** (update existing or create new):
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"CNAME\",\"name\":\"www\",\"content\":\"$DOMAIN\",\"ttl\":1,\"proxied\":true,\"comment\":\"WWW redirect to apex\"}" \
  | python3 -m json.tool
```

### 2.7 Configure SSL and HTTPS via API

**Set SSL to Full (strict):**
```bash
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value":"strict"}' \
  | python3 -m json.tool
```

**Enable Always Use HTTPS:**
```bash
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/always_use_https" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value":"on"}' \
  | python3 -m json.tool
```

### 2.8 Create WWW redirect rule

In the Cloudflare dashboard (API requires additional permissions):

1. Go to **Rules → Redirect Rules → Create rule**
2. Rule name: `WWW to apex redirect`
3. When: Hostname equals `www.YOUR_DOMAIN`
4. Then: Static redirect → `https://YOUR_DOMAIN` → Status: **301** → Preserve path suffix
5. Deploy

### 2.9 Verify

```bash
# DNS resolves to Cloudflare edge IPs
nslookup $DOMAIN 1.1.1.1

# HTTP redirects to HTTPS
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://$DOMAIN
# Expected: 301 https://YOUR_DOMAIN/

# WWW redirects to apex
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://www.$DOMAIN
# Expected: 301 https://YOUR_DOMAIN/

# API responses are not cached
curl -s -I "https://$DOMAIN/api/v1/version" | grep -i "cf-cache-status"
# Expected: CF-Cache-Status: DYNAMIC
```

---

## 3. Oracle VM Domain Cutover

### 3.1 Pre-flight test

Before modifying the VM, test the new domain against the origin using `--resolve` (bypasses DNS):

```bash
curl -s --resolve "$DOMAIN:443:$ORIGIN_IP" -k "https://$DOMAIN/api/v1/version"
# Expected: version JSON
```

### 3.2 Update nginx server_name

```bash
$SSH_CMD "sudo sed -i 's/server_name .*/server_name $DOMAIN;/' /etc/nginx/sites-available/fabt"
$SSH_CMD "sudo nginx -t"  # Verify syntax
```

### 3.3 Issue Let's Encrypt certificate

```bash
$SSH_CMD "sudo certbot certonly --nginx -d $DOMAIN --non-interactive --agree-tos"
```

### 3.4 Update nginx SSL paths and reload

```bash
$SSH_CMD "sudo sed -i 's|ssl_certificate .*/live/.*/|ssl_certificate /etc/letsencrypt/live/$DOMAIN/|g' /etc/nginx/sites-available/fabt"
$SSH_CMD "sudo nginx -t && sudo systemctl reload nginx"
```

### 3.5 Verify Certbot auto-renewal

```bash
$SSH_CMD "sudo certbot renew --dry-run"
# Expected: "Congratulations, all simulated renewals succeeded"

$SSH_CMD "systemctl list-timers certbot.timer --no-pager"
# Expected: certbot.timer listed with next trigger time
```

If the dry-run fails, the HTTP-01 challenge may be blocked by Cloudflare's "Always Use HTTPS." Create a Cloudflare page rule to exclude `/.well-known/acme-challenge/*` from HTTPS redirect.

### 3.6 Update CORS

Find where CORS is configured (env file or docker-compose override):

```bash
$SSH_CMD "grep -r CORS ~/fabt-secrets/"
```

Update to your domain:

```bash
# If in docker-compose.prod.yml:
$SSH_CMD "sed -i 's|FABT_CORS_ALLOWED_ORIGINS:.*|FABT_CORS_ALLOWED_ORIGINS: https://$DOMAIN|' ~/fabt-secrets/docker-compose.prod.yml"

# If in .env.prod:
$SSH_CMD "sed -i 's|FABT_CORS_ALLOWED_ORIGINS=.*|FABT_CORS_ALLOWED_ORIGINS=https://$DOMAIN|' ~/fabt-secrets/.env.prod"
```

### 3.7 Restart containers

```bash
$SSH_CMD "cd ~/finding-a-bed-tonight && docker compose --env-file ~/fabt-secrets/.env.prod -f docker-compose.yml -f ~/fabt-secrets/docker-compose.prod.yml up -d"
```

### 3.8 Verify

```bash
# HTTPS through Cloudflare
curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN
# Expected: 200

# Certificate chain
echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -subject -issuer
# Expected: subject=CN=YOUR_DOMAIN

# CORS
curl -s -I -X OPTIONS -H "Origin: https://$DOMAIN" -H "Access-Control-Request-Method: GET" "https://$DOMAIN/api/v1/version" | grep -i access-control-allow-origin
# Expected: Access-Control-Allow-Origin: https://YOUR_DOMAIN
```

### 3.9 Rollback procedure

If the cutover fails, revert on the VM:

```bash
$SSH_CMD "sudo cp /etc/nginx/sites-available/fabt.bak /etc/nginx/sites-available/fabt"
$SSH_CMD "sudo nginx -t && sudo systemctl reload nginx"
# Restore old CORS value and restart containers
```

---

## 4. SSE Cloudflare Configuration

Cloudflare's proxy can buffer Server-Sent Events, breaking real-time bed availability updates. Two fixes are required:

### 4.1 Add X-Accel-Buffering header

**In the backend** (`NotificationController.java`):
```java
@GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public SseEmitter stream(Authentication auth, ..., HttpServletResponse response) {
    response.setHeader("X-Accel-Buffering", "no");
    // ...
}
```

**In the container nginx** (SSE location block):
```nginx
location /api/v1/notifications/stream {
    proxy_pass http://backend:8080;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 86400s;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding off;
    add_header X-Accel-Buffering "no" always;
}
```

Both are needed: the backend sets the header, but nginx strips `X-Accel-*` headers by default. The `add_header` in the nginx location block ensures it reaches Cloudflare.

### 4.2 Heartbeat keeps the connection alive

Cloudflare terminates idle connections after 100 seconds. FABT's SSE heartbeat fires every 20 seconds — well within the limit. No configuration change needed, but if you modify the heartbeat interval, keep it under 90 seconds.

### 4.3 Verify SSE through Cloudflare

```bash
TOKEN=$(curl -s -X POST "https://$DOMAIN/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"outreach@dev.fabt.org","password":"admin123","tenantSlug":"dev-coc"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

curl -s -N -H "Authorization: Bearer $TOKEN" "https://$DOMAIN/api/v1/notifications/stream" --max-time 45
# Expected: connected event immediately, heartbeat events every 20 seconds
```

---

## 5. Origin Security Lockdown

Restrict HTTP/HTTPS traffic to Cloudflare IPs only — prevents direct-to-origin attacks that bypass the WAF.

### 5.1 Fetch Cloudflare IP ranges

```bash
curl -s https://www.cloudflare.com/ips-v4/
curl -s https://www.cloudflare.com/ips-v6/
```

### 5.2 Check existing firewall rules

```bash
$SSH_CMD "sudo iptables -L INPUT -n --line-numbers | head -20"
```

Look for broad ACCEPT rules on ports 80/443 (e.g., `0.0.0.0/0 tcp dpt:443 ACCEPT`). These need to be replaced with Cloudflare-specific rules.

### 5.3 Apply Cloudflare IP restrictions

```bash
$SSH_CMD 'bash -s' << 'SCRIPT'
# Delete existing broad 80/443 rules
sudo iptables -D INPUT -p tcp --dport 443 -m state --state NEW -j ACCEPT
sudo iptables -D INPUT -p tcp --dport 80 -m state --state NEW -j ACCEPT

# Insert Cloudflare-specific rules (before the REJECT rule)
POS=5  # Adjust based on your rule numbering
for cidr in 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 \
  141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 \
  197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 \
  104.24.0.0/14 172.64.0.0/13 131.0.72.0/22; do
    sudo iptables -I INPUT $POS -p tcp -m multiport --dports 80,443 -s $cidr \
      -j ACCEPT -m comment --comment "Cloudflare"
done

# Persist rules
sudo netfilter-persistent save
SCRIPT
```

**CAUTION:** Never use `iptables -F INPUT` — it flushes ALL rules and will lock you out of SSH.

### 5.4 Verify

```bash
# SSH still works
$SSH_CMD "echo 'SSH OK'"

# Cloudflare-proxied traffic works
curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN
# Expected: 200

# Direct-to-origin blocked
curl -s --connect-timeout 5 -k https://$ORIGIN_IP
# Expected: timeout or refused
```

### 5.5 Updating Cloudflare IP ranges

Cloudflare IP ranges change infrequently. When they do:

1. Fetch new ranges from `https://www.cloudflare.com/ips-v4/` and `https://www.cloudflare.com/ips-v6/`
2. Compare with current iptables rules: `$SSH_CMD "sudo iptables -L INPUT -n | grep Cloudflare"`
3. Add new CIDRs, remove obsolete ones
4. Run `sudo netfilter-persistent save`

---

## 6. Verification Checklist

Run after completing all sections:

```bash
echo "=== 1. Version ===" && curl -s https://$DOMAIN/api/v1/version
echo "=== 2. Cloudflare proxy ===" && curl -s -I https://$DOMAIN | grep -i "server: cloudflare"
echo "=== 3. SSL ===" && echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -subject -dates
echo "=== 4. CORS ===" && curl -s -I -X OPTIONS -H "Origin: https://$DOMAIN" -H "Access-Control-Request-Method: GET" https://$DOMAIN/api/v1/shelters | grep -i access-control-allow-origin
echo "=== 5. HTTP→HTTPS ===" && curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN
echo "=== 6. API not cached ===" && curl -s -I https://$DOMAIN/api/v1/version | grep -i cf-cache-status
echo "=== 7. Origin locked ===" && curl -s --connect-timeout 5 -k https://$ORIGIN_IP 2>&1 || echo "BLOCKED"
echo "=== 8. DV canary ===" && TOKEN=$(curl -s -X POST https://$DOMAIN/api/v1/auth/login -H "Content-Type: application/json" -d "{\"email\":\"outreach@dev.fabt.org\",\"password\":\"admin123\",\"tenantSlug\":\"dev-coc\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])") && curl -s -H "Authorization: Bearer $TOKEN" https://$DOMAIN/api/v1/shelters | python3 -c "import sys,json; d=json.load(sys.stdin); dv=[s for s in d if s.get('isDomesticViolence') or s.get('domesticViolence')]; print(f'DV visible: {len(dv)} — {\"FAIL\" if dv else \"PASS\"}')"
```

Expected: all checks pass, DV canary = PASS.

---

## 7. Lessons Learned

Gotchas encountered during the initial `findabed.org` setup (April 2, 2026):

1. **Cloudflare zone activates fast.** DNS propagation to Cloudflare's own resolver (1.1.1.1) happened within minutes, though the local ISP resolver took longer. Use `nslookup DOMAIN 1.1.1.1` to verify before waiting for local propagation.

2. **Cloudflare auto-imports registrar DNS records.** When adding the zone, Cloudflare imported Namecheap's parking page A record (`192.64.119.254`), a www CNAME to `parkingpage.namecheap.com`, 5 MX records, and an SPF TXT record. The parking A record had to be deleted and the www CNAME updated — otherwise traffic would split between the origin and the parking page.

3. **CORS was in docker-compose.prod.yml, not .env.prod.** The CORS origin was hardcoded in the production docker-compose override file, not the environment file. Check both locations when updating CORS.

4. **nginx strips X-Accel-Buffering headers.** The backend set `X-Accel-Buffering: no` on the SSE response, but the container nginx proxy stripped it (nginx treats `X-Accel-*` as internal directives). The fix required adding `add_header X-Accel-Buffering "no" always;` to the SSE location block in the container nginx config. Both the backend header AND the nginx directive are needed.

5. **SSE connected event arrives immediately through Cloudflare.** Once the `X-Accel-Buffering` header was set correctly, SSE events streamed in real-time with no buffering. The 20-second heartbeat interval keeps connections alive well within Cloudflare's 100-second idle timeout.

6. **Certbot dry-run holds a lock.** If a Certbot process is running (or was killed uncleanly), subsequent Certbot commands fail with "Another instance of Certbot is already running." Fix: `sudo pkill -f certbot` or remove lock files at `/tmp/.certbot.lock`.

7. **Backend needs a few seconds after restart.** After restarting containers, the first request through Cloudflare returned 502 (Bad Gateway) because the Spring Boot backend was still initializing. Subsequent requests succeeded. Allow 10–15 seconds after container restart before testing.

8. **Cloudflare API token scope matters.** The "Edit zone DNS" template only grants DNS permissions. Setting SSL mode and HTTPS settings requires adding "Zone Settings: Edit" to the token. The SSL verification endpoint (`/ssl/verification`) requires even broader permissions — but the SSL status is already visible in the `/settings/ssl` response (`certificate_status: "active"`), so the verification endpoint isn't needed.

9. **Redirect rules require dashboard, not API.** Creating Cloudflare redirect rules (www→apex) via the API requires permissions beyond what the zone-scoped token provides. Use the Cloudflare dashboard: Rules → Redirect Rules. This is a one-time setup.

10. **iptables rule ordering matters.** When replacing broad ACCEPT rules with Cloudflare-specific rules, delete the broad rules first, then insert new rules at the correct position (before the REJECT rule). Use `-I INPUT $POSITION` (insert at position) not `-A INPUT` (append at end), and never use `iptables -F INPUT` (flushes everything including SSH).

---

*Finding A Bed Tonight — Domain Setup Guide*
*Created: April 2, 2026 during findabed.org deployment*
