## 1. Project Scaffold

- [ ] 1.1 Initialize monorepo structure: `/backend`, `/frontend`, `/infra`, root `README.md`
- [ ] 1.2 Initialize Spring Boot 3.4.x project in `/backend` with Java 21, Maven, groupId `org.fabt`, structured as a modular monolith
- [ ] 1.3 Add core dependencies: Spring Web, Spring Security, Spring Data JDBC, PostgreSQL driver, Flyway, Caffeine, Jackson, Springdoc OpenAPI, Micrometer, Logback (JSON encoder), ArchUnit (test scope)
- [ ] 1.4 Add optional dependencies with Maven profiles: Lettuce (Redis), Spring Kafka
- [ ] 1.5a Create modular monolith package structure: `shared/` (config, cache, event, security, web) + domain modules (`tenant/`, `auth/`, `shelter/`, `dataimport/`, `observability/`) each with `api/`, `domain/`, `repository/`, `service/` sub-packages and `package-info.java`
- [ ] 1.5b Create `ArchitectureTest.java` with ArchUnit rules enforcing: shared kernel must not depend on modules, modules must not access other modules' repositories or domain entities, controllers in `api/` packages, repositories in `repository/` packages
- [ ] 1.5 Initialize React + Vite project in `/frontend` with TypeScript, React Router, react-intl, Workbox, and vite-plugin-pwa (generates `manifest.json` with app name, theme color, and PWA icons)
- [ ] 1.6 Create root `docker-compose.yml` for local development (PostgreSQL 16, Redis 7, Kafka optional)
- [ ] 1.7 Create multi-stage `Dockerfile` for backend (build + runtime)
- [ ] 1.8 Create `Dockerfile` for frontend (build + nginx serve)

## 2. Database Schema and Migrations

- [ ] 2.1 Create Flyway baseline migration `V1__create_tenants.sql`: tenant table (id UUID PK, name, slug UNIQUE, config JSONB, created_at, updated_at)
- [ ] 2.2 Create migration `V2__create_users.sql`: user table (id UUID PK, tenant_id FK, email, password_hash, display_name, roles TEXT[], dv_access BOOLEAN, created_at, updated_at)
- [ ] 2.3 Create migration `V3__create_api_keys.sql`: api_key table (id UUID PK, tenant_id FK, shelter_id FK nullable, key_hash, key_suffix CHAR(4), label, role, active BOOLEAN, created_at, last_used_at)
- [ ] 2.4 Create migration `V4__create_shelters.sql`: shelter table (id UUID PK, tenant_id FK, name, address_street, address_city, address_state, address_zip, phone, latitude, longitude, dv_shelter BOOLEAN, created_at, updated_at) with index on (tenant_id, dv_shelter)
- [ ] 2.5 Create migration `V5__create_shelter_constraints.sql`: shelter_constraints table (shelter_id FK PK, sobriety_required, id_required, referral_required, pets_allowed, wheelchair_accessible, curfew_time, max_stay_days, population_types_served TEXT[])
- [ ] 2.6 Create migration `V6__create_shelter_capacity.sql`: shelter_capacity table (shelter_id FK, population_type, beds_total) with composite PK (shelter_id, population_type)
- [ ] 2.7 Create migration `V7__create_coordinator_assignments.sql`: coordinator_assignment table (user_id FK, shelter_id FK) with composite PK
- [ ] 2.8 Create migration `V8__enable_rls.sql`: enable RLS on shelter table, create policy `dv_shelter_access` using `dv_shelter = false OR current_setting('app.dv_access', true)::boolean = true`
- [ ] 2.9 Create migration `V9__create_import_log.sql`: import_log table (id UUID PK, tenant_id FK, import_type VARCHAR, filename, created_count, updated_count, skipped_count, error_count, errors JSONB, created_at)

## 3. Deployment Profiles

- [ ] 3.1 Create `application.yml` with base configuration (server port, flyway, jackson, logging format)
- [ ] 3.2 Create `application-lite.yml`: Caffeine cache config, disable Redis/Kafka auto-configuration
- [ ] 3.3 Create `application-standard.yml`: Caffeine + Redis config, disable Kafka auto-configuration
- [ ] 3.4 Create `application-full.yml`: Caffeine + Redis + Kafka config
- [ ] 3.5 Implement `DeploymentTier` enum (LITE, STANDARD, FULL) and `DeploymentTierDetector` component
- [ ] 3.6 Implement `CacheService` interface with `CaffeineCacheService` (lite) and `TieredCacheService` (standard/full) implementations using `@Profile`
- [ ] 3.7 Implement `EventBus` interface with `SpringEventBus` (lite), `PgNotifyEventBus` (lite real-time), and `KafkaEventBus` (full) using `@Profile`
- [ ] 3.8 Log deployment tier on startup; default to Lite with warning if no profile set

