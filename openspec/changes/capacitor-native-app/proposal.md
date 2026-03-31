## Why

Three critical limitations of the PWA approach cannot be solved with web technology alone:

1. **Push notifications die when backgrounded.** SSE connections are killed by iOS within seconds and Android within minutes of backgrounding. Darius needs "a bed just opened up" alerts while the app is in his pocket. FCM/APNs deliver even when the app is killed.

2. **iOS purges PWA storage after 7 days.** Safari evicts Service Worker caches and IndexedDB data if the user doesn't open the PWA for a week. The offline hold queue — the critical Darius-in-a-parking-lot scenario — vanishes. Native storage is permanent.

3. **Hospital IT blocks PWAs.** Dr. Whitfield's locked-down hospital Chrome disables service workers and prevents PWA installation. A native app pre-installed via MDM bypasses all browser restrictions.

Every major humanitarian field worker platform (CommCare, ODK Collect, KoboToolbox) went native for the same reasons. The pattern is universal: web admin dashboard + native mobile for field workers.

Capacitor wraps the existing React PWA in a native shell with ~95% code reuse. The existing Vite build pipeline, React components, API layer, and offline queue all work unchanged. Only token storage, routing abstraction, and native feature integration are needed.

## What Changes

**Phase 1 — Capacitor wrapper (existing PWA in native shell):**
- Add `@capacitor/core`, `@capacitor/cli`, `@capacitor/ios`, `@capacitor/android`
- Configure `capacitor.config.ts` pointing to `frontend/dist`
- Create iOS (Xcode) and Android (Android Studio) native projects
- Build pipeline: `npm run build && npx cap sync`

**Phase 2 — Native feature integration:**
- Push notifications via `@capacitor/push-notifications` + FCM/APNs backend integration
- Biometric auth via `@capawesome-team/capacitor-biometrics` (Face ID / Touch ID / fingerprint)
- SQLite offline storage via `@capacitor-community/sqlite` (replaces IndexedDB for hold queue)
- Secure token storage via `@capacitor-community/secure-storage` (replaces localStorage)
- Deep linking for shelter URLs
- Abstract `window.location.href` redirects for native routing

**Phase 3 — App Store submission:**
- Apple: Privacy manifest (`PrivacyInfo.xcprivacy`), screenshots, demo credentials in review notes, native features to pass Guideline 4.2
- Google Play: Play Store listing, Digital Asset Links
- OTA update pipeline via Capgo for JS-only hot fixes

**Backend changes:**
- FCM integration: send push notifications alongside SSE events for availability updates and referral responses
- Device token registration endpoint: `POST /api/v1/devices` (stores FCM token per user)
- Flyway migration for `device_token` table

## Capabilities

### New Capabilities
- `native-app-shell`: Capacitor project configuration, iOS + Android build pipeline
- `native-push-notifications`: FCM/APNs integration, device token management, backend push sender
- `native-biometric-auth`: Face ID / Touch ID / fingerprint login option
- `native-offline-storage`: SQLite for offline hold queue (replaces IndexedDB)
- `native-secure-storage`: Hardware-backed token storage (replaces localStorage)

### Modified Capabilities
- `pwa-shell`: Abstract routing (window.location.href → native-aware navigation)
- `sse-notifications`: Backend sends FCM alongside SSE events

## Impact

- **Frontend:** Capacitor config, token storage migration, routing abstraction, push notification registration
- **Backend:** FCM sender service, device token endpoint + migration, notification service dual-delivery (SSE + FCM)
- **New directories:** `ios/` (Xcode project), `android/` (Android Studio project) at repo root
- **New dependencies:** Capacitor core + plugins, Firebase Admin SDK (backend)
- **Build pipeline:** `npm run build && npx cap sync && npx cap open ios/android`
- **No UI changes** — existing React components render identically in the native WebView
- **PWA continues to work** — web users are unaffected, Capacitor and PWA coexist from the same codebase

## Risk

- **Apple App Store Guideline 4.2 rejection:** WebView-only apps may be rejected as "repackaged websites." Mitigated by adding native features (push, biometrics, SQLite) that demonstrate value beyond a browser.
- **Capacitor plugin maturity:** Some community plugins are less maintained than core plugins. Mitigated by preferring `@capacitor/*` official plugins where available.
- **Dual notification path complexity:** Backend sends both SSE and FCM. Mitigated by a unified `NotificationDispatcher` that delegates to both channels.
- **Hospital MDM distribution:** Requires Apple Developer Enterprise Program ($299/year) or TestFlight for internal distribution. Alternative: standard App Store with MDM-managed installation.
