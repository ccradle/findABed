## audience-specific-docs

Five audience-specific documentation pages serving distinct readers with distinct questions.

### Requirements

- REQ-AUD-1: `docs/FOR-COORDINATORS.md` MUST be written in plain English with zero jargon, answerable by a first-time volunteer coordinator
- REQ-AUD-2: `docs/FOR-COC-ADMINS.md` MUST address HUD reporting capabilities, shelter onboarding, DV protection explanation, HMIS connectivity, and deployment cost
- REQ-AUD-3: `docs/FOR-CITIES.md` MUST address data ownership, WCAG conformance, security posture, Apache 2.0 procurement implications, and support model
- REQ-AUD-4: `docs/FOR-DEVELOPERS.md` MUST contain all technical content from the current README without loss of information
- REQ-AUD-5: `docs/FOR-FUNDERS.md` MUST lead with the problem story, include theory of change, sustainability model, and what funding enables
- REQ-AUD-6: Each audience page MUST be self-contained — a reader should not need to read any other page to get their questions answered
- REQ-AUD-7: `docs/PITCH-BRIEFS.md` MUST contain 90-second briefs for coordinator, CoC admin, city official, and funder audiences

### Requirement: On-domain audience HTML pages
The findabed.org site SHALL serve all "Who It's For" audience pages as on-domain HTML files under `demo/`, not as links to GitHub markdown.

#### Scenario: Coordinator page served on-domain
- **WHEN** a visitor clicks the "Shelter Coordinators" card on the homepage
- **THEN** they are taken to `demo/for-coordinators.html` on findabed.org
- **AND** the page contains all content from `docs/FOR-COORDINATORS.md` formatted as accessible HTML

#### Scenario: CoC Admin page served on-domain
- **WHEN** a visitor clicks the "CoC Administrators" card on the homepage
- **THEN** they are taken to `demo/for-coc-admins.html` on findabed.org
- **AND** the page contains all content from `docs/FOR-COC-ADMINS.md` formatted as accessible HTML

#### Scenario: Funder page served on-domain
- **WHEN** a visitor clicks the "Funders" card on the homepage
- **THEN** they are taken to `demo/for-funders.html` on findabed.org
- **AND** the page contains all content from `docs/FOR-FUNDERS.md` formatted as accessible HTML

#### Scenario: No GitHub markdown links remain
- **WHEN** any "Who It's For" card is inspected on the homepage
- **THEN** zero href attributes point to `github.com`
- **AND** no stale `target="_blank"` or `rel` attributes from the old GitHub links remain

### Requirement: Audience-specific card link text
Each "Who It's For" card SHALL use intentional, audience-specific link text instead of generic "Read more".

#### Scenario: Card link text matches audience
- **WHEN** the homepage "Who It's For" section is rendered
- **THEN** the Shelter Coordinators card link text SHALL be "Quick Start Guide"
- **AND** the CoC Administrators card link text SHALL be "Admin Overview"
- **AND** the City Officials card link text SHALL be "Evaluation Guide" (existing)
- **AND** the Funders card link text SHALL be "Impact Report"

### Requirement: Audience page consistency with for-cities.html
All audience HTML pages SHALL follow the established pattern from `demo/for-cities.html`.

#### Scenario: Each audience page has required structure
- **WHEN** any audience HTML page is rendered
- **THEN** it SHALL include: FAQ structured data (`application/ld+json`), Open Graph meta tags, canonical URL, dark mode via `prefers-color-scheme`, skip-to-content link, semantic HTML (header/main/footer), and a back link to index.html

#### Scenario: Audience pages pass axe-core accessibility scan
- **WHEN** any audience HTML page is scanned with axe-core
- **THEN** zero Critical or Serious violations SHALL be reported

#### Scenario: Audience pages render correctly in dark mode
- **WHEN** a user's system preference is dark mode
- **THEN** audience pages SHALL render with dark background, light text, and sufficient contrast (WCAG AA)

### Requirement: Audience FOR-*.md docs scope each zero-PII claim
Each of `docs/FOR-COC-ADMINS.md`, `docs/FOR-CITIES.md`, `docs/FOR-DEVELOPERS.md` SHALL include, after every existing "zero PII" or "no client information" claim, a one-sentence scope addendum acknowledging the v0.55 navigator-hold opt-in PII path.

#### Scenario: COC Admins doc scopes its zero-PII claim
- **WHEN** `docs/FOR-COC-ADMINS.md:84` and `:108` are read post-change
- **THEN** each "zero PII" claim SHALL be followed (within the same paragraph or as the next sentence) by a scope statement acknowledging that v0.55 navigator holds may optionally collect client name/DOB/notes, encrypted at rest and purged 24h post-resolution

#### Scenario: Cities doc scopes its zero-PII claim
- **WHEN** `docs/FOR-CITIES.md:108` is read post-change
- **THEN** the existing "zero PII" claim SHALL be followed by the same path-scoping addendum

#### Scenario: Developers doc scopes its zero-PII claim
- **WHEN** `docs/FOR-DEVELOPERS.md:849` is read post-change
- **THEN** the existing "Zero client PII in the database" claim SHALL be followed by the path-scoping addendum

### Requirement: Audience-page acknowledgment of reentry use case
`docs/FOR-CITIES.md` and `docs/FOR-FUNDERS.md` SHALL include at least one sentence acknowledging reentry / justice-system-adjacent populations as a distinct use case the platform supports.

#### Scenario: Cities doc mentions reentry use case
- **WHEN** `docs/FOR-CITIES.md` is read post-change
- **THEN** at least one sentence SHALL reference the reentry use case
- **AND** the sentence SHALL NOT name a specific real city, real CoC, or real reentry program

#### Scenario: Funders doc mentions reentry use case
- **WHEN** `docs/FOR-FUNDERS.md` is read post-change
- **THEN** at least one sentence SHALL reference reentry as a distinct use case
- **AND** the sentence SHALL NOT name a specific real city, real CoC, or real reentry program

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
