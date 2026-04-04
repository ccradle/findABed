## ADDED Requirements

### Requirement: robots.txt serves proper crawler directives
A `robots.txt` file SHALL exist at `https://findabed.org/robots.txt` containing User-agent directives that allow crawling of public static pages and block SPA app routes and API endpoints.

#### Scenario: Googlebot reads robots.txt
- **WHEN** Googlebot requests `https://findabed.org/robots.txt`
- **THEN** the response is a valid robots.txt file (not the React SPA index.html) with `User-agent: *`, `Allow: /`, `Disallow: /api/`, `Disallow: /login`, `Disallow: /dashboard`, `Disallow: /admin`, and a `Sitemap:` directive

### Requirement: sitemap.xml lists all public static pages
A `sitemap.xml` file SHALL exist at `https://findabed.org/sitemap.xml` listing all static HTML pages with lastmod dates and priority values.

#### Scenario: Search engine reads sitemap
- **WHEN** a search engine requests `https://findabed.org/sitemap.xml`
- **THEN** the response is valid XML containing `<url>` entries for all 9 static pages (index.html, 404.html, and 7 demo pages) with `<loc>`, `<lastmod>`, and `<priority>` elements

#### Scenario: Sitemap uses findabed.org domain
- **WHEN** the sitemap is parsed
- **THEN** all `<loc>` URLs use `https://findabed.org/` as the base (not `ccradle.github.io`)

### Requirement: nginx serves SEO files before SPA fallthrough
The host nginx configuration SHALL serve `robots.txt` and `sitemap.xml` from the static file directory with explicit `location` blocks that take priority over the SPA fallthrough.

#### Scenario: robots.txt served as text/plain
- **WHEN** any client requests `/robots.txt`
- **THEN** nginx serves the file from `/var/www/findabed-docs/robots.txt` with `Content-Type: text/plain`

#### Scenario: sitemap.xml served as application/xml
- **WHEN** any client requests `/sitemap.xml`
- **THEN** nginx serves the file from `/var/www/findabed-docs/sitemap.xml` with `Content-Type: application/xml`

### Requirement: Site registered with Google Search Console
The `findabed.org` domain SHALL be registered with Google Search Console and the sitemap SHALL be submitted for indexing.

#### Scenario: Search Console verification
- **WHEN** the site owner accesses Google Search Console
- **THEN** `findabed.org` is verified and the sitemap shows submitted pages

### Requirement: Site registered with Bing Webmaster Tools
The `findabed.org` domain SHALL be registered with Bing Webmaster Tools and the sitemap SHALL be submitted.

#### Scenario: Bing verification
- **WHEN** the site owner accesses Bing Webmaster Tools
- **THEN** `findabed.org` is verified and the sitemap shows submitted pages
