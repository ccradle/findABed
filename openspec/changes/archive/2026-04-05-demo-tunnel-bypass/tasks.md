## 1. Branch & Baseline

- [x] 1.1 Create branch `demo-tunnel-bypass` in finding-a-bed-tonight repo
- [x] 1.2 Run `npm --prefix frontend run build` — confirm clean baseline
- [x] 1.3 Run backend tests (`mvn clean test 2>&1 | tee logs/backend-tests.log`) — confirm 388 pass

## 2. Container nginx — map directive

- [x] 2.1 Add `map $http_x_forwarded_for $fabt_traffic_source` directive to `infra/docker/nginx.conf` at the `http` level (before `server` block): `""` → "tunnel", `default` → "public"
- [x] 2.2 Add `proxy_set_header X-FABT-Traffic-Source $fabt_traffic_source` to all 3 API location blocks (SSE stream, version, general API)
- [x] 2.3 Add security model comment block in nginx.conf explaining: port 8081 localhost-only, iptables DROP, proxy_set_header replaces client values

## 3. Backend — DemoGuardFilter update

- [x] 3.1 Update `isInternalTraffic()` in `DemoGuardFilter.java`: check `X-FABT-Traffic-Source: tunnel` header first, retain existing IP-chain check as fallback for port 8080 direct access
- [x] 3.2 Add WARN-level log on bypass showing traffic source: `"Demo guard bypassed: {} traffic, remoteAddr={}, xff={}"` with header value
- [x] 3.3 Update existing block log to include traffic source: `"Demo guard blocked: {} {} from {} (source={})"` 
- [x] 3.4 Add security model comment in DemoGuardFilter explaining the nginx header trust chain

## 4. Local Testing — DemoGuard with demo profile

- [x] 4.1 Start local dev stack with nginx AND demo profile: `SPRING_PROFILES_ACTIVE=lite,demo ./dev-start.sh --nginx`
- [x] 4.1a Verify DemoGuard is active — attempt a blocked mutation: `curl -X POST http://localhost:8081/api/v1/users -H "Authorization: Bearer ..." -H "Content-Type: application/json" -d '{}'` should return 403 `demo_restricted`. If it returns 401 or 200, the demo profile is not active — check `dev-start.sh` profile handling and retry with `./dev-start.sh --nginx --demo` or direct env var override.
- [x] 4.2 Test public path simulation — curl with XFF header: `curl -H "X-Forwarded-For: 203.0.113.1" -X POST http://localhost:8081/api/v1/users ...` → should return 403 demo_restricted
- [x] 4.3 Test tunnel path simulation — curl without XFF header: `curl -X POST http://localhost:8081/api/v1/users ...` (with auth) → should succeed (no XFF = tunnel = bypass)
- [x] 4.4 Test forged header — curl with forged `X-FABT-Traffic-Source: tunnel` PLUS XFF: `curl -H "X-FABT-Traffic-Source: tunnel" -H "X-Forwarded-For: 203.0.113.1" -X POST http://localhost:8081/api/v1/users ...` → should return 403 (nginx overwrites forged header to "public")
- [x] 4.4a Verify nginx map values in backend logs — check log output from tasks 4.2 and 4.3: public path should log `source=public`, tunnel path should log `source=tunnel`. This confirms the nginx map directive is producing correct `X-FABT-Traffic-Source` values (not empty or missing).
- [x] 4.5 Test port 8080 direct — curl to `http://localhost:8080/api/v1/users ...` → should succeed (localhost IP-chain fallback)
- [x] 4.6 Test SSE works — connect to `http://localhost:8081/api/v1/notifications/stream`, verify heartbeats arrive
- [x] 4.7 Test safe mutations still work with XFF — `curl -H "X-Forwarded-For: 203.0.113.1" -X POST http://localhost:8081/api/v1/auth/login ...` → should succeed (login is allowlisted)
- [x] 4.8 Run backend tests — confirm 388 pass
- [x] 4.9 Run Playwright suite — confirm no regressions
- [x] 4.10 Screenshot: capture browser screenshot through localhost:8081 showing admin creating a user successfully (visual proof of bypass)

