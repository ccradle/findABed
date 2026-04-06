## 1. DemoGuardFilter Implementation

- [x] 1.1 Create `DemoGuardFilter.java` in `org.fabt.shared.security` package — `@Component @Profile("demo") OncePerRequestFilter` with:
  - Allowlist of safe mutation URL patterns (auth, bed search, holds, referrals, availability, webhooks)
  - Block all other POST/PUT/PATCH/DELETE requests with 403 + JSON error body
  - Admin bypass — two-layer check:
    1. `request.getRemoteAddr()` is `127.0.0.1` or `::1` → bypass (direct backend tunnel via :8080)
    2. `X-Forwarded-For` header is absent AND `request.getRemoteAddr()` is a private network IP → bypass (container nginx tunnel via :8081, no upstream proxy)
  - GET/HEAD/OPTIONS always pass through (read-only access to all screens)

- [x] 1.2 Define the safe mutation allowlist — exact URL patterns and methods:

```
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/verify-totp
POST   /api/v1/auth/enroll-totp
POST   /api/v1/auth/confirm-totp-enrollment
POST   /api/v1/auth/access-code
POST   /api/v1/queries/beds
POST   /api/v1/reservations
PATCH  /api/v1/reservations/*/confirm
PATCH  /api/v1/reservations/*/cancel
POST   /api/v1/dv-referrals
PATCH  /api/v1/dv-referrals/*/accept
PATCH  /api/v1/dv-referrals/*/reject
PATCH  /api/v1/shelters/*/availability
POST   /api/v1/subscriptions
DELETE /api/v1/subscriptions/*
```

Explicitly BLOCKED (not on allowlist):
- `PUT /api/v1/auth/password` — prevents visitors from changing demo passwords
- All user CRUD, shelter CRUD, tenant management, surge, import, batch, OAuth2, TOTP admin delete, API keys

- [x] 1.3 Implement the JSON error response:

```json
{
  "error": "demo_restricted",
  "message": "<context-specific message>",
  "status": 403,
  "timestamp": "2026-04-02T..."
}
```

Use endpoint-aware messaging where possible (e.g., "User management is disabled" for `/api/v1/users`, "Shelter modification is disabled" for `/api/v1/shelters`). Fall back to generic "This operation is disabled in the demo environment." for unrecognized endpoints.

- [x] 1.4 Write unit tests for `DemoGuardFilter`:
  - Test: destructive endpoint blocked (POST /api/v1/users → 403)
  - Test: GET endpoint allowed (GET /api/v1/users → passes through)
  - Test: allowlisted mutation passes (POST /api/v1/reservations → passes through)
  - Test: localhost bypasses guard (remoteAddr=127.0.0.1 + POST /api/v1/users → passes through)
  - Test: Docker tunnel bypasses guard (remoteAddr=172.18.0.x + no X-Forwarded-For → passes through)
  - Test: public traffic NOT exempt (remoteAddr=172.18.0.x + X-Forwarded-For present → guard applies)
  - Test: password change blocked (PUT /api/v1/auth/password → 403)
  - Test: filter not created without demo profile (verify @Profile annotation)

- [x] 1.5 Write integration test: start backend with `demo` profile, verify a destructive endpoint returns 403 and a safe endpoint returns 200

## 2. Docker Network Localhost Verification

- [x] 2.1 Verify `request.getRemoteAddr()` and `X-Forwarded-For` behavior for all three traffic paths. Add temporary debug logging to the filter or a test endpoint, then test:

```bash
# Path 1: Public (Cloudflare → host nginx → container nginx → backend)
curl -s https://findabed.org/api/v1/version
# Expected: remoteAddr = Docker bridge IP (172.18.0.x), X-Forwarded-For = real client IP

# Path 2: SSH tunnel to :8081 (container nginx → backend, no host nginx)
ssh -i ~/.ssh/fabt-oracle -L 8081:localhost:8081 ubuntu@${FABT_VM_IP}
curl -s http://localhost:8081/api/v1/version
# Expected: remoteAddr = Docker bridge IP, X-Forwarded-For = ABSENT (no upstream proxy)

# Path 3: SSH tunnel to :8080 (backend directly, no nginx)
ssh -i ~/.ssh/fabt-oracle -L 8080:localhost:8080 ubuntu@${FABT_VM_IP}
curl -s http://localhost:8080/api/v1/version
# Expected: remoteAddr = 127.0.0.1, X-Forwarded-For = ABSENT
```

