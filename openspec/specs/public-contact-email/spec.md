## public-contact-email

Static-site contact surface: every public-facing HTML page on findabed.org carries a JS-injected `mailto:` link populated at runtime from `/api/v1/public/contact-info`, with a hardcoded `<noscript>` GH-issues fallback for non-JS visitors and an API-failure fallback to the same GH-issues link. The literal email address never appears in git-tracked HTML.

### Requirements

### Requirement: Static-site footer surfaces project contact via JS-injected mailto

Every static HTML page served from findabed.org SHALL include a placeholder `<a class="contact-email" href="#" hidden aria-live="polite">` element in its footer markup, paired with a `<script defer src="/contact.js">` reference. The shared `/contact.js` fetches `GET /api/v1/public/contact-info`, populates the link's `href` to `mailto:<email>`, sets the visible text to the email address, and removes the `hidden` attribute. `aria-live="polite"` ensures screen readers announce the populated text after JS injection (see `feedback_no_named_stakeholders_in_docs` posture: announcing the email itself is acceptable; announcing a real maintainer name would not be).

The literal email address MUST NOT appear in the git-tracked HTML source.

The set of in-scope pages MUST include the root `index.html`, all `demo/*.html` files, and `404.html`. Future audience pages added to the static site MUST follow the same pattern.

#### Scenario: Placeholder element is present in source markup

- **WHEN** the git-tracked source of any in-scope HTML page is inspected
- **THEN** the file contains the placeholder element matching `<a class="contact-email" href="#" hidden aria-live="polite">` (or equivalent attributes) within the page footer
- **AND** the file contains a `<script defer src="/contact.js">` reference
- **AND** the file does NOT contain the literal contact email address

#### Scenario: Page rendered with JS injects the live mailto link

- **GIVEN** the runtime backend is reachable and `/api/v1/public/contact-info` returns a non-empty platform email
- **WHEN** a browser loads any in-scope page and executes `/contact.js`
- **THEN** the placeholder element's `href` becomes `mailto:<email>`
- **AND** the visible link text is the email address
- **AND** the `hidden` attribute is removed
- **AND** the `aria-live="polite"` attribute remains, so screen readers announce the late-injected text

#### Scenario: Page loaded by a JS-less bot reveals no email

- **GIVEN** a request hits findabed.org with a User-Agent that does not execute JavaScript
- **WHEN** the response body is inspected
- **THEN** the body contains the placeholder element with `href="#"` and `hidden` still set
- **AND** the body does NOT contain any plain-text email address

### Requirement: noscript fallback offers a non-JS alternative path

Adjacent to every contact placeholder, an inline `<noscript>` block MUST render an alternate path so visitors with JavaScript disabled (and screen-reader users on no-JS configurations) still have a working contact channel. The fallback is a link to the project's GitHub Issues page, which is already public and unauthenticated. The `<noscript>` markup MUST be hardcoded in source — it does not depend on any runtime fetch.

#### Scenario: noscript block renders a GH-issues link

