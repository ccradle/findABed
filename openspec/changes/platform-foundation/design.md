## Context

Finding A Bed Tonight (FABT) is a greenfield open-source platform for real-time shelter bed availability. No codebase exists yet. This design establishes the foundation that all six domain capabilities (bed query, availability update, surge mode, DV referral, HMIS bridge, CoC analytics) will build on.

Key constraints:
- Must run on budgets from $15/month (rural county volunteer) to $100+/month (metro city IT)
- Must be adoptable by cities with no custom development — deploy, configure, use
- Contributors range from experienced Java developers to first-time open-source contributors
- Zero PII stored. DV shelter data protected at database layer, not application routing
- HSDS 3.0 compatibility for future upstream proposal to Open Referral

## Goals / Non-Goals

**Goals:**
- Runnable monorepo with backend API, PWA frontend, and infrastructure-as-code
- Multi-tenant shared-schema data model with tenant isolation
- Hybrid auth: JWT-based user/role model + OAuth2/OIDC social login + configurable org-level API keys
- PostgreSQL RLS infrastructure for DV shelter data isolation
- Three deployment tiers (Lite/Standard/Full) via Spring profiles
- PWA shell with offline foundation, role-gated routing, and i18n
- CI/CD pipeline and Docker packaging
- Multiple data import paths (manual, HSDS, 211)

**Non-Goals:**
- Implementing bed availability query/update, surge mode, reservations (including reservation schema, soft-hold, expiry — separate change), HMIS bridge, or CoC analytics (all separate changes)
- Native mobile apps (PWA-first strategy)
- Reactive stack (Spring MVC + JDBC is the default; WebFlux reserved for proven hotspots)
- Production Terraform for any specific cloud provider (modules are reusable templates)
- User-facing analytics dashboards (CoC analytics capability comes later)

## Decisions

### D1: Monorepo structure

The project uses two independent git repositories (not submodules):

**Repo 1: Documentation** (`C:\Development\findABed`, GitHub: `ccradle/findABed`, private)
- OpenSpec artifacts, proposals, playbooks, AI tool configs
- `.gitignore` excludes `finding-a-bed-tonight/`

**Repo 2: Code Monorepo** (`C:\Development\findABed\finding-a-bed-tonight`, GitHub: `ccradle/finding-a-bed-tonight`, private)
```
finding-a-bed-tonight/
├── backend/                    # Spring Boot application
│   ├── src/main/java/org/fabt/
│   │   ├── config/             # Spring configuration, profiles, security
│   │   ├── tenant/             # Tenant entity, service, filter
│   │   ├── auth/               # JWT, API key, roles, security config
│   │   ├── shelter/            # Shelter, ShelterConstraints, HSDS model
│   │   ├── user/               # User entity, service
│   │   ├── dataimport/         # Import services (HSDS, 211, manual)
│   │   └── common/             # Shared: pagination, error handling, i18n
│   ├── src/main/resources/
│   │   ├── db/migration/       # Flyway SQL migrations
│   │   ├── application.yml     # Base config
│   │   ├── application-lite.yml
│   │   ├── application-standard.yml
│   │   ├── application-full.yml
│   │   └── messages/           # i18n message bundles
│   └── src/test/
├── frontend/                   # React + Vite PWA
│   ├── src/
│   │   ├── components/         # Shared UI components
│   │   ├── pages/              # Route-level pages
│   │   ├── hooks/              # Custom React hooks
│   │   ├── services/           # API client, offline queue
│   │   ├── i18n/               # Message catalogs
│   │   ├── auth/               # Auth context, guards
│   │   └── sw/                 # Service worker, Workbox config
│   └── public/
├── infra/
│   ├── terraform/              # Terraform modules
│   │   ├── modules/            # network, postgres, redis, kafka, app
│   │   └── environments/       # lite, standard, full
│   ├── docker/
│   │   ├── Dockerfile          # Multi-stage backend build
│   │   └── docker-compose.yml  # Local development
│   └── scripts/                # Setup, seed data, migration helpers
└── .github/workflows/          # CI/CD pipeline
```

**Rationale:** Single repo lowers the barrier for contributors — clone once, build everything. Module boundaries are directory-based, not repo-based. If scale demands splitting later, the package structure supports it.

