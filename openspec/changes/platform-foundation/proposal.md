## Why

There is no open-source infrastructure for real-time shelter bed availability. A social worker with a family of five in a parking lot at midnight has no system to query — they make phone calls until something works or the family gives up. Every city that wants to solve this today must build from scratch or buy commercial software that shelters cannot afford. This change lays the foundation: a multi-tenant platform with authentication, data model, deployment profiles, and a PWA shell that every subsequent capability (bed queries, surge mode, reservations, HMIS bridge) plugs into.

## What Changes

- New multi-tenant data model with shared schema (tenant_id pattern) on PostgreSQL 16 with Flyway migrations
- Tenant, organization, shelter, and user entities with role-based access control
- Hybrid auth: user/role model as primary, OAuth2/OIDC social login (Google, Microsoft, etc.), configurable shelter/org-level API key auth
- PostgreSQL Row Level Security infrastructure for DV shelter data isolation
- Three deployment tiers (Lite, Standard, Full) selectable via Spring profiles
  - **Lite**: PostgreSQL only, Caffeine cache, LISTEN/NOTIFY, scheduled tasks
  - **Standard**: PostgreSQL + Redis (distributed cache)
  - **Full**: PostgreSQL + Redis + Kafka (event-driven, multi-service)
- HSDS 3.0-compatible data model with extension points for bed availability objects
- RESTful API scaffolding at `/api/v1/` with OpenAPI documentation
- PWA shell (React + Vite + Workbox) with role-gated routing, offline foundation, and i18n wiring
- Multiple data import paths: manual entry, HSDS JSON import, 211 directory import
- CI/CD pipeline (GitHub Actions) and Terraform infrastructure modules
- Seed data generator with synthetic shelters modeled on realistic patterns

## Capabilities

### New Capabilities

- `multi-tenancy`: Tenant isolation via shared schema with tenant_id, tenant provisioning, and cross-tenant admin operations
- `auth-and-roles`: User/role model (coordinator, outreach-worker, coc-admin, platform-admin) with JWT auth, OAuth2/OIDC social login (Google, Microsoft — pre-created accounts linked by email), configurable org-level API key auth, and session variable propagation for RLS
- `shelter-profile`: Shelter entity CRUD aligned to HSDS 3.0, including ShelterConstraints (sobriety, ID, referral, pets, wheelchair, DV flag, population types served)
- `deployment-profiles`: Spring profile-based tier selection (lite/standard/full) governing cache, messaging, and event infrastructure
- `data-import`: HSDS JSON bulk import, 211 directory import, and manual entry — all tenant-scoped with validation and error reporting
- `pwa-shell`: React + Vite PWA with role-gated routing, service worker registration, offline storage foundation (IndexedDB), and i18n wiring (react-intl)
- `observability`: Micrometer metrics, structured JSON logging, health endpoints, and data-age tracking infrastructure

### Modified Capabilities

_None — this is a greenfield foundation._

## Impact

- **New codebase**: Monorepo with `/backend` (Spring Boot 3.4.x, Java 21, Spring MVC + JDBC), `/frontend` (React + Vite), `/infra` (Terraform + Docker)
- **Database**: PostgreSQL 16 schema with tenant, organization, shelter, user, role, and API key tables; RLS policies for DV isolation
- **APIs**: `/api/v1/tenants`, `/api/v1/shelters`, `/api/v1/users`, `/api/v1/import`, `/api/v1/auth`
- **Dependencies**: Spring Boot 3.4.x, Spring Security, Spring Security OAuth2 Client, Flyway, Caffeine, optionally Redis (Lettuce) and Kafka (Spring Kafka), React 18, Vite, Workbox, react-intl
- **Infrastructure**: Terraform modules for network, PostgreSQL, Redis, Kafka, app; GitHub Actions CI/CD pipeline; Docker image (`ghcr.io/ccradle/finding-a-bed-tonight`)
- **External systems**: None directly — HMIS bridge and 211 integration are import-path only in this change