- **GIVEN** any in-scope HTML page
- **WHEN** the markup is inspected
- **THEN** adjacent to the contact placeholder there is a `<noscript>` block containing an `<a href="https://github.com/ccradle/finding-a-bed-tonight/issues">` link with localized "Contact via GitHub Issues" copy
- **AND** the `<noscript>` block is visible only when JS is disabled (the browser's native noscript handling)

#### Scenario: JS-disabled visitor sees the GH-issues fallback

- **GIVEN** a visitor with JavaScript disabled in their browser
- **WHEN** they load any in-scope page
- **THEN** the contact placeholder is `hidden` (no JS to un-hide it)
- **AND** the `<noscript>` block renders the GH-issues link as the visible alternative
- **AND** automated test coverage exercises this path via `page.context().setJavaScriptEnabled(false)` in Playwright

### Requirement: API-failure fallback replaces placeholder with GH-issues link

When `/contact.js` runs but the `/api/v1/public/contact-info` fetch fails (network error, non-2xx status, malformed JSON, or empty platform email), the script MUST replace the placeholder with the same GH-issues fallback link rendered in the `<noscript>` block — not leave it `hidden`. This ensures visitors always have a working contact path regardless of backend availability, JS engine, or operator misconfiguration.

#### Scenario: Backend unreachable → GH-issues fallback rendered

- **GIVEN** `/api/v1/public/contact-info` returns a 5xx, network error, or unparseable response
- **WHEN** a browser loads any in-scope page and executes `/contact.js`
- **THEN** the placeholder is replaced (its `href`, text, and `hidden` attribute are updated) to render the GH-issues fallback link
- **AND** no broken `mailto:#` is exposed to the visitor

#### Scenario: Empty platform email → GH-issues fallback rendered

- **GIVEN** `/api/v1/public/contact-info` returns `{platform: {email: ""}, tenant: null}` (operator forgot to set the env var)
- **WHEN** a browser loads any in-scope page and executes `/contact.js`
- **THEN** the placeholder renders the GH-issues fallback link

### Requirement: Footer lead-in copy localized day-one for any page with Spanish

For each in-scope HTML page that already carries Spanish localization (a non-empty Spanish key set or a paired Spanish locale page in the static-content tree), the footer lead-in copy adjacent to the contact placeholder ("Contact the project team:" or equivalent) MUST ship a Spanish translation in the same PR — no English-only fallback in the Spanish locale. Pages without existing Spanish localization remain English-only with a `feedback_demotier_alert_traffic_floor`-style follow-up note (NOT in scope to retrofit Spanish to those pages here).

#### Scenario: Spanish-localized page renders Spanish lead-in copy

- **GIVEN** an in-scope HTML page with existing Spanish localization
- **WHEN** the page is loaded in the Spanish locale
- **THEN** the footer lead-in copy adjacent to the contact placeholder renders in Spanish
- **AND** no English text appears in that copy block

### Requirement: No response-time or operational SLA claim accompanies the contact link

The static site MUST NOT publish any response-time or service-level claim adjacent to the contact link (e.g., "we reply within 24 hours", "always", "every inquiry"). The link is presented as a working contact channel without any verifiable-but-unverified promise. Future additions of response-time copy require a separate change with operational signal backing the claim.

#### Scenario: No response-time copy in initial rollout

- **WHEN** the static pages are inspected for any string matching `/24[ -]?hours?|reply within|respond within|we['']?ll get back|always reply|guarantee/i` adjacent to the contact placeholder
- **THEN** zero matches are found

### Requirement: Project-team voice on contact surfaces

Copy adjacent to the contact placeholder MUST refer to the project as "the FABT project team" (canonical phrasing) or "the project maintainers" (acceptable variant). The copy MUST NOT name a specific maintainer or a specific real-world organization, partner, or pilot CoC. Pick "the FABT project team" as the default in new copy unless an existing page's voice strongly favors the variant.

#### Scenario: No personal name in contact copy

- **WHEN** the static pages are inspected for first-name + last-name patterns adjacent to the contact placeholder
- **THEN** zero matches against the real-name list per `feedback_no_named_stakeholders_in_docs`

### Requirement: Pre-deploy verification of Cloudflare Email Address Obfuscation

The deploy runbook MUST include a pre-deploy verification step that confirms Cloudflare Scrape Shield → Email Address Obfuscation is enabled on the `findabed.org` zone. The JS-injection pattern (above) is the primary defense; Cloudflare obfuscation is a defense-in-depth layer and not a sole reliance. The runbook step exists so an accidental Cloudflare-dashboard toggle does not silently degrade the secondary defense without operator awareness.

#### Scenario: Pre-deploy verification

- **WHEN** an operator prepares a static-content deploy that touches the contact placeholder or `/contact.js`
- **THEN** the operator confirms the Cloudflare dashboard setting is `On`
- **AND** records the confirmation in the deploy log

### Requirement: CI guard prevents drift in placeholder + script-tag + noscript-fallback presence

A scripted check SHALL grep across the canonical in-scope static HTML page list and fail if any one of them is missing the placeholder element OR the `/contact.js` script tag OR the `<noscript>` GH-issues fallback. The canonical page list lives alongside the script (not inferred from a glob) so additions to the static site are an explicit operator decision.

#### Scenario: Guard catches a missing placeholder

- **GIVEN** the canonical page list includes `index.html`, every `demo/*.html`, and `404.html`
- **WHEN** any one of those pages does NOT contain `class="contact-email"` AND a `/contact.js` script reference AND a `<noscript>` block with a GH-issues link
- **THEN** the CI guard exits with a non-zero status
- **AND** the failure message names the offending file and which marker is missing

#### Scenario: Guard catches the literal email address being checked in

- **WHEN** any in-scope HTML file contains a string matching `/[A-Za-z0-9._%+-]+@findabed\.org/`
- **THEN** the CI guard exits with a non-zero status
- **AND** the failure message names the offending file and instructs the operator to remove the literal address