The filter bypass logic should be:
- Path 1 (public): has X-Forwarded-For → NOT exempt → guard applies ✓
- Path 2 (tunnel :8081): no X-Forwarded-For + private IP → exempt → full admin ✓
- Path 3 (tunnel :8080): localhost → exempt → full admin ✓

- [x] 2.2 If the X-Forwarded-For check is insufficient (e.g., container nginx adds its own X-Forwarded-For), implement fallback: check for a custom `X-Demo-Admin` header with a secret from `FABT_DEMO_ADMIN_SECRET` environment variable. Admin sets this header via curl/Postman through the tunnel.

## 3. Credential Reset (via SSH tunnel — after deploy)

Credentials must be reset AFTER the demo guard is deployed and the SSH tunnel admin bypass is verified (tasks 4.4–4.6). This uses the backend's own PasswordEncoder — no manual bcrypt hashing.

- [x] 3.1 Via SSH tunnel (`localhost:8081`), log in as admin and reset `cocadmin@dev.fabt.org` password to `admin123` using the admin password reset API:

```bash
# Through SSH tunnel (bypasses demo guard):
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8081/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@dev.fabt.org","password":"<current-admin-password>","tenantSlug":"dev-coc"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# Get cocadmin user ID
COCADMIN_ID=$(curl -s "http://localhost:8081/api/v1/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -c "import sys,json; users=json.load(sys.stdin); print([u['id'] for u in users if u['email']=='cocadmin@dev.fabt.org'][0])")

# Reset password via API
curl -s -X POST "http://localhost:8081/api/v1/users/$COCADMIN_ID/reset-password" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"newPassword":"admin123"}'
```

- [x] 3.2 Reset `admin@dev.fabt.org` password to `admin123` — admin can change their own password via `PUT /api/v1/auth/password` through the tunnel:

```bash
curl -s -X PUT "http://localhost:8081/api/v1/auth/password" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"currentPassword":"<current-admin-password>","newPassword":"admin123"}'
```

- [x] 3.3 Verify all 4 demo credentials work via the PUBLIC URL (not tunnel):

```bash
for user in outreach@dev.fabt.org cocadmin@dev.fabt.org admin@dev.fabt.org dv-outreach@dev.fabt.org; do
  result=$(curl -s -X POST "https://findabed.org/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$user\",\"password\":\"admin123\",\"tenantSlug\":\"dev-coc\"}" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if 'accessToken' in d else 'FAIL')")
  echo "$user: $result"
done
# Expected: all 4 return OK
```

## 4. Deploy Demo Guard

- [x] 4.1 Build backend with demo guard filter included

- [x] 4.2 Rebuild backend Docker image on Oracle VM

- [x] 4.3 Add `demo` to `SPRING_PROFILES_ACTIVE` in production config:

```bash
ssh -i ~/.ssh/fabt-oracle ubuntu@${FABT_VM_IP} "grep SPRING_PROFILES_ACTIVE ~/fabt-secrets/docker-compose.prod.yml"
# Update from: SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE},observability
# To: SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE},observability,demo
# Or add demo to .env.prod: SPRING_PROFILES_ACTIVE=lite,demo
```

- [x] 4.4 Restart backend container and verify demo guard is active:

```bash
ssh -i ~/.ssh/fabt-oracle ubuntu@${FABT_VM_IP} "cd ~/finding-a-bed-tonight && docker compose --env-file ~/fabt-secrets/.env.prod -f docker-compose.yml -f ~/fabt-secrets/docker-compose.prod.yml up -d backend"

# Wait for startup, then test:
# Destructive op should be blocked:
TOKEN=$(curl -s -X POST "https://findabed.org/api/v1/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@dev.fabt.org","password":"admin123","tenantSlug":"dev-coc"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

curl -s -X POST "https://findabed.org/api/v1/users" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"email":"test@test.com","password":"test123","displayName":"Test","tenantSlug":"dev-coc"}'
# Expected: 403 {"error": "demo_restricted", ...}
```

