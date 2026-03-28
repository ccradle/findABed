## Tasks

### Setup

- [x] T-0: Working on `main` in docs repo (`findABed`). No code repo changes.

### GitHub Pages Infrastructure

- [x] T-1: .nojekyll created
- [x] T-2: robots.txt created with sitemap reference
- [x] T-3: sitemap.xml created with 7 pages
- [x] T-4: Branded 404.html with dark mode, mission messaging, WCAG accessible

### Landing Page

- [x] T-5: Root index.html — story hero, audience cards, demo links, dark mode, OG tags, mobile responsive — parking lot story hero, "No more midnight phone calls" headline, problem-in-numbers section, solution paragraph, 4 audience routing cards, CTA links, demo walkthrough links. System fonts, dark mode, mobile-first responsive, OG meta tags, WCAG 2.1 AA. Use `frontend-design` skill. (REQ-STORY-1 through REQ-STORY-3, REQ-STORY-5, REQ-STORY-6)

### Demo Walkthrough Enhancement

- [x] T-6: Add contextual narrative sentences before each screenshot section in `demo/index.html` — "An outreach worker searches for a bed at 11pm..." pattern (REQ-STORY-4)
- [x] T-7: Add contextual narrative to `demo/dvindex.html`, `demo/hmisindex.html`, `demo/analyticsindex.html`

### Outreach One-Pager

- [x] T-8: Built `demo/outreach-one-pager.html` — print styles, story-first, DV section, dark mode — printable A4/Letter with `@media print` styles (hide nav, 12pt font, show URLs after links, @page margins). Story-first sections for outreach workers and coordinators, cost, how to get started. Must fit on one printed page. Use `frontend-design` skill. (REQ-PAGER-1 through REQ-PAGER-6)
- [ ] T-9: Test print layout — verify it fits on one page in Chrome print preview (requires manual Chrome print preview)

### City Landing Page

- [x] T-10: Built `demo/for-cities.html` — data ownership, WCAG, security checklist, procurement, dark mode — distilled city adoption page with data ownership, WCAG, security, Apache 2.0, contact info. Dark mode, OG meta tags, responsive. (REQ-STORY-7)

### SEO & Meta Tags

- [x] T-11: Add Open Graph + Twitter Card meta tags to all new pages (landing, one-pager, for-cities, 404) — verify preview card renders when URL is shared
- [x] T-12: Add OG meta tags to existing walkthrough pages (demo/index.html, dvindex.html, hmisindex.html, analyticsindex.html)

### Verification

- [x] T-13: Verify all relative links work — test from both local file:// and deployed GitHub Pages URL
- [x] T-14: Verify dark mode renders correctly on all new pages (test via browser dev tools)
- [x] T-15: Verify accessibility — semantic HTML, heading hierarchy, contrast ratios in both light and dark mode, keyboard navigation
- [ ] T-16: Commit and push to docs repo
- [ ] T-17: Verify all pages render correctly on ccradle.github.io/findABed/ after deploy (allow 1-10 min for Pages to update)
