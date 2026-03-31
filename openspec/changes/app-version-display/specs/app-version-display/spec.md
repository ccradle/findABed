## ADDED Requirements

### Requirement: Public version API endpoint

`GET /api/v1/version` SHALL return the application version from `pom.xml` without requiring authentication.

**Acceptance criteria:**
- Returns `{"version": "X.Y.Z"}` with 200 status
- No authentication required (public endpoint)
- Version matches the Maven artifact version from pom.xml
- Backend integration test verifies endpoint

### Requirement: Version on login page

The login page SHALL display the application version in a footer.

**Acceptance criteria:**
- Version fetched from `/api/v1/version` on page mount
- Displayed as small, unobtrusive text (e.g., "v0.23.0")
- If fetch fails, no version shown (no error displayed)
- Playwright test verifies version is visible on login page

### Requirement: Version in admin panel

The admin panel SHALL display the application version in a footer or header area.

**Acceptance criteria:**
- Same version string as login page
- Visible to all authenticated users in the admin panel
- Playwright test verifies version is visible

### Requirement: BuildProperties Maven configuration

The `spring-boot-maven-plugin` SHALL include the `build-info` goal to ensure `BuildProperties` is populated at build time.

**Acceptance criteria:**
- `pom.xml` includes `<goal>build-info</goal>` in spring-boot-maven-plugin execution
- `BuildProperties` bean is injectable in controllers
- Version reflects the actual pom.xml version at build time
