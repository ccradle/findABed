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
