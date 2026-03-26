## 1. Branch Setup

- [x] 1.1 Create branch `feature/hold-duration-admin-config` from main

## 2. Backend — Default Change

- [x] 2.1 Change `DEFAULT_HOLD_DURATION_MINUTES` from 45 to 90 in `ReservationService.java`
- [x] 2.2 Update `seed-data.sql`: change `"hold_duration_minutes": 45` to `"hold_duration_minutes": 90` in tenant config JSONB

## 3. Admin UI — Hold Duration Config

- [x] 3.1 Add "Reservation Settings" section to Admin panel with hold duration number input
- [x] 3.2 Read current value from tenant config via existing API
- [x] 3.3 Save via GET+merge+PUT on `/api/v1/tenants/{id}/config` (existing endpoint)
- [x] 3.4 Validation: min=5, max=480, step=5
- [x] 3.5 Success confirmation on save (aria-live for accessibility)
- [x] 3.6 Add `data-testid` attributes for Playwright
- [x] 3.7 i18n: add EN/ES strings for hold duration labels

## 4. Outreach Worker UI — Show Configured Duration

- [x] 4.1 Hold success: countdown uses `remainingSeconds` from API — no hardcoded value in frontend
- [x] 4.2 Verify countdown timer uses `remainingSeconds` from API (confirmed — OutreachSearch.tsx line 236)

## 5. Documentation Fixes (Code Repo)

- [x] 5.1 `docs/partial-participation-guide.md`: "45 minutes" → "90 minutes (configurable)"
- [x] 5.2 `docs/schema.dbml`: `hold_duration_minutes: int (default 45)` → `(default 90)`
- [x] 5.3 `docs/runbook.md`: no 45-minute references found — clean
- [x] 5.4 `docs/WCAG-ACR.md`: updated to "default 90 minutes" with accessibility framing
- [x] 5.5 `docs/government-adoption-guide.md`: no 45-minute references — clean
- [x] 5.6 `README.md`: 3 instances updated (API table, glossary, checklist)
- [x] 5.7 `ReservationController.java` Javadoc: "default 45 minutes" → "default 90 minutes"

## 6. Documentation Fixes (Docs Repo)

- [x] 6.1 `demo/index.html`: "45 minutes" → "90 minutes (configurable via Admin UI)"
- [x] 6.2 `fabt-hsds-extension-spec.md`: "default: 2 hours" → "default: 90 minutes, configurable"
- [x] 6.3 `MCP-BRIEFING.md`: removed hold_duration_minutes as API param, clarified tenant config
- [x] 6.4 `PERSONAS.md`: Sandra "45→90"; Dr. Whitfield updated with configurable 180-240 note
- [x] 6.5 `PRE-DEMO-CHECKLIST.md` Tier 3: hospital hold item closed
- [x] 6.6 `docs/theory-of-change.md`: reviewed — "45-120" is workflow time, not hold duration. No change needed.

## 7. Testing

- [x] 7.1 Backend: 236 tests pass with DEFAULT_HOLD_DURATION_MINUTES=90
- [x] 7.2 Backend: getHoldDurationMinutes() reads from tenant config (existing coverage)
- [x] 7.3 Playwright: 114 tests pass (Admin UI, axe-core, virtual SR, observability)
- [x] 7.4 Playwright: axe-core 8/8 pages zero violations with ReservationSettings UI
- [x] 7.5 Karate: 73/73 pass with observability stack

## 8. API Documentation

- [x] 8.1 Update OpenAPI/Swagger annotations on ReservationController — Javadoc updated to "default 90 minutes"
- [x] 8.2 Update AsyncAPI (docs/asyncapi.yaml) — no hold duration refs, events use expires_at timestamp. Clean.
- [x] 8.3 Update demo-activity-seed.sql — hold duration range updated from 10-40 to 20-90 min

## 9. Screenshots and Walkthroughs

- [x] 9.1 Re-capture demo screenshots — "Bed Hold Duration: 90" and "Dev Admin" visible
- [x] 9.2 demo/index.html already updated in Section 6
- [x] 9.3 analyticsindex.html — no hold duration refs, expiry descriptions generic. Clean.

## 10. README Updates

- [x] 10.1 Code repo README: test counts current (236+114+73), prerequisites updated
- [x] 10.2 Update docs repo README — add hold-duration-admin-config to archived changes
- [x] 10.3 Deep review both READMEs for remaining "45" — zero found

## 11. Reviewer Feedback

- [x] 11.1 Observability tab renders correctly with auth — confirmed via DOM inspection + 4/4 Playwright tests pass. Reviewer's blank page was Swagger 401 issue (now fixed).
- [x] 11.2 README: Docker Desktop must be running, chmod +x for macOS/Linux
- [x] 11.3 Swagger 401 FIXED: added /api/v1/swagger-ui/** to web.ignoring() (Lesson 58). Now returns 200 without auth.

## 12. Clean-Room Test

- [x] 12.1 Clone repo to fresh directory from GitHub
- [x] 12.2 Follow README setup steps — found logs dir bug (fixed)
- [x] 12.3 dev-start.sh starts after fix — PostgreSQL, backend, seed, frontend all up
- [x] 12.4 Login works with seed credentials (admin, outreach, cocadmin)
- [x] 12.5 All Admin tabs render — found observability blank page (temperatureF undefined, fixed v0.13.2)
- [x] 12.6 Swagger UI loads without auth (fixed v0.13.1 — web.ignoring Lesson 58)
- [x] 12.7 Bed search, hold verified via Playwright (114 tests pass from clean clone)
- [x] 12.8 Analytics tab shows populated data (364 data points from demo seed)
- [x] 12.9 Playwright 114 pass, Karate 69 pass, Gatling 0% failures from clean clone
- [x] 12.10 Issues found and fixed: logs dir, observability crash, Swagger 401, 19 null-safety fixes

## 13. Regression and PR

- [x] 13.1 Backend: 236 tests, 0 failures
- [x] 13.2 Playwright: 114 tests, 0 failures
- [x] 13.3 Karate: 69/73 (4 need observability stack) + Gatling p99 95ms
- [x] 13.4 Committed and pushed (multiple commits: hold duration, Swagger fix, observability fix, null-safety, home link)
- [x] 13.5 Merged to main (PR #12 + direct commits for post-merge fixes)
- [x] 13.6 Tagged v0.13.1, v0.13.2, v0.13.3
