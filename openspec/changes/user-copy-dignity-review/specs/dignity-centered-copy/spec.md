## dignity-centered-copy

User-facing labels, badges, and messages reviewed through lived experience and communications lenses.

### Requirements

- REQ-COPY-1: The population type filter MUST display "Safety Shelter" instead of "DV Survivors" or "DV_SURVIVOR" in the outreach search interface
- REQ-COPY-2: The internal enum value `DV_SURVIVOR` MUST remain unchanged — only the display label changes
- REQ-COPY-3: Freshness badges MUST include a plain-text relative time description alongside the status label (e.g., "Fresh · Updated 12 min ago")
- REQ-COPY-4: The offline banner MUST include reassurance that the user's last search is still available
- REQ-COPY-5: All copy changes MUST be implemented through the i18n system (en.json, es.json) — no hardcoded display strings
- REQ-COPY-6: Spanish translations MUST be culturally appropriate, not just literal translations
- REQ-COPY-7: Playwright tests MUST verify the updated labels render correctly in both languages

### Scenarios

```gherkin
Scenario: DV population type shows "Safety Shelter" in search interface
  Given an outreach worker is on the bed search page
  When they open the population type dropdown
  Then "Safety Shelter" appears instead of "DV Survivors"
  And the API request still sends populationType: "DV_SURVIVOR"

Scenario: Client sitting next to outreach worker sees no DV terminology
  Given an outreach worker has a DV survivor client present
  When the worker searches for Safety Shelter beds
  Then no text on the visible screen contains "DV", "domestic violence", or "survivor"

Scenario: Freshness badge shows human-readable age
  Given a shelter's last update was 12 minutes ago
  When the outreach worker views search results
  Then the freshness badge shows "Fresh · Updated 12 min ago" (not just "Fresh")

Scenario: Offline banner reassures user
  Given the outreach worker loses network connectivity
  When the offline banner appears
  Then it reads "You are offline — your last search is still available"

Scenario: Spanish locale shows translated dignity-centered labels
  Given the user has switched to Spanish
  When they view the population type dropdown
  Then "Refugio Seguro" appears instead of "Sobrevivientes de VD"
```
