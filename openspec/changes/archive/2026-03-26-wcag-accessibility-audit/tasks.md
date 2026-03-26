## Prerequisites

- **Requires `demo-seed-data` change merged first** so axe-core scans run against populated UI states (charts with data, tables with rows, non-zero metrics). Scanning empty pages misses violations that only appear with real content.

## 1. Branch Setup

- [x] 1.1 Create branch `feature/wcag-accessibility-audit` from main (re-branch from main after demo-seed-data merges)

## 2. Automated Scanning Infrastructure

- [x] 2.1 Install `@axe-core/playwright` as dev dependency
- [x] 2.2 Create `accessibility.spec.ts`: scan login, search, coordinator dashboard, admin (all tabs), analytics tab
- [x] 2.3 Scan pages in multiple states: empty, loaded, error, modal open
- [x] 2.4 Configure axe tags: `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`
- [x] 2.5 Run initial scan — catalog all existing violations with severity (6 pages failing → 0 after fixes)

## 3. Focus Management (D2, D3)

- [x] 3.1 Create `RouteAnnouncer` component: listens to location changes, updates `aria-live="polite"` hidden region
- [x] 3.2 Move focus to `<main>` or first `<h1>` on route change
- [x] 3.3 Add skip-to-content link as first focusable element in `Layout.tsx`
- [x] 3.4 Style skip link: visually hidden, visible on focus
- [x] 3.5 Add `id="main-content"` to `<main>` element

## 4. Keyboard Navigation (D7, D8)

- [x] 4.1 Admin tab bar: add `role="tablist"`, `role="tab"`, `role="tabpanel"`, `aria-selected`, `aria-controls`
- [x] 4.2 Admin tab bar: implement arrow key navigation with roving tabindex
- [x] 4.3 Verify all modals: focus moves in on open, Tab cycles within, Escape closes, focus returns to trigger
- [x] 4.4 Audit all interactive elements: every button, link, input keyboard-reachable and operable
- [ ] 4.5 Test: outreach worker search→hold→confirm flow completable via keyboard only (deferred — manual verification)

## 5. Color Independence (D4)

- [x] 5.1 Freshness badges: add text labels ("Fresh", "Stale", "Unknown") alongside color
- [x] 5.2 RAG utilization badges: add status text ("OK", "Low", "Over") alongside percentage
- [x] 5.3 Reservation status badges: verify text labels present, check contrast ratios
- [x] 5.4 Batch job status badges: verify text labels present, check contrast ratios
- [x] 5.5 Verify all badge text meets 4.5:1 contrast ratio against badge background
- [x] 5.6 Test with simulated color blindness (protanopia, deuteranopia) — text labels ensure distinguishability regardless of color perception

## 6. Touch Targets (D5)

- [x] 6.1 Audit all buttons, links, and interactive controls for 44x44px minimum
- [x] 6.2 Fix undersized elements: increase padding, min-height, min-width as needed
- [x] 6.3 Verify: filter toggles, stepper +/- buttons, modal close buttons, tab bar buttons
- [x] 6.4 Test on mobile viewport (375px width) — all critical elements have minHeight/minWidth 44px

## 7. ARIA Remediation (D6, D9, D10)

- [x] 7.1 Bed count steppers: add aria-label, increase size to 44px minimum touch target
- [x] 7.2 Sortable tables: N/A — tables do not have sort functionality in current version
- [x] 7.3 Dynamic content: add `aria-live="polite"` regions for save confirmations
- [x] 7.4 Spanish locale: update `document.documentElement.lang` to `"es"` on locale switch, `"en"` on switch back
- [x] 7.5 Recharts: "Show as table" toggle provides accessible data table alternative
- [x] 7.6 Recharts: disable animations when `prefers-reduced-motion: reduce` is set
- [x] 7.7 Leaflet map: N/A — geographic view uses table fallback only (no map rendered)
- [x] 7.8 Geographic view: table is always shown (not conditional on tile load failure)
- [x] 7.9 Add `aria-label` or `aria-labelledby` to all icon-only buttons (close, edit, delete)

## 8. Session Timeout Warning (D11)

- [x] 8.1 Detect JWT expiry within 2 minutes + user activity tracking (throttled 30s)
- [x] 8.2 Show modal alertdialog with Continue/Log Out buttons (per WAI-ARIA APG, not banner)
- [x] 8.3 Continue button triggers /auth/refresh, BroadcastChannel cross-tab sync
- [x] 8.4 Warning uses role="alertdialog" with aria-modal, aria-labelledby, aria-describedby, focus trap
- [x] 8.5 Backend: expiresIn added to TokenResponse (no JWT decode on client per OWASP)

## 9. Accessibility Conformance Report (D12)

- [x] 9.1 Create `docs/WCAG-ACR.md` with VPAT 2.5 WCAG template structure
- [x] 9.2 Fill in product info, evaluation methods, report date
- [x] 9.3 Complete all 30 Level A criteria rows with conformance level + remarks
- [x] 9.4 Complete all 20 Level AA criteria rows with conformance level + remarks
- [x] 9.5 Add self-assessment disclaimer
- [x] 9.6 Link ACR from code repo README

## 10. Legal Language Review (D13)

- [x] 10.1 Scan all documents for "compliant", "certified", "ensures compliance", "guarantees"
- [x] 10.2 Replace overclaimed language with "designed to support" or "self-assessed" (6 instances fixed)
- [x] 10.3 Verify demo walkthrough HTML pages use qualified language (already clean)
- [x] 10.4 Verify README accessibility section uses qualified language
- [x] 10.5 Verify DV-OPAQUE-REFERRAL.md language (confirmed clean)

## 11. Testing

- [x] 11.1 Playwright: all axe-core scans pass with zero violations (8/8 pages)
- [x] 11.2 Virtual SR: search page navigation announces shelters and headings
- [x] 11.3 Virtual SR: freshness badges announce "Fresh"/"Stale" text labels
- [x] 11.4 Playwright: skip-to-content link announced by virtual SR
- [x] 11.5 Playwright: admin tab bar ARIA roles + arrow key navigation verified
- [x] 11.6 Playwright: stepper buttons have aria-labels + 44px touch targets
- [x] 11.7 Playwright: Spanish locale sets lang="es" on document element
- [ ] 11.8 Session timeout warning test (requires short-lived token config)
- [ ] 11.9 Real screen reader testing (NVDA/VoiceOver) — deferred to release-gate CI with @guidepup/playwright

## 12. Documentation

- [x] 12.1 Update code repo README: add accessibility section with ACR link
- [x] 12.2 Update docs repo README: add wcag-accessibility-audit to active/completed
- [x] 12.3 Update test counts in README (236 backend, 113 Playwright, 73 Karate = 422 total)

## 13. Regression and PR

- [x] 13.1 Run full backend test suite (236 tests, 0 failures)
- [x] 13.2 Run Playwright suite (113 tests, 0 failures)
- [x] 13.3 Run Karate suite (73 tests, 0 failures)
- [ ] 13.4 Commit all changes on feature branch
- [ ] 13.5 Push branch, create PR to main
- [ ] 13.6 Merge PR to main
- [ ] 13.7 Tag release (v0.13.0)
