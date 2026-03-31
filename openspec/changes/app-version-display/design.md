## Context

Spring Boot's `BuildProperties` bean automatically reads the Maven `pom.xml` version at build time via `spring-boot-maven-plugin`. It's available as `buildProperties.getVersion()` with zero configuration. The `/actuator/info` endpoint already exposes this, but it's behind the management port (9091) and not accessible to the frontend.

## Goals / Non-Goals

**Goals:**
- Version visible on login page without authentication
- Version visible in admin panel for operators
- No manual version string maintenance — sourced from pom.xml automatically

**Non-Goals:**
- Build metadata (commit hash, build timestamp) — keep it simple, just version
- Version negotiation or API versioning — this is display only

## Design

**Backend:**

```java
@RestController
@RequestMapping("/api/v1")
public class VersionController {
    private final BuildProperties buildProperties;

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of("version", buildProperties.getVersion());
    }
}
```

Endpoint is public (add to SecurityConfig's `permitAll` list alongside `/api/v1/auth/**`).

**Frontend:**

Login page: small gray text in footer — `"v0.23.0"`. Fetched once on login page mount via `GET /api/v1/version`.

Admin panel: same version in a footer or header subtitle — `"Finding A Bed Tonight v0.23.0"`.

**Fallback:** If the version endpoint fails (e.g., dev mode without Maven build), show nothing. Don't break the login page over a cosmetic feature.

## Risks

- **Version disclosure:** Intentional. Evaluators and operators need this. A determined attacker can fingerprint the stack anyway via response headers.
- **BuildProperties not available in dev:** When running via `mvn spring-boot:run`, `BuildProperties` may not be populated unless `spring-boot-maven-plugin` runs the `build-info` goal. Add `<goal>build-info</goal>` to the plugin config.