**Alternatives considered:**
- Multi-repo (backend, frontend, infra separate): Higher contributor friction, version coordination overhead. Rejected for MVP.
- Gradle multi-module: Adds build complexity without clear benefit at current scale. Single Spring Boot module is sufficient.

### D2: Multi-tenancy via shared schema with tenant_id

Every tenant-scoped table includes a `tenant_id` column (UUID, NOT NULL, indexed). A `TenantFilter` servlet filter extracts tenant context from the JWT or API key and sets it on a `ThreadLocal`. Repository queries include `WHERE tenant_id = ?` enforced by a base repository pattern or Spring Data query derivation.

**Rationale:** Shared schema enables cross-tenant analytics (CoC-level aggregation), simpler operations (one migration applies to all tenants), and lower cost (one database instance). Tenant isolation is enforced at the application layer and reinforced by RLS for DV data.

**Alternatives considered:**
- Schema-per-tenant: Stronger isolation but operationally complex (N schemas to migrate), prevents cross-tenant queries, incompatible with $15/month Lite tier. Rejected.
- Database-per-tenant: Same issues amplified. Rejected.

### D3: Hybrid authentication — JWT + configurable API keys

**User/role model (primary):** Users authenticate via username/password, receive a JWT. Roles: `PLATFORM_ADMIN`, `COC_ADMIN`, `COORDINATOR`, `OUTREACH_WORKER`. JWT contains `userId`, `tenantId`, `roles[]`, and `dvAccess` claim.

**Org-level API keys (configurable):** A tenant admin can create long-lived API keys scoped to a shelter or organization. Keys carry an implicit role (typically `COORDINATOR`). Designed for the D5 use case: coordinators updating on mobile, standing up, stressed — no login flow.

**Resolution order:** `Authorization: Bearer <jwt>` checked first. `X-API-Key: <key>` checked second. Both resolve to the same `SecurityContext` with tenant, roles, and DV access flag.

**Rationale:** JWT for interactive users (dashboard, admin). API keys for programmatic/low-friction shelter updates. Admin controls which auth methods are enabled per tenant.

**OAuth2/OIDC social login:** Spring Security OAuth2 Client handles the redirect/callback flow. Provider configuration (client ID, client secret, issuer URI) is stored per tenant in `tenant_oauth2_provider` table. Supported providers: Google, Microsoft (extensible to any OIDC-compliant provider).

**Account linking model (Option C):** OAuth2 login does NOT auto-provision users. A CoC admin pre-creates the user with an email and role. On first OAuth2 login, the system matches the ID token email to the pre-created user and links the OAuth2 identity. This prevents unauthorized access — random Google users cannot self-provision into a shelter system. The linked OAuth2 identity is stored in a `user_oauth2_link` table (user_id, provider, external_subject_id) for subsequent logins.

**JWT issuance:** After successful OAuth2 callback and account link, the system issues the same JWT (userId, tenantId, roles[], dvAccess) as password login. Downstream code is auth-method-agnostic.

**Alternatives considered:**
- Auto-provision on first OAuth2 login (Option A): Requires mapping unknown users to tenants, risks unauthorized access. Rejected.
- Admin-approved OAuth2 accounts (Option B): Adds friction — admin creates user, user logs in, admin must approve again. Rejected.
- API keys only: Insufficient for role granularity and audit trail on admin actions. Rejected as sole method.

### D4: PostgreSQL Row Level Security for DV shelters

RLS policy on shelter-related tables:

```sql
CREATE POLICY dv_shelter_access ON shelter
  USING (
    dv_shelter = false
    OR current_setting('app.dv_access', true)::boolean = true
  );
```

Application sets `SET LOCAL app.dv_access = 'true'` at the start of each transaction when the authenticated principal has DV access rights. This is done in the `TenantFilter` or a `HandlerInterceptor` before any repository call.

**Rationale:** Data-layer enforcement means no application bug can leak DV shelter data. `SET LOCAL` is transaction-scoped — automatically cleared on commit/rollback. Application-managed (vs. database-role-per-user) because the number of concurrent users is small and the operational overhead of managing PostgreSQL roles per user is disproportionate.

**Alternatives considered:**
- Application-layer filtering (WHERE clause in service): Single point of failure — one missed filter leaks data. Rejected per project rule D4.
- Database-role-per-tenant: Operationally heavy, requires connection pool per role. Rejected.

### D5: Deployment tiers via Spring profiles

