## ADDED Requirements

### Requirement: lite-profile
The system SHALL support a Lite deployment profile using only PostgreSQL, with no Redis or Kafka dependencies.

#### Scenario: Lite profile cache behavior
- **WHEN** the application starts with `--spring.profiles.active=lite`
- **THEN** the system uses Caffeine as the sole cache layer with 60-second TTL
- **AND** no Redis connection is attempted

#### Scenario: Lite profile real-time push
- **WHEN** a shelter availability update occurs in Lite mode
- **THEN** the system broadcasts the update via PostgreSQL LISTEN/NOTIFY
- **AND** connected SSE clients receive the update

### Requirement: standard-profile
The system SHALL support a Standard deployment profile using PostgreSQL and Redis.

#### Scenario: Standard profile cache behavior
- **WHEN** the application starts with `--spring.profiles.active=standard`
- **THEN** the system uses Caffeine L1 (60s TTL) and Redis L2 (300s TTL) as a two-tier cache

#### Scenario: Redis failure fallback
- **WHEN** Redis becomes unavailable in Standard mode
- **THEN** the system falls back to Caffeine-only caching
- **AND** the system logs a warning and exposes a health indicator showing degraded cache status

### Requirement: full-profile
The system SHALL support a Full deployment profile using PostgreSQL, Redis, and Kafka.

#### Scenario: Full profile event bus
- **WHEN** the application starts with `--spring.profiles.active=full`
- **THEN** the system publishes domain events (availability updates, surge events) to Kafka topics
- **AND** consumes events from Kafka for real-time push to SSE clients

#### Scenario: Full profile includes Standard capabilities
- **WHEN** the Full profile is active
- **THEN** all Standard profile capabilities (Redis cache, Redis failure fallback) are also active

### Requirement: profile-abstraction
The system SHALL abstract tier-specific infrastructure behind common interfaces so that application code does not depend on a specific deployment tier.

#### Scenario: CacheService interface
- **WHEN** application code needs to cache or retrieve data
- **THEN** it calls `CacheService.get()` / `CacheService.put()` regardless of whether the backing implementation is Caffeine-only or Caffeine+Redis

#### Scenario: EventBus interface
- **WHEN** application code needs to publish a domain event
- **THEN** it calls `EventBus.publish(event)` regardless of whether the backing implementation is Spring Events, PG LISTEN/NOTIFY, or Kafka

#### Scenario: Profile selected at startup
- **WHEN** no Spring profile is explicitly set
- **THEN** the system defaults to the Lite profile
- **AND** logs a warning: "No deployment profile set — defaulting to lite"
