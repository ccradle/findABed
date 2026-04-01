## Context

Spring Boot's `BuildProperties` bean automatically reads the Maven `pom.xml` version at build time via `spring-boot-maven-plugin`. It's available as `buildProperties.getVersion()` with zero configuration. The `/actuator/info` endpoint already exposes this, but it's behind the management port (9091) and not accessible to the frontend.

OWASP WSTG-INFO-02 flags version disclosure as information leakage. Marcus Webb (pen tester persona) recommends: expose only major.minor, rate-limit the endpoint, and accept the residual risk since the project is open source.

## Goals / Non-Goals

**Goals:**
- Version visible on login page without authentication
- Version visible in admin/coordinator layouts for operators
- No manual version string maintenance — sourced from pom.xml automatically
- Rate-limited at nginx layer to prevent abuse and avoid security scan findings
- Return major.minor only — sufficient for display, reduces fingerprinting value

**Non-Goals:**
- Build metadata (commit hash, build timestamp) — keep it simple
- Version negotiation or API versioning — this is display only
- Application-layer rate limiting — nginx handles this

## Design

**Backend:**

```java
@RestController
@RequestMapping("/api/v1")
@ConditionalOnBean(BuildProperties.class)
public class VersionController {
    private final BuildProperties buildProperties;

    @GetMapping("/version")
    public Map<String, String> version() {
        String full = buildProperties.getVersion();
        // Return major.minor only (e.g., "0.25.0" → "0.25")
        String[] parts = full.split("\\.");
        String display = parts.length >= 2 ? parts[0] + "." + parts[1] : full;
        return Map.of("version", display);
    }
}
```

- `@ConditionalOnBean(BuildProperties.class)` — endpoint doesn't register in dev mode without `build-info` goal, avoiding startup failures
- Endpoint is public (add to SecurityConfig's `permitAll` list alongside `/api/v1/auth/**`)

**Nginx rate limiting:**

```nginx
# Top of nginx.conf (outside server block — requires http context)
# For Docker nginx, this goes inside the server block using limit_req_zone in a separate conf
# or in the http block via a custom nginx.conf template

limit_req_zone $binary_remote_addr zone=public_api:1m rate=10r/m;

# Inside server block:
location = /api/v1/version {
    limit_req zone=public_api burst=5 nodelay;
    proxy_pass http://backend:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Note: `limit_req_zone` must be in the `http` context, not `server`. The current nginx.conf only has a `server` block (Docker nginx includes it inside `http` via `/etc/nginx/conf.d/`). We need a separate file at `/etc/nginx/conf.d/rate-limit.conf` for the zone definition, or use a full nginx.conf template. Simplest approach: add a `rate-limit.conf` that defines the zone, mount it alongside `default.conf`.

**Frontend:**

Login page: small gray text in footer — `"v0.25"`. Fetched once on login page mount via `GET /api/v1/version`.

Admin/coordinator layout: same version in footer — `"Finding A Bed Tonight v0.25"`.

**Fallback:** If the version endpoint fails (dev mode, rate-limited, network issue), show nothing. Don't break the UI over a cosmetic feature.

**Dev testing:** Test through nginx dev proxy (:8081) to verify rate limiting works before deploying to Oracle. Use `docker compose -f docker-compose.yml -f docker-compose.dev-nginx.yml --profile nginx up -d frontend-nginx`.

## Risks

- **Version disclosure:** Intentional, mitigated by major.minor-only and rate limiting. Open-source project — changelog is public anyway.
- **BuildProperties not available in dev:** Handled by `@ConditionalOnBean` — endpoint simply doesn't register.
- **Rate limit zone memory:** 1m zone stores ~16,000 IPs — more than sufficient for demo/pilot scale.
