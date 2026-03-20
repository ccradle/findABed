## ADDED Requirements

### Requirement: pwa-installable
The system SHALL serve a Progressive Web App that is installable on mobile and desktop devices.

#### Scenario: PWA install prompt
- **WHEN** a user visits the application in a supported browser
- **THEN** the browser offers an "Add to Home Screen" / install prompt
- **AND** the installed app opens in standalone mode without browser chrome

#### Scenario: Service worker registration
- **WHEN** the application loads for the first time
- **THEN** a Workbox-managed service worker registers and precaches the app shell (HTML, CSS, JS, icons)

### Requirement: login-page
The system SHALL present a login page with username/password and tenant-configured OAuth2 provider buttons.

#### Scenario: Login page with OAuth2 providers
- **WHEN** a user navigates to the login page for a tenant that has Google and Microsoft OAuth2 configured
- **THEN** the page displays a username/password form AND "Login with Google" and "Login with Microsoft" buttons

#### Scenario: Login page without OAuth2 providers
- **WHEN** a user navigates to the login page for a tenant with no OAuth2 providers configured
- **THEN** the page displays only the username/password form

#### Scenario: OAuth2 login error displayed
- **WHEN** a user attempts OAuth2 login but their email does not match a pre-created account
- **THEN** the login page displays: "No account found for this email. Contact your CoC administrator to be added."

### Requirement: role-gated-routing
The system SHALL route users to role-appropriate interfaces based on their authenticated roles.

#### Scenario: Coordinator sees coordinator interface
- **WHEN** a user with COORDINATOR role logs in
- **THEN** the system routes to `/coordinator` showing shelter profile and bed update interface

#### Scenario: Outreach worker sees search interface
- **WHEN** a user with OUTREACH_WORKER role logs in
- **THEN** the system routes to `/outreach` showing shelter search and filter interface

#### Scenario: CoC admin sees admin dashboard
- **WHEN** a user with COC_ADMIN role logs in
- **THEN** the system routes to `/admin` showing tenant management, user management, and surge controls

#### Scenario: Unauthorized route access
- **WHEN** a coordinator navigates to `/admin`
- **THEN** the system redirects to the coordinator's default route
- **AND** no admin content is rendered or fetched

### Requirement: offline-foundation
The system SHALL provide offline support infrastructure for outreach workers using IndexedDB and service worker caching.

#### Scenario: App shell available offline
- **WHEN** an outreach worker opens the app without network connectivity
- **THEN** the app shell loads from the service worker cache
- **AND** previously cached shelter data is displayed with a visible "offline" indicator

#### Scenario: Offline action queue
- **WHEN** an outreach worker performs an action (e.g., shelter search) while offline
- **THEN** the action is queued in IndexedDB with a timestamp
- **AND** the UI shows the action as "pending sync"

#### Scenario: Online sync and reconciliation
- **WHEN** network connectivity is restored
- **THEN** the system replays queued actions in order
- **AND** for each action, if the server returns a conflict (e.g., data has changed since cached), the UI notifies the outreach worker with the conflict reason

#### Scenario: Data age visible
- **WHEN** cached data is displayed
- **THEN** the UI shows the age of the data (e.g., "Updated 5 minutes ago") prominently near the data

### Requirement: i18n-support
The system SHALL support internationalization in both the frontend and backend from day one.

#### Scenario: Frontend locale switching
- **WHEN** a user selects a different locale from the language selector
- **THEN** all UI text (labels, messages, errors) switches to the selected language without page reload

#### Scenario: Default locale
- **WHEN** no locale preference is set
- **THEN** the system uses the browser's preferred language if a translation exists, otherwise falls back to English (en)

#### Scenario: Backend error messages localized
- **WHEN** the backend returns a validation error and the request includes `Accept-Language: es`
- **THEN** the error message is returned in Spanish if a translation exists

#### Scenario: Message catalog structure
- **WHEN** a developer adds a new UI string
- **THEN** they add it to the English catalog (`en.json`) as the source of truth
- **AND** other locale files (`es.json`, etc.) are updated by translators independently

### Requirement: responsive-design
The system SHALL render correctly on devices from 320px (small phone) to 1920px (desktop) width.

#### Scenario: Mobile coordinator experience
- **WHEN** a coordinator accesses the bed update interface on a 375px-wide phone screen
- **THEN** the interface renders with touch-friendly targets (minimum 44x44px) and no horizontal scrolling

#### Scenario: Desktop admin experience
- **WHEN** a CoC admin accesses the admin dashboard on a 1440px desktop
- **THEN** the interface uses the available space with a sidebar navigation and multi-column layout
