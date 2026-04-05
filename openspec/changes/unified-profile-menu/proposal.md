## Why

The header has three separate account-related buttons (Password, Security, Sign Out) plus a username display — a pattern that no production app uses. Gmail, Slack, GitHub, and Notion all consolidate behind a single avatar/profile trigger. This matters for:

- **Teresa Nguyen (procurement):** Separate header buttons look like developer UI, not enterprise software
- **Darius Webb (outreach, mobile):** Password and Security buttons consume space for operations he does once per year — the v0.29.1 kebab menu already hides them on mobile, but desktop still shows them inline
- **Devon Kessler (training):** "Where do I change my password?" — coordinators expect a profile icon, not standalone buttons
- **Keisha Thompson (dignity):** A polished, consolidated profile signals maturity

Enhancement request from SRE: "Single Profile button at the top right corner which can take care of Password Reset, Security along with user profile details with edit options."

## What Changes

### Phase 1 — UI Consolidation (this change)

**Header simplification:**
- Replace inline username + Password + Security + Sign Out with a single avatar/initials button
- Desktop: avatar button opens a dropdown popover with name, role badge, and links
- Mobile: avatar button replaces the kebab menu (consistent trigger across breakpoints)
- Notification bell and language selector remain in the header (frequent-access items)

**New `/settings` route:**
- Create a settings page with two sections: Password and Security
- Password section: same form as current ChangePasswordModal, rendered inline
- Security section: same TOTP enrollment as current TotpEnrollmentPage, rendered inline
- Accessible from the profile dropdown via "Settings" link

**Profile dropdown contents:**
- User initials avatar (top)
- Display name + role badge
- "Settings" link → `/settings`
- Language selector
- Sign Out (visually separated, last item)

### Phase 2 — Self-Service Profile Editing (future, NOT this change)
- View own email, roles, DV access (read-only)
- Edit display name (requires new backend API)
- View TOTP enrollment status
- Manage/disable TOTP

## Capabilities

### New Capabilities
- `unified-profile-menu`: Avatar/initials trigger with dropdown, `/settings` page with password + security sections

### Modified Capabilities
- `mobile-header-overflow-menu`: Kebab menu replaced by avatar button on mobile (same content, consistent trigger)

## Impact

**Frontend:**
- `Layout.tsx` — header restructured: avatar button replaces 4 inline items
- New: `ProfileDropdown.tsx` (or inline in Layout) — avatar trigger + dropdown
- New: `SettingsPage.tsx` — combined password + security settings
- `App.tsx` — add `/settings` route
- `ChangePasswordModal.tsx` — refactor to reusable form component (used in SettingsPage)
- `TotpEnrollmentPage.tsx` — refactor to reusable component (used in SettingsPage)
- `en.json` / `es.json` — new i18n keys for settings page, profile dropdown

**No backend changes** in Phase 1 — all existing APIs are sufficient.
**No OpenAPI/AsyncAPI updates** — no new endpoints or changed contracts.
**No Gatling performance tests** — no new API calls or queries.
**Security:** Existing rate limiting and DemoGuard on auth endpoints remain in effect. `/settings` page calls same APIs.
**Phase 2 note:** `PUT /api/v1/auth/profile` will need OpenAPI spec, rate limiting, DemoGuard allowlist review, and XSS sanitization for displayName input.