## 4. Multi-Tenancy and Roles

- [ ] 4.1 Create `Role` enum: PLATFORM_ADMIN, COC_ADMIN, COORDINATOR, OUTREACH_WORKER (needed by all authorization checks in sections 4–7)
- [ ] 4.2 Create `TenantContext` with ThreadLocal storage for current tenant ID
- [ ] 4.3 Create `TenantFilter` servlet filter: extract tenant ID from JWT or API key, set on TenantContext, set `SET LOCAL app.dv_access` within a `@Transactional` boundary (service layer manages transactions, filter sets context before dispatch), clear on request completion
- [ ] 4.4 Create `Tenant` entity and `TenantRepository` (Spring Data JDBC)
- [ ] 4.5 Create `TenantService` with create, update, getById, getBySlug operations
- [ ] 4.6 Create `TenantController` REST endpoints: POST/GET/PUT `/api/v1/tenants` with PLATFORM_ADMIN authorization
- [ ] 4.7 Create `TenantConfigController`: GET/PUT `/api/v1/tenants/{id}/config` with COC_ADMIN authorization
- [ ] 4.8 Add integration test: verify tenant isolation (user in tenant A cannot see tenant B data)

## 5. Authentication

- [ ] 5.1 Create `User` entity and `UserRepository` (dvAccess defaults to false for new users — principle of least privilege)
- [ ] 5.2 Create `JwtService`: generate access token (15min) and refresh token (7d) with userId, tenantId, roles[], dvAccess claims
- [ ] 5.3 Create `AuthController`: POST `/api/v1/auth/login` (username/password → JWT), POST `/api/v1/auth/refresh` (refresh → new access token)
- [ ] 5.4 Create `JwtAuthenticationFilter`: parse Bearer token, validate, set SecurityContext
- [ ] 5.5 Create `ApiKey` entity and `ApiKeyRepository`
- [ ] 5.6 Create `ApiKeyService`: create (returns plaintext once), rotate, deactivate, validate; resolve key to tenant + shelter (optional) + implicit role (COORDINATOR for shelter-scoped keys, COC_ADMIN for org-level keys where shelter_id is null)
- [ ] 5.7 Create `ApiKeyAuthenticationFilter`: parse X-API-Key header, validate, resolve tenant/shelter/role, set SecurityContext
- [ ] 5.8 Create `SecurityConfig`: configure filter chain with OAuth2 login → JWT filter → API key filter, role-based endpoint authorization
- [ ] 5.9 Create `UserController`: CRUD endpoints POST/GET/PUT `/api/v1/users` with COC_ADMIN authorization
- [ ] 5.10 Create `ApiKeyController`: POST/GET/DELETE `/api/v1/api-keys`, POST `/api/v1/api-keys/{id}/rotate` with COC_ADMIN authorization
- [ ] 5.11 Create Flyway migration `V10__create_oauth2_tables.sql`: `tenant_oauth2_provider` table (tenant_id FK, provider_name, client_id, client_secret_encrypted, issuer_uri, enabled BOOLEAN) and `user_oauth2_link` table (user_id FK, provider_name, external_subject_id, linked_at) with unique constraint on (provider_name, external_subject_id)
- [ ] 5.12 Configure Spring Security OAuth2 Client with dynamic tenant-based provider registration (load client IDs/secrets from `tenant_oauth2_provider` at runtime)
- [ ] 5.13 Create `OAuth2AccountLinkService`: on successful OAuth2 callback, match ID token email to pre-created user, link identity in `user_oauth2_link`, issue JWT; reject with error if no matching user found
- [ ] 5.14 Create tenant OAuth2 provider management endpoints: POST/GET/PUT/DELETE `/api/v1/tenants/{id}/oauth2-providers` with COC_ADMIN authorization
- [ ] 5.15 Create public OAuth2 provider list endpoint: GET `/api/v1/tenants/{slug}/oauth2-providers/public` (unauthenticated, returns provider names and login URLs only — no secrets)
- [ ] 5.16 Add integration test: verify role-based access (coordinator cannot access admin endpoints)
- [ ] 5.17 Add integration test: verify DV RLS (user without dvAccess cannot see DV shelters via any query path)
- [ ] 5.18 Add integration test: verify OAuth2 login links to pre-created account and rejects unknown emails
- [ ] 5.19 Add integration test: verify JWT from OAuth2 login is identical in structure to password-based JWT

