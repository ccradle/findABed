## Context

FABT is a React 19 SPA with inline styles (no CSS framework), react-intl for i18n (EN/ES), and react-router-dom for routing. The frontend has no component library — all UI is hand-built. The admin panel (AdminPanel.tsx, 1,739 lines) contains 10 tab-rendered sections. The coordinator dashboard uses custom stepper controls for bed counts. Status indicators (freshness badges, RAG utilization, reservation status) use inline color styles.

The primary users — Darius (outreach, mobile, one-handed, low-light) and Sandra (coordinator, desktop, interrupted, keyboard) — have accessibility needs that go beyond legal compliance. The legal requirement (ADA Title II, WCAG 2.1 AA, April 2026 deadline) aligns with practical user needs.

## Goals / Non-Goals

**Goals:**
- Pass axe-core automated scan with zero violations on all pages (CI gate)
- Fix all Level A and Level AA WCAG 2.1 violations
- Produce a self-assessed ACR using VPAT 2.5 WCAG template
- Ensure Darius can complete search→hold→confirm with one hand in low light
- Ensure Sandra can complete login→find shelter→update beds→save entirely via keyboard
- Scan all project documents for overclaimed compliance language

**Non-Goals:**
- WCAG 2.1 AAA conformance (target, not mandate)
- Third-party accessibility audit (future, if city requires)
- Screen reader optimization beyond functional compliance (future)
- Redesigning the UI — remediate within existing design language

## Decisions

### D1: axe-core integration approach

Install `@axe-core/playwright`. Add a dedicated `accessibility.spec.ts` test file that scans every route. Make it a CI-blocking gate — zero violations allowed. Scan pages in multiple states (empty, loaded, error, modal open).

Tags to test: `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`.

### D2: Focus management on route change

Create a `RouteAnnouncer` component that:
1. Listens to react-router-dom location changes
2. Updates an `aria-live="polite"` visually-hidden region with the new page title
3. Moves focus to the `<main>` element or first `<h1>` on navigation

This is the single most common SPA accessibility failure.

### D3: Skip-to-content link

Add a visually-hidden "Skip to main content" link as the first focusable element in `Layout.tsx`. It becomes visible on focus (keyboard users see it, mouse users don't). Links to `<main id="main-content">`.

### D4: Color independence for status indicators

All badges that currently use color alone must add a text label or icon:

| Badge | Current | Fix |
|---|---|---|
| Freshness (FRESH/STALE/UNKNOWN) | Green/amber/gray background | Add text: "Fresh", "Stale", "Unknown" |
| RAG utilization | Green/amber/red | Add text: "76.0% OK", "92.0% High", "108.0% Over" |
| Reservation status | Color-coded | Already has text labels — verify contrast |
| Enabled/Disabled (batch jobs) | Green/red badge | Already has text — verify contrast |

This fixes WCAG 1.4.1 Use of Color (Level A) — the most basic compliance level.

### D5: Touch target sizing

Enforce minimum 44x44px on all interactive elements. This exceeds the WCAG 2.1 AA requirement (which has no target size criterion — that's WCAG 2.2) but is essential for Darius's one-handed outdoor use and aligns with Apple HIG (44pt) and Material Design (48dp) guidelines.

Audit: all buttons, links, filter toggles, stepper +/- buttons, tab bar buttons, modal close buttons.

### D6: Bed count stepper ARIA

The coordinator dashboard's +/- bed count controls should use the spinbutton pattern:
- Wrap in `role="group"` with `aria-labelledby` pointing to the field label
- The numeric display uses `role="spinbutton"` with `aria-valuenow`, `aria-valuemin`, `aria-valuemax`
- +/- buttons get `aria-hidden="true"` (they're mouse/touch shortcuts — keyboard users use arrow keys on the spinbutton)

### D7: Admin tab bar — W3C APG tabs pattern

The admin panel tab bar must follow the W3C APG Tabs pattern:
- Container: `role="tablist"`
- Each tab: `role="tab"`, `aria-selected`, `aria-controls`
- Each panel: `role="tabpanel"`, `aria-labelledby`
- Keyboard: Arrow keys move between tabs (not Tab key), Home/End jump to first/last
- Roving tabindex: active tab gets `tabindex="0"`, others `tabindex="-1"`

### D8: Modal/dialog accessibility

All confirmation dialogs, the referral modal, and the cron edit modal should use native `<dialog>` with `showModal()` where possible. For React compatibility, ensure:
- Focus moves into dialog on open
- Tab cycles within dialog only
- Escape closes
- Focus returns to trigger on close
- `aria-labelledby` and `aria-describedby` set

### D9: `lang` attribute for Spanish content

When the user switches locale to Spanish via react-intl, update `document.documentElement.lang` to `"es"`. Switch back to `"en"` on English. This is WCAG 3.1.1 (Level A) — screen readers use the `lang` attribute to select the correct speech synthesis voice.

### D10: Recharts and Leaflet accessibility

**Recharts:** Enable `accessibilityLayer` prop on charts. Add a toggle button "Show as table" that renders the same data as an HTML `<table>` instead of the chart. The table is the primary accessible experience; the chart is the visual enhancement.

**Leaflet:** Already has a table fallback for air-gapped deployments (D16 from coc-analytics). Ensure map tiles get `aria-hidden="true"`, markers get descriptive `title` attributes, and the table fallback is available via a toggle button (not just on tile load failure) so screen reader users can always access the data.

**Motion sensitivity:** Disable Recharts animations when `prefers-reduced-motion: reduce` is set. Check via `window.matchMedia('(prefers-reduced-motion: reduce)').matches` and pass `isAnimationActive={false}` to chart components. This addresses WCAG 2.3.3 Animation from Interactions (AAA) — not mandated but important for motion-sensitive users.

### D11: Session timeout warning

If the JWT access token is within 2 minutes of expiry and the user is active (mouse/keyboard events in the last 5 minutes), show a non-modal warning: "Your session expires in 2 minutes. [Extend]". Clicking Extend triggers a token refresh. This addresses WCAG 2.2.1 Timing Adjustable and Sandra's interrupted workflow.

### D12: ACR document format

Produce `docs/WCAG-ACR.md` using the VPAT 2.5 WCAG template structure:
- Product name, version, report date, evaluation methods
- Table for all 30 Level A criteria with conformance level + remarks
- Table for all 20 Level AA criteria with conformance level + remarks
- Self-assessment disclaimer: "This report reflects a self-assessment conducted by the project team using automated tools (axe-core) and manual testing. It does not constitute a third-party certification of accessibility compliance."

Conformance levels: Supports, Partially Supports, Does Not Support, Not Applicable.
Honest "Partially Supports" with remediation notes is better than false "Supports".

### D13: Legal language review scope

Scan these files for overclaimed compliance language:
- `finding-a-bed-tonight/README.md`
- `findABed/README.md`
- `docs/DV-OPAQUE-REFERRAL.md`
- `docs/runbook.md`
- `demo/index.html`, `demo/dvindex.html`, `demo/hmisindex.html`, `demo/analyticsindex.html`
- Any file containing "compliant", "certified", "ensures compliance", "guarantees"

Replace with "designed to support", "self-assessed", "aligned with" per established project policy (legal-language-corrections precedent).
