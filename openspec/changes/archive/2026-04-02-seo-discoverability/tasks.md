## 1. SEO Infrastructure

- [x] 1.1 Create `robots.txt` in the docs repo root with proper crawler directives:

```
User-agent: *
Allow: /
Disallow: /api/
Disallow: /login
Disallow: /dashboard
Disallow: /admin
Disallow: /actuator/

Sitemap: https://findabed.org/sitemap.xml
```

- [x] 1.2 Create `sitemap.xml` in the docs repo root with all 10 static pages:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://findabed.org/</loc><lastmod>2026-04-02</lastmod><priority>1.0</priority></url>
  <url><loc>https://findabed.org/demo/</loc><lastmod>2026-04-02</lastmod><priority>0.9</priority></url>
  <url><loc>https://findabed.org/demo/for-cities.html</loc><lastmod>2026-04-02</lastmod><priority>0.8</priority></url>
  <url><loc>https://findabed.org/demo/outreach-one-pager.html</loc><lastmod>2026-04-02</lastmod><priority>0.8</priority></url>
  <url><loc>https://findabed.org/demo/shelter-onboarding.html</loc><lastmod>2026-04-02</lastmod><priority>0.7</priority></url>
  <url><loc>https://findabed.org/demo/dvindex.html</loc><lastmod>2026-04-02</lastmod><priority>0.7</priority></url>
  <url><loc>https://findabed.org/demo/analyticsindex.html</loc><lastmod>2026-04-02</lastmod><priority>0.7</priority></url>
  <url><loc>https://findabed.org/demo/hmisindex.html</loc><lastmod>2026-04-02</lastmod><priority>0.7</priority></url>
</urlset>
```

- [x] 1.3 Deploy `robots.txt` and `sitemap.xml` to Oracle VM:

```bash
scp -i ~/.ssh/fabt-oracle robots.txt sitemap.xml ubuntu@150.136.221.232:/var/www/findabed-docs/
```

- [x] 1.4 Update host nginx to serve robots.txt and sitemap.xml before SPA fallthrough — insert location blocks inside the server block, before the `location /` catch-all:

```bash
ssh -i ~/.ssh/fabt-oracle ubuntu@150.136.221.232 "sudo sed -i '/location \/ {/i\    # SEO files — serve before SPA fallthrough\n    location = /robots.txt {\n        root /var/www/findabed-docs;\n        default_type text/plain;\n    }\n    location = /sitemap.xml {\n        root /var/www/findabed-docs;\n        default_type application/xml;\n    }\n' /etc/nginx/sites-available/fabt"

# Verify config is valid before reloading
ssh -i ~/.ssh/fabt-oracle ubuntu@150.136.221.232 "sudo nginx -t"
# If test fails: restore backup with sudo cp /etc/nginx/sites-available/fabt.bak /etc/nginx/sites-available/fabt
```

- [x] 1.5 Verify robots.txt and sitemap.xml serve correctly:

```bash
curl -s https://findabed.org/robots.txt | head -5
# Expected: User-agent: * (NOT React SPA HTML)

curl -s https://findabed.org/sitemap.xml | head -3
# Expected: <?xml version="1.0" (NOT React SPA HTML)
```

- [x] 1.6 Register findabed.org with Google Search Console (manual — browser):
  1. Go to https://search.google.com/search-console
  2. Add property → Domain → `findabed.org`
  3. Verify via DNS TXT record (add via Cloudflare API or dashboard)
  4. Submit sitemap: Sitemaps → enter `sitemap.xml` → Submit

- [x] 1.7 Register findabed.org with Bing Webmaster Tools (manual — browser):
  1. Go to https://www.bing.com/webmasters
  2. Add site → `findabed.org`
  3. Verify via DNS or meta tag
  4. Submit sitemap

## 2. Structured Data (JSON-LD)

- [x] 2.1 Add Organization + SoftwareApplication JSON-LD to `index.html` — insert in `<head>` before `</head>`:

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Finding A Bed Tonight",
  "url": "https://findabed.org",
  "logo": "https://findabed.org/favicon.svg",
  "description": "Open-source emergency shelter bed availability platform for Continuums of Care",
  "sameAs": [
    "https://github.com/ccradle/finding-a-bed-tonight",
    "https://github.com/ccradle/findABed"
  ]
}
</script>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Finding A Bed Tonight",
  "applicationCategory": "WebApplication",
  "operatingSystem": "All",
  "description": "Real-time emergency shelter bed availability with soft-hold reservations, DV privacy enforcement, and HUD reporting",
  "license": "https://opensource.org/licenses/Apache-2.0",
  "url": "https://findabed.org",
  "downloadUrl": "https://github.com/ccradle/finding-a-bed-tonight",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD"
  }
}
</script>
```