## 6. Shelter Profile

- [ ] 6.1 Create `Shelter` entity with all fields from migration V4
- [ ] 6.2 Create `ShelterConstraints` entity (embedded or separate table reference)
- [ ] 6.3 Create `ShelterCapacity` entity for per-population-type capacity
- [ ] 6.4 Create `PopulationType` enum: SINGLE_ADULT, FAMILY_WITH_CHILDREN, WOMEN_ONLY, VETERAN, YOUTH_18_24, YOUTH_UNDER_18, DV_SURVIVOR
- [ ] 6.5 Create `ShelterRepository` with tenant-scoped queries and constraint filtering
- [ ] 6.6 Create `ShelterService` with CRUD operations, coordinator assignment validation
- [ ] 6.7 Create `ShelterController`: POST/GET/PUT `/api/v1/shelters`, GET `/api/v1/shelters/{id}` with pagination and constraint filters
- [ ] 6.8 Create `ShelterHsdsMapper`: map FABT shelter to HSDS 3.0 JSON with `fabt:` extension namespace
- [ ] 6.9 Add GET `/api/v1/shelters/{id}?format=hsds` endpoint for HSDS-compatible export
- [ ] 6.10 Create coordinator assignment endpoints: POST/DELETE `/api/v1/shelters/{id}/coordinators`
- [ ] 6.11 Add integration test: verify constraint filtering returns correct shelters
- [ ] 6.12 Add integration test: verify coordinator can only update assigned shelters

## 7. Data Import

- [ ] 7.1 Create `ShelterImportService` with validation pipeline: validate → deduplicate (name + address within tenant; duplicate = full replace of all fields from import source) → persist → report
- [ ] 7.2 Create `HsdsImportAdapter`: parse HSDS 3.0 JSON, map to FABT shelter model, feed to ShelterImportService
- [ ] 7.3 Create `TwoOneOneImportAdapter`: parse 211 CSV, fuzzy column header matching, preview mapping, feed to ShelterImportService
- [ ] 7.4 Create `ImportController`: POST `/api/v1/import/hsds` (multipart file), POST `/api/v1/import/211` (multipart file), GET `/api/v1/import/211/preview` (column mapping preview)
- [ ] 7.5 Create `ImportLog` entity and `ImportLogRepository` for audit trail
- [ ] 7.6 Add integration test: HSDS import creates shelters and handles duplicates
- [ ] 7.7 Add integration test: 211 CSV import with non-standard column names (fuzzy header matching, unmapped column warnings in report)
- [ ] 7.8 Add integration test: verify population type enum validation returns all 7 valid types in 400 error response

## 8. Observability

- [ ] 8.1 Configure structured JSON logging with logback-encoder: timestamp, level, logger, message, tenantId, userId, traceId, spanId
- [ ] 8.2 Create `TenantMdcFilter`: inject tenantId and userId into MDC for all log entries
- [ ] 8.3 Configure Micrometer metrics: API timer (endpoint, method, status, tenantId), cache counters (cache_name, result)
- [ ] 8.4 Configure Spring Actuator: health (liveness, readiness with DB/Redis/Kafka checks), prometheus endpoint
- [ ] 8.5 Implement `DataAgeResponseAdvice`: `@ControllerAdvice` that adds `data_age_seconds` to responses served from cache or containing a `snapshot_ts` field (shelter list, shelter detail endpoints)
- [ ] 8.6 Add integration test: verify structured log output includes tenantId
- [ ] 8.7 Add integration test: verify /actuator/health reports component status per deployment tier
- [ ] 8.8 Configure Spring `LocaleResolver` (Accept-Language header) and `MessageSource` (resource bundle) for localized API error responses
- [ ] 8.9 Add integration test: verify API error responses are localized when `Accept-Language: es` is sent
- [ ] 8.10 Add integration test: verify no PII (names, addresses, phone numbers of people experiencing homelessness) appears in structured log output during shelter CRUD, user creation, and OAuth2 callback operations. Shelter names and addresses (public business data) are permitted in logs.

## 9. PWA Shell