## 5. Negative Tests — DemoGuard Still Protects

- [x] 5.1 Playwright test (or manual): login via public path → attempt create user → verify "disabled in demo environment" message
- [x] 5.2 Playwright test: existing `demo-guard-verify.spec.ts` still passes
- [x] 5.3 Verify DV canary: non-DV outreach worker cannot see DV shelters (unrelated to this change but always verify)

## 6. Deployment

- [x] 6.1 Create `docs/oracle-update-notes-v0.29.3.md` — both containers restart, backout plan, full smoke test procedure
- [x] 6.2 Commit on branch, push, create PR
- [x] 6.3 Wait for CI scans to pass
- [x] 6.4 Merge to main, tag v0.29.3
- [x] 6.5 SSH to VM: `git pull origin main`
- [x] 6.6 Rebuild frontend Docker image: `npm --prefix frontend run build && docker build -t fabt-frontend:latest -f infra/docker/Dockerfile.frontend .`
- [x] 6.7 Rebuild backend Docker image: `cd backend && mvn package -DskipTests -q && cd .. && docker build -t fabt-backend:latest -f infra/docker/Dockerfile.backend .`
- [x] 6.8 Restart both containers: `docker compose ... up -d backend frontend`
- [x] 6.9 Wait 15 seconds for backend startup, verify version: `curl -s localhost:8080/api/v1/version`
- [x] 6.10 Cleanup: `docker image prune -f`

## 7. Post-Deploy Smoke Tests — Part A: Public Path (DemoGuard blocks)

- [x] 7.1 Open incognito browser → https://findabed.org → login as admin@dev.fabt.org
- [x] 7.2 Navigate to Administration → Users → click "Create User" → fill form → submit → verify "disabled in demo environment"
- [x] 7.3 Navigate to Surge tab → attempt activation → verify "disabled in demo environment"
- [x] 7.4 Navigate to Shelters → expand shelter → update bed count → save → verify save succeeds (safe mutation)
- [x] 7.5 Wait 60 seconds → verify no "Reconnecting" banner (SSE healthy)
- [x] 7.6 Login as outreach@dev.fabt.org → verify no DV shelters visible (DV canary)

## 8. Post-Deploy Smoke Tests — Part B: Tunnel Path (DemoGuard bypassed)

- [x] 8.1 Open SSH tunnel: `ssh -i ~/.ssh/fabt-oracle -L 8081:localhost:8081 ubuntu@150.136.221.232 -N`
- [x] 8.2 Open NEW incognito browser → http://localhost:8081 → login as admin@dev.fabt.org
- [x] 8.3 Navigate to Administration → Users → Create User → fill form → submit → verify user created successfully
- [x] 8.4 Delete the test user just created
- [x] 8.5 Navigate to Surge tab → activate surge → verify activation succeeds
- [x] 8.6 Deactivate the surge
- [x] 8.7 Navigate to Shelters → edit a shelter name → save → verify edit succeeds
- [x] 8.8 Revert the shelter name
- [x] 8.9 Wait 60 seconds → verify no "Reconnecting" banner (SSE via tunnel)

## 9. Post-Deploy Smoke Tests — Part C: Verify Public Path Still Protected

- [x] 9.1 Close SSH tunnel
- [x] 9.2 Open NEW incognito browser → https://findabed.org → login as admin
- [x] 9.3 Attempt create user → verify still blocked with "disabled in demo environment"
- [x] 9.4 Verify all 4 demo credentials still work (admin, cocadmin, outreach, dv-outreach with admin123)

## 10. Backout Plan (if anything goes wrong)

Document in runbook. Steps:
```
git checkout v0.29.2
npm --prefix frontend run build
docker build -t fabt-frontend:latest -f infra/docker/Dockerfile.frontend .
cd backend && mvn package -DskipTests -q && cd ..
docker build -t fabt-backend:latest -f infra/docker/Dockerfile.backend .
docker compose --env-file ~/fabt-secrets/.env.prod \
  -f docker-compose.yml -f ~/fabt-secrets/docker-compose.prod.yml \
  up -d backend frontend
```
