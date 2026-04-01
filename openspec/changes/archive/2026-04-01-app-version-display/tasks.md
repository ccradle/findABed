## Tasks

- [x] Task 0: Create feature branch — combined into `sprint-2-quick-wins` branch
- [x] Task 1: Add `build-info` goal to `spring-boot-maven-plugin` in `pom.xml`
- [x] Task 2: Create `VersionController.java` with public `GET /api/v1/version` (major.minor only, @ConditionalOnResource)
- [x] Task 3: Add `/api/v1/version` to SecurityConfig `permitAll` list
- [x] Task 4: Backend integration test — verify endpoint returns version or is not auth-gated
- [x] Task 5: Create `00-rate-limit.conf` for nginx with `limit_req_zone` (10r/m, 1m zone)
- [x] Task 6: Add rate-limited `/api/v1/version` location block in `nginx.conf` (burst=5, nodelay, 429 status)
- [x] Task 7: Mount `00-rate-limit.conf` in `docker-compose.dev-nginx.yml` and production Dockerfile
- [x] Task 8: Frontend — fetch version on login page, display in footer (data-testid="app-version")
- [x] Task 9: Frontend — display version in Layout footer (data-testid="app-version")
- [x] Task 10: Playwright test — version visible on login page
- [x] Task 11: Playwright test — version visible in admin panel
- [x] Task 12: Test rate limiting through nginx dev proxy (:8081) — verified: 5 pass then 429s
- [ ] Task 13: Run full test suite, merge, deploy
