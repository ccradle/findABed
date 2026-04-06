## Tasks

### Setup

- [x] Task 0: Create feature branch in code repo
  **Repo:** `finding-a-bed-tonight/`
  **Action:** `git checkout -b import-hardening main`. All code changes (Tasks 1–10) are committed to this branch. Merge to main after Task 11 verification passes.

### Bug Fix

- [x] Task 1: Fix admin panel import navigation
  **File:** `frontend/src/pages/AdminPanel.tsx` (~line 960-969)
  **Action:** Replace `<a href="/import/211">` with `<Link to="/coordinator/import/211">` and `<a href="/import/hsds">` with `<Link to="/coordinator/import/hsds">`. Add `import { Link } from 'react-router-dom'` if not already imported. Preserve existing inline styles including `textDecoration: 'none'` and button-like appearance. `Link` accepts the same `style` prop as `<a>`.

### Backend Security

- [x] Task 2: Create CsvSanitizer utility
  **File:** `backend/src/main/java/org/fabt/dataimport/service/CsvSanitizer.java` (new)
  **Action:** Create utility class with `sanitize(String value)` method:
  - Strip leading `=` when next char is non-digit
  - Strip leading `+` when next char is non-digit (preserve `+1` phone format)
  - Strip leading `@` always
  - Strip tab (`\t`) and carriage return (`\r`) characters throughout
  - Return null for null input
  - Log warning when sanitization modifies a value (include field context)
  - Add class-level Javadoc noting `@`-stripping is shelter-field-specific; if email fields are ever imported, the sanitizer needs a field-type-aware mode

- [x] Task 3: Apply CsvSanitizer in TwoOneOneImportAdapter
  **File:** `backend/src/main/java/org/fabt/dataimport/service/TwoOneOneImportAdapter.java`
  **Action:** Call `CsvSanitizer.sanitize()` on every string field in `parseCsv()` after `getField()` extraction, before building `ShelterImportRow`.

- [x] Task 4: Apply CsvSanitizer in HsdsImportAdapter
  **File:** `backend/src/main/java/org/fabt/dataimport/service/HsdsImportAdapter.java`
  **Action:** Call `CsvSanitizer.sanitize()` on every string field extracted from JSON nodes before building `ShelterImportRow`.

- [x] Task 5: Add field length validation to ShelterImportService
  **File:** `backend/src/main/java/org/fabt/dataimport/service/ShelterImportService.java`
  **Action:** Add length checks in `validateRow()`: name ≤ 255, addressStreet ≤ 500, addressCity ≤ 255, addressState ≤ 50 (DB is VARCHAR(50); real 211 data may have full state names), addressZip ≤ 10, phone ≤ 50. Produce row-level ImportError for violations (don't truncate).

- [x] Task 6: Add MIME type validation to ImportController
  **File:** `backend/src/main/java/org/fabt/dataimport/api/ImportController.java`
  **Action:** Before `readFileContent()` in both 211 and HSDS endpoints, check `file.getContentType()`. For 211: accept `text/csv`, `text/plain`, `application/csv`, `application/octet-stream`, null. For HSDS: accept `application/json`, `text/plain`, `application/octet-stream`, null. Reject others with 400 and clear message. Accept null because some clients don't send content type. Log a warning when MIME type is null for monitoring visibility.

### Backend Tests

- [x] Task 7: Add CsvSanitizer unit tests
  **File:** `backend/src/test/java/org/fabt/dataimport/CsvSanitizerTest.java` (new)
  **Action:** Use JUnit 5 `@ParameterizedTest` with `@CsvSource` for concise, extensible test coverage:
  - `=CMD(...)` → stripped, `+cmd|...` → stripped, `+1-919...` → preserved, `@SUM(...)` → stripped, `-123 Main` → preserved, tabs/CR stripped, null → null, empty → empty, clean values → unchanged.

- [x] Task 8: Add negative integration tests to ImportIntegrationTest
  **File:** `backend/src/test/java/org/fabt/dataimport/ImportIntegrationTest.java`
  **Action:** Add tests:
  - `test_211Import_emptyFile_returns400`
  - `test_211Import_headersOnly_returns400`
  - `test_211Import_malformedCsv_returns400`
  - `test_211Import_csvInjection_sanitized` — verify stored values have dangerous prefixes removed
  - `test_211Import_fieldLengthExceeded_reportsRowError`
  - `test_211Import_missingNameColumn_reportsError`
  - `test_hsdsImport_csvInjection_sanitized`

### Playwright E2E Tests

- [x] Task 9: Add admin panel import link click-through test
  **File:** `e2e/playwright/tests/admin-panel.spec.ts`
  **Action:** Add test: login as admin → admin panel → click Imports tab → click "2-1-1 Import" → verify import page renders (file upload area visible). This is the test that would have caught the navigation bug.

- [x] Task 10: Add import negative E2E tests
  **File:** `e2e/playwright/tests/demo-211-import-edit.spec.ts`
  **Action:** Add tests using `Buffer.from()` for in-memory CSV generation:
  - Empty file upload → error message visible
  - Headers only, no data rows → error message visible
  - CSV injection payload → import succeeds, verify sanitized values via API query

### Verification

- [x] Task 11: Run full test suite and verify locally
  **Action:** Run backend tests (`mvn test`), Playwright tests (`npx playwright test`). Verify:
  - All new tests pass
  - All existing tests still pass
  - Import works end-to-end from admin panel click-through
  - 211 import preview and confirm flow works with clean data

### Merge and Release

- [x] Task 12: Merge to main and push
  **Action:** `git checkout main && git merge import-hardening && git push origin main`. Delete feature branch after merge.

### Deploy to Demo

- [x] Task 13: Rebuild and deploy to Oracle demo instance
  **Action:** SSH to the VM (`ssh -i ~/.ssh/fabt-oracle ubuntu@${FABT_VM_IP}`):
  ```bash
  cd ~/finding-a-bed-tonight
  git pull origin main
  cd backend && mvn package -DskipTests -q && cd ..
  cd frontend && npm ci --silent && npm run build && cd ..
  docker build -f infra/docker/Dockerfile.backend -t fabt-backend:latest .
  docker build -f infra/docker/Dockerfile.frontend -t fabt-frontend:latest .
  docker compose -f docker-compose.yml -f ~/fabt-secrets/docker-compose.prod.yml \
    --env-file ~/fabt-secrets/.env.prod --profile observability \
    up -d --force-recreate backend frontend
  ```
  Wait 15 seconds, then verify:
  ```bash
  curl -s http://localhost:9091/actuator/health/liveness
  ```

- [x] Task 14: Smoke test live demo
  **Action:** In browser at `https://${FABT_VM_IP}.nip.io`:
  - Login as admin → Admin panel → click "2-1-1 Import" → verify import page loads
  - Upload test CSV → preview → confirm → verify success
  - DV canary: login as outreach worker, verify DV shelters invisible
