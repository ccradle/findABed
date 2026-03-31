## ADDED Requirements

### Requirement: Platform-aware token storage
Authentication tokens SHALL be stored in hardware-backed secure storage on native platforms and localStorage on web.

**Acceptance criteria:**
- `tokenStorage.get()`, `tokenStorage.set()`, `tokenStorage.remove()` API
- Native: uses `@capacitor-community/secure-storage` (iOS Keychain / Android Keystore)
- Web: uses `localStorage` (existing behavior unchanged)
- AuthContext, api.ts, and SessionTimeoutWarning migrated to use `tokenStorage`
- Tokens not accessible via JavaScript injection on native platform
- Existing Playwright tests pass unchanged (they test the web path)
