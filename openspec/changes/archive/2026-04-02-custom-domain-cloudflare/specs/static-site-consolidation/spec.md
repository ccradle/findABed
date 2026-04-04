## ADDED Requirements

### Requirement: Static site content served from Oracle VM nginx
The GitHub Pages static site content (HTML, CSS, JS, images, screenshots) SHALL be deployed to the Oracle VM and served by the host nginx from a dedicated directory (e.g., `/var/www/findabed-docs/`).

#### Scenario: Static landing page accessible
- **WHEN** a browser navigates to `https://findabed.org/`
- **THEN** the static landing/about page is served with correct styling and images

#### Scenario: Static assets cached by Cloudflare
- **WHEN** a browser requests a static asset (image, CSS, JS)
- **THEN** Cloudflare caches and serves it from its edge CDN on subsequent requests

### Requirement: Host nginx routes traffic between static site and app
The host nginx SHALL route requests to the correct backend:
- Static site content served directly from the filesystem for landing/about pages
- App traffic (React SPA + API) proxied to the container nginx on port 8081

#### Scenario: App routes proxied correctly
- **WHEN** a browser navigates to the app login page
- **THEN** the React SPA is served by the container nginx through the host nginx proxy

#### Scenario: API requests proxied correctly
- **WHEN** the frontend makes a request to `/api/v1/shelters`
- **THEN** the request passes through host nginx → container nginx → backend and returns shelter data

### Requirement: Static site OG meta tags updated
All `og:url` and `og:image` meta tags in the static site HTML files SHALL reference `https://findabed.org/` instead of `https://ccradle.github.io/findABed/`.

#### Scenario: Social sharing preview correct
- **WHEN** the `findabed.org` URL is shared on social media or Slack
- **THEN** the link preview shows the correct title, description, and image from `findabed.org`

### Requirement: Static site path prefix removed
The static site content SHALL be served from the domain root (`/`) without the `/findABed/` path prefix that GitHub Pages requires for project sites. All internal links and asset references SHALL use root-relative paths.

#### Scenario: No path prefix in URLs
- **WHEN** a user browses the static site at `findabed.org`
- **THEN** no URL contains `/findABed/` as a path segment

### Requirement: PWA manifest and service worker function correctly on new domain
The PWA manifest `start_url` and service worker scope SHALL be valid for the new domain. The service worker SHALL register and cache correctly at `https://findabed.org`. Any stale service worker cached under the old `nip.io` domain is orphaned and does not affect the new domain.

#### Scenario: PWA installs from new domain
- **WHEN** a user visits `https://findabed.org` on a supported browser
- **THEN** the PWA manifest loads, the service worker registers, and the app is installable

#### Scenario: Stale nip.io service worker does not interfere
- **WHEN** a user who previously visited the nip.io URL navigates to `https://findabed.org`
- **THEN** a fresh service worker is registered for the new domain (old nip.io SW is scoped to the old origin and does not apply)

### Requirement: GitHub Pages site remains accessible
The existing GitHub Pages site at `ccradle.github.io/findABed/` SHALL remain accessible as-is. No CNAME file is added to the docs repo. The GitHub Pages site serves as a secondary/legacy access point.

#### Scenario: GitHub Pages still works
- **WHEN** a user navigates to `https://ccradle.github.io/findABed/`
- **THEN** the site loads normally (unchanged)
