## ADDED Requirements

### Requirement: All static pages have meta descriptions
Every static HTML page SHALL have a unique `<meta name="description" content="...">` tag in the `<head>` with 100–160 characters of compelling, keyword-relevant text.

#### Scenario: Missing descriptions added
- **WHEN** the for-cities.html and outreach-one-pager.html pages are audited
- **THEN** both have `<meta name="description">` tags (currently missing from their HTML `<head>`)

#### Scenario: Descriptions are unique
- **WHEN** all 9 pages are compared
- **THEN** no two pages share the same meta description

### Requirement: All static pages have canonical tags
Every static HTML page SHALL have a `<link rel="canonical" href="https://findabed.org/...">` tag in the `<head>` pointing to its preferred URL.

#### Scenario: Canonical prevents duplicate content
- **WHEN** Googlebot crawls any static page
- **THEN** the canonical tag points to the `https://findabed.org/` version of that page

### Requirement: All demo images use lazy loading
All `<img>` tags in demo pages (44 images across 6 files) SHALL include `loading="lazy"` and explicit `width` and `height` attributes to prevent Cumulative Layout Shift.

#### Scenario: Images below the fold load lazily
- **WHEN** a user loads a demo page
- **THEN** images not in the initial viewport are loaded on scroll (not on page load)

#### Scenario: No layout shift from images
- **WHEN** images load on a demo page
- **THEN** the page does not shift because `width` and `height` reserve space

### Requirement: for-cities.html linked from root landing page
The root `index.html` persona card section ("Who It's For") SHALL include a card linking to `demo/for-cities.html` for the city official audience.

#### Scenario: City officials find their page
- **WHEN** a city IT evaluator visits the landing page
- **THEN** they see a card labeled "City Officials" (or similar) that links directly to `demo/for-cities.html`

### Requirement: outreach-one-pager.html included in sitemap
The `sitemap.xml` SHALL include `demo/outreach-one-pager.html` with appropriate priority.

#### Scenario: One-pager discoverable via sitemap
- **WHEN** Google reads the sitemap
- **THEN** `https://findabed.org/demo/outreach-one-pager.html` is listed as a crawlable URL

### Requirement: Outreach one-pager URL updated to findabed.org
Any reference to `ccradle.github.io/findABed` in the outreach one-pager (link text, QR codes, or URLs) SHALL use `findabed.org` instead.

#### Scenario: Printed one-pager has correct URL
- **WHEN** the outreach one-pager is printed for distribution
- **THEN** all URLs reference `https://findabed.org` (not the GitHub Pages URL)
