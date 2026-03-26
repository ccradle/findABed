## Why

ADA Title II final rule (April 2024) mandates WCAG 2.1 Level AA for all state and local government web content, with a compliance deadline of April 24, 2026 for cities with population 50,000+. Raleigh falls in this category. City procurement officer Teresa Nguyen requires an Accessibility Conformance Report (ACR) before any formal adoption conversation. Without it, FABT cannot be evaluated for city procurement regardless of technical merit.

Beyond legal compliance, FABT's primary users operate in conditions that demand accessibility: Darius (outreach worker) uses the app one-handed on a mid-range Android in low light and direct sunlight. Sandra (coordinator) uses it on a shared desktop with frequent interruptions, relying on keyboard navigation. Both depend on status indicators (freshness badges, RAG utilization badges) that currently convey meaning through color alone — a Level A violation affecting 8% of color-blind men.

## What Changes

- **Automated accessibility scanning**: Install `@axe-core/playwright`, scan every page/route, make violations a CI-blocking gate
- **Focus management**: Add skip-to-content link, manage focus on React Router navigation, announce route changes via `aria-live`
- **Keyboard navigation**: Implement W3C APG tab pattern for admin tab bar, ensure all modals use native `<dialog>` with proper focus trap/return, verify all interactive elements keyboard-operable
- **Color independence**: Add text labels and/or icons to all status badges (FRESH/STALE, RAG utilization, reservation status) so color is never the sole indicator
- **Touch targets**: Audit and enforce minimum 44x44px on all interactive elements (Darius's one-handed outdoor use)
- **ARIA remediation**: Spinbutton pattern for bed count steppers, `aria-sort` on sortable tables, `aria-live` regions for dynamic content updates, `lang` attribute switching for Spanish content
- **Recharts accessibility**: Enable `accessibilityLayer`, add data table toggle as alternative to charts
- **Leaflet map accessibility**: Hide tile images from screen readers, label markers, provide table fallback (already implemented for air-gapped deployments)
- **Session timeout warning**: Warn users before session expiry (Sandra's interrupted workflow)
- **Self-assessed ACR document**: Complete VPAT 2.5 WCAG template covering all 50 WCAG 2.1 AA criteria with honest conformance levels and self-assessment disclaimer
- **Legal language review**: Scan all documents for overclaimed compliance — replace "compliant" with "designed to support" per established project policy

## Capabilities

### New Capabilities
- `wcag-accessibility-compliance`: Automated accessibility scanning (axe-core CI gate), ARIA remediation, keyboard navigation, focus management, color independence, touch target enforcement, and self-assessed ACR document

### Modified Capabilities
- `coc-analytics-dashboard`: Recharts accessibility layer, data table toggle for charts, map marker labels
- `bed-availability-query`: Color-independent freshness badges (add text/icon alongside color)

## Impact

- **Frontend (all pages)**: Skip-to-content link, focus management on route change, `lang` attribute switching, session timeout warning
- **Frontend (outreach search)**: Freshness badge text labels, touch target audit, hold dialog focus management
- **Frontend (coordinator dashboard)**: Bed count spinbutton ARIA, keyboard navigation, success/error state announcements
- **Frontend (admin panel)**: Tab bar APG pattern, sortable table ARIA, modal focus management
- **Frontend (analytics tab)**: Recharts accessibilityLayer, data table toggle, map marker labels
- **New dependency**: `@axe-core/playwright` (dev)
- **New CI gate**: Accessibility scan blocks build on violations
- **New document**: `docs/WCAG-ACR.md` — self-assessed Accessibility Conformance Report
- **Modified documents**: All READMEs, walkthroughs, and addendums scanned for overclaimed compliance language
