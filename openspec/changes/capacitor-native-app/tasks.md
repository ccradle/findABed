## Tasks

### Phase 1 — Capacitor Wrapper

- [ ] Task 0: Create feature branch — `git checkout -b capacitor-native-app main`

- [ ] Task 1: Install Capacitor and create config
  **Action:** `cd frontend && npm install @capacitor/core @capacitor/cli && npx cap init "Finding A Bed Tonight" org.fabt.findabed --web-dir dist`. Create `capacitor.config.ts` with `androidScheme: 'https'` and push notification plugin config.

- [ ] Task 2: Add iOS and Android platforms
  **Action:** `npm install @capacitor/ios @capacitor/android && npx cap add ios && npx cap add android`. Verify both projects created at `ios/` and `android/`. **Repo decision:** Keep `ios/` and `android/` in the existing code repo (simpler CI, single version history). Add generated build artifacts to `.gitignore` (`ios/App/Pods/`, `android/.gradle/`, `android/app/build/`) to minimize git footprint. The native project config files (~5MB) are small enough to coexist.

- [ ] Task 3: Create icon assets
  **Action:** Generate `icon-192.png` and `icon-512.png` from the existing `favicon.svg`. Place in `frontend/public/`. Also generate iOS app icons (multiple sizes) and Android adaptive icons for the native projects.

- [ ] Task 4: Add iOS meta tags to index.html
  **Action:** Add `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `apple-mobile-web-app-title`, and `apple-touch-icon` tags.

- [ ] Task 5: Build, sync, and verify in simulators
  **Action:** `npm run build && npx cap sync`. Open in Xcode (`npx cap open ios`) and Android Studio (`npx cap open android`). Verify login page renders correctly in both simulators.

- [ ] Task 5b: Add --mobile flag to dev-start.sh
  **File:** `dev-start.sh`
  **Action:** Add `--mobile` flag (follows `--nginx` pattern). When set: runs `npm run build && npx cap sync` and prints instructions for opening Xcode/Android Studio. Pairs with `--observability` for full stack + mobile testing.

- [ ] Task 6: Abstract routing for native
  **File:** `frontend/src/services/api.ts`, `frontend/src/auth/AuthContext.tsx`
  **Action:** Replace `window.location.href = '/login'` with platform-aware dispatch. AuthContext listens for `fabt:auth-expired` event and uses React Router `navigate()`.

### Phase 2 — Secure Storage & Token Migration

- [ ] Task 7: Install secure storage plugin
  **Action:** `npm install @capacitor-community/secure-storage`

- [ ] Task 8: Create tokenStorage abstraction with in-memory cache
  **File:** `frontend/src/services/storage.ts` (new)
  **Action:** Implement `tokenStorage.get()`, `set()`, `remove()` with Capacitor.isNativePlatform() branching. Native uses SecureStorage, web uses localStorage. **Critical: cache the token in memory** after reading from SecureStorage on login — this keeps the request interceptor synchronous (reads from memory, not async SecureStorage). On login: `await SecureStorage.set()` + update memory cache. On request: read from memory cache (synchronous). On logout: clear both.

- [ ] Task 9: Migrate AuthContext, api.ts, SessionTimeoutWarning
  **Action:** Replace all `localStorage.getItem('fabt_access_token')` and related calls with `tokenStorage`. Ensure async nature of SecureStorage is handled (the calls are now `await`).

### Phase 3 — Push Notifications

- [ ] Task 10: Backend — Flyway migration for device_token table
  **File:** `V31__create_device_token.sql`
  **Action:** `device_token` table: id (UUID), user_id (UUID FK), token (VARCHAR 500), platform (VARCHAR 10), created_at (TIMESTAMPTZ). Unique constraint on (user_id, token).

- [ ] Task 11: Backend — DeviceTokenRepository and registration endpoint
  **Files:** `DeviceTokenRepository.java`, `DeviceController.java`
  **Action:** `POST /api/v1/devices` (register token), `DELETE /api/v1/devices/{token}` (unregister). Upsert on register. Authenticated endpoint.

- [ ] Task 12: Backend — Push notification sender (direct HTTP, no Firebase SDK)
  **File:** `PushNotificationSender.java` (new)
  **Action:** Use direct FCM HTTP v1 API calls (no `firebase-admin` SDK dependency — keeps the backend cloud-provider-agnostic). Authenticate via Google service account JWT (short-lived OAuth2 token). Send method accepts user ID + payload, looks up device tokens, sends via `https://fcm.googleapis.com/v1/projects/{project}/messages:send`. Auto-deregisters invalid tokens on 404/410 response. Requires: `GOOGLE_APPLICATION_CREDENTIALS` env var pointing to service account JSON. No new Maven dependencies — uses existing `java.net.http.HttpClient`.

