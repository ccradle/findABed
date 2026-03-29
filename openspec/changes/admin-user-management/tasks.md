## Tasks

### Setup

- [ ] T-0: Create branch `feature/admin-user-management` in code repo (`finding-a-bed-tonight`)

### Backend — Database (Flyway range: V28–V29)

- [ ] T-1: Flyway V28: add `status VARCHAR DEFAULT 'ACTIVE'` and `token_version INTEGER DEFAULT 0` to `app_user`
- [ ] T-2: Flyway V29: create `audit_events` table (id UUID, timestamp TIMESTAMPTZ, actor_user_id UUID, target_user_id UUID, action VARCHAR, details JSONB, ip_address VARCHAR)
- [ ] T-3: Update `User.java` domain entity with `status`, `tokenVersion` fields

### Backend — JWT Token Versioning

- [ ] T-4: `JwtService.generateAccessToken()` — embed `ver` claim from user.getTokenVersion()
- [ ] T-5: `JwtService.JwtClaims` — add `tokenVersion` field, parse from `ver` claim
- [ ] T-6: `JwtAuthenticationFilter` — after password check, compare `claims.tokenVersion()` against `user.getTokenVersion()`. Mismatch = reject (same pattern as passwordChangedAt)

### Backend — User Edit & Deactivation

- [ ] T-7: `UserService.updateUser()` — edit name, email, roles, dvAccess. Increment tokenVersion on role or dvAccess change.
- [ ] T-8: `UserService.deactivateUser()` — set status=DEACTIVATED, increment tokenVersion
- [ ] T-9: `UserService.reactivateUser()` — set status=ACTIVE, increment tokenVersion
- [ ] T-10: `AuthService.login()` — reject login if user.status == DEACTIVATED with clear message
- [ ] T-11: `UserController` — PUT /api/v1/users/{id} for edit, PATCH /api/v1/users/{id}/status for deactivate/reactivate
- [ ] T-12: On deactivation, call `NotificationService.completeEmitter(userId)` to disconnect SSE

### Backend — Audit Trail

- [ ] T-13: Create `AuditEvent` record and `AuditEventService` with async persistence via `@EventListener`
- [ ] T-14: Publish audit events from UserService on: role change, dvAccess change, deactivation, reactivation, password reset
- [ ] T-15: GET /api/v1/audit-events?targetUserId={id} endpoint (COC_ADMIN+)

### Backend — Tests

- [ ] T-16: Integration test: edit user roles, verify tokenVersion incremented
- [ ] T-17: Integration test: deactivate user, verify login rejected with 401
- [ ] T-18: Integration test: deactivated user's JWT rejected (stale tokenVersion)
- [ ] T-19: Integration test: audit events persisted on role change, deactivation
- [ ] T-20: Integration test: reactivate user, verify login works again

### Frontend — User Edit Drawer

- [ ] T-21: Create `UserEditDrawer.tsx` — slide-out panel with fields: display name, email, roles (multi-select), dvAccess toggle, status badge
- [ ] T-22: Add "Edit" button to each user row in AdminPanel Users tab
- [ ] T-23: Add "Deactivate"/"Reactivate" button with confirmation dialog
- [ ] T-24: On save, call PUT /api/v1/users/{id}. On deactivate/reactivate, call PATCH /api/v1/users/{id}/status
- [ ] T-25: Show status badge (Active/Deactivated) on user rows
- [ ] T-26: Add i18n keys for user management (en.json + es.json)

### Frontend — Tests

- [ ] T-27: Playwright: open user edit drawer, change role, save, verify
- [ ] T-28: Playwright: deactivate user, confirm dialog, verify status badge
- [ ] T-29: Playwright: reactivate deactivated user

### Seed Data & Screenshots

- [ ] T-30: Add deactivated user to seed data for screenshot captures
- [ ] T-31: Capture screenshots: user edit drawer, deactivate confirmation, status badges

### Docs-as-Code — DBML, AsyncAPI, OpenAPI, ArchUnit

- [ ] T-32: Update `docs/schema.dbml` — add `status`, `token_version` to app_user table, add `audit_events` table definition
- [ ] T-33: Update `docs/asyncapi.yaml` — add `user.deactivated` and `user.role-changed` event channels with payload schemas
- [ ] T-34: Add `@Operation` annotations to all new endpoints (user edit, deactivate/reactivate, audit events query)
- [ ] T-35: Add ArchUnit boundary rule for `notification` module (missing from v0.18.0 — notification must not access other modules' repositories or domain entities)
- [ ] T-36: Add ArchUnit boundary rule for audit functionality — ensure audit event persistence does not create circular dependencies

### Documentation

- [ ] T-37: Update FOR-DEVELOPERS.md — API reference (user edit, deactivate, audit events), project status
- [ ] T-38: Update runbook — user deactivation procedure, JWT invalidation troubleshooting

### Verification

- [ ] T-39: Run full backend test suite (including ArchUnit) — all green
- [ ] T-40: Run full Playwright test suite — all green
- [ ] T-41: ESLint + TypeScript clean
- [ ] T-42: CI green on all jobs
- [ ] T-43: Merge to main, tag
