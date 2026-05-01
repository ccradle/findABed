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
