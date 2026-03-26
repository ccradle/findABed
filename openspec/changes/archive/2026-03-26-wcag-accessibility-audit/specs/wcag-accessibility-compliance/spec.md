## ADDED Requirements

### Requirement: automated-accessibility-scanning
The system SHALL pass automated WCAG 2.1 AA accessibility scans on all pages with zero violations, enforced as a CI-blocking gate.

#### Scenario: All pages pass axe-core scan
- **WHEN** axe-core scans every route (login, search, coordinator, admin with all tabs, analytics)
- **THEN** zero violations are reported for tags wcag2a, wcag2aa, wcag21a, wcag21aa

#### Scenario: CI blocks on accessibility violations
- **WHEN** a code change introduces an accessibility violation
- **THEN** the Playwright accessibility test fails and blocks the build

### Requirement: keyboard-navigation
The system SHALL be fully operable via keyboard for all core workflows.

#### Scenario: Outreach worker completes search-to-hold via keyboard
- **WHEN** a keyboard user navigates the search page
- **THEN** they can search, filter, select a shelter, view details, and hold a bed using only keyboard

#### Scenario: Coordinator updates bed count via keyboard
- **WHEN** a keyboard user navigates the coordinator dashboard
- **THEN** they can find their shelter, adjust occupied/total beds using arrow keys on spinbutton, and save — all without mouse

#### Scenario: Admin navigates tabs via arrow keys
- **WHEN** a keyboard user reaches the admin tab bar
- **THEN** arrow keys move between tabs, Enter/Space activates, Tab moves into the panel content

#### Scenario: Skip-to-content link available
- **WHEN** a keyboard user presses Tab on any page
- **THEN** the first focusable element is a "Skip to main content" link that jumps to the main content area

### Requirement: focus-management
The system SHALL manage focus correctly on route changes, modal open/close, and dynamic content updates.

#### Scenario: Route change announces new page
- **WHEN** the user navigates between routes (e.g., search → admin)
- **THEN** the new page title is announced via aria-live region and focus moves to the main heading

#### Scenario: Modal opens with focus inside
- **WHEN** a modal dialog opens (referral, hold confirmation, cron edit)
- **THEN** focus moves into the modal, Tab cycles within it, Escape closes it, and focus returns to the trigger

### Requirement: color-independence
The system SHALL not use color as the sole means of conveying information.

#### Scenario: Freshness badges readable without color
- **WHEN** a user views bed search results
- **THEN** each freshness badge shows a text label ("Fresh", "Stale", "Unknown") alongside the color

#### Scenario: RAG utilization badges readable without color
- **WHEN** an admin views shelter performance or analytics
- **THEN** utilization badges include the percentage text and a status word (e.g., "76.0% OK", "108.0% Over")

#### Scenario: Status indicators visible in high contrast mode
- **WHEN** the user's OS is set to high contrast or prefers-contrast: more
- **THEN** all status badges remain visually distinguishable

### Requirement: touch-target-sizing
The system SHALL ensure all interactive elements meet minimum 44x44px touch targets for mobile/outdoor use.

#### Scenario: All buttons and links meet minimum size
- **WHEN** the app is rendered on a mobile viewport
- **THEN** every button, link, and interactive control has at least 44x44px tappable area

### Requirement: assistive-technology-support
The system SHALL work correctly with screen readers and other assistive technologies.

#### Scenario: Bed count steppers announced correctly
- **WHEN** a screen reader user focuses a bed count stepper
- **THEN** they hear the label, current value, min, and max via spinbutton ARIA attributes

#### Scenario: Dynamic content updates announced
- **WHEN** bed availability data refreshes or a save confirmation appears
- **THEN** the update is announced via aria-live region without stealing focus

#### Scenario: Spanish locale sets lang attribute
- **WHEN** the user switches to Spanish
- **THEN** document.documentElement.lang is set to "es" so screen readers use Spanish speech synthesis

#### Scenario: Charts have table alternative
- **WHEN** a screen reader user encounters a Recharts chart
- **THEN** a "Show as table" toggle provides the same data in an accessible HTML table

### Requirement: session-timeout-warning
The system SHALL warn users before session expiry so interrupted workflows are not lost silently.

#### Scenario: Active user sees timeout warning
- **WHEN** the JWT token is within 2 minutes of expiry and the user has been active
- **THEN** a non-modal warning appears with an option to extend the session

### Requirement: accessibility-conformance-report
The system SHALL include a self-assessed ACR document covering all WCAG 2.1 AA criteria.

#### Scenario: ACR covers all criteria
- **WHEN** the ACR document is reviewed
- **THEN** it addresses all 30 Level A and 20 Level AA success criteria with conformance levels and remarks

#### Scenario: ACR includes self-assessment disclaimer
- **WHEN** the ACR document is reviewed
- **THEN** it includes a disclaimer stating this is a self-assessment, not a third-party certification

### Requirement: legal-language-review
The system SHALL not overclaim compliance in any project documentation.

#### Scenario: No documents claim "compliant" without qualification
- **WHEN** all project documents are scanned
- **THEN** no document uses "compliant", "certified", or "ensures compliance" without qualification
- **AND** all compliance references use "designed to support" or "self-assessed" language
