## Why

The SSH tunnel admin bypass for the DemoGuard filter doesn't work. Administrators cannot perform admin-level operations (activate surge, create users, edit shelters) through the browser UI when tunneled to the demo site. The DemoGuardFilter's IP-chain check fails because container nginx's `$proxy_add_x_forwarded_for` behavior doesn't produce the expected header values for tunnel traffic.

This matters for demos and presentations — the project lead needs to make live admin changes during presentations to stakeholders (Teresa Nguyen, Priya Anand) and for ongoing demo data maintenance. Currently the only workaround is raw curl commands against port 8080, which has no UI.

## What Changes

### nginx map directive for traffic source detection
- Add `map $http_x_forwarded_for $fabt_traffic_source` to container nginx config (`infra/docker/nginx.conf`)
- Tunnel traffic (no incoming XFF) → header set to "tunnel"
- Public traffic (XFF present from Cloudflare/host nginx) → header set to "public"
- Add `proxy_set_header X-FABT-Traffic-Source $fabt_traffic_source` to all API location blocks

### DemoGuardFilter update
- Check `X-FABT-Traffic-Source: tunnel` header first (set by container nginx, unforgeable)
- Retain existing IP-chain check as fallback for port 8080 direct access
- Add WARN-level logging showing traffic source determination for blocked/bypassed requests

## Capabilities

### Modified Capabilities
- `demo-guard`: Add nginx-based traffic source detection for reliable SSH tunnel bypass

## Impact

**Container nginx** (`infra/docker/nginx.conf`):
- Add `map` directive at http level
- Add `proxy_set_header X-FABT-Traffic-Source` to 3 location blocks

**Backend** (`DemoGuardFilter.java`):
- Update `isInternalTraffic()` to check `X-FABT-Traffic-Source` header first
- Add diagnostic logging showing header value on block/bypass decisions

**No changes to:**
- Host nginx on VM (no SSH config changes)
- Cloudflare settings
- Frontend JavaScript
- Database
- SSE behavior
