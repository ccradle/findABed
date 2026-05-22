## story-landing-page

GitHub Pages index as a story-first entry point with audience routing.

### Requirements

- REQ-STORY-1: The landing page MUST lead with the parking lot story in the first viewport (above the fold)
- REQ-STORY-2: "No more midnight phone calls" MUST appear as a headline or tagline within the first 3 lines
- REQ-STORY-3: The page MUST include audience routing cards — at minimum: Outreach Workers, Shelter Coordinators, City Officials, Developers
- REQ-STORY-4: Each demo walkthrough page MUST include a narrative sentence before each screenshot section explaining what the user is seeing and why it matters
- REQ-STORY-5: The landing page MUST use the same system font stack as the application (system-ui)
- REQ-STORY-6: The landing page MUST be accessible (WCAG 2.1 AA) — proper heading hierarchy, alt text, keyboard navigable, sufficient contrast
- REQ-STORY-7: A city/CoC adoption page (`for-cities.html`) MUST exist with data ownership, WCAG, security summary, and contact information
- REQ-STORY-8: A `.nojekyll` file MUST exist at the repo root to prevent Jekyll processing
- REQ-STORY-9: All inter-page links MUST use relative paths (never absolute paths starting with `/`) to work correctly on GitHub Pages project sites
- REQ-STORY-10: Every page MUST include Open Graph and Twitter Card meta tags for link preview when shared
- REQ-STORY-11: Every page MUST support dark mode via `prefers-color-scheme` media query
- REQ-STORY-12: A branded `404.html` MUST exist with mission-aligned messaging
- REQ-STORY-13: A `robots.txt` and `sitemap.xml` MUST exist for search engine discoverability
- REQ-STORY-14: All pages MUST be mobile-first responsive (Darius on mid-range Android)

### Requirement: Front-door page scopes PII claims to specific data paths
The root `index.html` (front-door page on findabed.org) SHALL NOT make platform-wide assertions about zero-PII storage when the deployed code optionally collects PII. Any PII-related claim SHALL be scoped to the specific data path it describes (DV referral path) or rephrased to acknowledge the navigator-hold opt-in path.

#### Scenario: No platform-wide "ever" claim about client name storage
- **WHEN** root `index.html` is fetched after v0.55 deploy
- **THEN** the page SHALL NOT contain the literal string "no client name, no address in the system, ever"
- **AND** any zero-PII assertion SHALL be qualified by the path it describes

#### Scenario: DV-specific claim remains intact
- **WHEN** root `index.html` is read
- **THEN** any zero-PII statement specifically about DV referral SHALL be preserved (the DV referral_token model is unchanged at v0.55)
- **AND** the DV-specific claim SHALL appear in proximity to the DV-referral context, not as a platform-wide header statement

### Requirement: "See It Work" grid surfaces the reentry capability
The root `index.html` "See It Work" capability deep-dive grid SHALL include the reentry capability as a tile linking to `demo/reentry-story.html`.

#### Scenario: Five-tile grid post-change
- **WHEN** root `index.html` "See It Work" section is rendered
- **THEN** the grid SHALL contain five tiles: Platform Walkthrough, DV Referral Flow, HMIS Bridge, CoC Analytics, Reentry Story
- **AND** the Reentry Story tile SHALL link to `demo/reentry-story.html`

### Requirement: Root index.html footer surfaces project contact via JS-injected placeholder with noscript fallback

The root landing page `index.html` SHALL include the canonical `<a class="contact-email" href="#" hidden aria-live="polite">` placeholder element within its existing `<footer>` element (the section currently containing the "No more midnight phone calls" tagline), paired with a `<script defer src="/contact.js">` reference and an inline `<noscript>` block carrying the GH-issues fallback link. `aria-live="polite"` ensures screen readers announce the populated text after JS injection.

The link MUST appear above or alongside the tagline so a visitor scrolling to the footer sees both the project framing and the contact path together. The literal email address MUST NOT appear in the git-tracked source of `index.html`. The lead-in copy ("Contact the FABT project team:") uses the canonical project-team voice; if the page has Spanish localization, a Spanish translation key MUST ship in the same PR.

#### Scenario: Placeholder + script-tag + noscript fallback present in root source

- **WHEN** the git-tracked source of `index.html` is inspected
- **THEN** the file contains the `class="contact-email"` placeholder with `aria-live="polite"` within the `<footer>` element
- **AND** the file contains a `<script defer src="/contact.js">` reference
- **AND** the file contains a `<noscript>` block with a `<a href="https://github.com/ccradle/finding-a-bed-tonight/issues">` link adjacent to the placeholder
- **AND** the file does NOT contain any plain-text email address

#### Scenario: Rendered footer contains the populated mailto link (JS enabled)

- **GIVEN** the runtime backend is reachable and returns a non-empty platform email
- **WHEN** a visitor loads `https://findabed.org/` with JS enabled and scrolls to the footer
- **THEN** the rendered footer contains an `<a href="mailto:<platform-email>">` link with visible email text
- **AND** the existing footer tagline "No more midnight phone calls." remains present and unmodified

#### Scenario: JS-disabled visitor sees the GH-issues fallback in the footer

- **GIVEN** a visitor with JavaScript disabled
- **WHEN** they load `https://findabed.org/`
- **THEN** the placeholder remains `hidden`
- **AND** the `<noscript>` block renders the GH-issues link as the visible alternative

#### Scenario: API-failure visitor sees the GH-issues fallback (placeholder swap)

- **GIVEN** the runtime backend is unreachable or returns empty platform email
- **WHEN** a visitor loads `https://findabed.org/` with JS enabled
- **THEN** `/contact.js` swaps the placeholder's `href` to the GH-issues link and renders it as the visible link

#### Scenario: Contact link surrounded by project-team voice

- **WHEN** the root footer is inspected for the copy adjacent to the contact placeholder
- **THEN** the surrounding label refers to the project itself ("Contact the FABT project team:" canonical, or "the project maintainers" acceptable variant)
- **AND** the label does not name any individual maintainer
- **AND** the label does not make a response-time claim

### Requirement: feedback-support-section
The landing page SHALL include a "Feedback & Support" section providing visitors with clear paths to report issues, request features, and ask questions.

#### Scenario: Feedback section visible on landing page
- **WHEN** a visitor views the landing page
- **THEN** a "Feedback & Support" section SHALL be visible
- **AND** it SHALL contain three links: "Report a Problem", "Request a Feature", and "Ask a Question"

#### Scenario: Report a Problem links to issue template
- **WHEN** a visitor clicks "Report a Problem"
- **THEN** a new tab SHALL open to the GitHub `report-a-problem.yml` issue template

#### Scenario: Request a Feature links to feature template
- **WHEN** a visitor clicks "Request a Feature"
- **THEN** a new tab SHALL open to the GitHub `feature-request.yml` issue template

#### Scenario: Ask a Question links to Discussions
- **WHEN** a visitor clicks "Ask a Question"
- **THEN** a new tab SHALL open to the GitHub Discussions Q&A category

#### Scenario: Feedback section accessible in dark mode
- **WHEN** the visitor's OS is set to dark mode
- **THEN** the feedback section SHALL render with adequate contrast per existing dark mode tokens

#### Scenario: Feedback section accessible on mobile
- **WHEN** the visitor views the landing page on a 320px viewport
- **THEN** the feedback section SHALL reflow without horizontal scrolling
- **AND** all links SHALL have minimum 44x44px touch targets
