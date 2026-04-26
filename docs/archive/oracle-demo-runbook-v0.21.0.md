# Oracle Always Free — FABT Demo Deployment Runbook

**Version:** v0.21.0 — March 2026 (updated April 2026 for custom domain)
**Target tag:** v0.21.0 (color system, dark mode, HIC/PIT FY2024+, shelter edit)
**VM target:** Oracle Cloud Always Free — 1× VM.Standard.A1.Flex (ARM64)
**Stack:** Lite tier + Observability — PostgreSQL 16 + Prometheus + Grafana + Jaeger
**Cost: $0** — Oracle Always Free is free forever, not a trial

> **Custom domain:** The current FABT demo runs at `https://findabed.org` behind Cloudflare CDN/WAF.
> This runbook uses `YOUR_DOMAIN` as a placeholder. For the current deployment, `YOUR_DOMAIN` = `findabed.org`.
> For Cloudflare setup, DNS configuration, and origin lockdown, see `domain-setup-guide.md`.

---

## What You Get

- `https://YOUR_DOMAIN` — React PWA with automatic dark mode (nginx, TLS via Let's Encrypt)
- `https://YOUR_DOMAIN/api/` — Spring Boot 4.0 backend (Java 25, virtual threads)
- PostgreSQL 16 (Lite tier — no Redis, see note below)
- Prometheus + Grafana (5 operational dashboards) + Jaeger (distributed tracing)
- 13 seed shelters (10 regular + 3 DV), 28 days of demo activity data, 4 demo users
- Default hold duration: 90 minutes
- Auto-renewing TLS — never expires manually
- DV shelter protection: database-level Row Level Security, verified by automated canary every 15 minutes

**Time estimate:** 2–3 hours end to end.

**Why Lite, not Standard?** The Standard tier adds Redis, but Redis integration is placeholder code (TODOs in TieredCacheService and RedisReservationExpiryService). All 296 backend tests and 167 Playwright tests run on Lite. Performance is identical — BedSearch p50=21ms, p95=45ms. Don't add untested infrastructure to your first public demo.

---

## What's Different from the v0.14.1 Runbook

- **30 Flyway migrations** (V1–V29 + V8.1). V27 (password_changed_at), V28 (user status + token_version), V29 (audit_events).
- **13 shelters**, not 10. 3 DV shelters added for small-cell suppression threshold.
- **Dark mode.** App follows OS dark mode setting automatically. Screenshots look different at night.
- **Color system.** All 18 component files use CSS custom property tokens. Radix/Carbon split pattern for accessibility.
- **HIC/PIT export rewritten.** Matches HUD Inventory.csv schema (FY2024+) with integer codes. Downloads use fetch+blob (JWT auth fixed).
- **Shelter edit.** Admin and coordinator can edit shelters. DV safeguards with confirmation dialog and audit logging.
- **Import/export hardening.** Apache Commons CSV parser, file size limits (10MB), CSV injection protection, UTF-8 BOM handling.
- **Training materials.** Coordinator quick-start card and admin onboarding checklist (in docs repo, print from GitHub Pages).
- **Observability included.** Prometheus, Grafana, Jaeger, OTel Collector — all within Always Free limits.

---

## Resource Budget (Oracle Always Free)

| Resource | Used | Limit | Headroom |
|---|---|---|---|
| OCPUs | 4 | 4 | Fully utilized |
| RAM | ~5 GB (7 containers + OS) | 24 GB | 79% free |
| Disk | ~8 GB (OS + DB + Prometheus) | 100 GB boot | 92% free |
| Outbound bandwidth | < 1 GB/month (demo traffic) | 10 TB/month | 99.99% free |

---

## Domain Setup

This runbook uses `YOUR_DOMAIN` as a placeholder for your custom domain. For the current FABT deployment, `YOUR_DOMAIN` = `findabed.org`.

**Current setup:** Domain registered on Namecheap, DNS managed by Cloudflare (free tier), with CDN/WAF/DDoS protection. All HTTP/HTTPS traffic flows through Cloudflare before reaching the Oracle VM. The VM's origin IP is restricted to Cloudflare IP ranges only.

Your demo URL:
```
https://YOUR_DOMAIN
```

For full domain registration, Cloudflare configuration, and origin lockdown instructions, see `domain-setup-guide.md`.

> **Legacy:** Earlier versions of this runbook used `nip.io` (a free wildcard DNS service that maps IP addresses to hostnames). This was replaced with a proper domain in April 2026.
> Throughout this runbook, `YOUR_IP` means the Oracle VM's public IP address.

---

## Architecture on the VM

```
Internet
    │ 443 (HTTPS)
    ▼
Host nginx (Let's Encrypt TLS termination)
    │ proxy_pass 127.0.0.1:8081
    ▼
Docker network: fabt_default
    ┌──────────────────────────────────────────────┐
    │  frontend (nginx:alpine)  :8081→80           │
    │    ├── React PWA static assets (dark mode)   │
    │    └── proxy /api/ → backend:8080            │
    │                                              │
    │  backend (eclipse-temurin:25) :8080          │
    │    ├── Spring Boot 4.0 + Java 25             │
    │    ├── Virtual threads enabled                │
    │    ├── Flyway migrations (30)                │
    │    ├── Graceful shutdown (30s timeout)        │
    │    └── Management port 9091 (lo only)        │
    │                                              │
    │  postgres (postgres:16-alpine)  :5432        │
    │                                              │
    │  prometheus (prom/prometheus) :9090           │
    │    └── Scrapes backend:9091 every 15s        │
    │                                              │
    │  grafana (grafana/grafana) :3000              │
    │    └── 5 dashboards, datasource: prometheus  │
    │                                              │
    │  jaeger (jaegertracing/all-in-one) :16686    │
    │    └── In-memory trace storage               │
    │                                              │
    │  otel-collector :4318                        │
    │    └── Routes spans → jaeger:4317            │
    └──────────────────────────────────────────────┘
```

**Public ports:** 22 (SSH), 80 (HTTP → HTTPS redirect), 443 (HTTPS) only.
**Never exposed:** 5432, 8080, 8081, 9090, 9091, 3000, 4317, 4318, 16686.
**Observability access:** Via SSH tunnel from your laptop (see Part 10).

---

## Part 1 — Oracle Cloud Account and VM

> **All CLI commands use Git Bash** (not PowerShell). Open Git Bash on Windows:
> press Windows key, type `git bash`, open it. Right-click to paste.

### 1.1 Create Your Oracle Cloud Account

1. Go to: https://www.oracle.com/cloud/free/
2. Click **Start for free**
3. Home region: **US East (Ashburn)** — best A1 Flex availability
4. Enter credit card for identity verification (no charge)
5. Complete phone verification
6. Wait for "Your account is ready" email (10–30 min)

### 1.2 Upgrade to Pay-As-You-Go (strongly recommended)

Always Free A1 Flex instances are frequently out of capacity. Upgrading to Pay-As-You-Go (PAYG) gives your account priority for capacity allocation and disables idle instance reclamation. **You will not be charged** as long as you stay within Always Free resource limits.

1. Oracle Console → click **☰ hamburger menu** (top-left)
2. Select **Billing & Cost Management**
3. Click **Upgrade and Manage Payment**
4. Select **Upgrade to Pay as you go**
5. Review credit card (pre-filled from signup) → accept Terms → click **Upgrade your Account**
6. Wait for confirmation email (minutes to a couple hours)

> Oracle places a temporary ~$100 authorization hold during upgrade. It's reversed
> immediately on their side, but your bank may take a few days to release it.

### 1.3 Install and Configure OCI CLI (one-time, on your Windows machine)

The OCI CLI lets you provision everything from the command line. Install it once.

**Install:** Open PowerShell (not Git Bash) for the installer:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-WebRequest https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.ps1 -OutFile install.ps1
.\install.ps1 -AcceptAllDefaults
# Close and reopen your terminal after install
```

**Configure:** Open PowerShell or Git Bash:
```bash
oci setup config
# Prompts for:
#   1. Tenancy OCID → find in Oracle Console → Profile icon → Tenancy → copy OCID
#   2. User OCID → Profile icon → My Profile → copy OCID
#   3. Region → us-ashburn-1
#   4. Generates API key pair automatically (press Enter for defaults)
```

**Upload the API key to Oracle:**
1. Oracle Console → **Profile icon → My Profile → API Keys → Add API Key**
2. Select **Paste Public Key** → paste contents of `~/.oci/oci_api_key_public.pem`
3. Click **Add**

**Fix file permissions warning** (run once):
```bash
oci setup repair-file-permissions --file ~/.oci/config
oci setup repair-file-permissions --file ~/.oci/oci_api_key.pem
```

**Verify CLI works** (in Git Bash):
```bash
export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True
oci iam region list --output table
```

### 1.4 Generate SSH Key Pair

In Git Bash:
```bash
ssh-keygen -t ed25519 -C "fabt-oracle-demo" -f ~/.ssh/fabt-oracle
# Press Enter twice — no passphrase
```

### 1.5 Create Networking (VCN, Internet Gateway, Subnet)

Oracle doesn't create a network by default. These commands create the networking infrastructure your VM needs. Run each command individually in Git Bash:

```bash
export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True

# Your tenancy OCID IS your compartment for Always Free
C=$(grep tenancy ~/.oci/config | head -1 | cut -d'=' -f2 | tr -d ' ')
echo "Compartment: $C"
```

```bash
# Create Virtual Cloud Network
VCN_ID=$(oci network vcn create --compartment-id "$C" --display-name "fabt-vcn" --cidr-blocks '["10.0.0.0/16"]' --query 'data.id' --raw-output)
echo "VCN: $VCN_ID"
```

```bash
# Create Internet Gateway (allows outbound traffic)
IG_ID=$(oci network internet-gateway create --compartment-id "$C" --vcn-id "$VCN_ID" --display-name "fabt-igw" --is-enabled true --query 'data.id' --raw-output)
echo "Internet Gateway: $IG_ID"
```

```bash
# Add route to Internet Gateway
RT_ID=$(oci network route-table list --compartment-id "$C" --vcn-id "$VCN_ID" --query 'data[0].id' --raw-output)
echo "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$IG_ID\",\"destinationType\":\"CIDR_BLOCK\"}]" > /tmp/routes.json
oci network route-table update --rt-id "$RT_ID" --route-rules "$(cat /tmp/routes.json)" --force > /dev/null
echo "Route table updated"
```

```bash
# Create subnet
SUBNET=$(oci network subnet create --compartment-id "$C" --vcn-id "$VCN_ID" --display-name "fabt-subnet" --cidr-block "10.0.0.0/24" --query 'data.id' --raw-output)
echo "Subnet: $SUBNET"
```

Verify all values are real OCIDs (start with `ocid1.`):
```bash
echo "C=$C"
echo "VCN=$VCN_ID"
echo "IG=$IG_ID"
echo "SUBNET=$SUBNET"
```

### 1.6 Provision the VM

Get the Ubuntu 22.04 ARM64 image and availability domain:

```bash
AD=$(oci iam availability-domain list --compartment-id "$C" --query 'data[0].name' --raw-output)
echo "AD: $AD"
```

```bash
IMG=$(oci compute image list --compartment-id "$C" --shape "VM.Standard.A1.Flex" --operating-system "Canonical Ubuntu" --operating-system-version "22.04" --query 'data[0].id' --raw-output)
echo "Image: $IMG"
```

Launch the VM (all on one line — do not split across lines):

```bash
oci compute instance launch --compartment-id "$C" --availability-domain "$AD" --shape "VM.Standard.A1.Flex" --shape-config '{"ocpus":4,"memoryInGBs":24}' --display-name "fabt-demo" --image-id "$IMG" --subnet-id "$SUBNET" --assign-public-ip true --ssh-authorized-keys-file ~/.ssh/fabt-oracle.pub --boot-volume-size-in-gbs 100
```

> **"Out of host capacity" error:** All three Ashburn ADs may be full. Options:
>
> 1. **Retry loop** — use the `launch-fabt.sh` script (included in the repo root)
>    which retries every 5 minutes automatically:
>    ```bash
>    cd /c/Development/findABed && chmod +x launch-fabt.sh && ./launch-fabt.sh
>    ```
> 2. **Try a different AD:**
>    ```bash
>    oci iam availability-domain list --compartment-id "$C" --query 'data[].name' --raw-output
>    ```
>    Then re-run the launch command with a different `--availability-domain` value.
> 3. **Try smaller shape** — 2 OCPUs / 12 GB is plenty for demo:
>    ```bash
>    --shape-config '{"ocpus":2,"memoryInGBs":12}'
>    ```
> 4. **PAYG upgrade** (Part 1.2) — most effective for resolving capacity constraints.

Once the instance launches, get the public IP:

```bash
INSTANCE_ID=$(oci compute instance list --compartment-id "$C" --display-name "fabt-demo" --query 'data[0].id' --raw-output)
VNIC_ID=$(oci compute vnic-attachment list --compartment-id "$C" --instance-id "$INSTANCE_ID" --query 'data[0]."vnic-id"' --raw-output)
PUBLIC_IP=$(oci network vnic get --vnic-id "$VNIC_ID" --query 'data."public-ip"' --raw-output)
echo "Public IP: $PUBLIC_IP"
echo "Demo URL: https://YOUR_DOMAIN"  # Replace with your actual domain (e.g., findabed.org)
echo "SSH: ssh -i ~/.ssh/fabt-oracle ubuntu@${PUBLIC_IP}"
```

### 1.7 Open Oracle Firewall Ports

#### Option A — Console UI

1. Oracle Console → **Compute → Instances → fabt-demo** → click the **Subnet** link
2. **Security Lists → Default Security List → Add Ingress Rules**

   | Source CIDR | Protocol | Dest Port |
   |---|---|---|
   | 0.0.0.0/0 | TCP | 80 |
   | 0.0.0.0/0 | TCP | 443 |

3. Leave port 22 in place. **Do NOT open** 3000, 5432, 8080, 8081, 9090, 9091, or 16686.

#### Option B — OCI CLI

```bash
SL=$(oci network security-list list --compartment-id "$C" --vcn-id "$VCN_ID" --query 'data[0].id' --raw-output)

echo '[{"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},{"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},{"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":443,"max":443}}}]' > /tmp/security-rules.json

oci network security-list update --security-list-id "$SL" --ingress-security-rules "$(cat /tmp/security-rules.json)" --force > /dev/null
echo "Firewall ports 22, 80, 443 opened"
```

> **CRITICAL:** The `update` command **replaces** the entire ingress rule set.
> The JSON above includes port 22 (SSH). If you omit it, you'll lock yourself out.

### 1.8 SSH to the VM

```bash
ssh -i ~/.ssh/fabt-oracle ubuntu@$PUBLIC_IP
```

All commands from this point forward run on the VM unless noted otherwise.

---

## Part 2 — VM Baseline Setup

### 2.1 System update

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### 2.2 Ubuntu firewall

Oracle Security Lists, iptables, and ufw are independent — all must allow ports.

Oracle Ubuntu images ship with iptables rules that **default-DROP** all inbound traffic except SSH. You must open ports 80 and 443 in iptables before ufw rules will have any effect.

```bash
# Open ports 80 and 443 in iptables (insert before the REJECT rule)
sudo iptables -I INPUT 5 -p tcp --dport 80 -m state --state NEW -j ACCEPT
sudo iptables -I INPUT 6 -p tcp --dport 443 -m state --state NEW -j ACCEPT
sudo netfilter-persistent save
```

Then enable ufw:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status
```

### 2.3 Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
exit   # must log out to activate group membership
```

Re-SSH, then verify:
```bash
docker --version
docker compose version
```

### 2.4 Install JDK 25

```bash
# Add Adoptium (Temurin) repository
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg

echo "deb https://packages.adoptium.net/artifactory/deb \
  $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list

sudo apt-get update
sudo apt-get install -y temurin-25-jdk
```

Set `JAVA_HOME` permanently:
```bash
echo 'export JAVA_HOME=/usr/lib/jvm/temurin-25' >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

Verify:
```bash
java -version     # openjdk version "25"
echo $JAVA_HOME   # /usr/lib/jvm/temurin-25
```

### 2.5 Install Maven, Node.js 20, Certbot, and nginx

```bash
sudo apt-get install -y maven
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs certbot python3-certbot-nginx nginx
sudo systemctl enable nginx
```

Final verification:
```bash
java -version    # openjdk 25
mvn -version     # Java version: 25
node --version   # v20.x
nginx -version   # nginx/1.x
```

---

## Part 3 — DNS Verification

Verify your domain resolves correctly (via Cloudflare or your DNS provider):

```bash
nslookup YOUR_DOMAIN
# If using Cloudflare: should return Cloudflare edge IPs (not your origin IP)
# If using direct A record: should return YOUR_IP

# Example:
nslookup findabed.org
# Answer: 104.21.88.145, 172.67.183.152 (Cloudflare edge IPs)
```

If `nslookup` returns nothing or an error:
- Verify DNS is configured correctly (Cloudflare dashboard or your DNS provider)
- DNS propagation can take up to 48 hours after nameserver changes
- Try `nslookup YOUR_DOMAIN 1.1.1.1` to query Cloudflare's resolver directly

DNS must resolve correctly before Let's Encrypt will issue a certificate in Part 8.

---

## Part 4 — Build the Application

### 4.1 Clone at v0.21.0

```bash
cd ~
git clone https://github.com/ccradle/finding-a-bed-tonight.git
cd finding-a-bed-tonight
git checkout v0.21.0
```

Confirm the tag:
```bash
git describe --tags
# v0.21.0
```

### 4.2 Verify all 29 migrations are present

```bash
ls backend/src/main/resources/db/migration/ | wc -l
# Should show 30 (V1-V29 + V8.1)

ls backend/src/main/resources/db/migration/ | sort -V | tail -3
# V27__add_password_changed_at.sql
# V28__add_user_status_and_token_version.sql
# V29__create_audit_events.sql
```

### 4.3 Build the backend JAR

```bash
cd backend
mvn package -DskipTests -q
cd ..
ls backend/target/finding-a-bed-tonight-*.jar
# Must exist before continuing
```

First run takes 5–8 minutes (dependency download).

### 4.4 Build the frontend

```bash
cd frontend
npm ci --silent
npm run build
cd ..
ls frontend/dist/index.html
# Must exist before continuing
```

### 4.5 Build Docker images

Both base images have native ARM64 variants — no emulation on the A1 Flex.

```bash
# Backend
docker build -f infra/docker/Dockerfile.backend \
  -t fabt-backend:v0.21.0 \
  -t fabt-backend:latest .

# Frontend
docker build -f infra/docker/Dockerfile.frontend \
  -t fabt-frontend:v0.21.0 \
  -t fabt-frontend:latest .
```

Verify:
```bash
docker images | grep fabt
docker run --rm fabt-backend:latest java -version
# openjdk version "25"
```

---

## Part 5 — Clean Database Verification

Run all 29 migrations against a throwaway container before deploying.

```bash
# Start throwaway PostgreSQL
docker run -d --name fabt-migrate-test \
  -e POSTGRES_DB=fabt \
  -e POSTGRES_USER=fabt \
  -e POSTGRES_PASSWORD=fabt \
  -p 5433:5432 \
  postgres:16-alpine

# Wait for ready
until docker exec fabt-migrate-test \
  pg_isready -U fabt 2>/dev/null; do sleep 1; done
echo "PostgreSQL ready"

# Boot backend (migrations only)
docker run -d --name fabt-migrate-run \
  --network host \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5433/fabt \
  -e SPRING_PROFILES_ACTIVE=lite \
  -e FABT_DB_APP_USER=fabt \
  -e FABT_DB_APP_PASSWORD=fabt \
  -e FABT_DB_URL=jdbc:postgresql://localhost:5433/fabt \
  -e FABT_DB_OWNER_USER=fabt \
  -e FABT_DB_OWNER_PASSWORD=fabt \
  -e FABT_JWT_SECRET=verify-only-not-for-production \
  fabt-backend:latest

# Watch for completion (allow 60 seconds)
echo "Waiting for migrations..."
sleep 60
docker logs fabt-migrate-run 2>&1 \
  | grep -E "migration|Started|ERROR|Exception" | head -30

# Confirm all 29 migrations applied
docker exec fabt-migrate-test psql -U fabt -d fabt -c \
  "SELECT installed_rank, version, description, success
   FROM flyway_schema_history
   ORDER BY installed_rank;"
# Should show 30 rows (29 + V8.1), all success=true

# Clean up
docker stop fabt-migrate-run fabt-migrate-test
docker rm fabt-migrate-run fabt-migrate-test
echo "Verification complete"
```

If any migration shows `success=false`, stop here and resolve.

---

## Part 6 — Production Configuration

### 6.1 Create secrets directory

```bash
mkdir -p ~/fabt-secrets
chmod 700 ~/fabt-secrets
```

### 6.2 Generate strong secrets

Save all three values in a password manager before continuing.

```bash
echo "DB_OWNER_PW: $(openssl rand -base64 32)"
echo "DB_APP_PW:   $(openssl rand -base64 32)"
echo "JWT_SECRET:  $(openssl rand -base64 64)"
```

### 6.3 Create the environment file

```bash
cat > ~/fabt-secrets/.env.prod << 'EOF'
# FABT Demo — Oracle Always Free (v0.21.0)
# NEVER commit this file. Keep on server only.

# PostgreSQL owner credentials (Flyway DDL)
POSTGRES_DB=fabt
POSTGRES_USER=fabt
POSTGRES_PASSWORD=REPLACE_DB_OWNER_PASSWORD

# Application datasource (RLS-enforced fabt_app role)
SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/fabt
FABT_DB_URL=jdbc:postgresql://postgres:5432/fabt
FABT_DB_APP_USER=fabt_app
FABT_DB_APP_PASSWORD=REPLACE_DB_APP_PASSWORD
FABT_DB_OWNER_USER=fabt
FABT_DB_OWNER_PASSWORD=REPLACE_DB_OWNER_PASSWORD

# JWT secret (256+ bits)
FABT_JWT_SECRET=REPLACE_JWT_SECRET

# Deployment profile — Lite (no Redis)
FABT_DEPLOYMENT_TIER=lite
SPRING_PROFILES_ACTIVE=lite

# Management port — localhost only, never expose publicly
MANAGEMENT_SERVER_ADDRESS=127.0.0.1

# Tracing — enabled for Jaeger visibility
TRACING_SAMPLING_PROBABILITY=1.0

# Swagger UI — disabled for demo security
SPRINGDOC_SWAGGER_UI_ENABLED=false
SPRINGDOC_API_DOCS_ENABLED=false

# CORS — required for browser login via custom domain
# Replace YOUR_IP with your VM's public IP (e.g., 129.153.42.7)
FABT_CORS_ALLOWED_ORIGINS=https://YOUR_DOMAIN

# NOAA weather monitoring (Raleigh/RDU)
FABT_NOAA_LAT=35.8776
FABT_NOAA_LON=-78.7875
FABT_NOAA_STATION=KRDU
EOF
```

Edit and replace all three `REPLACE_*` placeholders and the `YOUR_IP` in `FABT_CORS_ALLOWED_ORIGINS`:
```bash
nano ~/fabt-secrets/.env.prod
```

Lock down and verify:
```bash
chmod 600 ~/fabt-secrets/.env.prod
grep REPLACE ~/fabt-secrets/.env.prod
# Must return nothing
```

### 6.4 Create the production Compose override

```bash
cat > ~/fabt-secrets/docker-compose.prod.yml << 'EOF'
# Production override — Oracle Always Free (v0.21.0)

services:

  postgres:
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports: []

  backend:
    image: fabt-backend:latest
    container_name: fabt-backend
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE},observability
      SPRING_DATASOURCE_URL: ${SPRING_DATASOURCE_URL}
      FABT_DB_APP_USER: ${FABT_DB_APP_USER}
      FABT_DB_APP_PASSWORD: ${FABT_DB_APP_PASSWORD}
      FABT_DB_URL: ${FABT_DB_URL}
      FABT_DB_OWNER_USER: ${FABT_DB_OWNER_USER}
      FABT_DB_OWNER_PASSWORD: ${FABT_DB_OWNER_PASSWORD}
      FABT_JWT_SECRET: ${FABT_JWT_SECRET}
      FABT_DEPLOYMENT_TIER: ${FABT_DEPLOYMENT_TIER}
      MANAGEMENT_SERVER_ADDRESS: 0.0.0.0
      MANAGEMENT_OTLP_TRACING_ENDPOINT: http://otel-collector:4318/v1/traces
      TRACING_SAMPLING_PROBABILITY: ${TRACING_SAMPLING_PROBABILITY}
      SPRINGDOC_SWAGGER_UI_ENABLED: ${SPRINGDOC_SWAGGER_UI_ENABLED}
      SPRINGDOC_API_DOCS_ENABLED: ${SPRINGDOC_API_DOCS_ENABLED}
      FABT_NOAA_LAT: ${FABT_NOAA_LAT}
      FABT_NOAA_LON: ${FABT_NOAA_LON}
      FABT_NOAA_STATION: ${FABT_NOAA_STATION}
      FABT_CORS_ALLOWED_ORIGINS: ${FABT_CORS_ALLOWED_ORIGINS}
    ports:
      - "127.0.0.1:8080:8080"
      - "127.0.0.1:9091:9091"

  frontend:
    image: fabt-frontend:latest
    container_name: fabt-frontend
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "127.0.0.1:8081:80"

  prometheus:
    restart: unless-stopped
    ports: []

  grafana:
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${POSTGRES_PASSWORD}
    ports: []

  jaeger:
    restart: unless-stopped
    ports: []

  otel-collector:
    restart: unless-stopped
    ports: []
EOF
```

> **Note:** `MANAGEMENT_SERVER_ADDRESS: 0.0.0.0` in the backend lets Prometheus scrape
> metrics from within the Docker network. Port 9091 is NOT exposed publicly — it's only
> accessible inside Docker's `fabt_default` network and via SSH tunnel.

### 6.5 Create the fabt_app password rotation script

```bash
cat > ~/fabt-secrets/rotate-db-password.sh << 'ROTEOF'
#!/bin/bash
set -euo pipefail
source ~/fabt-secrets/.env.prod

echo "Rotating fabt_app password..."
# Note: container name is from docker compose, not "fabt-postgres"
docker exec -i finding-a-bed-tonight-postgres-1 psql -U fabt -d fabt << SQL
ALTER ROLE fabt_app PASSWORD '${FABT_DB_APP_PASSWORD}';
SQL
echo "Done."
ROTEOF
chmod 700 ~/fabt-secrets/rotate-db-password.sh
```

---

## Part 7 — First Start

### 7.1 Update Prometheus target for Docker networking

The default `prometheus.yml` scrapes `host.docker.internal:9091` (for dev). For Docker-to-Docker networking, update it:

```bash
cd ~/finding-a-bed-tonight
sed -i "s/host.docker.internal:9091/backend:9091/" prometheus.yml
```

Verify:
```bash
grep targets prometheus.yml
# Should show: targets: ['backend:9091']
```

### 7.2 Start the stack

> **Important:** Always use `--env-file` to pass secrets. Do NOT rely on `source .env.prod` —
> the env file uses `KEY=value` format without `export`, so `source` does not export variables
> to child processes like `docker compose`.

```bash
cd ~/finding-a-bed-tonight

docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --env-file ~/fabt-secrets/.env.prod \
  --profile observability \
  up -d
```

Verify no `WARN ... variable is not set` messages in the output. If you see warnings, the `--env-file` path is wrong or the file has missing variables.

### 7.3 Watch startup

```bash
docker compose logs -f backend
```

Flyway runs all 30 migrations automatically (V1–V29 + V8.1). Allow 30–60 seconds.
You should see migration log lines followed by:
```
Started Application in X.XXX seconds
```

Press Ctrl+C. Check all containers:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
# fabt-backend                             Up X minutes
# fabt-frontend                            Up X minutes
# finding-a-bed-tonight-postgres-1         Up X minutes (healthy)
# finding-a-bed-tonight-prometheus-1       Up X minutes
# finding-a-bed-tonight-grafana-1          Up X minutes
# finding-a-bed-tonight-jaeger-1           Up X minutes
# finding-a-bed-tonight-otel-collector-1   Up X minutes
```

### 7.4 Rotate the fabt_app password (one-time)

The `fabt_app` role is created by Flyway migration V1 with a placeholder password.
This step sets the real password from your `.env.prod` file.

```bash
~/fabt-secrets/rotate-db-password.sh
docker restart fabt-backend
sleep 15
curl -s http://localhost:9091/actuator/health/liveness
# {"status":"UP"}
```

> **Port 9091, not 8080:** With the observability profile active, actuator endpoints
> (health, readiness, prometheus) are served on the management port **9091**.
> API endpoints remain on 8080. All `actuator` URLs in subsequent steps use 9091.

### 7.5 Load seed data

```bash
docker exec -i finding-a-bed-tonight-postgres-1 \
  psql -U fabt -d fabt \
  < ~/finding-a-bed-tonight/infra/scripts/seed-data.sql

# Load 28 days of demo activity data
docker exec -i finding-a-bed-tonight-postgres-1 \
  psql -U fabt -d fabt \
  < ~/finding-a-bed-tonight/infra/scripts/demo-activity-seed.sql
```

> **Container name:** Docker Compose names containers as `<project>-<service>-<n>`.
> The postgres container is `finding-a-bed-tonight-postgres-1`, not `fabt-postgres`.
> Use `docker ps` to verify if unsure.

### 7.6 Verify health

```bash
curl -s http://localhost:9091/actuator/health/liveness | python3 -m json.tool
# { "status": "UP" }

curl -s http://localhost:9091/actuator/health/readiness | python3 -m json.tool
# { "status": "UP" }
```

### 7.7 Verify DV shelter protection — CRITICAL, do not skip

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"tenantSlug":"dev-coc",
       "email":"outreach@dev.fabt.org",
       "password":"admin123"}' \
  | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['accessToken'])")

curl -s -X POST http://localhost:8080/api/v1/queries/beds \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"populationType":"SINGLE_ADULT","limit":20}' \
  | python3 -m json.tool | grep -i "safe haven"
```

**Expected: no output.** "Safe Haven" DV shelter must be invisible to the outreach worker.
If it appears, **STOP — RLS is broken. Do not proceed.**

### 7.8 Verify bed search returns results

```bash
curl -s -X POST http://localhost:8080/api/v1/queries/beds \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"populationType":"SINGLE_ADULT","limit":5}' \
  | python3 -m json.tool
```

Expected: array of shelter results with `bedsAvailable`, `dataFreshness`.

### 7.9 Verify observability stack

Prometheus, Grafana, and Jaeger have `ports: []` in the prod override (not publicly accessible).
To verify from the VM, use `docker exec` to query from inside the Docker network:

```bash
# Prometheus scraping backend metrics?
docker exec finding-a-bed-tonight-prometheus-1 \
  wget -qO- http://prometheus:9090/api/v1/targets \
  | python3 -c "import sys,json; t=json.load(sys.stdin)['data']['activeTargets'][0]; print(f'Target: {t[\"labels\"][\"job\"]} — {t[\"health\"]}')"
# Should show: Target: fabt-backend — up

# Grafana responding?
docker exec finding-a-bed-tonight-grafana-1 \
  wget -qO- http://grafana:3000/api/health \
  | python3 -m json.tool
# { "database": "ok" }

# Jaeger has traces? (after a few API requests)
docker exec finding-a-bed-tonight-jaeger-1 \
  wget -qO- http://jaeger:16686/api/services \
  | python3 -m json.tool
# Should list "finding-a-bed-tonight"
```

> **Alternative:** If you have the SSH tunnel running (Part 10), you can use
> `curl http://localhost:9090/...` etc. from your local machine instead.

---

## Part 8 — TLS and Public Access

### 8.1 Configure host nginx for your domain

Replace `YOUR_IP` with your actual VM IP:

```bash
# Set your IP as a variable (replace with your actual IP)
export MY_IP=YOUR_IP
```

Now create the nginx config. **Paste carefully** — the closing `NGINXEOF` must be on its
own line with **no leading spaces**, or the heredoc won't terminate:

```bash
sudo tee /etc/nginx/sites-available/fabt << NGINXEOF
server {
    listen 80;
    server_tokens off;
    server_name YOUR_DOMAIN;

    # Security headers (TLS layer — HSTS added by certbot to 443 block)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    }
}
NGINXEOF
```

> **Pasting from Windows (Git Bash / SSH):** If you see a `>` prompt after pasting,
> the `NGINXEOF` delimiter had leading spaces. Type `NGINXEOF` (no spaces) and press Enter.
> Then verify the file doesn't contain a literal `NGINXEOF` line: `cat /etc/nginx/sites-available/fabt`

Activate and test:
```bash
sudo ln -sf /etc/nginx/sites-available/fabt \
  /etc/nginx/sites-enabled/fabt
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

Verify nginx is serving (HTTP, before TLS):
```bash
curl -s -o /dev/null -w "%{http_code}" http://YOUR_DOMAIN
# 200
```

### 8.2 Obtain TLS certificate via Let's Encrypt

Let's Encrypt validates domain ownership by making an HTTP request to your server. Your DNS (Cloudflare or direct A record) resolves to your IP, so Let's Encrypt reaches your nginx, confirms you control the domain, and issues a free certificate.

```bash
sudo certbot --nginx \
  -d YOUR_DOMAIN \
  --non-interactive \
  --agree-tos \
  --email YOUR_EMAIL \
  --redirect
```

> Replace `YOUR_EMAIL` with your real email — Let's Encrypt sends expiry warnings here.

Certbot automatically:
1. Obtains the certificate
2. Configures nginx for HTTPS (port 443)
3. Sets up HTTP→HTTPS redirect (port 80 → 443)
4. Schedules auto-renewal (certificates renew before the 90-day expiry)

Verify auto-renewal works:
```bash
sudo certbot renew --dry-run
# Should complete without errors
```

### 8.3 Test from a browser

Navigate to `https://YOUR_DOMAIN` (e.g., `https://findabed.org`).

- **Padlock icon** — browser shows valid TLS (issued by Let's Encrypt)
- **FABT login page** loads with the Finding A Bed Tonight header
- Log in: tenant `dev-coc`, email `outreach@dev.fabt.org`, password `admin123`
- **Dark mode**: if your phone/computer is in dark mode, the app renders with dark background automatically
- **Test on your phone** — open the URL in your phone's browser. This is how outreach workers will use it.
- **Phone certificate error?** Make sure you're using `https://YOUR_DOMAIN`, not the bare IP address. The TLS certificate is only valid for the registered domain.

**Share this URL with family and friends:**
```
https://YOUR_DOMAIN
```

Give them the outreach worker credentials to try the bed search flow.

---

## Part 9 — Demo Users and Credentials

| Role | Email | Password | What They See |
|---|---|---|---|
| Platform Admin | `admin@dev.fabt.org` | `admin123` | Full admin panel, CoC Analytics, all tabs, DV shelters visible |
| CoC Admin | `cocadmin@dev.fabt.org` | `admin123` | Dashboard, analytics, surge controls, NO DV shelter visibility |
| Outreach Worker | `outreach@dev.fabt.org` | `admin123` | Bed search, 90-min hold, DV shelters invisible |
| (Deactivated) | `former@dev.fabt.org` | `admin123` | Login rejected — "Account deactivated" |

**Default hold duration:** 90 minutes. Configurable per tenant:
Admin → Hold Duration (top of admin panel).

**DV shelters:** Safe Haven, Harbor House, Bridges to Safety — invisible to outreach worker.
Visible to admin only (dvAccess=true).

**Demo flow recommendation:**
1. Outreach worker → bed search → hold a bed → show countdown
2. Coordinator (cocadmin) → dashboard → update bed count → see hold indicator → Edit Details
3. Admin → Shelters tab → Edit a shelter → configure DV flag
4. Admin → Import 211 Data → upload demo CSV → preview → confirm
5. Admin → Analytics tab → show utilization trends, HIC/PIT export download
6. Dark mode: toggle your OS dark mode setting → app switches automatically

---

## Part 10 — Observability & API Docs via SSH Tunnel

Prometheus, Grafana, Jaeger, and Swagger UI are NOT exposed publicly. They're accessible only from inside the VM. To reach them from your laptop, you create an **SSH tunnel** — a secure, encrypted connection that maps ports on your local machine to ports on the VM.

**How SSH tunnels work:** When you run `ssh -L 3000:localhost:3000`, your laptop's port 3000 becomes a window into the VM's port 3000. You browse `localhost:3000` on your laptop, but the traffic goes through SSH to the VM. No ports need to be opened in Oracle's firewall.

### 10.1 Open the tunnel (run on your Windows machine, not the VM)

```powershell
ssh -i "$env:USERPROFILE\.ssh\fabt-oracle" `
  -L 3000:localhost:3000 `
  -L 9090:localhost:9090 `
  -L 16686:localhost:16686 `
  -L 8080:localhost:8080 `
  -N ubuntu@YOUR_IP
```

This maps:
- `localhost:3000` → **Grafana** (dashboards)
- `localhost:9090` → **Prometheus** (raw metrics)
- `localhost:16686` → **Jaeger** (distributed traces)
- `localhost:8080` → **Backend API** (Swagger UI, API docs)

The `-N` flag means "don't open a shell, just tunnel." Leave this terminal open while you use the tools. Close the terminal (or Ctrl+C) to disconnect.

> **Tip:** Port 8080 is commonly used by other local services and may fail with
> `bind: Permission denied`. If so, use a different local port:
> `-L 9080:localhost:8080` then browse `localhost:9080` instead.
> The other three tunnels (3000, 9090, 16686) will still work even if 8080 fails.

### 10.2 Access the tools

| Tool | URL | Credentials | What You See |
|---|---|---|---|
| **Grafana** | http://localhost:3000 | admin / (your DB owner password) | 5 operational dashboards |
| **Prometheus** | http://localhost:9090 | None | Raw metrics, target health |
| **Jaeger** | http://localhost:16686 | None | Distributed traces |
| **Swagger UI** | http://localhost:8080/api/v1/docs | None | Interactive API documentation |
| **OpenAPI Spec** | http://localhost:8080/api/v1/api-docs | None | Raw OpenAPI JSON |

### 10.3 Swagger UI and API Documentation

Swagger UI is disabled for public access (env var `SPRINGDOC_SWAGGER_UI_ENABLED=false` blocks it through the public URL). But it's still accessible via the SSH tunnel because the tunnel connects directly to the backend container, bypassing the frontend nginx that applies the env var restriction.

> **Wait — is Swagger really accessible via tunnel?** The `SPRINGDOC_SWAGGER_UI_ENABLED=false` environment variable disables Swagger at the Spring Boot application level, not just at the nginx level. If you need Swagger for development via tunnel, temporarily set `SPRINGDOC_SWAGGER_UI_ENABLED=true` in the env file and restart the backend:
> ```bash
> # On the VM:
> sed -i 's/SPRINGDOC_SWAGGER_UI_ENABLED=false/SPRINGDOC_SWAGGER_UI_ENABLED=true/' ~/fabt-secrets/.env.prod
> sed -i 's/SPRINGDOC_API_DOCS_ENABLED=false/SPRINGDOC_API_DOCS_ENABLED=true/' ~/fabt-secrets/.env.prod
> docker compose -f docker-compose.yml -f ~/fabt-secrets/docker-compose.prod.yml \
>   --env-file ~/fabt-secrets/.env.prod --profile observability \
>   up -d --force-recreate backend
> ```
> Remember to disable it again before sharing the demo URL publicly.

**What Swagger shows you:**
- Every API endpoint with method, path, parameters, request/response schemas
- "Try it out" button to test endpoints interactively
- Authentication: paste a JWT token (from login response) into the Authorize dialog
- Useful for understanding the API during development or showing to technical evaluators

### 10.3 Grafana dashboards to show

| Dashboard | What It Shows | Demo Moment |
|---|---|---|
| **FABT Operations** | Bed search rate, latency, reservations, stale shelters | "Here's how we monitor the system in real time" |
| **CoC Analytics** | Utilization rate, zero-result searches, conversion rate | "Here's unmet demand data no HMIS captures" |
| **DV Referrals** | Referral request rate, acceptance rate, response time | "Here's the DV pipeline — zero PII, all metrics" |
| **HMIS Bridge** | Push rate, failures, circuit breaker state | "Here's the vendor integration health" |
| **Virtual Thread Performance** | JVM threads, CPU, memory, connection pool | "Here's the system under load" |

### 10.4 Jaeger trace exploration

1. Open http://localhost:16686
2. Service dropdown: select `finding-a-bed-tonight`
3. Click **Find Traces**
4. Click any trace to see the waterfall — API → service → database
5. Show this to a city IT person: "Every request is traceable"

---

## Part 11 — Post-Deployment Security Hardening

Complete every item below before sharing the URL with anyone.

### 11.1 Verify what's disabled

```bash
# Swagger UI should be disabled via public URL
curl -s -o /dev/null -w "%{http_code}" https://YOUR_DOMAIN/api/v1/docs
# Expected: 404 (Swagger disabled via SPRINGDOC_SWAGGER_UI_ENABLED=false)

# API docs endpoint should be disabled
curl -s -o /dev/null -w "%{http_code}" https://YOUR_DOMAIN/api/v1/api-docs
# Expected: 404

# Test reset endpoint should not exist (lite profile, not dev)
curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  https://YOUR_DOMAIN/api/v1/test/reset \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Confirm-Reset: DESTROY"
# Expected: 403 or 404 (endpoint only exists in dev/test profiles)
```

> **Swagger is still accessible via SSH tunnel** (see Part 10.3) — this is intentional.
> Public users can't reach it, but you can for development and technical evaluations.

### 11.2 Verify management port is not public

```bash
# From your local machine (NOT the SSH tunnel):
curl -s --connect-timeout 5 http://YOUR_IP:9091/actuator/prometheus  # direct to management port, NOT via domain
# Expected: connection refused or timeout
```

### 11.3 Verify internal ports are not public

```bash
# From your local machine:
curl -s --connect-timeout 5 http://YOUR_IP:5432
curl -s --connect-timeout 5 http://YOUR_IP:3000
curl -s --connect-timeout 5 http://YOUR_IP:9090
curl -s --connect-timeout 5 http://YOUR_IP:16686
# ALL should timeout or refuse connection
```

### 11.4 Change default passwords

**Seed user passwords are `admin123`.** For a demo shared with external people:

1. Log in as `admin@dev.fabt.org`
2. Admin → Users tab → click **Reset Password** on each account
3. Set unique passwords for admin and cocadmin accounts
4. Keep `outreach@dev.fabt.org` with a simple password for demo participants
5. Write down the new passwords and store securely

### 11.5 Who should get which account

| Audience | Give Them | Why |
|---|---|---|
| Family / friends | Outreach worker account | Can search beds, hold beds, see the core flow. Cannot break anything. |
| Shelter coordinator candidates | Outreach worker account | Same — they see the search experience first. |
| CoC administrator evaluators | CoC Admin account | Can see dashboard, analytics, surge. Cannot delete users or manage DV. |
| Only you | Platform Admin account | Full access including DV shelters, user management, HIC/PIT export. |

### 11.6 Rate limiting verification

> **Lite tier note:** Rate limiting uses in-memory counters in the lite deployment tier.
> The in-memory rate limiter may not trigger 429 responses as reliably as the Redis-backed
> rate limiter in the standard tier. If all 11 attempts return 401, this is expected on lite.

```bash
# Login rate limit: 10 attempts per 15 minutes per IP
# Try 11 rapid login attempts:
for i in $(seq 1 11); do
  curl -s -o /dev/null -w "%{http_code} " \
    -X POST http://localhost:8080/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"tenantSlug":"dev-coc","email":"wrong@test.org","password":"wrong"}'
done
echo ""
# First 10 should be 401, #11 should be 429 (rate limited)
# On lite tier: all 11 may return 401 — see note above
```

---

## Part 12 — Post-Deployment Sanity Checks

Run these checks every time you update the deployment.

### 12.1 Infrastructure

```bash
# All containers running?
docker ps --format "table {{.Names}}\t{{.Status}}" | sort

# Expected: 7 containers, all "Up"
```

### 12.2 Application health

```bash
curl -s http://localhost:9091/actuator/health/liveness | python3 -m json.tool
curl -s http://localhost:9091/actuator/health/readiness | python3 -m json.tool
# Both: {"status":"UP"}
```

### 12.3 DV canary (most important check)

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"tenantSlug":"dev-coc","email":"outreach@dev.fabt.org","password":"admin123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# Must return NO DV shelters
curl -s -X POST http://localhost:8080/api/v1/queries/beds \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"populationType":"DV_SURVIVOR","limit":20}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{len(d)} results — {\"PASS\" if len(d)==0 else \"FAIL: DV SHELTERS VISIBLE\"}')"
```

### 12.4 Observability health

```bash
# Prometheus target up?
curl -s http://localhost:9090/api/v1/targets \
  | python3 -c "import sys,json; t=json.load(sys.stdin)['data']['activeTargets']; print(f'{len(t)} targets, health: {t[0][\"health\"] if t else \"none\"}')"

# Grafana healthy?
curl -s http://localhost:3000/api/health | python3 -c "import sys,json; print(json.load(sys.stdin)['database'])"
# "ok"

# Jaeger has service?
curl -s http://localhost:16686/api/services \
  | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(f'Services: {d}')"
```

### 12.5 Database migrations

```bash
docker exec finding-a-bed-tonight-postgres-1 psql -U fabt -d fabt -c \
  "SELECT count(*) AS migrations,
          bool_and(success) AS all_success
   FROM flyway_schema_history;"
# migrations: 30, all_success: t
```

### 12.6 TLS certificate

```bash
sudo certbot certificates
# Check expiry date — should be 60+ days out
echo | openssl s_client -servername YOUR_DOMAIN -connect YOUR_DOMAIN:443 2>/dev/null \
  | openssl x509 -noout -dates
```

---

## Part 13 — Keeping It Updated

```bash
cd ~/finding-a-bed-tonight
git fetch --tags
git checkout vX.X.X   # new version tag

# Rebuild
cd backend && mvn package -DskipTests -q && cd ..
cd frontend && npm ci --silent && npm run build && cd ..

# Rebuild images
docker build -f infra/docker/Dockerfile.backend \
  -t fabt-backend:latest .
docker build -f infra/docker/Dockerfile.frontend \
  -t fabt-frontend:latest .

# Restart (graceful ~1s downtime)
docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --env-file ~/fabt-secrets/.env.prod \
  --profile observability \
  up -d --force-recreate backend frontend
```

Flyway applies new migrations automatically on backend startup.

---

## Part 14 — Operational Reference

### Container management
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker logs fabt-backend --tail 50 -f
docker restart fabt-backend   # graceful ~1s
```

### Stop / start everything
```bash
# Stop
docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --profile observability down

# Start
docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --env-file ~/fabt-secrets/.env.prod \
  --profile observability up -d
```

### Database access
```bash
docker exec -it finding-a-bed-tonight-postgres-1 psql -U fabt -d fabt
```

### Reset seed data (restores demo to clean state)
```bash
docker exec -i finding-a-bed-tonight-postgres-1 psql -U fabt -d fabt -c \
  "TRUNCATE bed_availability, reservation, referral_token,
   hmis_outbox_entries, bed_search_log, daily_utilization_summary,
   audit_events CASCADE;"

docker exec -i finding-a-bed-tonight-postgres-1 psql -U fabt -d fabt \
  < ~/finding-a-bed-tonight/infra/scripts/seed-data.sql

docker exec -i finding-a-bed-tonight-postgres-1 psql -U fabt -d fabt \
  < ~/finding-a-bed-tonight/infra/scripts/demo-activity-seed.sql

docker restart fabt-backend
```

---

## Part 15 — Troubleshooting

### Backend won't start — "password authentication failed for user fabt_app"
```bash
docker logs fabt-backend --tail 20 | grep -i "password\|FATAL"
```
Most common: `fabt_app` password not rotated. Re-run password rotation (Part 7.4).
The password rotation script must run **after** every fresh database start.

### Backend won't start — "relation does not exist"
```bash
docker logs fabt-backend | grep -E "ERROR|Flyway|migration"
```
`fabt_app` role missing. Re-run password rotation (Part 7.4).

### 403 on browser login — "Request failed with status 403"
CORS is blocking the browser's request. Verify `FABT_CORS_ALLOWED_ORIGINS` is set in `.env.prod`
and included in the backend environment in `docker-compose.prod.yml`:
```bash
docker exec fabt-backend env | grep CORS
# Must show: FABT_CORS_ALLOWED_ORIGINS=https://YOUR_DOMAIN
```
If blank, add it to both files (see Part 6.3 and 6.4) and restart the backend.

### 401 on all API calls after restart
```bash
docker exec fabt-backend env | grep FABT_JWT
# Must show the secret — if blank, --env-file isn't being picked up
```

### "variable is not set" warnings on docker compose up
You forgot `--env-file ~/fabt-secrets/.env.prod`. Do NOT use `source .env.prod` —
the file uses `KEY=value` without `export`, so shell sourcing does not work.

### Prometheus target "down"
```bash
# Check if backend management port is reachable inside Docker network
docker exec finding-a-bed-tonight-prometheus-1 wget -q -O- http://backend:9091/actuator/health/liveness
```
If it fails, the backend's `MANAGEMENT_SERVER_ADDRESS` may still be `127.0.0.1` instead of `0.0.0.0`.

### Grafana shows "No data"
```bash
# Verify Prometheus datasource is accessible from Grafana
docker exec finding-a-bed-tonight-grafana-1 wget -q -O- http://prometheus:9090/api/v1/status/config
```

### Jaeger shows no traces
Check `TRACING_SAMPLING_PROBABILITY` is `1.0` (not `0.0`) and `MANAGEMENT_OTLP_TRACING_ENDPOINT` points to `http://otel-collector:4318/v1/traces`.

### DV shelter visible to outreach worker
**Stop the demo immediately.** Check backend logs for RLS errors:
```bash
docker logs fabt-backend | grep -i "role\|rls\|dv"
```

### TLS certificate expired
```bash
sudo certbot renew
sudo systemctl reload nginx
```

### Bed Search page keeps refreshing every few seconds

**Symptom:** The search results flash/reload constantly. Browser console shows repeated
`/api/v1/queries/beds` and `/api/v1/dv-referrals/mine` requests every 5 seconds, plus
Workbox `Cache.put()` errors.

**Cause:** The frontend nginx is buffering the SSE notification stream
(`/api/v1/notifications/stream`). SSE requires an unbuffered, long-lived connection.
When nginx buffers it, the EventSource disconnects and auto-reconnects every few seconds.
Each reconnect triggers a full data refetch — creating constant page refreshing.

**Fix:** The frontend container's `nginx.conf` must have a dedicated SSE location block
**before** the general `/api/` block:

```nginx
# SSE notifications — must disable buffering for streaming
location /api/v1/notifications/stream {
    proxy_pass http://backend:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 86400s;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding off;
}
```

If you see this after a deploy, the nginx.conf was likely overwritten without the SSE block.
Rebuild the frontend image and redeploy.

**In plain language:** The app has a live connection to the server that listens for bed
availability changes — like a walkie-talkie. If the web server accidentally hangs up on
that connection every few seconds, the app reloads all data each time to catch up, causing
the screen to keep refreshing. The fix keeps that connection open.

---

## Part 16 — Go/No-Go Checklist

Complete every item before declaring the demo ready.

**Infrastructure:**
- [ ] VM Running in Oracle Console
- [ ] Ports 80 and 443 open in Oracle Security Lists
- [ ] Ports 80 and 443 open in iptables (Part 2.2) AND Ubuntu ufw
- [ ] All 7 containers Up and healthy

**Database:**
- [ ] `flyway_schema_history` has 30 rows, all `success=true`
- [ ] `fabt_app` password rotation completed

**Application:**
- [ ] `/actuator/health/liveness` returns `{"status":"UP"}`
- [ ] `/actuator/health/readiness` returns `{"status":"UP"}`
- [ ] Bed search returns results as outreach worker
- [ ] DV shelters invisible to outreach worker
- [ ] 90-minute hold countdown visible and ticking
- [ ] CoC Analytics tab loads with historical data
- [ ] Shelter edit works (admin → Shelters → Edit)
- [ ] 211 import: click "2-1-1 Import" from Admin panel → import page loads (not a blank page)
- [ ] 211 import: upload CSV → preview shows column mapping → confirm → success
- [ ] Dark mode works when OS dark mode is enabled

**Security:**
- [ ] Swagger UI returns 404
- [ ] Test reset endpoint returns 403/404
- [ ] Management port 9091 not reachable from internet
- [ ] Prometheus/Grafana/Jaeger not reachable from internet
- [ ] TLS certificate valid — browser shows padlock
- [ ] HTTP redirects to HTTPS
- [ ] CORS origin set to `https://YOUR_DOMAIN` (browser login works)
- [ ] CSV injection protection active (imported data sanitized — CWE-1236)
- [ ] Default passwords changed (or accepted for demo scope)
- [ ] Rate limiting working (429 on 11th login attempt, or all 401 on lite tier — see 11.6)

**Observability:**
- [ ] Prometheus target shows "up"
- [ ] Grafana FABT Operations dashboard renders data
- [ ] Jaeger shows traces for `finding-a-bed-tonight` service
- [ ] SSH tunnel works from local machine

**Mobile:**
- [ ] Platform accessible on a phone browser (use `https://YOUR_DOMAIN`, NOT bare IP)
- [ ] Dark mode renders correctly on phone

**Before sharing beyond family and friends:**
- [ ] OWASP ZAP baseline scan against `https://YOUR_DOMAIN` (see Part 16.1 below)

### 16.1 OWASP ZAP Baseline Scan (before external sharing)

The ZAP baseline scan in SECURITY-ASSESSMENT.md Section 3.6 was run against local dev.
Before sharing the live deployment with anyone outside family and friends (city IT evaluators,
CoC administrators, funders), re-run ZAP against the production URL. Different network path,
nginx TLS termination, and Cloudflare proxy mean different findings. Takes ~20 minutes.

```bash
# From any machine with Docker installed (your laptop is fine):
docker run -t zaproxy/zap-stable zap-baseline.py \
  -t https://YOUR_DOMAIN \
  -c zap-baseline.conf \
  -I
```

> **Why this matters:** Any city IT officer evaluating FABT will run a scanner against the
> public URL. Running ZAP yourself first means you see what they'll see — and fix it before
> they do. This is exactly the kind of due diligence that builds trust with technical evaluators.

Review the report for any WARN or FAIL items. With the current nginx configuration (v0.21.0+), the following rules should all PASS:
- `[10035]` Strict-Transport-Security — set at host nginx (TLS layer)
- `[10038]` Content-Security-Policy — set at frontend container nginx
- `[10036]` Server version leak — suppressed by `server_tokens off`
- `[10021]` X-Content-Type-Options — set on all responses including static assets
- `[10063]` Permissions Policy — set on all responses including static assets

Acceptable remaining WARNs (informational):
- `[10049]` Non-Storable Content — correct behavior for `no-cache` on HTML
- `[10055]` CSP style-src unsafe-inline — required for Vite critical CSS
- `[10109]` Modern Web Application — ZAP noting it's a SPA
- `[90004]` Cross-Origin-Opener-Policy missing — future improvement

---

## Reference: All Environment Variables

| Variable | Description |
|---|---|
| `POSTGRES_DB` | Database name (`fabt`) |
| `POSTGRES_USER` | PostgreSQL owner — Flyway DDL user |
| `POSTGRES_PASSWORD` | PostgreSQL owner password |
| `FABT_DB_APP_USER` | Runtime app role (`fabt_app`) — RLS enforced |
| `FABT_DB_APP_PASSWORD` | App role password — must match rotated DB value |
| `FABT_DB_OWNER_USER` | Flyway migration user (same as `POSTGRES_USER`) |
| `FABT_DB_OWNER_PASSWORD` | Flyway migration password |
| `SPRING_DATASOURCE_URL` | JDBC URL for runtime connections |
| `FABT_DB_URL` | JDBC URL for Flyway migrations |
| `FABT_JWT_SECRET` | JWT signing secret — minimum 256 bits |
| `FABT_DEPLOYMENT_TIER` | `lite` — no Redis (standard tier untested) |
| `SPRING_PROFILES_ACTIVE` | `lite,observability` for demo |
| `MANAGEMENT_SERVER_ADDRESS` | `0.0.0.0` in Docker (for Prometheus scraping) |
| `MANAGEMENT_OTLP_TRACING_ENDPOINT` | OTel Collector endpoint for trace export |
| `TRACING_SAMPLING_PROBABILITY` | `1.0` for demo (all traces), `0.0` to disable |
| `SPRINGDOC_SWAGGER_UI_ENABLED` | `false` — Swagger disabled for demo security |
| `SPRINGDOC_API_DOCS_ENABLED` | `false` — API docs disabled for demo security |
| `FABT_NOAA_LAT` | NOAA weather latitude (default: RDU) |
| `FABT_NOAA_LON` | NOAA weather longitude (default: RDU) |
| `FABT_NOAA_STATION` | NOAA station ID (default: `KRDU`) |

---

*Finding A Bed Tonight — Oracle Always Free Demo Runbook*
*v0.21.0 · March 2026*
*Lite tier + Observability · Java 25 · Spring Boot 4.0*
*296 backend tests · 167 Playwright tests · Zero axe-core violations (light + dark)*