- [x] 4.5 Verify safe mutations still work:

```bash
# Bed search (POST) should work:
curl -s -X POST "https://findabed.org/api/v1/queries/beds" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"populationType":"SINGLE_ADULT"}'
# Expected: 200 with bed results

# Login should work:
curl -s -X POST "https://findabed.org/api/v1/auth/login" -H "Content-Type: application/json" -d '{"email":"outreach@dev.fabt.org","password":"admin123","tenantSlug":"dev-coc"}'
# Expected: 200 with tokens
```

- [x] 4.6 Verify localhost bypass via SSH tunnel:

```bash
# SSH tunnel to backend
ssh -i ~/.ssh/fabt-oracle -L 8081:localhost:8081 ubuntu@${FABT_VM_IP}

# From another terminal, via tunnel:
TOKEN=$(curl -s -X POST "http://localhost:8081/api/v1/auth/login" -H "Content-Type: application/json" -d '{"email":"admin@dev.fabt.org","password":"admin123","tenantSlug":"dev-coc"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# Destructive op should WORK via tunnel:
curl -s "http://localhost:8081/api/v1/users" -H "Authorization: Bearer $TOKEN"
# Expected: 200 with user list (not 403)
```

## 5. Frontend Demo Toast

- [x] 5.1 Update the API error handler in the React frontend to detect `error: "demo_restricted"` responses and display a demo-specific toast/notification

- [x] 5.2 Suggested toast copy: "This feature is available in a full deployment. Contact us to set up a pilot."

- [x] 5.3 Rebuild frontend Docker image and redeploy

- [x] 5.4 Verify in browser: log in as admin, click "Create User", confirm the demo toast appears instead of a generic error

## 5b. Fix Swallowed Error Catch Blocks (29 instances across 3 files)

Root cause: `catch { setError(intl.formatMessage({ id: 'coord.error' })) }` discards API error messages.
Correct pattern: `catch (err: unknown) { const apiErr = err as { message?: string }; setError(apiErr.message || intl.formatMessage({ id: 'fallback' })); }`

Reference files that already do it correctly: `UserEditDrawer.tsx` (lines 76, 92), `ShelterForm.tsx` (line 189).

- [x] 5b.1 Fix AdminPanel.tsx — find and update all catch blocks that swallow errors. **Do not rely on line numbers** — they shift after edits. Instead:

```bash
# Find all catch blocks in AdminPanel.tsx
grep -n 'catch' frontend/src/pages/AdminPanel.tsx
```

For each catch block that uses `catch {` or `catch (e) {` with a generic `setError(intl.formatMessage(...))`:
  - Change to `catch (err: unknown) {`
  - Change `setError(intl.formatMessage({ id: '...' }))` to `const apiErr = err as { message?: string }; setError(apiErr.message || intl.formatMessage({ id: '...' }))`
  - Leave intentionally silent blocks (those with `/* comments explaining why */`) as-is

- [x] 5b.2 Fix CoordinatorDashboard.tsx — update all 8 catch blocks that swallow errors:
  - Lines: 104, 151, 152, 163, 175, 234, 241
  - Same pattern: add `err` parameter, use `apiErr.message` with intl fallback

- [x] 5b.3 Fix ShelterEditPage.tsx — update the 1 catch block (line 60):
  - Change `catch { setError('Failed to load shelter'); }` to use `apiErr.message || 'Failed to load shelter'`

- [x] 5b.4 Verify: no remaining `catch {` without error parameter in admin-facing components:
  ```bash
  grep -n 'catch {' frontend/src/pages/AdminPanel.tsx frontend/src/pages/CoordinatorDashboard.tsx frontend/src/pages/ShelterEditPage.tsx
  # Expected: only intentionally silent blocks with comments remain
  ```

