## ADDED Requirements

### Requirement: Landing page has "Try the Demo" section
The root `index.html` SHALL include a "Try the Demo" section with a link to `findabed.org/login`, demo credentials for all 4 roles, and a disclaimer about fictional data.

#### Scenario: Visitor finds demo credentials
- **WHEN** a visitor scrolls the landing page
- **THEN** they see a clearly labeled section with the login URL, tenant slug, email/password for each role, and a disclaimer

#### Scenario: Credentials match working accounts
- **WHEN** a visitor uses the published credentials
- **THEN** they can log in successfully as any of the 4 roles

### Requirement: Demo walkthrough has "Try It Live" call-to-action
The `demo/index.html` walkthrough page SHALL include a "Try It Live" section at the end with a link to the login page and the same credentials.

#### Scenario: Walkthrough ends with live demo CTA
- **WHEN** a visitor finishes reading the demo walkthrough
- **THEN** they see a call-to-action to try the live platform with credentials

### Requirement: Disclaimer warns about fictional data
The demo credentials section SHALL include a clear disclaimer that the environment contains fictional data and visitors should not enter real client, shelter, or location information.

#### Scenario: Disclaimer visible
- **WHEN** a visitor views the demo credentials
- **THEN** a disclaimer is visible: "This is a demonstration environment with fictional shelter and location data. Do not enter real client, shelter, or location information."

### Requirement: Frontend displays friendly toast for demo-restricted responses
When the API returns a response with `{"error": "demo_restricted", ...}`, the React frontend SHALL display a toast/notification with the message text instead of a generic error.

#### Scenario: Admin clicks "Create User" in demo
- **WHEN** a demo visitor clicks the Create User button in the admin panel
- **THEN** the UI displays a toast: "This feature is available in a full deployment. Contact us to set up a pilot."

#### Scenario: Non-demo-restricted errors display normally
- **WHEN** the API returns a non-demo error (e.g., validation error, 401)
- **THEN** the error displays using the existing error handling, not the demo toast

### Requirement: Demo credentials use stable passwords
All 4 demo account passwords SHALL remain `admin123` (or be reset to `admin123` if previously changed). The demo guard blocks password changes, ensuring credentials remain stable for future visitors.

#### Scenario: All published credentials work
- **WHEN** credentials are published for outreach, cocadmin, admin, dv-outreach
- **THEN** all 4 accounts can log in with `admin123`