- [ ] Task 13: Backend — Integrate push into NotificationService
  **File:** `NotificationService.java`
  **Action:** After SSE broadcast, call `PushNotificationSender.send()` for the same event. Dual delivery: SSE for foreground web users, FCM for backgrounded native users. Push is fire-and-forget (don't block SSE delivery on push failure).

- [ ] Task 14: Frontend — Push notification registration on native
  **File:** `frontend/src/hooks/usePushNotifications.ts` (new)
  **Action:** On native platform after login: request permission, get FCM token via `@capacitor/push-notifications`, register with `POST /api/v1/devices`. Handle token refresh. Handle foreground notification display.

- [ ] Task 15: Backend integration tests for push
  **Action:** Test device registration, unregistration, duplicate handling. Mock FCM sender for unit tests.

### Phase 4 — Biometric Auth

- [ ] Task 16: Install biometric plugin
  **Action:** `npm install @capawesome-team/capacitor-biometrics`

- [ ] Task 17: Implement biometric unlock flow
  **File:** `frontend/src/hooks/useBiometricAuth.ts` (new)
  **Action:** After successful password login, offer to enable biometric. On subsequent launches, attempt biometric → unlock SecureStorage token → skip password. Fallback to password after 3 failures.

### Phase 5 — SQLite Offline Storage

- [ ] Task 18: Install and verify SQLite plugin
  **Action:** `npm install @capacitor-community/sqlite`. Before building the StorageAdapter, verify: (1) plugin supports Capacitor 6.x (check package.json peer deps), (2) no open critical bugs on GitHub issues, (3) test basic CRUD on both iOS simulator and Android emulator. If plugin is unmaintained or broken, fallback to `@nicepay/capacitor-sqlite` or raw WebSQL.

- [ ] Task 19: Create StorageAdapter abstraction
  **File:** `frontend/src/services/offlineStorage.ts` (new)
  **Action:** Interface with `enqueue()`, `replay()`, `getSize()`, `clear()`. Two implementations: `IndexedDbAdapter` (existing offlineQueue.ts logic) and `SqliteAdapter` (new). Platform detection selects at runtime.

- [ ] Task 20: Migrate offlineQueue.ts to use StorageAdapter
  **File:** `frontend/src/services/offlineQueue.ts`
  **Action:** Refactor to delegate to the StorageAdapter. Existing behavior unchanged on web. SQLite path on native. **Both paths must be tested:** web path verified by existing Playwright tests (no regression), native SQLite path verified manually on physical device (Task 26) — enqueue hold while airplane mode, verify SQLite contains the record, disable airplane mode, verify replay succeeds.

### Phase 6 — App Store Submission

- [ ] Task 21: Apple Privacy manifest
  **File:** `ios/App/PrivacyInfo.xcprivacy`
  **Action:** Declare data collection practices: authentication tokens, device tokens, usage analytics (none currently). Required since May 2024.

- [ ] Task 22: App Store screenshots and metadata
  **Action:** Capture screenshots on iPhone 15 Pro and iPad Pro simulators. Write App Store description, keywords, support URL. Include demo login credentials in review notes. **Apple Developer Program:** Standard program ($99/year) is sufficient for App Store distribution. Enterprise program ($299/year) only needed if hospital IT requires in-house MDM distribution without App Store. Start with standard — TestFlight supports up to 10,000 beta testers.

- [ ] Task 23: Google Play Store listing
  **Action:** Generate Play Store screenshots, write listing description, configure Digital Asset Links for deep linking.

- [ ] Task 24: OTA update pipeline
  **Action:** Evaluate OTA options: Capgo (SaaS, free tier 1,000 devices), `@capawesome/capacitor-live-update` (self-hosted), or Ionic Appflow (enterprise). Choose based on cost and control. Configure auto-update check on app launch. Verify Apple and Google compliance (JS-only updates, no native code changes). For a single-app open-source project, Capgo free tier is likely sufficient initially.

### Phase 7 — Testing & Verification

- [ ] Task 25: Verify PWA still works unchanged
  **Action:** Run full Playwright suite (Vite + nginx) — must pass with zero regressions. The Capacitor changes must not break the web experience.

- [ ] Task 26: Manual testing on physical devices (Go/No-Go checklist)
  **Action:** Test on physical iPhone + physical Android device. Every item must pass:
  - [ ] Login with password succeeds
  - [ ] Bed search loads with shelter results
  - [ ] Hold a bed → countdown appears
  - [ ] Coordinator availability update reflects in outreach search
  - [ ] Background the app → send availability update from another device → push notification banner appears
  - [ ] Kill the app → send availability update → push notification banner appears
  - [ ] Tap push notification → app opens to correct screen
  - [ ] Airplane mode → hold a bed → "Hold queued" shown → disable airplane mode → hold replays
  - [ ] Verify SQLite persists hold queue after app kill (reopen in airplane mode, queue still has the hold)
  - [ ] Biometric unlock on subsequent launch (Face ID / Touch ID / fingerprint)
  - [ ] Deep link `fabt://search` opens bed search
  - [ ] Dark mode renders correctly
  - [ ] App size < 25MB on both platforms

- [ ] Task 27: Submit to TestFlight (iOS) and Internal Testing (Android)
  **Action:** First submission for beta testing. Gather feedback from a small group before public release.

### Merge and Release

- [ ] Task 28: Merge to main, tag, create release
- [ ] Task 29: Submit to Apple App Store and Google Play Store
- [ ] Task 30: Update documentation (README, FOR-DEVELOPERS, runbook)
