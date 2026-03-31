## ADDED Requirements

### Requirement: Biometric unlock option
After successful password login on a native platform, the app SHALL offer to enable biometric unlock (Face ID / Touch ID / fingerprint) for subsequent launches.

**Acceptance criteria:**
- Prompt appears after first successful login: "Enable Face ID/Touch ID for faster login?"
- If enabled: JWT stored in biometric-protected SecureStorage
- On subsequent launches: biometric prompt appears, success unlocks the app without password
- If biometric fails 3 times: falls back to password login
- User can disable biometric in settings

### Requirement: Biometric availability detection
The app SHALL detect whether biometric authentication is available on the device and only offer it when supported.

**Acceptance criteria:**
- On devices without biometrics: option not shown
- On web platform: option not shown
- Supports Face ID (iPhone X+), Touch ID (older iPhones), fingerprint (Android)
