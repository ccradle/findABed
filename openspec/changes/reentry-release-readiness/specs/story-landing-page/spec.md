## ADDED Requirements

### Requirement: Front-door page scopes PII claims to specific data paths
The root `index.html` (front-door page on findabed.org) SHALL NOT make platform-wide assertions about zero-PII storage when the deployed code optionally collects PII. Any PII-related claim SHALL be scoped to the specific data path it describes (DV referral path) or rephrased to acknowledge the navigator-hold opt-in path.

#### Scenario: No platform-wide "ever" claim about client name storage
- **WHEN** root `index.html` is fetched after v0.55 deploy
- **THEN** the page SHALL NOT contain the literal string "no client name, no address in the system, ever"
- **AND** any zero-PII assertion SHALL be qualified by the path it describes

#### Scenario: DV-specific claim remains intact
- **WHEN** root `index.html` is read
- **THEN** any zero-PII statement specifically about DV referral SHALL be preserved (the DV referral_token model is unchanged at v0.55)
- **AND** the DV-specific claim SHALL appear in proximity to the DV-referral context, not as a platform-wide header statement

### Requirement: "See It Work" grid surfaces the reentry capability
The root `index.html` "See It Work" capability deep-dive grid SHALL include the reentry capability as a tile linking to `demo/reentry-story.html`.

#### Scenario: Five-tile grid post-change
- **WHEN** root `index.html` "See It Work" section is rendered
- **THEN** the grid SHALL contain five tiles: Platform Walkthrough, DV Referral Flow, HMIS Bridge, CoC Analytics, Reentry Story
- **AND** the Reentry Story tile SHALL link to `demo/reentry-story.html`
