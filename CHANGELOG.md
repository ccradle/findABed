# Changelog

All notable changes to Finding A Bed Tonight are documented here.
This is the capability-focused changelog for non-technical audiences.
For technical details (migrations, API changes), see `finding-a-bed-tonight/CHANGELOG.md`.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

- Shutdown reliability improvements for development environments
- Fixed stale Docker configuration after Java 25 migration

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

The platform now meets WCAG 2.1 Level AA — the accessibility standard required by the ADA for government web content.

### Added
- Automated accessibility testing blocks any release with violations
- Session timeout warning gives users time to extend their session
- Screen reader support verified with automated virtual screen reader tests
- All charts now have a table view toggle for non-visual access
- Accessibility Conformance Report documenting compliance

### Changed
- All buttons and controls meet 44x44px minimum touch target (outdoor one-handed use)
- Status indicators now include text labels alongside color

---

## [v0.12.0] — 2026-03-25 — CoC Analytics + Search Optimization

Community administrators can now view utilization trends, demand signals, and export HUD-required HIC/PIT reports directly from the platform.

### Added
- Analytics dashboard with utilization trends, demand signals, and shelter performance
- One-click HIC/PIT export in HUD-required CSV format
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
- No client personally identifiable information is stored at any point

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
- DV shelter data isolation enforced at the database layer, not just the application
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
