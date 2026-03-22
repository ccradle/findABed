## ADDED Requirements

### Requirement: automated-screenshot-capture
The system SHALL include a Playwright spec that captures full-page screenshots of all key application views against a running local stack. The spec reuses existing auth fixtures for pre-authenticated navigation.

#### Scenario: All views captured successfully
- **WHEN** `capture-screenshots.spec.ts` runs against a running stack
- **THEN** 11 PNG screenshots are saved to `demo/screenshots/`
- **AND** each screenshot is named with a numbered prefix (01-login.png through 11-jaeger-traces.png)

#### Scenario: Observability views captured when stack includes observability profile
- **WHEN** the stack is running with `--observability`
- **THEN** Grafana dashboard and Jaeger trace screenshots are captured
- **AND** if the observability stack is not running, those captures are skipped gracefully

### Requirement: html-walkthrough
The system SHALL include a static `index.html` that displays all captured screenshots as a browsable walkthrough with numbered cards, captions, and responsive layout. The file has no external dependencies and opens offline in any browser.

#### Scenario: Walkthrough opens offline
- **WHEN** a user opens `demo/index.html` in a browser without a server
- **THEN** all screenshots display with captions in numbered order

#### Scenario: Walkthrough is responsive
- **WHEN** the walkthrough is viewed on mobile or narrow viewport
- **THEN** screenshot cards stack vertically and remain readable

### Requirement: capture-script
The system SHALL include a shell script (`demo/capture.sh`) that verifies the stack is running, executes the Playwright capture, and reports results.

#### Scenario: Capture script succeeds
- **WHEN** `./demo/capture.sh` is run with the stack running
- **THEN** all screenshots are regenerated and the script reports success

#### Scenario: Capture script fails gracefully when stack is down
- **WHEN** `./demo/capture.sh` is run without the stack running
- **THEN** the script reports an error and exits without partial output
