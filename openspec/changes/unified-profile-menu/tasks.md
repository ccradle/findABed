## 1. Branch & Baseline

- [ ] 1.1 Create branch `unified-profile-menu` in finding-a-bed-tonight repo
- [ ] 1.2 Run `npm --prefix frontend run build` — confirm clean baseline
- [ ] 1.3 Run backend tests — confirm green baseline
- [ ] 1.4 Capture before screenshots at 412px, 768px, 1024px

## 2. Avatar/Initials Component

- [ ] 2.1 Create initials extraction utility: first char of first word + first char of second word from displayName. Single word → first two chars. Empty → "?"
- [ ] 2.2 Create avatar circle component: 36px visible circle with 44px minimum tappable area (padding for WCAG 2.5.5). Background: `color.primary`, text: `color.textInverse` — CSS custom property tokens only, no hardcoded hex. Use `text.*` and `weight.*` from typography.ts. `data-testid="profile-avatar"`
- [ ] 2.3 Add i18n keys: `profile.settings`, `profile.signout`, `settings.title`, `settings.password`, `settings.security` in en.json and es.json

## 3. Profile Dropdown

- [ ] 3.1 Replace desktop inline buttons (Password, Security, Sign Out, username) with avatar button + dropdown in `Layout.tsx`
- [ ] 3.2 Dropdown contents: display name + role badge (top), Settings link (`data-testid="profile-settings-link"`), language selector (mobile only), Sign Out with border separator (`data-testid="profile-signout"`)
- [ ] 3.3 Dropdown container: `data-testid="profile-dropdown"`, `role="menu"`, positioned below avatar, z-index above page content
- [ ] 3.4 Close on outside click, Escape (return focus to avatar), and action selection — reuse pattern from kebab menu
- [ ] 3.5 Avatar button: `aria-haspopup="true"`, `aria-expanded`, keyboard accessible
- [ ] 3.6 Language selector: stays in header on desktop (>= 768px), moves into dropdown on mobile (< 768px) — same as current kebab behavior
- [ ] 3.7 Remove kebab menu code — avatar dropdown replaces it on mobile
- [ ] 3.8 Notification bell AND queue status indicator stay in header on all breakpoints
- [ ] 3.9 Update existing Playwright tests that reference `change-password-button`, `totp-settings-button` in the header — these now appear in /settings page or are accessed via profile dropdown. Search all spec.ts files for these testids and update locators.

## 4. Settings Page

- [ ] 4.1 Create `SettingsPage.tsx` with two sections: Password and Security. Use `text.*`, `weight.*`, `leading.*` from typography.ts and `color.*` from colors.ts — no hardcoded values. Line-height >= 1.5 (WCAG 1.4.12). No fixed height containers that clip text.
- [ ] 4.2 Extract password change form from `ChangePasswordModal.tsx` into reusable `PasswordChangeForm.tsx` component
- [ ] 4.3 Extract TOTP enrollment flow from `TotpEnrollmentPage.tsx` into reusable `TotpEnrollmentSection.tsx` component
- [ ] 4.4 Compose both in `SettingsPage.tsx` with section headers and responsive layout (stacked on mobile, side-by-side or stacked on desktop)
- [ ] 4.5 Add `/settings` route to `App.tsx` with AuthGuard (all authenticated roles)
- [ ] 4.6 Settings link in profile dropdown navigates to `/settings`
- [ ] 4.7 Update ChangePasswordModal to use the extracted form component (backwards compatible)
- [ ] 4.8 Verify TOTP enrollment flow works in settings page context (QR code, code entry, backup codes)
- [ ] 4.9 Run `npm --prefix frontend run build` — confirm TypeScript compiles clean

## 5. Positive Tests

- [ ] 5.1 Playwright (1024px): header shows avatar, language, bell — no Password/Security/Sign Out buttons
- [ ] 5.2 Playwright (412px): header shows avatar, bell — no kebab icon
- [ ] 5.3 Playwright (1024px): click avatar → dropdown with name, role, Settings, Sign Out
- [ ] 5.4 Playwright (412px): click avatar → dropdown with name, role, language, Settings, Sign Out
- [ ] 5.5 Playwright: click Settings → navigates to /settings page with Password and Security sections
- [ ] 5.6 Playwright: change password from /settings page → works (same as modal)
- [ ] 5.7 Playwright: Sign Out from dropdown → redirects to login
- [ ] 5.8 Playwright: Escape closes dropdown, focus returns to avatar
- [ ] 5.9 Playwright: avatar displays correct initials ("DA" for Dev Admin)
- [ ] 5.10 axe-core scan: zero Critical/Serious violations at 412px and 1024px (light mode)
- [ ] 5.10a Playwright (320px viewport): no horizontal scrollbar — avatar + bell + queue + FABT title fit (WCAG 1.4.10)
- [ ] 5.10b axe-core scan in dark mode at 412px and 1024px — zero contrast violations on avatar + dropdown
- [ ] 5.11 Screenshot: capture avatar + dropdown at 412px and 1024px for visual verification — READ and verify before marking done
- [ ] 5.12 DemoGuard: verify password change from /settings page returns 403 `demo_restricted` on public path (same API, different UI)
- [ ] 5.13 Verify TOTP enrollment from /settings page is allowed in demo mode (on allowlist)

## 6. Negative Tests

- [ ] 6.1 Playwright (1024px): language selector still visible in header (not moved to dropdown)
- [ ] 6.2 Playwright (1024px): notification bell still visible in header
- [ ] 6.3 Playwright: existing DV referral, coordinator, admin tests pass (no regressions)
- [ ] 6.4 Run full Playwright suite — confirm zero regressions
- [ ] 6.5 Run full backend suite — confirm zero regressions (no backend changes)
- [ ] 6.6 Breakpoint boundary: 768px → desktop (avatar + lang in header), 767px → mobile (avatar, lang in dropdown)
- [ ] 6.7 Dark mode: axe-core scan with `prefers-color-scheme: dark` at 412px and 1024px — zero contrast violations on header, avatar, and dropdown. Avatar `color.primary` on dark header must meet 3:1 UI component contrast.

## 7. Integration & Release

- [ ] 7.1 Run `npm --prefix frontend run build` — clean
- [ ] 7.2 Test through nginx proxy
- [ ] 7.3 Test in incognito (stale SW)
- [ ] 7.4 Update test counts if changed
- [ ] 7.5 Commit, PR, CI scans
- [ ] 7.6 Merge and tag
- [ ] 7.7 Deploy — frontend-only (no backend changes)
- [ ] 7.8 Post-deploy: verify avatar dropdown on live site (desktop + mobile)
- [ ] 7.9 Post-deploy: verify /settings page works (password + TOTP)
