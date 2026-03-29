## Tasks

### Setup

- [x] T-0: Create branch `feature/admin-user-management` in code repo (`finding-a-bed-tonight`)

### Backend — Database (Flyway range: V28–V29)

- [x] T-1: Flyway V28: add `status VARCHAR DEFAULT 'ACTIVE'` and `token_version INTEGER DEFAULT 0` to `app_user`
- [x] T-2: Flyway V29: create `audit_events` table (id UUID, timestamp TIMESTAMPTZ, actor_user_id UUID, target_user_id UUID, action VARCHAR, details JSONB, ip_address VARCHAR)
- [x] T-3: Update `User.java` domain entity with `status`, `tokenVersion` fields

### Backend — JWT Token Versioning

- [x] T-4: `JwtService.generateAccessToken()` — embed `ver` claim from user.getTokenVersion()
- [x] T-5: `JwtService.JwtClaims` — add `tokenVersion` field, parse from `ver` claim
- [x] T-6: `JwtAuthenticationFilter` — after password check, compare `claims.tokenVersion()` against `user.getTokenVersion()`. Mismatch = reject (same pattern as passwordChangedAt)

### Backend — User Edit & Deactivation

- [x] T-7: `UserService.updateUser()` — edit name, email, roles, dvAccess. Increment tokenVersion on role or dvAccess change. (Refactored: extracted UserService from controller — was tech debt)
- [x] T-8: `UserService.deactivateUser()` — set status=DEACTIVATED, increment tokenVersion
- [x] T-9: `UserService.reactivateUser()` — set status=ACTIVE, increment tokenVersion
- [x] T-10: `AuthController.login()` — reject login if user.status == DEACTIVATED with clear message
- [x] T-11: `UserController` — PUT /api/v1/users/{id} for edit, PATCH /api/v1/users/{id}/status for deactivate/reactivate
- [x] T-12: On deactivation, call `NotificationService.completeEmitter(userId)` to disconnect SSE

### Backend — Audit Trail

- [x] T-13: Create `AuditEventEntity`, `AuditEventRepository`, `AuditEventService` with `@EventListener` persistence in shared.audit package
- [x] T-14: Publish audit events from UserService on: role change, dvAccess change, deactivation, reactivation
- [x] T-15: GET /api/v1/audit-events?targetUserId={id} endpoint (COC_ADMIN+) with SecurityConfig rule

### Backend — Tests

- [x] T-16: Integration test: edit user roles, verify tokenVersion incremented
- [x] T-17: Integration test: deactivate user, verify login rejected with 401
- [x] T-18: Integration test: deactivated user's JWT rejected (stale tokenVersion)
- [x] T-19: Integration test: audit events persisted on role change, deactivation
- [x] T-20: Integration test: reactivate user, verify login works again

### Frontend — User Edit Drawer

- [x] T-21: Create `UserEditDrawer.tsx` — slide-out panel with fields: display name, email, roles (multi-select), dvAccess toggle, status badge, deactivate/reactivate with confirmation dialog
- [x] T-22: Add "Edit" button to each user row in AdminPanel Users tab
- [x] T-23: Add "Deactivate"/"Reactivate" button with confirmation dialog (in drawer)
- [x] T-24: On save, call PUT /api/v1/users/{id}. On deactivate/reactivate, call PATCH /api/v1/users/{id}/status
- [x] T-25: Show status badge (Active/Deactivated) on user rows
- [x] T-26: Add i18n keys for user management (en.json + es.json) — 11 keys each

### Frontend — Tests

- [x] T-27: Playwright: open user edit drawer, change role, save, verify
- [x] T-28: Playwright: deactivate user, confirm dialog, verify status badge
- [x] T-29: Playwright: reactivate deactivated user (combined in user-management.spec.ts — 7 tests)

### Frontend — Lint Check

- [x] T-29a: Run `npm run lint` + `npx tsc --noEmit` — clean, no errors

### Seed Data & Screenshots

- [x] T-30: Add deactivated user to seed data (former@dev.fabt.org, DEACTIVATED status)
- [x] T-31: Screenshots captured with notification bell + status badges visible in admin view

### Docs-as-Code — DBML, AsyncAPI, OpenAPI, ArchUnit

- [x] T-32: Update `docs/schema.dbml` — add `status`, `token_version`, `password_changed_at` to app_user, add `audit_events` table
- [x] T-33: Update `docs/asyncapi.yaml` — add UserLifecyclePayload schema for user lifecycle events
- [x] T-34: `@Operation` annotations on all 5 UserController endpoints + AuditEventController
- [x] T-35: Add ArchUnit boundary rule for `notification` module (22 rules total, all passing)
- [x] T-36: Fix ArchUnit violations: moved AuditEventRecord to shared.audit (no auth dependency), AuditEventController to shared.audit.api, AuditEventRepository to shared.audit.repository

### Documentation

- [x] T-37: Update FOR-DEVELOPERS.md — API reference (user edit, deactivate/reactivate, audit events endpoint)
- [x] T-38: Update runbook — user deactivation procedure, reactivation, JWT invalidation troubleshooting

### Verification

- [x] T-39: Run full backend test suite — 278 tests, all green (22 ArchUnit rules)
- [x] T-40: Run full Playwright test suite — 150 passed, 2 skipped, 0 failures
- [x] T-41: ESLint + TypeScript clean
- [x] T-42: CI green on all jobs
- [x] T-43: Merge to main, tag v0.19.0, GitHub release
