## Why

`findabed.org` launched today with strong content — narrative-driven landing pages, persona-targeted demo walkthroughs, and 100% image alt text coverage. But Google can't see any of it. The site has zero indexation, no robots.txt, no sitemap, no structured data, and no search console registration. Someone searching "emergency shelter bed availability" or "homeless shelter management software" will never find FABT. For Darius's supervisor evaluating tools, Teresa's IT team researching options, or Priya's foundation scanning the civic tech landscape — discoverability is the difference between FABT existing and FABT being found.

## What Changes

- Create proper `robots.txt` allowing public pages, blocking `/api/` and SPA app routes
- Create `sitemap.xml` with all static pages, deployed to the VM
- Configure nginx to serve robots.txt and sitemap.xml from static directory before SPA fallthrough
- Add `<meta name="description">` to the 2 pages missing them (for-cities, outreach-one-pager HTML `<head>`)
- Add `<link rel="canonical">` tags to all 9 static HTML pages
- Add JSON-LD structured data: Organization + SoftwareApplication on landing page, FAQPage on for-cities.html, HowTo on shelter-onboarding.html
- Add `loading="lazy"` and explicit `width`/`height` to all 44 images across demo pages
- Add for-cities.html link to the persona card grid on root index.html
- Add outreach-one-pager.html to sitemap
- Register findabed.org with Google Search Console and Bing Webmaster Tools
- Update outreach-one-pager QR code / URL from GitHub Pages to findabed.org

## Capabilities

### New Capabilities
- `seo-infrastructure`: robots.txt, sitemap.xml, canonical tags, nginx routing for SEO files, search console registration
- `structured-data`: JSON-LD schema markup (Organization, SoftwareApplication, FAQPage, HowTo) across static pages
- `on-page-seo`: Meta descriptions, image lazy loading, internal linking improvements, keyword optimization

### Modified Capabilities
(none — all changes are to static HTML files and nginx config, not to existing spec'd capabilities)

## Impact

- **Static site HTML (docs repo):** All 9 HTML files modified — meta tags, canonical links, JSON-LD scripts, image attributes
- **Oracle VM nginx:** Host nginx config updated to serve robots.txt and sitemap.xml before SPA fallthrough
- **New files:** robots.txt, sitemap.xml deployed to `/var/www/findabed-docs/`
- **External accounts:** Google Search Console and Bing Webmaster Tools registration (manual)
- **No app code changes** — all modifications are to static HTML and nginx configuration
- **No risk to the running application** — static file additions only
