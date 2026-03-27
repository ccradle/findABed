## typography-playwright-tests

Playwright tests verifying font consistency across views and WCAG text spacing compliance.

### Requirements

- REQ-PW-TYP-1: A Playwright test MUST verify that the computed `font-family` on body text is consistent across login, search, coordinator dashboard, and admin pages
- REQ-PW-TYP-2: A Playwright test MUST verify that no element on any key page renders with a serif `font-family`
- REQ-PW-TYP-3: A Playwright test MUST inject WCAG 1.4.12 text spacing overrides (line-height 1.5x, letter-spacing 0.12em, word-spacing 0.16em) and verify no text is clipped or overflows its container
- REQ-PW-TYP-4: A Playwright test MUST verify that form elements (input, select, button) use the same font-family as body text
- REQ-PW-TYP-5: Tests MUST use `data-testid` locators where available, consistent with the project's existing Playwright conventions

### Scenarios

```gherkin
Scenario: Font consistency across all key views
  Given the user logs in as outreach worker
  When they visit the bed search page, then the coordinator dashboard, then the admin panel
  Then the computed font-family on the main heading of each page is identical
  And none of them contain "serif" (without "sans-" prefix) in the computed value

Scenario: Text spacing override causes no clipping
  Given the user is on the bed search results page with multiple shelters
  When CSS is injected to set line-height: 2, letter-spacing: 0.12em, word-spacing: 0.16em
  Then no shelter card has text overflowing its container
  And all shelter names remain fully visible
  And all availability numbers remain fully visible

Scenario: Form inputs use system font
  Given the user is on the login page
  When the page renders
  Then the email input, password input, and login button all have computed font-family starting with "system-ui" or the platform system font
```
