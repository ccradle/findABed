# Changelog

All notable changes to Finding A Bed Tonight are documented here.
This is the capability-focused changelog for non-technical audiences.
For technical details (migrations, API changes), see `finding-a-bed-tonight/CHANGELOG.md`.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

*(Nothing yet)*

---

## [v0.16.0] — 2026-03-28 — Password Management

### Added
- Users can now change their own password from any screen — one tap on "Password" in the header opens the form
- CoC administrators and platform administrators can reset any user's password from the Admin panel Users tab
- All existing sessions are invalidated immediately when a password is changed — the user (or anyone with their old credentials) must sign in again
- SSO-only users see a clear message explaining their password is managed by their identity provider
- New passwords must be at least 12 characters (following NIST 800-63B guidance — length over complexity)
- Full Spanish translation of all password management forms

### Security
- Password change and reset endpoints are rate-limited to prevent brute force attacks
- If an outreach worker's phone is lost or stolen, the administrator can reset their credentials in one click and all active sessions end immediately

### Changed
- GitHub Pages demo walkthrough updated with new screenshot showing the Change Password modal
- Admin Users tab screenshot recaptured showing the Reset Password button on each user row
- False claims about pilot deployments removed from funder and sustainability documentation — the platform is not yet deployed in any community

---

## [v0.15.3] — 2026-03-28 — README Restructure

### Added
- The code repository README now routes you to the right page in seconds — separate pages for shelter coordinators, CoC administrators, city officials, developers, and funders
- 90-second pitch briefs for each audience (PITCH-BRIEFS.md)
- Updated screenshots showing "Safety Shelter" labels and refreshed freshness badges

### Fixed
- Population type labels on shelter cards and coordinator dashboard now show human-readable names in both English and Spanish (was showing raw API values like "DV SURVIVOR")
- Security vulnerability in a frontend build dependency resolved

---

## [v0.15.2] — 2026-03-28 — Dignity-Centered Copy

### Changed
- The search filter that previously showed "DV Survivors" now shows "Safety Shelter" — protecting the dignity and safety of people in crisis when the outreach worker's screen is visible to a client
- Freshness badges ("Fresh," "Stale") now translate to Spanish when the language is switched
- The offline banner now reassures users: "your last search is still available"
- Error messages are warmer and more actionable for outreach workers

---

## [v0.15.1] — 2026-03-27 — Typography System

### Added
- The platform now uses a consistent system font across all views and all platforms (Windows, macOS, Linux, Android, iOS)
- Form elements (input fields, buttons, dropdowns) now match the rest of the interface — no more mismatched browser default fonts
- Automated tests verify font consistency and detect regressions

### Changed
- Accessibility Conformance Report updated: text spacing and resize criteria now reference the typography system and automated Playwright verification
- Government adoption guide updated: design token system noted in WCAG posture

### Fixed
- Inconsistent serif vs sans-serif rendering across views has been resolved
- All code quality warnings resolved (zero ESLint errors)

---

## [v0.15.0] — 2026-03-27 — Security Hardening

The platform has undergone a security review and hardening pass before pilot deployment.

### Added
- Login and password reset endpoints are now protected against brute force attacks (rate limiting)
- The platform now returns proper security headers on all responses (required by automated security scans)
- If your organization's single sign-on provider goes down, password-authenticated users continue working without interruption
- An OWASP ZAP security scan has been run against the application with zero high-severity findings (local development environment — infrastructure scanning will be completed on deployed environment)
- Operational runbook updated with rate limiting configuration and SSO outage procedures
- Government adoption guide updated with security scan results and SSO resilience documentation

### Security
- Application startup now validates JWT secret strength — refuses to start with missing, weak, or default development secrets in production
- No error responses expose internal implementation details (stack traces, class names, server version)
- Multi-tenant data isolation verified under concurrent load (100 simultaneous requests)
- DV shelter data isolation verified under concurrent load with connection pool recycling — DV shelter names and IDs never leak to unauthorized users

---

## [v0.14.1] — 2026-03-27 — Reliability + Release Notes

### Added
- Release notes and changelog for all versions (v0.1.0 through v0.14.0)
- README now has a table of contents and a section describing all five Grafana dashboards
- Policy documents (government adoption, hospital privacy, etc.) moved to a more prominent location in README

### Fixed
- Development environment starts and stops reliably — shutdown now completes in ~1 second instead of hanging
- Docker configuration updated for Java 25

---

## [v0.14.0] — 2026-03-26 — Java 25 + Virtual Threads

The platform now runs on Java 25, the latest long-term support release. Virtual threads improve how the system handles many simultaneous users without requiring additional hardware.

### Changed
- Upgraded from Java 21 to Java 25 (latest LTS release)
- Upgraded from Spring Boot 3.4 to 4.0
- Improved concurrency model using virtual threads — better performance under load at the same hardware cost

---

## [v0.13.1] — 2026-03-26 — Hold Duration + Admin Controls

Shelter bed holds now last 90 minutes by default (up from 45), giving outreach workers more time during transportation. Administrators can adjust the hold duration per community.

