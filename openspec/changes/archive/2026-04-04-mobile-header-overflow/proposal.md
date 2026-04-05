## Why

The header bar forces horizontal scrolling on mobile devices (Samsung Galaxy S25 Ultra at 480px, and narrower Android devices at ~412px). The header requires ~805px but only has 412-480px available. Security and Sign Out buttons are completely off-screen, requiring two-handed horizontal scroll to reach. This is a usability blocker for Darius Webb (outreach worker, one-handed Android use) and a potential WCAG 1.4.10 (Reflow) violation with the ADA Title II deadline 20 days away. (#55)

## What Changes

### Mobile Header Responsive Layout
- Add a kebab (three-dot) overflow menu component for mobile (< 768px breakpoint, matching existing `isMobile` threshold)
- On mobile: header shows only app title (shortened), notification bell (badge must remain visible), and kebab menu icon
- Kebab menu contains: username display, language selector, change password, security/2FA, sign out
- On desktop (>= 768px): no change — all controls remain inline as they are today
- Remove horizontal overflow on header — `overflow-x: hidden` as safety net
- All touch targets remain >= 44x44px (WCAG 2.5.5 AAA)
- Kebab menu closes on outside click, Escape key, and after action selection

### App Title Shortening on Mobile
- On mobile: shorten "Finding A Bed Tonight" to "FABT" or use a compact display to prevent 3-line wrapping
- On desktop: full title unchanged

## Capabilities

### New Capabilities
- `mobile-header-overflow-menu`: Kebab overflow menu component for mobile header, responsive layout switching at 768px

### Modified Capabilities
- `wcag-accessibility-compliance`: Header reflow fix satisfies WCAG 1.4.10 (Reflow) at 320px minimum

## Impact

**Frontend (finding-a-bed-tonight/frontend):**
- `Layout.tsx` — header section restructured for responsive mobile/desktop rendering
- Kebab menu implemented inline in `Layout.tsx` (Design D3 — no separate component needed)
- `LocaleSelector.tsx` — may need to render inside the overflow menu on mobile
- `NotificationBell.tsx` — no changes (stays visible in header)

**Tests:**
- Playwright: mobile viewport tests for header overflow, kebab menu interaction, desktop regression
- axe-core: verify no new WCAG violations at mobile viewport
- Visual: screenshots at 412px, 480px, 768px, 1024px breakpoints