| Concern | Lite (`--spring.profiles.active=lite`) | Standard (`standard`) | Full (`full`) |
|---------|-------|----------|------|
| Cache L1 | Caffeine (60s TTL) | Caffeine (60s TTL) | Caffeine (60s TTL) |
| Cache L2 | None | Redis (300s TTL) | Redis (300s TTL) |
| Real-time push | PG LISTEN/NOTIFY via SSE | Redis Pub/Sub via SSE | Kafka consumer via SSE |
| Event bus | In-process Spring Events | In-process Spring Events | Kafka topics |
| Estimated cost | $15-30/month | $30-75/month | $100+/month |

A `DeploymentTier` enum and `@ConditionalOnProperty` / `@Profile` annotations wire the correct implementations. Interfaces (`CacheService`, `EventBus`) abstract the tier-specific implementations.

**Rationale:** A rural county volunteer should not need to run Kafka. A metro city IT team should not be limited by PostgreSQL LISTEN/NOTIFY. Same codebase, different infrastructure.

### D6: PWA architecture

React 18 + Vite + React Router for SPA routing. Workbox for service worker (precache app shell, runtime cache API responses). IndexedDB (via idb or Dexie) for offline data queue. react-intl for i18n with message catalogs per locale.

**Role-gated routing:**
- `/coordinator/*` — Shelter profile, bed count update
- `/outreach/*` — Search, reserve, offline queue
- `/admin/*` — Tenant management, surge, analytics (future)
- `/login`, `/` — Public

**Offline strategy:**
- Service worker caches app shell and recent API responses
- Outreach worker actions (queries, shelter searches) queue to IndexedDB when offline
- On reconnect, queue replays with conflict detection (data may have changed)
- Stale cache shows `data_age_seconds` prominently in UI

**Rationale:** PWA-first avoids app store friction, works on any device, and a single codebase serves all three roles. Offline via service worker + IndexedDB is the standard approach with broad browser support.

### D7: Data import architecture

Three import paths, all tenant-scoped:

1. **Manual entry** — Form-based shelter profile creation in the PWA admin interface
2. **HSDS JSON import** — Upload an HSDS 3.0-compliant JSON package; parser maps to FABT schema, validates, reports errors
3. **211 directory import** — CSV/API adapter for 211 data sources; maps common 211 fields to HSDS-compatible shelter profiles

All imports go through a `ShelterImportService` that validates, deduplicates (by name + address within tenant), and produces an import report (created, updated, skipped, errors).

**Rationale:** Cities with existing 211 data or HSDS directories shouldn't re-enter everything manually. The import service normalizes all paths to the same validation pipeline.

## Risks / Trade-offs

- **[Shared schema data leak]** → Mitigation: Every tenant-scoped query MUST include `tenant_id`. Code review checklist item. Integration tests verify cross-tenant isolation.
- **[RLS performance on large tables]** → Mitigation: `tenant_id` + `dv_shelter` indexed. RLS adds minimal overhead at expected scale (<1000 shelters per tenant). Monitor with `EXPLAIN ANALYZE`.
- **[Offline conflict on reconnect]** → Mitigation: Offline queue uses optimistic conflict detection — stale data is reported to user, not silently retried. Last-write-wins with `updated_at` comparison.
- **[Three deployment tiers = three test matrices]** → Mitigation: CI runs integration tests against all three profiles. Testcontainers spins up PostgreSQL (always), Redis (standard/full), Kafka (full).
- **[API key compromise]** → Mitigation: Keys are scoped to a single shelter, rotatable by admin, logged on every use. Compromised key cannot access other shelters or DV data (unless explicitly granted).
- **[Spring MVC thread pool under load]** → Mitigation: Virtual threads (Java 21 `--enable-preview` or Spring Boot 3.4 native support) can be enabled if thread pool becomes a bottleneck. This is the path to concurrency improvement before considering WebFlux.

## Open Questions

- **OAuth2/OIDC integration**: Some cities may require SSO (Azure AD, Okta). Design supports adding an additional `AuthenticationProvider` without changing the role model, but the specific integration is deferred.
- **211 API variability**: 211 data formats vary by region. The import adapter may need per-region plugins. Start with CSV import and add API adapters as cities onboard.
- **Terraform provider**: Modules are written provider-agnostic where possible, but PostgreSQL managed services differ across AWS RDS, Azure Database, GCP Cloud SQL. Initial templates target AWS (most common in government IT).
