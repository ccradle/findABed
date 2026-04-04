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
