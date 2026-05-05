## ADDED Requirements

### Requirement: Root index.html footer surfaces project contact via JS-injected placeholder with noscript fallback

The root landing page `index.html` SHALL include the canonical `<a class="contact-email" href="#" hidden aria-live="polite">` placeholder element within its existing `<footer>` element (the section currently containing the "No more midnight phone calls" tagline), paired with a `<script defer src="/contact.js">` reference and an inline `<noscript>` block carrying the GH-issues fallback link. `aria-live="polite"` ensures screen readers announce the populated text after JS injection.

The link MUST appear above or alongside the tagline so a visitor scrolling to the footer sees both the project framing and the contact path together. The literal email address MUST NOT appear in the git-tracked source of `index.html`. The lead-in copy ("Contact the FABT project team:") uses the canonical project-team voice; if the page has Spanish localization, a Spanish translation key MUST ship in the same PR.

#### Scenario: Placeholder + script-tag + noscript fallback present in root source

- **WHEN** the git-tracked source of `index.html` is inspected
- **THEN** the file contains the `class="contact-email"` placeholder with `aria-live="polite"` within the `<footer>` element
- **AND** the file contains a `<script defer src="/contact.js">` reference
- **AND** the file contains a `<noscript>` block with a `<a href="https://github.com/ccradle/finding-a-bed-tonight/issues">` link adjacent to the placeholder
- **AND** the file does NOT contain any plain-text email address

#### Scenario: Rendered footer contains the populated mailto link (JS enabled)

- **GIVEN** the runtime backend is reachable and returns a non-empty platform email
- **WHEN** a visitor loads `https://findabed.org/` with JS enabled and scrolls to the footer
- **THEN** the rendered footer contains an `<a href="mailto:<platform-email>">` link with visible email text
- **AND** the existing footer tagline "No more midnight phone calls." remains present and unmodified

#### Scenario: JS-disabled visitor sees the GH-issues fallback in the footer

- **GIVEN** a visitor with JavaScript disabled
- **WHEN** they load `https://findabed.org/`
- **THEN** the placeholder remains `hidden`
- **AND** the `<noscript>` block renders the GH-issues link as the visible alternative

#### Scenario: API-failure visitor sees the GH-issues fallback (placeholder swap)

- **GIVEN** the runtime backend is unreachable or returns empty platform email
- **WHEN** a visitor loads `https://findabed.org/` with JS enabled
- **THEN** `/contact.js` swaps the placeholder's `href` to the GH-issues link and renders it as the visible link

#### Scenario: Contact link surrounded by project-team voice

- **WHEN** the root footer is inspected for the copy adjacent to the contact placeholder
- **THEN** the surrounding label refers to the project itself ("Contact the FABT project team:" canonical, or "the project maintainers" acceptable variant)
- **AND** the label does not name any individual maintainer
- **AND** the label does not make a response-time claim
