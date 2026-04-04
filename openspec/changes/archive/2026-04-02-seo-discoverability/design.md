## Context

`findabed.org` launched today with a custom domain behind Cloudflare CDN/WAF. The static site content (9 HTML pages, 55 screenshots) is served from `/var/www/findabed-docs/` on the Oracle VM, with the React SPA catching all other routes via nginx `try_files` fallthrough. The content quality is strong (Simone rates 8.5/10) but Google has zero indexation — the site is invisible to search engines.

The host nginx currently routes: static files first (`try_files $uri $uri/`), then falls through to the React SPA (`@app`). This means requests for `/robots.txt` and `/sitemap.xml` that don't exist as static files get served the SPA's `index.html` — a React login page — which is wrong for search engine crawlers.

## Goals / Non-Goals

**Goals:**
- Make all 9 static pages discoverable by Google within 30 days
- Add proper crawl infrastructure (robots.txt, sitemap.xml, canonical tags)
- Add JSON-LD structured data for rich results and AI Overview citations
- Improve Core Web Vitals with image lazy loading
- Register with Google Search Console and Bing Webmaster Tools

**Non-Goals:**
- Spanish page translations (separate OpenSpec — hreflang tags deferred until translations exist)
- Blog/content marketing strategy (future)
- Google Ad Grants (requires 501(c)(3) status)
- App-side SEO (authenticated SPA doesn't need indexation)
- Video walkthrough creation
- Backlink outreach campaign

## Decisions

### D1: Static files take priority over SPA fallthrough for SEO files

**Decision:** Add explicit nginx `location` blocks for `/robots.txt` and `/sitemap.xml` that serve from the static directory, preventing the SPA fallthrough from intercepting them.

**Rationale:** Googlebot requesting `/robots.txt` currently gets a React SPA login page. This must return a proper robots.txt file. Same for sitemap.xml.

### D2: JSON-LD over microdata or RDFa

**Decision:** Use JSON-LD `<script type="application/ld+json">` for all structured data.

**Rationale:** Google recommends JSON-LD. It's additive (inject into `<head>`, no HTML structure changes), testable with Google's Rich Results Test, and doesn't risk breaking existing markup.

### D3: Conservative robots.txt — allow public pages, block app routes

**Decision:** Allow crawling of all static pages under `/` and `/demo/`. Block `/api/`, `/login`, `/dashboard`, `/admin`, and other SPA routes that serve the React app (which renders a login wall for crawlers).

**Rationale:** Googlebot crawling SPA routes wastes crawl budget and may index login pages or error states. Public static content is the only content worth indexing.

### D4: All changes are static file edits — no app code changes

**Decision:** This change modifies only static HTML files and nginx configuration. No backend or frontend code changes.

**Rationale:** Zero risk to the running application. All changes can be tested locally and deployed via scp/rsync.

## Risks / Trade-offs

**[Risk] Google sandbox delay for new domain** → Mitigation: Expected 1-3 months before organic rankings appear. Structured data and Search Console registration accelerate the process but can't eliminate it. Patience required.

**[Risk] SPA routes still indexed despite robots.txt** → Mitigation: robots.txt is advisory — some crawlers may ignore it. Adding `<meta name="robots" content="noindex">` to the SPA's index.html would be a belt-and-suspenders approach, but that's an app code change (out of scope for this change).

**[Risk] Structured data validation errors** → Mitigation: Test all JSON-LD with Google's Rich Results Test before deploying. Schema.org validation is strict on required fields.
