## ADDED Requirements

### Requirement: Reentry capability deep-dive page exists
A new file `demo/reentry-story.html` SHALL exist as the fifth capability deep-dive in the public demo site, mirroring the structural pattern of `demo/dvindex.html` (capability deep-dive) rather than the audience-card pattern (`demo/for-coordinators.html`, etc.).

#### Scenario: File exists and renders
- **WHEN** `https://findabed.org/demo/reentry-story.html` is fetched post-deploy
- **THEN** the response is 200 with valid HTML
- **AND** the page contains an `<h1>` introducing the reentry-on-release-day story
- **AND** the page contains at least 5 `<h2>` section headings (story open, what the navigator sees, the hold, when the answer is no, what this changes — and what it doesn't)

#### Scenario: Page leads with the person, not the technology
- **WHEN** the first viewport of the page is rendered
- **THEN** the lede paragraph names a synthetic client and a specific time-of-day situation, NOT a feature list or a system diagram
- **AND** the page does not contain the strings "platform" or "system" before the second `<h2>`

#### Scenario: Page includes the failure-path screenshot
- **WHEN** the page's `<img>` tags are enumerated
- **THEN** at least one image SHALL depict a search result where the only county-eligible shelter excludes the relevant offense type (the "the answer is no" moment)
- **AND** the alt text for that image describes what the navigator LEARNS (e.g., "Only shelter in this county excludes the relevant offense type — no match available"), not what the rectangle visually shows

### Requirement: Reentry capture spec exists and produces six screenshots
A new Playwright test file `e2e/playwright/tests/capture-reentry-screenshots.spec.ts` SHALL exist and contain at least six tests, each producing a distinct screenshot for the reentry story page.

#### Scenario: Capture spec file exists
- **WHEN** the e2e directory is listed
- **THEN** `tests/capture-reentry-screenshots.spec.ts` SHALL be present

#### Scenario: Six required screenshots produced
- **WHEN** the capture spec runs against the dev stack with V95 reentry seed loaded and `features.reentryMode=true` for `dev-coc`
- **THEN** at least these six PNG files SHALL be produced in `demo/screenshots/`: `reentry-01-advanced-search-filters.png`, `reentry-02-search-results-filtered.png`, `reentry-03-shelter-detail-eligibility.png`, `reentry-04-hold-dialog-attribution.png`, `reentry-05-admin-reservation-settings.png`, `reentry-06-no-match-failure-path.png`

#### Scenario: Failure-path shot reflects a deliberately-seeded conflict
- **WHEN** `reentry-06` is captured
- **THEN** the screenshot SHALL show a search result with at least one shelter whose `excluded_offense_types` overlaps the navigator's filter intent
- **AND** the V95 (or successor V96) seed SHALL provide such a configuration in `dev-coc-east` or `dev-coc-west`

### Requirement: Reentry story page is reachable from the front door
The root `index.html` "See It Work" grid SHALL include a fifth tile linking to `demo/reentry-story.html`, parallel to the existing tiles for Platform Walkthrough, DV Referral Flow, HMIS Bridge, and CoC Analytics.

#### Scenario: Fifth tile present
- **WHEN** root `index.html` is fetched
- **THEN** the "See It Work" grid SHALL contain exactly five capability deep-dive tiles
- **AND** the fifth tile's link target SHALL be `demo/reentry-story.html`
- **AND** the fifth tile's headline SHALL describe reentry / release-day bed placement in non-clinical, non-system-jargon language

### Requirement: Cross-page links acknowledge the new story
Each of `demo/for-coordinators.html`, `demo/for-cities.html`, `demo/for-funders.html`, and `demo/dvindex.html` SHALL be updated to acknowledge the reentry story page exists and link to it where relevant.

#### Scenario: Coordinator page links to reentry story
- **WHEN** `demo/for-coordinators.html` is read post-change
- **THEN** it SHALL contain at least one paragraph distinguishing the navigator role from the outreach-worker role
- **AND** that paragraph SHALL link to `demo/reentry-story.html`

#### Scenario: City page acknowledges reentry as a use case
- **WHEN** `demo/for-cities.html` is read post-change
- **THEN** it SHALL contain at least one sentence referencing reentry / justice-system-adjacent populations as a use case the platform supports

#### Scenario: Funder page acknowledges reentry as a use case
- **WHEN** `demo/for-funders.html` is read post-change
- **THEN** it SHALL contain at least one sentence referencing reentry as a distinct use case

#### Scenario: DV index footer links reciprocally to reentry story
- **WHEN** `demo/dvindex.html` is read post-change
- **THEN** the footer SHALL contain a "see also" link pointing to `demo/reentry-story.html`

### Requirement: Reentry story page is SEO-discoverable
The new `demo/reentry-story.html` page SHALL be added to `sitemap.xml`, allowed in `robots.txt`, and SHALL include Open Graph + Twitter Card meta tags consistent with the other capability deep-dive pages (`dvindex.html`, `hmisindex.html`, `analyticsindex.html`).

#### Scenario: Sitemap entry exists
- **WHEN** `sitemap.xml` is read post-change
- **THEN** it SHALL contain a `<url>` entry for `demo/reentry-story.html`

#### Scenario: Robots.txt allows the page
- **WHEN** `robots.txt` is read post-change
- **THEN** it SHALL NOT contain a `Disallow:` rule that excludes `demo/reentry-story.html`

#### Scenario: Open Graph + Twitter Card meta tags present
- **WHEN** the rendered HTML `<head>` of `demo/reentry-story.html` is inspected
- **THEN** it SHALL include `og:title`, `og:description`, `og:type` (with `og:image` if any other capability deep-dive includes one), `twitter:card`, `twitter:title`, `twitter:description` meta tags
- **AND** the values SHALL match the page's actual content (no boilerplate inheriting from another deep-dive)

### Requirement: No fictional pilots, partnerships, or named stakeholders
The reentry story page SHALL contain no real city names, real CoC names, real reentry program names, or real organizational partners. All persona names in the story SHALL be synthetic.

#### Scenario: No real-organization references
- **WHEN** the page is grepped for the names of real NC reentry organizations, real cities, or real CoCs
- **THEN** zero matches SHALL be present
- **AND** any North Carolina contextual reference (e.g., the 28% / 5,610 stat) SHALL cite a public source (NC DPS) rather than a private partner
- **AND** any NC-specific statistic SHALL be accompanied by a footnote citing a public-source URL and document title (e.g., NC DPS annual report, with publication year)
- **AND** if the cited statistic cannot be sourced to a public document at edit time, the statistic SHALL NOT appear on the page (per `feedback_truthfulness_above_all`)

#### Scenario: Persona names are synthetic
- **WHEN** the page contains a story about a navigator and a client
- **THEN** the names used SHALL be synthetic and SHALL NOT match the persona names in `PERSONAS.md` (Demetrius is the persona file's archetype; the story page uses different synthetic names)
- **AND** Demetrius's verbatim quote (`PERSONAS.md:398`) MAY be cited but SHALL be attributed anonymously (e.g., "from a North Carolina reentry navigator")
