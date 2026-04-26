# Oracle Always Free — FABT Demo Deployment Runbook

**Author:** Jordan Reyes (SRE)
**Version:** 3 — March 2026
**Target tag:** v0.14.1 (current latest — Java 25, Spring Boot 4.0, WCAG complete)
**VM target:** Oracle Cloud Always Free — 1× VM.Standard.A1.Flex (ARM64)
**Stack:** Standard tier — PostgreSQL 16 + Redis 7
**Reviewer:** Srinivasan Nallagounder — please review before executing Part 5+

---

## What You Get

- `https://YOUR_DOMAIN` — React PWA (nginx, TLS via Let's Encrypt)
- `https://YOUR_DOMAIN/api/` — Spring Boot 4.0 backend (Java 25, virtual threads)
- PostgreSQL 16 + Redis 7 (Standard tier)
- 10 seed shelters, 28 days of demo activity data, 3 demo users
- Default hold duration: 90 minutes
- Auto-renewing TLS — never expires manually
- **Cost: $0** — Oracle Always Free is free forever, not a trial

**Time estimate:** 2–3 hours end to end.

---

## What's Different from Previous Runbook Versions

If you've read an earlier version of this runbook, the meaningful changes are:

- **Java 25, not 21.** The backend runs on `eclipse-temurin:25-jre-alpine`. The
  VM needs JDK 25 for the Maven build. `JAVA_HOME` must be set explicitly.
- **Spring Boot 4.0.** Virtual threads enabled by default. Graceful shutdown
  configured — backend stops cleanly in ~1 second, not 36+ seconds.
- **26 Flyway migrations**, not 22. V22–V26 all merged to main. Clean-DB
  verification step added before first deploy.
- **Hold duration is 90 minutes**, not 45. All seed data and documentation
  reflect this. Tenant config UI allows per-tenant override.
- **28 days of demo activity seed data.** More realistic demo environment
  with historical utilization, search logs, and CoC Analytics data.

---

## Domain Decision

### Option A — nip.io (immediate, no registration)

nip.io is a free public wildcard DNS service. Your URL is:
```
https://YOUR_IP.nip.io
```
No configuration needed. Works immediately. Let's Encrypt TLS works with nip.io.
**Use this for initial setup and Srinivasan's review.**

### Option B — Real domain (before first external demo)

Register a real domain before showing the platform to anyone at Oak City Cares,
Street Reach, or Wake County. ~$12/year at Namecheap. A real domain is a
credibility signal in any city-level meeting.

> Throughout this runbook, replace `YOUR_DOMAIN` with either `YOUR_IP.nip.io`
> or your real domain, and `YOUR_IP` with the Oracle VM's public IP address.

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
    ┌──────────────────────────────────────────┐
    │  frontend (nginx:alpine)  :8081→80       │
    │    ├── React PWA static assets           │
    │    └── proxy /api/ → backend:8080        │
    │                                          │
    │  backend (eclipse-temurin:25) :8080      │
    │    ├── Spring Boot 4.0 + Java 25         │
    │    ├── Virtual threads enabled           │
    │    ├── Flyway migrations (26)            │
    │    ├── Graceful shutdown (30s timeout)   │
    │    └── Management port 9091 (lo only)   │
    │                                          │
    │  postgres (postgres:16-alpine)  :5432    │
    │  redis    (redis:7-alpine)      :6379    │
    └──────────────────────────────────────────┘
```

Ports 5432, 6379, 8080, 8081, 9091 are **never** exposed to the public internet.
Only 22 (SSH), 80 (HTTP → HTTPS redirect), and 443 (HTTPS) are public.

---

## Part 1 — Oracle Cloud Account and VM

### 1.1 Create Your Oracle Cloud Account

1. Go to: https://www.oracle.com/cloud/free/
2. Click **Start for free**
3. Home region: **US East (Ashburn)** — best A1 Flex availability
4. Enter credit card for identity verification (no charge)
5. Complete phone verification
6. Wait for "Your account is ready" email (10–30 min)

> **"Out of capacity" error:** The most common Always Free obstacle.
> Wait a few hours and retry. If Ashburn stays constrained after 24 hours,
> try US West (Phoenix).

### 1.2 Generate SSH Key Pair (Windows)

```powershell
ssh-keygen -t ed25519 -C "fabt-oracle-demo" `
  -f "$env:USERPROFILE\.ssh\fabt-oracle"
# Press Enter twice — no passphrase
```

View your public key (paste this into Oracle in step 1.3):
```powershell
Get-Content "$env:USERPROFILE\.ssh\fabt-oracle.pub"
```

### 1.3 Provision the VM

1. Oracle Console → **Compute → Instances → Create Instance**
2. Configure:

   | Field | Value |
   |---|---|
   | Name | `fabt-demo` |
   | Image | **Canonical Ubuntu 22.04** (not 24.04) |
   | Shape | **VM.Standard.A1.Flex** |
   | OCPUs | **4** |
   | Memory | **24 GB** |
   | Boot volume | **100 GB** |

3. **Add SSH keys** → paste the full contents of your `.pub` key
4. Click **Create** → wait ~3 minutes for **Running** state
5. Note the **Public IP address** — you'll use it throughout this runbook

### 1.4 Open Oracle Firewall Ports

Oracle blocks all inbound except port 22 by default.

1. Instance detail page → click the **Subnet** link
2. **Security Lists → Default Security List → Add Ingress Rules**

   | Source CIDR | Protocol | Dest Port |
   |---|---|---|
   | 0.0.0.0/0 | TCP | 80 |
   | 0.0.0.0/0 | TCP | 443 |

3. Leave port 22 in place. Do not open 5432, 6379, 8080, 8081, or 9091.

### 1.5 SSH to the VM

```powershell
ssh -i "$env:USERPROFILE\.ssh\fabt-oracle" ubuntu@YOUR_IP
```

All commands from this point forward run on the VM unless noted otherwise.

---

## Part 2 — VM Baseline Setup

### 2.1 System update

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### 2.2 Ubuntu firewall

Oracle Security Lists and Ubuntu ufw are independent — both must allow ports.

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

> **Critical:** Maven uses `JAVA_HOME`, not `PATH`. Ubuntu 22.04's default JDK
> is 21. We need 25. Both the environment variable and PATH must be set.

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

Verify both `java` and `mvn` see JDK 25:
```bash
java -version
# openjdk version "25" ...

echo $JAVA_HOME
# /usr/lib/jvm/temurin-25

mvn -version
# Apache Maven ... Java version: 25 ...
```

> If `mvn -version` still shows Java 21, run
> `sudo update-alternatives --config java` and select JDK 25,
> then `source ~/.bashrc` again.

### 2.5 Install Maven, Node.js 20, Certbot, and nginx

```bash
# Maven
sudo apt-get install -y maven

# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Certbot and nginx
sudo apt-get install -y certbot nginx
sudo systemctl enable nginx
```

Final verification:
```bash
java -version    # openjdk 25
mvn -version     # Java version: 25
node -version    # v20.x
nginx -version   # nginx/1.x
```

---

## Part 3 — DNS Verification

### nip.io

```bash
nslookup YOUR_IP.nip.io
# Should return YOUR_IP immediately — no config needed
```

### Real domain

Add an A record pointing to `YOUR_IP`, then:
```bash
nslookup YOUR_DOMAIN
# Should return YOUR_IP
```

DNS must resolve correctly before Let's Encrypt will issue a certificate
in Part 8. Don't rush this step.

---

## Part 4 — Build the Application

### 4.1 Clone at v0.14.1

```bash
cd ~
git clone https://github.com/ccradle/finding-a-bed-tonight.git
cd finding-a-bed-tonight
git checkout v0.14.1
```

Confirm the tag:
```bash
git describe --tags
# v0.14.1
```

### 4.2 Verify all 26 migrations are present

```bash
ls backend/src/main/resources/db/migration/ | wc -l
# Should show 27 (V1-V26 + V8.1)

ls backend/src/main/resources/db/migration/ | sort | tail -5
# Should end at V26__...sql
```

### 4.3 Build the backend JAR

```bash
cd backend
mvn package -DskipTests -q
cd ..
```

First run takes 5–8 minutes (dependency download). Subsequent builds are faster.

```bash
ls backend/target/finding-a-bed-tonight-*.jar
# Must exist before continuing
```

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
# Backend: eclipse-temurin:25-jre-alpine (Java 25, ARM64 native)
docker build -f infra/docker/Dockerfile.backend \
  -t fabt-backend:v0.14.1 \
  -t fabt-backend:latest .

# Frontend: node:20-alpine + nginx:alpine (ARM64 native)
docker build -f infra/docker/Dockerfile.frontend \
  -t fabt-frontend:v0.14.1 \
  -t fabt-frontend:latest .
```

Verify:
```bash
docker images | grep fabt
```

Spot-check that the backend image is actually running Java 25:
```bash
docker run --rm fabt-backend:latest java -version
# openjdk version "25" ...
```

---

## Part 5 — Clean Database Verification

26 migrations is a meaningful chain. Run them against a throwaway container
before deploying to the real environment. This catches any ordering or
compatibility issues before they cause a failed first boot.

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

# Boot backend against throwaway DB (migrations only)
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

# Watch for migration completion (allow 60 seconds)
echo "Waiting for migrations..."
sleep 60
docker logs fabt-migrate-run 2>&1 \
  | grep -E "migration|Started|ERROR|Exception" | head -30

# Confirm all 26 migrations applied
docker exec fabt-migrate-test psql -U fabt -d fabt -c \
  "SELECT installed_rank, version, description, success
   FROM flyway_schema_history
   ORDER BY installed_rank;"
# Should show 27 rows, all success=true

# Clean up
docker stop fabt-migrate-run fabt-migrate-test
docker rm fabt-migrate-run fabt-migrate-test
echo "Verification complete"
```

If any migration shows `success=false` or you see `ERROR` in the logs,
stop here and resolve before deploying to the real environment.

---

## Part 6 — Production Configuration

### 6.1 Create secrets directory

```bash
mkdir -p ~/fabt-secrets
chmod 700 ~/fabt-secrets
```

### 6.2 Generate strong secrets

Run each line and **save all three values** in a password manager
before continuing. You cannot recover them after closing the terminal.

```bash
echo "DB_OWNER_PW: $(openssl rand -base64 32)"
echo "DB_APP_PW:   $(openssl rand -base64 32)"
echo "JWT_SECRET:  $(openssl rand -base64 64)"
```

### 6.3 Create the environment file

```bash
cat > ~/fabt-secrets/.env.prod << 'EOF'
# FABT Production — Oracle Always Free (v0.14.1)
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

# Deployment profile
FABT_DEPLOYMENT_TIER=standard
SPRING_PROFILES_ACTIVE=standard

# Redis (Docker service name — must match compose)
REDIS_HOST=redis
REDIS_PORT=6379

# Management port — localhost only, never expose publicly
MANAGEMENT_SERVER_ADDRESS=127.0.0.1

# Tracing disabled for demo
TRACING_SAMPLING_PROBABILITY=0.0

# NOAA weather monitoring (Raleigh/RDU defaults)
FABT_NOAA_LAT=35.8776
FABT_NOAA_LON=-78.7875
FABT_NOAA_STATION=KRDU
EOF
```

Edit and replace all three `REPLACE_*` placeholders:
```bash
nano ~/fabt-secrets/.env.prod
```

Lock down permissions and verify no placeholders remain:
```bash
chmod 600 ~/fabt-secrets/.env.prod
grep REPLACE ~/fabt-secrets/.env.prod
# Must return nothing
```

### 6.4 Create the production Compose override

```bash
cat > ~/fabt-secrets/docker-compose.prod.yml << 'EOF'
# Production override — Oracle Always Free (v0.14.1)

services:

  postgres:
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports: []

  redis:
    restart: unless-stopped
    ports: []

  backend:
    image: fabt-backend:latest
    container_name: fabt-backend
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE}
      SPRING_DATASOURCE_URL: ${SPRING_DATASOURCE_URL}
      FABT_DB_APP_USER: ${FABT_DB_APP_USER}
      FABT_DB_APP_PASSWORD: ${FABT_DB_APP_PASSWORD}
      FABT_DB_URL: ${FABT_DB_URL}
      FABT_DB_OWNER_USER: ${FABT_DB_OWNER_USER}
      FABT_DB_OWNER_PASSWORD: ${FABT_DB_OWNER_PASSWORD}
      FABT_JWT_SECRET: ${FABT_JWT_SECRET}
      FABT_DEPLOYMENT_TIER: ${FABT_DEPLOYMENT_TIER}
      REDIS_HOST: ${REDIS_HOST}
      REDIS_PORT: ${REDIS_PORT}
      MANAGEMENT_SERVER_ADDRESS: ${MANAGEMENT_SERVER_ADDRESS}
      TRACING_SAMPLING_PROBABILITY: ${TRACING_SAMPLING_PROBABILITY}
      FABT_NOAA_LAT: ${FABT_NOAA_LAT}
      FABT_NOAA_LON: ${FABT_NOAA_LON}
      FABT_NOAA_STATION: ${FABT_NOAA_STATION}
    ports: []

  frontend:
    image: fabt-frontend:latest
    container_name: fabt-frontend
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "127.0.0.1:8081:80"
EOF
```

### 6.5 Create the fabt_app password rotation script

`init-app-user.sql` creates the `fabt_app` role with the hardcoded
password `'fabt_app'`. Rotate it immediately after first PostgreSQL startup.
**Do not skip this step.**

```bash
cat > ~/fabt-secrets/rotate-db-password.sh << 'ROTEOF'
#!/bin/bash
set -euo pipefail
source ~/fabt-secrets/.env.prod

echo "Rotating fabt_app password..."
docker exec -i fabt-postgres psql -U fabt -d fabt << SQL
ALTER ROLE fabt_app PASSWORD '${FABT_DB_APP_PASSWORD}';
SQL
echo "Done."
ROTEOF
chmod 700 ~/fabt-secrets/rotate-db-password.sh
```

---

## Part 7 — First Start

### 7.1 Start the stack

```bash
cd ~/finding-a-bed-tonight

docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --env-file ~/fabt-secrets/.env.prod \
  --profile standard \
  up -d
```

### 7.2 Watch startup

```bash
docker compose logs -f backend
```

Flyway runs all 26 migrations automatically. Allow 30–60 seconds.
You should see migration log lines followed by:
```
Started Application in X.XXX seconds
```

Press Ctrl+C once started. Check all containers are healthy:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
# fabt-backend    Up X minutes
# fabt-frontend   Up X minutes
# fabt-postgres   Up X minutes (healthy)
# fabt-redis      Up X minutes (healthy)
```

### 7.3 Rotate the fabt_app password (one-time)

```bash
~/fabt-secrets/rotate-db-password.sh

docker restart fabt-backend

# Wait for restart
sleep 15
curl -s http://localhost:8080/actuator/health/liveness
# {"status":"UP"}
```

### 7.4 Load seed data

```bash
docker exec -i fabt-postgres \
  psql -U fabt -d fabt \
  < ~/finding-a-bed-tonight/infra/scripts/seed-data.sql
```

Expected: multiple `INSERT 0 N` lines. Any `ERROR` means a migration
didn't complete — check Part 5 verification.

### 7.5 Verify health

```bash
curl -s http://localhost:8080/actuator/health/liveness \
  | python3 -m json.tool
# { "status": "UP" }

curl -s http://localhost:8080/actuator/health/readiness \
  | python3 -m json.tool
# { "status": "UP" } — confirms DB connection is healthy
```

### 7.6 Verify DV shelter protection — critical, do not skip

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

**Expected: no output.** "Safe Haven" (the DV shelter) must be invisible
to the outreach worker. If it appears, RLS is broken — do not proceed.

### 7.7 Verify bed search returns results

```bash
curl -s -X POST http://localhost:8080/api/v1/queries/beds \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"populationType":"SINGLE_ADULT","limit":5}' \
  | python3 -m json.tool
```

Expected: array of shelter results with `bedsAvailable`, `dataFreshness`,
and `distanceKm` fields.

---

## Part 8 — TLS and Public Access

### 8.1 Configure host nginx

```bash
sudo tee /etc/nginx/sites-available/fabt << 'NGINXEOF'
server {
    listen 80;
    server_name YOUR_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}
NGINXEOF

# Replace placeholder with actual domain
sudo sed -i 's/YOUR_DOMAIN/ACTUAL_DOMAIN_HERE/g' \
  /etc/nginx/sites-available/fabt

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

### 8.2 Obtain TLS certificate

```bash
sudo certbot --nginx \
  -d YOUR_DOMAIN \
  --non-interactive \
  --agree-tos \
  --email YOUR_EMAIL \
  --redirect
```

Certbot configures nginx for HTTPS and sets up HTTP→HTTPS redirect automatically.

Verify auto-renewal:
```bash
sudo certbot renew --dry-run
# Should complete without errors
```

### 8.3 Test from a browser

Navigate to `https://YOUR_DOMAIN`.

- Browser shows padlock (valid TLS)
- FABT login page loads
- Log in: tenant `dev-coc`, email `outreach@dev.fabt.org`, password `admin123`
- Test on a phone browser — this is the device Darius uses

---

## Part 9 — Demo Users and Credentials

| Role | Email | Password | What They See |
|---|---|---|---|
| Platform Admin | `admin@dev.fabt.org` | `admin123` | Full admin panel, CoC Analytics, HMIS config, all tabs |
| CoC Admin | `cocadmin@dev.fabt.org` | `admin123` | Dashboard, analytics tab, surge controls |
| Outreach Worker | `outreach@dev.fabt.org` | `admin123` | Bed search, 90-min hold, no DV shelter visibility |

**Default hold duration:** 90 minutes. Configurable per tenant:
Admin → Tenant Config → Hold Duration Minutes.

**DV shelter:** "Safe Haven" is invisible to the outreach worker account.
Visible to admin and CoC admin (dvAccess=true).

**CoC Analytics:** The admin and CoC admin see 28 days of historical
utilization data, zero-result demand signals, and batch job history.
This is the feature Marcus Okafor needed before CoC adoption conversations.

**Demo flow recommendation:**
1. Outreach worker login → bed search → hold a bed → show 90-min countdown
2. Switch to coordinator → update bed count → observe the hold indicator
3. Switch to admin → CoC Analytics tab → show utilization trends and demand signals
4. Admin → HMIS Export tab → show preview and push history

---

## Part 10 — Keeping It Updated

```bash
cd ~/finding-a-bed-tonight

# Pull latest or checkout a specific tag
git pull origin main
# or: git checkout vX.X.X

# Rebuild
cd backend && mvn package -DskipTests -q && cd ..
cd frontend && npm ci --silent && npm run build && cd ..

# Rebuild images
docker build -f infra/docker/Dockerfile.backend \
  -t fabt-backend:latest .
docker build -f infra/docker/Dockerfile.frontend \
  -t fabt-frontend:latest .

# Restart (graceful shutdown ~1s, ~2s total downtime)
docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --env-file ~/fabt-secrets/.env.prod \
  --profile standard \
  up -d --force-recreate backend frontend
```

Flyway applies any new migrations automatically on backend startup.

---

## Part 11 — Operational Reference

### Container status
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Logs
```bash
docker logs fabt-backend  --tail 50 -f
docker logs fabt-frontend --tail 20
docker logs fabt-postgres --tail 20
```

### Restart
```bash
docker restart fabt-backend   # graceful ~1s
docker restart fabt-frontend
```

### Stop / start everything
```bash
# Stop
docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --profile standard down

# Start
docker compose \
  -f docker-compose.yml \
  -f ~/fabt-secrets/docker-compose.prod.yml \
  --env-file ~/fabt-secrets/.env.prod \
  --profile standard up -d
```

### Database access
```bash
docker exec -it fabt-postgres psql -U fabt -d fabt
```

Key queries:
```sql
-- Confirm all 26 migrations applied
SELECT installed_rank, version, description, success
FROM flyway_schema_history ORDER BY installed_rank;
-- 27 rows, all success=true

-- Current bed availability
SELECT s.name, ba.population_type,
  ba.beds_total, ba.beds_occupied, ba.beds_on_hold,
  (ba.beds_total - ba.beds_occupied - ba.beds_on_hold) AS available,
  ba.snapshot_ts
FROM bed_availability ba
JOIN shelter s ON s.id = ba.shelter_id
ORDER BY ba.snapshot_ts DESC LIMIT 20;

-- Active holds with countdown
SELECT r.id, s.name, r.population_type, r.status,
  EXTRACT(EPOCH FROM (r.expires_at - NOW()))/60 AS minutes_left
FROM reservation r
JOIN shelter s ON s.id = r.shelter_id
WHERE r.status = 'HELD' ORDER BY r.expires_at;

-- DV canary (outreach worker view — Safe Haven must not appear)
SET app.current_tenant_id = 'e0000000-0000-0000-0000-000000000001';
SET app.dv_access = 'false';
SELECT id, name, dv_shelter FROM shelter;

-- Spring Batch job history
SELECT job_instance_id, job_name, status, start_time, end_time
FROM BATCH_JOB_EXECUTION ORDER BY start_time DESC LIMIT 10;
```

### Reset seed data
```bash
docker exec -i fabt-postgres psql -U fabt -d fabt -c \
  "TRUNCATE bed_availability, reservation, referral_token,
   hmis_outbox_entries, bed_search_logs CASCADE;"

docker exec -i fabt-postgres psql -U fabt -d fabt \
  < ~/finding-a-bed-tonight/infra/scripts/seed-data.sql
```

---

## Part 12 — Troubleshooting

### Backend won't start — "relation does not exist"
Flyway migration failed. Check:
```bash
docker logs fabt-backend | grep -E "ERROR|Flyway|migration"
```
Most common cause: `fabt_app` role missing. The `init-app-user.sql`
init script only runs on first PostgreSQL volume initialization.
If you recreated the postgres volume, it will run again automatically.

### 401 on all API calls after restart
JWT secret not loading:
```bash
docker exec fabt-backend env | grep FABT_JWT
# Must show the secret — if blank, --env-file isn't being picked up
```

### fabt_app password mismatch on startup
```bash
# Verify role exists
docker exec -i fabt-postgres psql -U fabt -c "\du fabt_app"

# Re-rotate
~/fabt-secrets/rotate-db-password.sh
docker restart fabt-backend
```

### Nginx 502 Bad Gateway
```bash
docker ps | grep frontend        # Is it running?
curl -s http://127.0.0.1:8081/  # Is port 8081 responding?
```
If the container is running but 8081 isn't responding, wait 10 seconds
and retry — nginx inside the container may still be starting.

### TLS certificate expired
```bash
sudo certbot renew
sudo systemctl reload nginx
```

### DV shelter visible to outreach worker
Stop the demo. Check backend logs for `SET ROLE fabt_app` errors.
Do not resume until resolved.

```bash
docker logs fabt-backend | grep -i "role\|rls\|dv"
```

### Virtual thread / connection pool warnings
```bash
# Check HikariCP pool metrics
curl -s http://localhost:9091/actuator/prometheus | grep hikari
```
Pool is sized for Standard tier demo load. Warnings during heavy testing
are expected — not a concern for demo use.

---

## Part 13 — Go/No-Go Checklist

Complete every item before declaring the demo environment ready.

**Infrastructure:**
- [ ] VM Running in Oracle Console
- [ ] Ports 80 and 443 open in Oracle Security Lists
- [ ] Ports 80 and 443 open in Ubuntu ufw
- [ ] All four containers Up: postgres (healthy), redis (healthy), backend, frontend

**Database:**
- [ ] `flyway_schema_history` has 27 rows, all `success=true`
- [ ] `fabt_app` password rotation completed

**Application:**
- [ ] `/actuator/health/liveness` returns `{"status":"UP"}`
- [ ] `/actuator/health/readiness` returns `{"status":"UP"}`
- [ ] Bed search returns results as outreach worker
- [ ] "Safe Haven" DV shelter does NOT appear in outreach worker search
- [ ] 90-minute hold countdown visible and ticking
- [ ] CoC Analytics tab loads with historical data
- [ ] Admin panel loads all tabs

**Public access:**
- [ ] TLS certificate valid — browser shows padlock
- [ ] HTTP redirects to HTTPS automatically
- [ ] Platform accessible on a phone browser
- [ ] Swagger UI accessible at `https://YOUR_DOMAIN/api/v1/docs`

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
| `FABT_DEPLOYMENT_TIER` | `lite` / `standard` / `full` |
| `SPRING_PROFILES_ACTIVE` | Spring profile(s) — use `standard` for demo |
| `REDIS_HOST` | Redis hostname — must match Docker service name (`redis`) |
| `REDIS_PORT` | Redis port (`6379`) |
| `MANAGEMENT_SERVER_ADDRESS` | Actuator bind address — `127.0.0.1` in production |
| `TRACING_SAMPLING_PROBABILITY` | OTel sampling — `0.0` disables tracing |
| `FABT_NOAA_LAT` | NOAA weather latitude (default: RDU) |
| `FABT_NOAA_LON` | NOAA weather longitude (default: RDU) |
| `FABT_NOAA_STATION` | NOAA station ID (default: `KRDU`) |

---

*Finding A Bed Tonight — Oracle Always Free Demo Runbook v3*
*Jordan Reyes · SRE · March 2026*
*Target: v0.14.1 · Java 25 · Spring Boot 4.0 · Standard tier*
*For review by Srinivasan Nallagounder before executing Part 5+*