- [ ] 9.1 Create `AuthContext` and `AuthGuard` component: store JWT, decode roles, redirect unauthorized
- [ ] 9.2 Set up React Router with role-gated routes: `/login`, `/coordinator/*`, `/outreach/*`, `/admin/*` (depends on AuthGuard from 9.1)
- [ ] 9.3 Create login page with username/password form and dynamic OAuth2 provider buttons (fetched from `/api/v1/tenants/{slug}/oauth2-providers/public`)
- [ ] 9.4 Create API client service with JWT/API key header injection and error handling
- [ ] 9.5 Configure Workbox: precache app shell, runtime cache API responses with stale-while-revalidate
- [ ] 9.6 Create `OfflineQueue` service: IndexedDB-backed action queue with timestamp, sync on reconnect, conflict reporting
- [ ] 9.7 Create `OnlineStatus` hook and offline indicator banner component
- [ ] 9.8 Create `DataAge` component: display "Updated X minutes ago" from `data_age_seconds`
- [ ] 9.9 Set up react-intl: English (`en.json`) as source of truth, Spanish (`es.json`) starter, locale selector component
- [ ] 9.10 Create responsive layout shell: sidebar navigation (desktop), bottom nav (mobile), minimum 44x44px touch targets
- [ ] 9.11 Create placeholder pages: coordinator dashboard, outreach search, admin panel (with role-appropriate placeholders for future capabilities)
- [ ] 9.12 Create shelter creation form for manual entry (CoC admin)
- [ ] 9.13 Create HSDS import file upload page with progress and report display
- [ ] 9.14 Create 211 import page with column mapping preview/confirmation step, file upload, progress, and report display

## 10. CI/CD Pipeline

- [ ] 10.1 Create GitHub Actions workflow `.github/workflows/ci.yml`: lint → test → build → docker
- [ ] 10.2 Backend stage: Maven build, run unit tests, run integration tests (Testcontainers for PostgreSQL, Redis)
- [ ] 10.3 Frontend stage: npm install, lint (ESLint), test (Vitest), build
- [ ] 10.4 Docker stage: build backend image, build frontend image, push to `ghcr.io/ccradle/finding-a-bed-tonight`
- [ ] 10.5 Add test profile configuration for Testcontainers (PostgreSQL 16, Redis 7)

## 11. Infrastructure as Code

- [ ] 11.1 Create Terraform module `modules/network`: VPC, subnets, security groups
- [ ] 11.2 Create Terraform module `modules/postgres`: PostgreSQL instance (RDS compatible), database, user, RLS-enabled role
- [ ] 11.3 Create Terraform module `modules/redis`: Redis instance (ElastiCache compatible)
- [ ] 11.4 Create Terraform module `modules/kafka`: Kafka cluster (MSK compatible)
- [ ] 11.5 Create Terraform module `modules/app`: ECS/container service, load balancer, environment variables
- [ ] 11.6 Create environment compositions: `environments/lite` (network + postgres + app), `environments/standard` (+ redis), `environments/full` (+ kafka)
- [ ] 11.7 Configure remote state: S3 + DynamoDB backend
- [ ] 11.8 Add cost guardrail: `$50/month` budget alarm for Lite tier

## 12. Seed Data and Developer Experience

- [ ] 12.1 Create seed data SQL script: default tenant ("Development CoC"), admin user (dvAccess=true), outreach worker user (dvAccess=false), sample OAuth2 provider config (Google, for local testing), sample shelters (10 synthetic shelters with varied constraints and capacities, including 1 DV shelter)
- [ ] 12.2 Create `dev-setup.sh` script: start docker-compose, run migrations, load seed data
- [ ] 12.3 Create `CONTRIBUTING.md` with setup instructions, architecture overview, and PR guidelines
- [ ] 12.4 Add OpenAPI spec auto-generation and Swagger UI at `/api/v1/docs`

## 13. Documentation Standards

- [ ] 13.1 Create `docs/schema.dbml` — DBML source derived from Flyway migrations V1–V10 (all tables, relationships, enums). Workflow: create DBML → paste into dbdiagram.io → export PNG → commit both
- [ ] 13.2 Create `docs/erd.png` — ERD image exported from dbdiagram.io, embedded inline in README
- [ ] 13.3 Create `docs/asyncapi.yaml` — AsyncAPI 3.0 spec documenting the EventBus contract: shelter-availability-updated, surge-event-activated, surge-event-deactivated channels. Covers all three tiers (Spring Events, PG NOTIFY, Kafka) with the same message schema
- [ ] 13.4 Create `README.md` — Project overview, mission statement, architecture diagram (ASCII + Mermaid), deployment tier table, ERD embed, badges (CI status, license, Java version), quick start instructions, API docs link, link to CONTRIBUTING.md
- [ ] 13.5 Create `docs/architecture.drawio` — draw.io diagram showing backend, frontend, PostgreSQL, Redis (optional), Kafka (optional), and the three deployment tiers
- [ ] 13.6 _(Deferred to future change)_ Create `docs/TEST-AUTOMATION-STRATEGY.md` — Cross-project test automation strategy (Karate, Pact, Gatling). Requires more implementation before test patterns can be documented meaningfully
