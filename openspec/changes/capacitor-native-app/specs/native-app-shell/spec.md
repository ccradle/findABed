## ADDED Requirements

### Requirement: Capacitor project configuration
The project SHALL include Capacitor configuration at `frontend/capacitor.config.ts` with `appId: 'org.fabt.findabed'`, `webDir: 'dist'`, and `androidScheme: 'https'`.

**Acceptance criteria:**
- `npx cap sync` copies built web assets to iOS and Android projects
- `npx cap open ios` opens Xcode with the FABT project
- `npx cap open android` opens Android Studio with the FABT project
- The existing PWA (`npm run dev`) continues to work unchanged

### Requirement: iOS native project
An Xcode project SHALL exist at `ios/` capable of building a distributable IPA.

**Acceptance criteria:**
- Project builds without errors in Xcode
- App launches in iOS Simulator with the FABT login page
- Bundle identifier: `org.fabt.findabed`
- Minimum deployment target: iOS 16.0

### Requirement: Android native project
An Android Studio project SHALL exist at `android/` capable of building a distributable APK/AAB.

**Acceptance criteria:**
- Project builds without errors in Android Studio
- App launches in Android Emulator with the FABT login page
- Application ID: `org.fabt.findabed`
- Minimum SDK: API 24 (Android 7.0)

### Requirement: Missing icon assets
PWA manifest icon assets SHALL exist at `frontend/public/icon-192.png` and `frontend/public/icon-512.png`.

**Acceptance criteria:**
- Icons render correctly on Android home screen, iOS home screen, and app launcher
- No console errors for missing icon assets

### Requirement: iOS meta tags
`index.html` SHALL include Apple-specific meta tags for standalone web app behavior.

**Acceptance criteria:**
- `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style`, `apple-mobile-web-app-title`, and `apple-touch-icon` tags present
- iOS home screen bookmark shows proper icon and splash behavior

### Requirement: Deep linking
The native app SHALL register a custom URL scheme (`fabt://`) and universal links (`https://YOUR_DOMAIN/shelter/{id}`) for deep linking into specific screens.

**Acceptance criteria:**
- `fabt://shelter/{id}` opens the shelter detail screen
- `fabt://search` opens bed search
- Push notification tap navigates to the relevant screen via deep link
- iOS: Associated Domains configured in Xcode for universal links
- Android: Intent filters configured in AndroidManifest.xml

### Requirement: App size budget
The native app SHALL be under 25MB installed size on both iOS and Android. Darius uses a mid-range Android with limited storage.

**Acceptance criteria:**
- iOS IPA: < 25MB (compressed)
- Android APK: < 25MB
- Measured after all assets, plugins, and native frameworks included

### Requirement: Routing abstraction
The `api.ts` 401 handler SHALL use a platform-aware navigation abstraction instead of `window.location.href = '/login'`.

**Acceptance criteria:**
- On web: existing redirect behavior unchanged
- On native: dispatches event that AuthContext handles via React Router `navigate()`
- No full page reload on native platform
