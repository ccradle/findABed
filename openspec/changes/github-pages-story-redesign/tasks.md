## Tasks

### Setup

- [x] T-0: Working on `main` in docs repo (`findABed`). No code repo changes.

### GitHub Pages Infrastructure

- [ ] T-1: Add `.nojekyll` file to repo root — prevents Jekyll processing of plain HTML
- [ ] T-2: Add `robots.txt` — allow all crawlers, reference sitemap
- [ ] T-3: Add `sitemap.xml` — list all public pages (landing, walkthroughs, one-pager, for-cities, 404)
- [ ] T-4: Add branded `404.html` — mission-aligned messaging with link back to landing page, system font stack, dark mode support

### Landing Page

- [ ] T-5: Design and build root `index.html` — parking lot story hero, "No more midnight phone calls" headline, problem-in-numbers section, solution paragraph, 4 audience routing cards, CTA links, demo walkthrough links. System fonts, dark mode, mobile-first responsive, OG meta tags, WCAG 2.1 AA. Use `frontend-design` skill. (REQ-STORY-1 through REQ-STORY-3, REQ-STORY-5, REQ-STORY-6)

### Demo Walkthrough Enhancement

- [ ] T-6: Add contextual narrative sentences before each screenshot section in `demo/index.html` — "An outreach worker searches for a bed at 11pm..." pattern (REQ-STORY-4)
- [ ] T-7: Add contextual narrative to `demo/dvindex.html`, `demo/hmisindex.html`, `demo/analyticsindex.html`

### Outreach One-Pager

- [ ] T-8: Design and build `demo/outreach-one-pager.html` — printable A4/Letter with `@media print` styles (hide nav, 12pt font, show URLs after links, @page margins). Story-first sections for outreach workers and coordinators, cost, how to get started. Must fit on one printed page. Use `frontend-design` skill. (REQ-PAGER-1 through REQ-PAGER-6)
- [ ] T-9: Test print layout — verify it fits on one page in Chrome print preview

### City Landing Page

- [ ] T-10: Create `demo/for-cities.html` — distilled city adoption page with data ownership, WCAG, security, Apache 2.0, contact info. Dark mode, OG meta tags, responsive. (REQ-STORY-7)

### SEO & Meta Tags

- [ ] T-11: Add Open Graph + Twitter Card meta tags to all new pages (landing, one-pager, for-cities, 404) — verify preview card renders when URL is shared
- [ ] T-12: Add OG meta tags to existing walkthrough pages (demo/index.html, dvindex.html, hmisindex.html, analyticsindex.html)

### Verification

- [ ] T-13: Verify all relative links work — test from both local file:// and deployed GitHub Pages URL
- [ ] T-14: Verify dark mode renders correctly on all new pages (test via browser dev tools)
- [ ] T-15: Verify accessibility — semantic HTML, heading hierarchy, contrast ratios in both light and dark mode, keyboard navigation
- [ ] T-16: Commit and push to docs repo
- [ ] T-17: Verify all pages render correctly on ccradle.github.io/findABed/ after deploy (allow 1-10 min for Pages to update)
