## Context

The header in `Layout.tsx` (lines 244-333) uses a single `display: flex` row with `gap: 12px` and no `flex-wrap`. On a 412px viewport, the header needs ~805px — a 48% overflow. The `isMobile` state (< 768px) controls sidebar/bottom-nav but the header is completely unresponsive to viewport width.

Current header items (left to right): app title, username, language selector, queue indicator, notification bell, change password button, security/TOTP button, sign out button.

## Goals / Non-Goals

**Goals:**
- Eliminate horizontal scrolling on mobile devices (412px–480px)
- Maintain full desktop header layout unchanged (>= 768px)
- All interactive elements meet 44x44px WCAG touch targets
- Satisfy WCAG 1.4.10 (Reflow) — no horizontal scroll at 320px minimum width
- Kebab menu is keyboard accessible (Escape closes, Tab navigates)

**Non-Goals:**
- Moving header items to bottom nav (future consideration, larger refactor)
- Redesigning the desktop header
- Adding hamburger menu for page navigation (bottom nav handles this)

## Decisions

### D1: Kebab overflow menu for secondary actions

On mobile (< 768px), secondary actions collapse behind a kebab (three-dot) icon. Primary items (notification bell) stay visible.

**Mobile header:** `[FABT title] ... [📤] [🔔] [⋮]`
**Kebab menu contents:** Username (display only), Language selector, Change Password, Security, Sign Out

QueueStatusIndicator (offline queue badge) and NotificationBell stay in the header bar — both are status indicators that Darius needs to glance at without opening a menu.

**Why kebab over hamburger:** Hamburger menus are for site navigation. Kebab menus are for contextual actions. Our items are actions, not navigation — the bottom nav already handles page routing. PatternFly's overflow menu pattern confirms this distinction.

**Alternative considered:** `flex-wrap` to wrap items to a second line. Rejected — wrapping 5+ buttons creates a visually chaotic double-row header that's harder to scan than a clean single row with overflow menu.

### D2: App title shortens on mobile via i18n key

On mobile, the title uses i18n key `app.nameShort` ("FABT" in both en and es). The full title uses `app.name`. The full title remains on desktop.

**Why:** The title wraps to 3 lines at 412px, consuming ~100px of vertical space and ~200px of horizontal. Shortening to "FABT" keeps the header to one line. "FABT" is the brand abbreviation, consistent across languages — the Spanish full name is "Encontrar Una Cama Esta Noche" (even longer than English), so a translated short name would still overflow.

**Implementation:** Conditionally render `app.nameShort` vs `app.name` based on `isMobile` state (already exists in Layout.tsx). Add `app.nameShort` to both `en.json` and `es.json`.

### D3: Inline component, not separate file

The kebab menu will be implemented inline in `Layout.tsx` using a `useState` toggle for menu visibility. No new component file needed — the menu is 3-5 items with simple click handlers that already exist in Layout.tsx.

**Why:** The menu items are already rendered in Layout.tsx with their onClick handlers. Extracting to a separate component would require prop-drilling all handlers, auth state, locale state, etc. Keeping it inline is simpler and matches the existing pattern.

**Alternative considered:** Separate `HeaderOverflowMenu.tsx` component. Rejected for unnecessary complexity — the menu is layout-specific, not reusable.

### D4: Click-outside and Escape to close

The kebab dropdown closes on: clicking outside the menu, pressing Escape, selecting any menu action, and navigating away. Uses a `useRef` + `useEffect` click-outside pattern (standard React pattern).

**Why:** WCAG 2.1 requires that content that appears on hover/focus can be dismissed (1.4.13). Escape key dismissal is keyboard accessibility best practice.

### D5: position: relative + z-index on header (NOT overflow-x: hidden)

Add `position: relative; z-index: 100` to the header element to establish a stacking context so the kebab dropdown renders above page content.

**Why:** The dropdown is `position: absolute` inside the header. Without a stacking context, the main content area covers it. `overflow-x: hidden` was originally planned as a safety net but **must NOT be used** — it clips the absolutely-positioned dropdown, making it invisible to users even though Playwright tests pass (element exists in DOM with non-zero dimensions but is visually clipped).

**Lesson learned:** Always capture and visually inspect screenshots after UI changes. A passing test doesn't guarantee visibility.

## Risks / Trade-offs

**[Risk] Kebab menu not discoverable** → Mitigation: The three-dot icon is universally recognized on Android. Darius Webb uses Android daily — this is native to his platform.

**[Risk] Desktop layout accidentally affected** → Mitigation: All mobile changes are gated behind `isMobile` (< 768px). Desktop rendering is untouched. Playwright tests verify both viewports.

**[Risk] Locale selector behavior in dropdown** → Mitigation: The `<select>` element inside a dropdown menu can have z-index/focus issues on some mobile browsers. Test on real Android device if possible; fallback is radio buttons for language selection inside the menu.

**[Risk] Stale service worker caches old Layout.tsx** → Mitigation: Lesson learned — test in incognito after deploy, no Cloudflare purge needed (no-cache on sw.js since v0.28.2).
