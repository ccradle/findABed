## Overview

Redesign GitHub Pages site from a screenshot gallery to a story-first entry point. Create a printable outreach one-pager. All work in the docs repo. Incorporates GitHub Pages best practices for SEO, accessibility, dark mode, and link reliability.

## Design Decisions

### GitHub Pages Infrastructure

Before any content work:
- Add `.nojekyll` file to repo root — prevents Jekyll processing of plain HTML
- Add `robots.txt` with sitemap reference
- Add `sitemap.xml` listing all public pages
- Add branded `404.html` — mission-aligned, not the default GitHub 404
- All filenames lowercase (GitHub Pages runs on Linux, case-sensitive)
- All inter-page links use **relative paths only** — absolute paths starting with `/` resolve to `github.io/`, not `github.io/findABed/`, breaking on project sites

### Landing Page (root `index.html`)

The current root serves the docs repo README. A new `index.html` at the repo root will override it on GitHub Pages (index.html wins over README.md).

Structure:
1. **Hero**: Parking lot story (large text, 3 sentences) + "No more midnight phone calls"
2. **Problem in numbers**: shelters in Wake County, outreach workers, the gap
3. **Solution**: one paragraph, no jargon
4. **Who uses it**: 4 audience cards (Outreach Workers, Coordinators, City Officials, Funders) routing to appropriate pages
5. **Call to action**: View the platform demo → Read the docs → Get in touch
6. **Demo walkthroughs**: links to existing screenshot galleries

Design approach:
- Clean, accessible, system font stack (`system-ui`) matching the app's typography system
- CSS custom properties for theming
- Dark mode via `prefers-color-scheme` (Darius uses his phone at midnight)
- Mobile-first responsive (Darius on mid-range Android)
- Open Graph meta tags on every page (Priya sharing URL shows preview card, not bare link)
- WCAG 2.1 AA: semantic HTML, proper heading hierarchy, 4.5:1 contrast, keyboard navigable, `lang` attribute
- Use the `frontend-design` skill for high-quality output

### Demo Walkthrough Handling

Keep existing `demo/index.html` as the walkthrough page (don't rename — renaming breaks existing shared links with no server-side redirect). The new root `index.html` links to `demo/index.html` for the walkthrough.

Add a narrative sentence before each screenshot section in all walkthrough pages:
- Before search: "An outreach worker searches for a bed at 11pm..."
- Before hold: "One tap holds the bed for 90 minutes — enough time to transport the client safely."
- Before coordinator: "Sandra updates her shelter's bed count in three taps between tasks."

### Outreach One-Pager (`demo/outreach-one-pager.html`)

Printable HTML page — Maria Torres (AI persona, PM) needs this for hallway conversations:
- `@media print` styles: hide nav/footer, 12pt font, show URLs after links, `@page` margins, `page-break-after: avoid` on headings
- Must fit on one printed page (A4/Letter)
- Story-first, not feature-first
- Sections: title, parking lot story, for outreach workers (3 bullets), for coordinators (3 bullets), what it costs, how to get started, contact
- Works both as a web page and printed document

### City Landing Page (`demo/for-cities.html`)

Distilled version of the code repo's `docs/FOR-CITIES.md` with story framing, visual design matching the landing page, and contact link. Teresa Nguyen (AI persona, City Official) should be able to share this URL directly with her city attorney.

### SEO

Every page gets:
```html
<meta property="og:title" content="Page Title" />
<meta property="og:description" content="150-char description" />
<meta property="og:image" content="https://ccradle.github.io/findABed/demo/screenshots/02-bed-search.png" />
<meta property="og:url" content="https://ccradle.github.io/findABed/" />
<meta name="twitter:card" content="summary_large_image" />
```

### Dark Mode

```css
@media (prefers-color-scheme: dark) {
  :root { --bg: #0f172a; --text: #e2e8f0; --accent: #3b82f6; }
}
```
Contrast verified in both modes. Slightly increased font weight in dark mode for readability.

## File Changes

| File | Change |
|------|--------|
| New: `.nojekyll` | Empty file — disables Jekyll processing |
| New: `robots.txt` | Allow all, reference sitemap |
| New: `sitemap.xml` | List all public pages |
| New: `404.html` | Branded 404 page with mission messaging |
| New: `index.html` (repo root) | Story-first landing page with audience routing |
| `demo/index.html` | Add contextual narrative before each screenshot section |
| `demo/dvindex.html` | Add contextual narrative |
| `demo/hmisindex.html` | Add contextual narrative |
| `demo/analyticsindex.html` | Add contextual narrative |
| New: `demo/outreach-one-pager.html` | Printable one-page outreach document |
| New: `demo/for-cities.html` | City/CoC adoption landing page |
