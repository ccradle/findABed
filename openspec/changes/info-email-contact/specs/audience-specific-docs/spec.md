## ADDED Requirements

### Requirement: Audience pages surface project contact via JS-injected CTA with noscript fallback

The four audience pages — `demo/for-cities.html`, `demo/for-coc-admins.html`, `demo/for-coordinators.html`, `demo/for-funders.html` — and the existing `demo/outreach-one-pager.html` `.contact` block SHALL include the same `<a class="contact-email" href="#" hidden aria-live="polite">` placeholder element within their existing "next steps", "get involved", or equivalent CTA section, paired with an inline `<noscript>` block carrying the GH-issues fallback link.

The link's `href` and visible text MUST be populated by `/contact.js` (the same shared script used by footers) at runtime, not hardcoded in the page source. The literal email address MUST NOT appear in any git-tracked HTML.

The framing MUST be audience-appropriate (a funder's CTA reads differently from a coordinator's) but MUST NOT make claims that go beyond the project's actual posture (no "we partner with...", no "every community", per `feedback_legal_claims_review`).

#### Scenario: Funder page CTA placeholder + noscript fallback + framing

- **WHEN** a visitor loads `https://findabed.org/demo/for-funders.html` (with JS enabled)
- **THEN** the page contains the placeholder element within a CTA section
- **AND** `/contact.js` populates it to `mailto:<platform-email>`
- **AND** an adjacent `<noscript>` block contains a GH-issues fallback link
- **AND** surrounding copy frames the link as the path for funding or pilot inquiries (verbiage Casey-reviewed per `feedback_legal_claims_review` before commit)

#### Scenario: CoC admin page CTA placeholder + pilot-inquiry framing

- **WHEN** a visitor loads `https://findabed.org/demo/for-coc-admins.html` (with JS enabled)
- **THEN** the page contains the placeholder element within a CTA section
- **AND** an adjacent `<noscript>` block contains a GH-issues fallback link
- **AND** surrounding copy frames the link as the path for pilot CoC inquiries or to request a deployment-readiness conversation
- **AND** the existing v0.55 "Reentry-Mode Tenant Flag" CTA paragraph cross-links to the new contact line

#### Scenario: Coordinator page CTA respects the existing "ask your CoC admin" pattern

- **GIVEN** `demo/for-coordinators.html` already has FAQ content directing coordinators to their CoC admin for shelter setup
- **WHEN** the placeholder is added to this page
- **THEN** the CTA framing is positioned for "questions your CoC admin can't answer" or "for the project itself, not platform support", not as a substitute for the established CoC-admin path
- **AND** the FAQ entry on coordinator → CoC admin coordination is not weakened or contradicted

#### Scenario: Cities page CTA placeholder + municipal-pilot-inquiry framing

- **WHEN** a visitor loads `https://findabed.org/demo/for-cities.html` (with JS enabled)
- **THEN** the page contains the placeholder element within a CTA section
- **AND** an adjacent `<noscript>` block contains a GH-issues fallback link
- **AND** surrounding copy frames the link as the path for municipal or county-government pilot inquiries

#### Scenario: outreach-one-pager .contact block populated via JS

- **GIVEN** `demo/outreach-one-pager.html` lines 207-213 have a `.contact` div with the framing "Contact us to set up a pilot conversation. We'll walk through the platform, ..."
- **WHEN** the placeholder is added to the `.contact` div and the page is rendered with JS
- **THEN** the placeholder is populated to `mailto:<platform-email>`
- **AND** an adjacent `<noscript>` block contains a GH-issues fallback link
- **AND** the surrounding "set up a pilot conversation" framing is preserved verbatim or only minimally tightened

#### Scenario: Audience CTAs use the same canonical placeholder as the footer

- **WHEN** the markup of an audience CTA placeholder is compared to the footer placeholder
- **THEN** both use `class="contact-email"` and the same `href="#"` + `hidden` + `aria-live="polite"` attributes
- **AND** both are populated by the same `/contact.js` script
- **AND** both have an inline `<noscript>` block with the GH-issues fallback

### Requirement: Spanish localization day-one for audience CTA framing

Audience CTA framing copy that surrounds the contact placeholder MUST ship with Spanish translations on day one for any page that already has Spanish localization. The translation keys MUST follow the existing `react-intl` (or static-content i18n harness) key naming convention used elsewhere in the page. The noscript GH-issues fallback copy MUST also be Spanish-localized day-one on these pages.

#### Scenario: Spanish keys present at PR time

- **GIVEN** an audience page already has Spanish translation keys for its existing copy
- **WHEN** the audience CTA framing is added to that page
- **THEN** the corresponding Spanish translation keys are added in the same PR
- **AND** no English-only fallback ships to the Spanish locale
- **AND** the noscript GH-issues fallback copy also has a Spanish key