### Added
- Hold duration is now configurable per community in the Admin panel
- User and community name displayed in the header for easier context switching
- 8 new policy documents for government adoption, hospital privacy, partial participation, and more

### Changed
- Default hold duration increased from 45 to 90 minutes

---

## [v0.13.0] — 2026-03-26 — WCAG 2.1 AA Accessibility

The platform is designed to support WCAG 2.1 Level AA — the accessibility standard adopted under ADA Title II for state and local government web content (DOJ Final Rule, April 2024).

### Added
- Automated accessibility testing blocks any release with violations
- Session timeout warning gives users time to extend their session
- Screen reader support verified with automated virtual screen reader tests
- All charts now have a table view toggle for non-visual access
- Accessibility Conformance Report documenting self-assessed conformance status

### Changed
- All buttons and controls meet 44x44px minimum touch target (outdoor one-handed use)
- Status indicators now include text labels alongside color

---

## [v0.12.0] — 2026-03-25 — CoC Analytics + Search Optimization

Community administrators can now view utilization trends, demand signals, and export data designed to support HUD-required HIC/PIT submissions directly from the platform.

### Added
- Analytics dashboard with utilization trends, demand signals, and shelter performance
- One-click HIC/PIT export in CSV format designed to align with HUD specifications
- Batch job management: scheduling, history, manual trigger
- Unmet demand tracking — the system now logs when searches return no results
- 28 days of demo activity data for realistic dashboard previews
- Grafana CoC Analytics dashboard for operations teams

### Changed
- Bed search is faster (optimized database queries)
- Application errors now logged consistently (22 previously silent failure points fixed)

### Privacy
- DV shelter data is protected in analytics: individual shelter counts are suppressed when fewer than 3 shelters or 5 beds would be identifiable

---

## [v0.11.0] — 2026-03-24 — HMIS Bridge

Shelter availability data can now be automatically sent to your HMIS system on a schedule.

### Added
- Automated push to Clarity, WellSky, or ClientTrack HMIS systems
- Administrators can preview data before sending and view push history
- Grafana dashboard for monitoring HMIS push health

### Privacy
- Domestic violence shelter data is protected — individual shelter occupancy is never sent to HMIS, only aggregated totals across all DV shelters

---

## [v0.10.1] — 2026-03-24 — DV Address Redaction

### Added
- Community administrators can now configure who sees DV shelter addresses
- Four visibility levels: admin + assigned coordinators (default), admin only, all DV-authorized users, or nobody
- Addresses are automatically redacted from API responses based on policy

---

## [v0.10.0] — 2026-03-23 — DV Opaque Referral

A privacy-preserving referral system for domestic violence shelters, designed to support VAWA and FVPSA requirements.

### Added
- Outreach workers can request a referral without knowing the DV shelter's location
- DV shelter staff screen every referral before accepting (human-in-the-loop)
- Shelter address is shared verbally during a phone call — never displayed in the system
- All referral data is permanently deleted within 24 hours
- The system is designed so that no client personally identifiable information is persisted to any data store

---

## [v0.9.0] — 2026-03-22 — OAuth2 Single Sign-On

### Added
- Staff can now sign in using their existing Google, Microsoft, or Keycloak accounts
- SSO providers are configured per community — each community chooses their own identity provider
- SSO buttons appear automatically on the login page

---

## [v0.8.0] — 2026-03-22 — Operational Monitoring

### Added
- Operations dashboard in Grafana with 10 panels (search rate, latency, shelter freshness, DV safety)
- Automated monitors alert on stale shelters, DV data leaks, and freezing-temperature gaps
- Temperature-aware surge detection — warns if temperature drops below threshold with no active surge
- Distributed tracing for investigating slow requests (optional, toggleable per community)

---

## [v0.7.0] — 2026-03-21 — Surge Mode

### Added
- Coordinators can activate surge mode during extreme weather or mass events
- Temporary overflow beds can be reported during surges
- Outreach workers see surge alerts and overflow capacity in search results

---

## [v0.6.0] — 2026-03-21 — Security Hardening

### Added
- Database-level security: restricted role prevents unauthorized data access
- DV shelter data isolation implemented at the database layer via Row Level Security, in addition to application-layer controls
- Automated DV safety check blocks deployments if DV data could leak

---

## [v0.5.0] — 2026-03-21 — Automated Testing

### Added
- Automated UI tests, API tests, and performance tests
- Continuous integration pipeline with quality gates

---

## [v0.3.0] — 2026-03-20 — Bed Reservations

### Added
- Outreach workers can hold a bed while transporting a client
- Countdown timer shows remaining hold time
- Holds automatically expire to prevent stale reservations

---

## [v0.2.0] — 2026-03-20 — Bed Availability

### Added
- Real-time bed availability search with population type and constraint filters
- Data freshness indicators show how recent each shelter's data is
- Coordinators can update their shelter's available bed count

---

## [v0.1.0-foundation] — 2026-03-20 — Platform Foundation

### Added
- Multi-tenant platform with role-based access (admin, CoC admin, coordinator, outreach worker)
- Shelter management with HSDS 3.0 data standard support
- React progressive web app with offline capability
- English and Spanish language support
