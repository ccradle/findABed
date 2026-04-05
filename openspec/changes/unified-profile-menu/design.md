## Context

The header currently shows 6 items on desktop: app title, username, language selector, notification bell, Password button, Security button, Sign Out button. On mobile (< 768px), these are behind a kebab menu (v0.29.1). Industry standard is a single avatar/profile trigger.

Current account flow:
- Password: modal overlay (`ChangePasswordModal.tsx`)
- Security: full page navigation (`/settings/totp` → `TotpEnrollmentPage.tsx`)
- Sign Out: immediate action
- No `/settings` or `/profile` route exists
- Users cannot view their own profile (email, roles) or edit display name

## Goals / Non-Goals

**Goals:**
- Single avatar/initials button in header for all account actions
- Consistent trigger across desktop and mobile (replaces kebab)
- `/settings` page with Password and Security sections
- Notification bell and language selector remain in header
- Sign Out accessible within one click of the avatar dropdown
- WCAG accessible (keyboard, focus, aria attributes)
- All existing functionality preserved (password change, TOTP enrollment)

**Non-Goals:**
- Self-service profile editing (Phase 2 — requires backend API)
- User avatar upload (Phase 2)
- Active sessions / login history (Phase 3)
- Theme/dark mode toggle in profile (system-only for now)

## Decisions

### D1: Avatar/initials button as trigger

Display user's initials (first letter of first + last name from displayName) in a colored circle. Falls back to first two letters if single name. This replaces both the desktop inline buttons and the mobile kebab menu.

**Why:** Industry standard (Gmail, Slack, GitHub). Universally recognized. Saves ~300px of header space on desktop. Consistent trigger across breakpoints.

### D2: Dropdown on desktop, bottom sheet on mobile (future)

Phase 1: dropdown popover on both desktop and mobile (same as current kebab behavior). Future enhancement: bottom sheet on mobile for better thumb reachability.

**Why:** Bottom sheet requires additional component infrastructure. The dropdown is sufficient for Phase 1 and matches the kebab pattern we already built.

### D3: `/settings` page with inline sections, not modals

Password change and TOTP enrollment render as sections within a single `/settings` page, not as modal overlays or separate page navigations.

**Why:** A settings page is the standard pattern for account management. It allows future sections (profile editing, sessions) without adding more modals or routes. The current modal (password) and full-page (TOTP) patterns are inconsistent.

**Implementation:** Extract the form logic from `ChangePasswordModal.tsx` and `TotpEnrollmentPage.tsx` into reusable components, then compose them in `SettingsPage.tsx`.

### D4: Sign Out stays one click from trigger

In the profile dropdown, Sign Out is the last item with a visual separator (border-top, red text). Opening the dropdown (1 click) + clicking Sign Out (1 click) = 2 clicks total. This matches Gmail, Slack, and GitHub.

**Why Sandra's concern:** Sandra needs quick sign out on shared devices. Two clicks is acceptable — the current mobile kebab already requires 2 clicks, and Sandra adapted. If needed, a keyboard shortcut could be added later.

### D5: Language selector stays in header

Language is a frequent-access item for bilingual coordinators who switch mid-session. It stays visible in the header, not buried in the profile dropdown.

**Why:** Keisha Thompson and the language-switching spec require immediate access. Moving it into a dropdown adds friction to a time-sensitive workflow.

**Exception:** On mobile (< 768px), language moves into the dropdown (same as current kebab behavior) to save header space.

### D6: Notification bell stays in header

The bell has a badge indicator that must be glanceable without interaction. It stays visible in the header on all breakpoints.

## Risks / Trade-offs

**[Risk] Sign Out is now 2 clicks instead of 1 on desktop** → Mitigation: Matches every major app. Sandra already uses 2 clicks on mobile (kebab). Acceptable.

**[Risk] Refactoring ChangePasswordModal + TotpEnrollmentPage** → Mitigation: Extract form logic into reusable components. The modal and page remain available as wrappers during transition, then deprecated.

**[Risk] Mobile kebab menu just built in v0.29.1, now replacing** → Mitigation: The avatar trigger reuses the same dropdown content and behavior. The kebab icon becomes an avatar icon — the menu structure is preserved.

**[Risk] initials extraction from displayName may be wrong** → Mitigation: Use first character of first word + first character of second word. If single word, use first two characters. If empty, use "?" fallback.
