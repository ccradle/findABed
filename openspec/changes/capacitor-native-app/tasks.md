## Tasks

### Phase 1 — Capacitor Wrapper

- [ ] Task 0: Create feature branch — `git checkout -b capacitor-native-app main`

- [ ] Task 1: Install Capacitor and create config
  **Action:** `cd frontend && npm install @capacitor/core @capacitor/cli && npx cap init "Finding A Bed Tonight" org.fabt.findabed --web-dir dist`. Create `capacitor.config.ts` with `androidScheme: 'https'` and push notification plugin config.

- [ ] Task 2: Add iOS and Android platforms
  **Action:** `npm install @capacitor/ios @capacitor/android && npx cap add ios && npx cap add android`. Verify both projects created at `ios/` and `android/`.

- [ ] Task 3: Create icon assets
  **Action:** Generate `icon-192.png` and `icon-512.png` from the existing `favicon.svg`. Place in `frontend/public/`. Also generate iOS app icons (multiple sizes) and Android adaptive icons for the native projects.

- [ ] Task 4: Add iOS meta tags to index.html
  **Action:** Add `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `apple-mobile-web-app-title`, and `apple-touch-icon` tags.

- [ ] Task 5: Build, sync, and verify in simulators
  **Action:** `npm run build && npx cap sync`. Open in Xcode (`npx cap open ios`) and Android Studio (`npx cap open android`). Verify login page renders correctly in both simulators.

- [ ] Task 6: Abstract routing for native
  **File:** `frontend/src/services/api.ts`, `frontend/src/auth/AuthContext.tsx`
  **Action:** Replace `window.location.href = '/login'` with platform-aware dispatch. AuthContext listens for `fabt:auth-expired` event and uses React Router `navigate()`.

### Phase 2 — Secure Storage & Token Migration

- [ ] Task 7: Install secure storage plugin
  **Action:** `npm install @capacitor-community/secure-storage`

- [ ] Task 8: Create tokenStorage abstraction
  **File:** `frontend/src/services/storage.ts` (new)
  **Action:** Implement `tokenStorage.get()`, `set()`, `remove()` with Capacitor.isNativePlatform() branching. Native uses SecureStorage, web uses localStorage.

- [ ] Task 9: Migrate AuthContext, api.ts, SessionTimeoutWarning
  **Action:** Replace all `localStorage.getItem('fabt_access_token')` and related calls with `tokenStorage`. Ensure async nature of SecureStorage is handled (the calls are now `await`).

### Phase 3 — Push Notifications

- [ ] Task 10: Backend — Flyway migration for device_token table
  **File:** `V31__create_device_token.sql`
  **Action:** `device_token` table: id (UUID), user_id (UUID FK), token (VARCHAR 500), platform (VARCHAR 10), created_at (TIMESTAMPTZ). Unique constraint on (user_id, token).

- [ ] Task 11: Backend — DeviceTokenRepository and registration endpoint
  **Files:** `DeviceTokenRepository.java`, `DeviceController.java`
  **Action:** `POST /api/v1/devices` (register token), `DELETE /api/v1/devices/{token}` (unregister). Upsert on register. Authenticated endpoint.

- [ ] Task 12: Backend — Firebase Admin SDK integration
  **File:** `PushNotificationSender.java` (new)
  **Action:** Add `firebase-admin` dependency. Configure with service account JSON (env var `GOOGLE_APPLICATION_CREDENTIALS`). Send method accepts user ID + payload, looks up device tokens, sends via FCM HTTP v1 API. Auto-deregisters invalid tokens on 404 response.

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

- [ ] Task 18: Install SQLite plugin
  **Action:** `npm install @capacitor-community/sqlite`

- [ ] Task 19: Create StorageAdapter abstraction
  **File:** `frontend/src/services/offlineStorage.ts` (new)
  **Action:** Interface with `enqueue()`, `replay()`, `getSize()`, `clear()`. Two implementations: `IndexedDbAdapter` (existing offlineQueue.ts logic) and `SqliteAdapter` (new). Platform detection selects at runtime.

- [ ] Task 20: Migrate offlineQueue.ts to use StorageAdapter
  **File:** `frontend/src/services/offlineQueue.ts`
  **Action:** Refactor to delegate to the StorageAdapter. Existing behavior unchanged on web. SQLite path on native.

### Phase 6 — App Store Submission

- [ ] Task 21: Apple Privacy manifest
  **File:** `ios/App/PrivacyInfo.xcprivacy`
  **Action:** Declare data collection practices: authentication tokens, device tokens, usage analytics (none currently). Required since May 2024.

- [ ] Task 22: App Store screenshots and metadata
  **Action:** Capture screenshots on iPhone 15 Pro and iPad Pro simulators. Write App Store description, keywords, support URL. Include demo login credentials in review notes.

- [ ] Task 23: Google Play Store listing
  **Action:** Generate Play Store screenshots, write listing description, configure Digital Asset Links for deep linking.

- [ ] Task 24: OTA update pipeline
  **Action:** Set up Capgo (or self-hosted alternative) for over-the-air JavaScript/asset updates. Configure auto-update check on app launch. Verify Apple and Google compliance (JS-only updates, no native code changes).

### Phase 7 — Testing & Verification

- [ ] Task 25: Verify PWA still works unchanged
  **Action:** Run full Playwright suite (Vite + nginx) — must pass with zero regressions. The Capacitor changes must not break the web experience.

- [ ] Task 26: Manual testing on physical devices
  **Action:** Test on physical iPhone + physical Android device:
  - Login, bed search, hold, availability update
  - Background the app → verify push notification arrives
  - Kill the app → verify push notification arrives
  - Offline mode → verify SQLite queue holds and replays
  - Biometric unlock on subsequent launch
  - Deep link from push notification to correct screen

- [ ] Task 27: Submit to TestFlight (iOS) and Internal Testing (Android)
  **Action:** First submission for beta testing. Gather feedback from a small group before public release.

### Merge and Release

- [ ] Task 28: Merge to main, tag, create release
- [ ] Task 29: Submit to Apple App Store and Google Play Store
- [ ] Task 30: Update documentation (README, FOR-DEVELOPERS, runbook)
