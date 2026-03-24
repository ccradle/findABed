## MODIFIED Requirements

### Requirement: swagger-ui-access
#### Scenario: Swagger UI disabled in production profiles
- **WHEN** the application runs with a production profile (prod, staging)
- **THEN** `/api/v1/docs`, `/api/v1/api-docs`, and `/swagger-ui/**` return 404
- **AND** SecurityConfig does not include permitAll rules for Swagger paths

#### Scenario: Swagger UI available in dev/local profiles
- **WHEN** the application runs with default (lite) or dev profile
- **THEN** Swagger UI is accessible at `/api/v1/docs`
- **AND** API docs are accessible at `/api/v1/api-docs`