- [x] 2.2 Add FAQPage JSON-LD to `demo/for-cities.html` — extract the 6 H2 questions and their answer text into FAQ schema. Insert in `<head>`.

- [x] 2.3 Add HowTo JSON-LD to `demo/shelter-onboarding.html` — map the 3 acts (Import, Correct, Protect) as steps with descriptions and images. Insert in `<head>`.

- [x] 2.4 Validate all JSON-LD with Google's Rich Results Test:

```
https://search.google.com/test/rich-results
```

Test each page URL. For the landing page, verify both Organization AND SoftwareApplication types are detected. Fix any errors before deploying.

## 3. On-Page SEO

- [x] 3.1 Add `<meta name="description">` to `demo/for-cities.html` `<head>`:

```html
<meta name="description" content="Finding A Bed Tonight for city officials: data ownership, WCAG 2.1 AA accessibility, security posture, Apache 2.0 licensing, and procurement guidance.">
```

- [x] 3.2 Verify/update `<meta name="description">` in `demo/outreach-one-pager.html` `<head>` — the audit found it exists but at 87 chars. Expand to 130-160 chars:

```html
<meta name="description" content="One-page overview of Finding A Bed Tonight for outreach workers and shelter coordinators. Real-time bed search, 3-tap holds, offline resilience, DV privacy.">
```

- [x] 3.3 Add `<link rel="canonical">` to all 9 static HTML pages — each points to its own findabed.org URL. Example for index.html:

```html
<link rel="canonical" href="https://findabed.org/">
```

- [x] 3.4 Add `loading="lazy"` and `width`/`height` attributes to all 44 images across demo pages. Determine actual dimensions from the screenshot files:

```bash
# Get dimensions for all screenshots
ssh -i ~/.ssh/fabt-oracle ubuntu@150.136.221.232 'for f in /var/www/findabed-docs/demo/screenshots/*.png; do echo "$(basename $f): $(identify -format "%wx%h" "$f" 2>/dev/null || file "$f" | grep -oP "\d+x\d+")"; done'
```

Add to each `<img>` tag: `loading="lazy" width="X" height="Y"`

- [x] 3.5 Add for-cities.html link to root `index.html` persona card section ("Who It's For"). Add a 5th card for city officials:

```html
<div class="card">
  <span class="card-role">🏛️ City Officials</span>
  <p>Data ownership, WCAG accessibility, security posture, procurement path.</p>
  <a href="demo/for-cities.html">Evaluation Guide →</a>
</div>
```

- [x] 3.6 Verify outreach one-pager URL references — confirm all `ccradle.github.io` references were already replaced in the domain migration change. If any remain, fix them.

## 4. Deploy & Verify

- [x] 4.1 Prepare updated static site locally — all HTML modifications from tasks 2.1–3.6 applied to the build directory

- [x] 4.2 Deploy updated static site to Oracle VM:

```bash
scp -i ~/.ssh/fabt-oracle -r /tmp/findabed-static-build/* ubuntu@150.136.221.232:/var/www/findabed-docs/
```

- [x] 4.3 Reload nginx if config was modified:

```bash
ssh -i ~/.ssh/fabt-oracle ubuntu@150.136.221.232 "sudo nginx -t && sudo systemctl reload nginx"
```

- [x] 4.4 Verify all pages load correctly after changes:

```bash
for page in "/" "/demo/" "/demo/for-cities.html" "/demo/outreach-one-pager.html" "/demo/shelter-onboarding.html" "/demo/dvindex.html" "/demo/analyticsindex.html" "/demo/hmisindex.html"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "https://findabed.org$page")
  echo "$page: $code"
done
```

- [x] 4.5 Verify structured data on deployed pages — use Google Rich Results Test on:
  - `https://findabed.org/` (Organization + SoftwareApplication)
  - `https://findabed.org/demo/for-cities.html` (FAQPage)
  - `https://findabed.org/demo/shelter-onboarding.html` (HowTo)

- [x] 4.6 Verify robots.txt and sitemap.xml serve correctly through Cloudflare:

```bash
curl -s https://findabed.org/robots.txt | grep "User-agent"
curl -s https://findabed.org/sitemap.xml | grep "<urlset"
```

- [x] 4.7 Submit sitemap in Google Search Console (after task 1.6 verification is complete)
- [x] 4.8 Run Lighthouse audit on landing page — check SEO score:

```bash
# Or use Chrome DevTools → Lighthouse → SEO category
# Target: 90+ SEO score
```
