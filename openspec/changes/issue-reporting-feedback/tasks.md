## 1. i18n Messages

- [ ] 1.1 Add `feedback.reportProblem` ("Report a Problem" / "Reportar un Problema") to `en.json` and `es.json`
- [ ] 1.2 Add `feedback.help` ("Help" / "Ayuda") to `en.json` and `es.json`
- [ ] 1.3 Add `feedback.requestFeature` ("Request a Feature" / "Solicitar una Funcionalidad") to `en.json` and `es.json`
- [ ] 1.4 Add `feedback.askQuestion` ("Ask a Question" / "Hacer una Pregunta") to `en.json` and `es.json`

## 2. Footer "Report a Problem" Link

- [ ] 2.1 Add "Report a Problem" link to the footer in `Layout.tsx`, below the version text
- [ ] 2.2 Construct GitHub issue URL with `template=report-a-problem.yml` and `labels=bug,triage` query params
- [ ] 2.3 Include app version in the URL (from existing `appVersion` state)
- [ ] 2.4 Set `target="_blank"` and `rel="noopener noreferrer"` on the link
- [ ] 2.5 Use `FormattedMessage` with the `feedback.reportProblem` i18n key
- [ ] 2.6 Ensure link meets WCAG: focusable, visible focus indicator, descriptive text

## 3. Mobile Kebab Menu "Help" Item

- [ ] 3.1 Add "Help" menu item to the kebab dropdown in `Layout.tsx`, positioned before "Sign Out"
- [ ] 3.2 Link to GitHub issue template chooser (`/issues/new/choose`)
- [ ] 3.3 Add `data-testid="header-overflow-help"` attribute
- [ ] 3.4 Add `role="menuitem"` and minimum 44px height (matching existing menu items)
- [ ] 3.5 Close kebab menu after tap (matching existing menu item behavior)
- [ ] 3.6 Use `FormattedMessage` with the `feedback.help` i18n key

## 4. Landing Page "Feedback & Support" Section

- [ ] 4.1 Add a "Feedback & Support" section to the landing page HTML (below existing content, above footer)
- [ ] 4.2 Add three links: Report a Problem → `report-a-problem.yml`, Request a Feature → `feature-request.yml`, Ask a Question → Discussions Q&A
- [ ] 4.3 All links open in new tab with `rel="noopener noreferrer"`
- [ ] 4.4 Ensure section works in dark mode (`prefers-color-scheme` media query)
- [ ] 4.5 Ensure section reflows at 320px with 44px minimum touch targets

## 5. Tests

- [ ] 5.1 Playwright test: footer "Report a Problem" link exists on outreach, coordinator, and admin pages
- [ ] 5.2 Playwright test: footer link href contains `report-a-problem.yml` and `target="_blank"`
- [ ] 5.3 Playwright test: footer link includes app version in URL
- [ ] 5.4 Playwright test: mobile kebab menu includes "Help" item with `data-testid="header-overflow-help"`
- [ ] 5.5 Playwright test: Help menu item opens correct URL in new tab
- [ ] 5.6 Playwright test: landing page "Feedback & Support" section has 3 links with correct hrefs
- [ ] 5.7 axe-core scan: verify zero new violations after changes (existing accessibility.spec.ts)
- [ ] 5.8 Run `npm run build` to verify frontend compiles clean

## 6. Documentation

- [ ] 6.1 Add CHANGELOG entry for the feedback links feature