## 5c. Local E2E Testing (before deployment)

Run all tests locally against a dev instance with `demo` profile before deploying to findabed.org.

- [x] 5c.1 Start local dev stack with demo profile. First verify `dev-start.sh` forwards the profile:

```bash
# Check if dev-start.sh respects SPRING_PROFILES_ACTIVE
grep -n 'SPRING_PROFILES' dev-start.sh

# If it does: start with demo profile
SPRING_PROFILES_ACTIVE=lite,demo ./dev-start.sh

# If it doesn't: either add demo profile support to dev-start.sh,
# or set it directly via docker-compose env override:
# export FABT_SPRING_PROFILES=lite,demo && ./dev-start.sh
```

- [x] 5c.2 Run DemoGuardFilter unit + integration tests:
  ```bash
  cd backend && mvn test -Dtest="org.fabt.shared.security.DemoGuardFilterTest,org.fabt.shared.security.DemoGuardIntegrationTest"
  ```

- [x] 5c.3 Run Playwright E2E demo-guard tests against local:
  ```bash
  cd e2e/playwright && BASE_URL=http://localhost:5173 npx playwright test tests/demo-guard-verify.spec.ts --trace on
  ```
  Expected: admin create user → sees "disabled in the demo environment" + "full deployment"

- [x] 5c.4 Manually verify in browser (localhost): log in as admin, attempt 3 different restricted operations (create user, activate surge, edit shelter), confirm each shows the actual API error message — not a generic "Couldn't load your shelters"

- [x] 5c.5 Run full Playwright test suite locally to verify no regressions:
  ```bash
  cd e2e/playwright && npx playwright test --trace on 2>&1 | tee logs/demo-guard-regression.log
  ```

## 6. Deploy to Demo Site (after local verification)

Only deploy after tasks 5b and 5c are complete and all local tests pass.

## 6a. Static Site — Try the Demo Section

- [x] 6.1 Add "Try the Demo" section to `index.html` landing page — between "See It Work" and "Open Source. Free Forever." sections:

```html
<section class="section section-alt">
  <h2>Try It Live</h2>
  <p>Explore the platform with demo credentials. All roles are accessible.
     Destructive operations (user management, shelter configuration) are
     disabled to protect the demo for other visitors.</p>
  <p><a href="/login">findabed.org/login</a></p>
  <table>
    <tr><td>Tenant</td><td>dev-coc</td></tr>
    <tr><td>Outreach Worker</td><td>outreach@dev.fabt.org / admin123</td></tr>
    <tr><td>CoC Administrator</td><td>cocadmin@dev.fabt.org / admin123</td></tr>
    <tr><td>Platform Admin</td><td>admin@dev.fabt.org / admin123</td></tr>
    <tr><td>DV Outreach Worker</td><td>dv-outreach@dev.fabt.org / admin123</td></tr>
  </table>
  <p><em>This is a demonstration environment with fictional shelter and
     location data. Do not enter real client, shelter, or location
     information.</em></p>
</section>
```

- [x] 6.2 Add "Try It Live" CTA to `demo/index.html` walkthrough — after the final screenshot section and before the footer

- [x] 6.3 Deploy updated static site pages to Oracle VM

- [x] 6.4 Verify the "Try the Demo" section renders correctly on the live site

## 7. Verification

- [x] 7.1 Full verification matrix:

```bash
echo "=== Destructive ops blocked ==="
# User creation
curl -s -w "\n%{http_code}" -X POST "https://findabed.org/api/v1/users" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'
# Expected: 403

# Password change
curl -s -w "\n%{http_code}" -X PUT "https://findabed.org/api/v1/auth/password" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"currentPassword":"admin123","newPassword":"hacked"}'
# Expected: 403

# Surge activation
curl -s -w "\n%{http_code}" -X POST "https://findabed.org/api/v1/surge-events" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'
# Expected: 403

echo "=== Safe ops allowed ==="
# Bed search
curl -s -w "\n%{http_code}" -X POST "https://findabed.org/api/v1/queries/beds" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"populationType":"SINGLE_ADULT"}'
# Expected: 200

# Login
curl -s -w "\n%{http_code}" -X POST "https://findabed.org/api/v1/auth/login" -H "Content-Type: application/json" -d '{"email":"outreach@dev.fabt.org","password":"admin123","tenantSlug":"dev-coc"}'
# Expected: 200

echo "=== Read access to admin screens ==="
# User list (GET)
curl -s -w "\n%{http_code}" "https://findabed.org/api/v1/users" -H "Authorization: Bearer $TOKEN"
# Expected: 200

# Shelter list (GET)
curl -s -w "\n%{http_code}" "https://findabed.org/api/v1/shelters" -H "Authorization: Bearer $TOKEN"
# Expected: 200
```

- [x] 7.2 Browser smoke test
- [x] 7.3 SSH tunnel admin test: log in as each of the 4 roles, navigate all screens, attempt one destructive action per role, confirm demo toast appears

- [x] 7.3 SSH tunnel admin test: connect via tunnel, log in as admin at `localhost:8081`, create a test user, delete the test user — confirm full admin capability via tunnel

- [x] 7.4 DV canary: verify DV shelters remain invisible to non-DV outreach worker at `https://findabed.org`

## 8. Site Cleanup (from SITE-CLEANUP.md)

- [x] 8.1 **C-02: Correct screenshot count** — count actual `<img>` tags in `demo/index.html` and update the text references on both the landing page walkthrough card and the demo page header to match:

```bash
# Count actual screenshots
grep -c '<img ' demo/index.html
# Update the "18 screenshots" text in both index.html and demo/index.html to match
```

- [x] 8.2 **C-03: Fix PITCH-BRIEFS.md broken link** — the landing page footer links to `PITCH-BRIEFS.md` which does not exist on the VM. The URL serves the React SPA login page (wrong). Either:
  - Deploy `PITCH-BRIEFS.md` as a static file to `/var/www/findabed-docs/` (if it exists in the repo)
  - Convert to an HTML page
  - Or remove the link from the footer if the content is obsolete

```bash
# Check if PITCH-BRIEFS.md exists locally
ls -la C:/Development/findABed/PITCH-BRIEFS.md
# If it exists, deploy it. If not, remove the link from index.html footer.
```

- [x] 8.3 **C-05: Remove developer note from demo walkthrough footer** — remove or comment out the line in `demo/index.html`:
  `Screenshots captured via Playwright. Regenerate with ./demo/capture.sh`

- [x] 8.4 **C-06: Add TOTP 2FA screenshots to demo walkthrough** — capture from the live site (which is now at v0.27.0 with demo guard deployed). Screenshots needed:
  - TOTP enrollment QR code screen
  - Two-phase login (TOTP input after password)
  - Recovery codes display (shown once at enrollment)
  - Admin "Generate Access Code" modal

Use the Playwright capture script or manual screenshots. Add to `demo/index.html` walkthrough in a new "Account Security" section.

**Prerequisite:** Demo guard must be deployed (task group 4 complete) and admin credentials reset (task group 3 complete) so the capture can access all screens.

- [x] 8.5 **C-07: Reorganize walkthrough "Account Security" section** — after C-06 screenshots are captured, reorganize the walkthrough to group security features together:
  - Secure login → 2FA enrollment → TOTP verification → change password → admin access code
  - Position this section after "Sandra's Side" and before "Behind the Scenes: Administration"
  - Update the screenshot numbering to reflect the new order

- [x] 8.6 Update screenshot count again after C-06/C-07 changes (the count will increase with TOTP screenshots)

- [x] 8.7 Deploy updated static site with all cleanup changes to Oracle VM

- [x] 8.8 Verify all cleanup items on live site:
  - Screenshot count matches actual images
  - PITCH-BRIEFS.md link either works or is removed
  - No developer note in demo walkthrough footer
  - TOTP screenshots visible in walkthrough
  - Account security section properly organized
