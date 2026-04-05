## Context

DemoGuardFilter (v0.28.0) was designed to block destructive operations for public traffic while allowing SSH tunnel traffic through. The original IP-chain check (`isInternalTraffic()`) verifies that all IPs in `remoteAddr` + `X-Forwarded-For` are private. This works in theory but fails in practice — the user confirmed 403 on tunnel traffic.

The root issue is that the IP-chain check depends on subtle nginx header behavior that varies by configuration. A more reliable approach: have container nginx itself declare the traffic source based on whether upstream XFF exists.

**Security model (verified 2026-04-05):**
- Port 8081: bound to `127.0.0.1` only (not internet-accessible)
- Port 8080: bound to `127.0.0.1` only
- iptables: default policy DROP, only 22/80/443 allowed (80/443 Cloudflare IPs only)
- Container nginx `proxy_set_header` always overwrites client-sent headers — forgery impossible

## Goals / Non-Goals

**Goals:**
- Administrator can open SSH tunnel to 8081, login in browser, and perform all admin operations (surge, users, shelters, imports)
- Public traffic through Cloudflare remains blocked by DemoGuard (no change to public behavior)
- SSE connections unaffected
- Full local testing before any VM changes
- Documented backout plan

**Non-Goals:**
- Changing host nginx configuration on the VM
- Changing Cloudflare settings
- Adding new ports or Docker compose changes
- Frontend code changes

## Decisions

### D1: nginx `map` directive based on XFF presence

```nginx
map $http_x_forwarded_for $fabt_traffic_source {
    default  "public";
    ""       "tunnel";
}
```

SSH tunnel traffic arrives at container nginx with NO XFF header (nothing upstream adds one). Public traffic always has XFF from Cloudflare → host nginx. The `map` evaluates at the container nginx level and sets a variable used in `proxy_set_header`.

**Why this works:**
- `proxy_set_header` always **replaces** any client-sent value — the backend sees only what nginx sets
- Port 8081 is localhost-only — no internet path to container nginx without going through host nginx (which adds XFF)
- iptables DROP policy + Cloudflare-only rules = double protection

**Alternative considered:** Separate nginx `server` block on port 8082 for tunnel. Rejected — requires Docker compose change, new port mapping, SSH tunnel target change. More moving parts.

**Alternative considered:** `X-Demo-Admin` header with shared secret. Rejected — requires header injection in browser (difficult for UI testing), secret management, doesn't enable browser-based admin.

### D2: DemoGuardFilter checks header first, IP-chain as fallback

```java
private boolean isInternalTraffic(HttpServletRequest request) {
    // Primary: nginx-set header (reliable, unforgeable)
    if ("tunnel".equals(request.getHeader("X-FABT-Traffic-Source"))) {
        log.info("Demo guard bypassed: tunnel traffic (X-FABT-Traffic-Source=tunnel)");
        return true;
    }
    // Fallback: IP-chain check for port 8080 direct access
    return isPrivateIpChain(request.getRemoteAddr(), request.getHeader("X-Forwarded-For"));
}
```

**Why keep the fallback:** Port 8080 direct access (curl, no nginx) doesn't go through container nginx, so the header won't be set. The IP-chain check handles this path.

### D3: Security documentation in code

Add comments in both `nginx.conf` and `DemoGuardFilter.java` explaining the security model:
- Port 8081 is localhost-only (verified by `ss -tlnp`)
- iptables DROP policy blocks direct access even if binding changes
- `proxy_set_header` replaces client-sent values — forgery impossible
- Host nginx always adds XFF for public traffic — `map` correctly distinguishes

**Why:** Future maintainers need to understand why this is safe before modifying port bindings, firewall rules, or nginx config.

## Risks / Trade-offs

**[Risk] Host nginx reconfigured to NOT add XFF** → Mitigation: If host nginx stops adding XFF, all traffic (public and tunnel) arrives without XFF → map produces "tunnel" → everyone bypasses guard. This would be caught immediately in testing. Document the dependency.

**[Risk] Docker compose changes expose port 8081 to 0.0.0.0** → Mitigation: The `docker-compose.prod.yml` override on the VM controls port binding. Currently `127.0.0.1:8081:80`. If changed to `0.0.0.0:8081:80`, the iptables DROP policy still blocks external access. But document this as a security invariant.

**[Risk] ~15 seconds downtime during deploy** → Mitigation: Both containers (frontend + backend) must restart together. Backend startup is ~15 seconds. Acceptable for a demo site.
