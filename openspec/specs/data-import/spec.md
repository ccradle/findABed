## ADDED Requirements

### Requirement: manual-shelter-entry
The system SHALL allow CoC admins to create shelter profiles manually via a form in the PWA admin interface.

#### Scenario: Manual shelter creation
- **WHEN** a CoC admin fills out the shelter creation form with name, address, phone, capacity, and constraints
- **THEN** the system validates all fields, creates the shelter within the admin's tenant, and displays a success confirmation

#### Scenario: Validation errors displayed
- **WHEN** a CoC admin submits the form with missing required fields (name, address)
- **THEN** the system displays inline validation errors without losing the entered data

### Requirement: hsds-json-import
The system SHALL support bulk import of shelter data from HSDS 3.0-compliant JSON packages.

#### Scenario: Successful HSDS import
- **WHEN** a CoC admin uploads an HSDS 3.0 JSON file via POST `/api/v1/import/hsds`
- **THEN** the system parses the file, maps organizations/services/locations to FABT shelter profiles, and returns an import report
- **AND** the report includes counts: created, updated, skipped, errors

#### Scenario: Duplicate detection
- **WHEN** an HSDS import contains a shelter with the same name and address as an existing shelter in the tenant
- **THEN** the system performs a full replace of all fields on the existing shelter with values from the import source
- **AND** the import report marks this shelter as "updated"

#### Scenario: Validation errors in import
- **WHEN** an HSDS import file contains records with invalid or missing required fields
- **THEN** the system skips invalid records, imports valid ones, and includes error details per record in the import report

#### Scenario: Non-HSDS file rejected
- **WHEN** an uploaded file does not conform to HSDS 3.0 structure
- **THEN** the system returns 400 Bad Request with a message identifying the structural issue

### Requirement: 211-directory-import
The system SHALL support import of shelter data from 211 directory CSV exports.

#### Scenario: Successful 211 CSV import
- **WHEN** a CoC admin uploads a 211 CSV file via POST `/api/v1/import/211`
- **THEN** the system maps common 211 fields (agency name, address, phone, service description) to FABT shelter profiles
- **AND** returns an import report with created, updated, skipped, and error counts

#### Scenario: Field mapping with unmapped columns
- **WHEN** a 211 CSV contains columns that do not map to FABT fields
- **THEN** the system ignores unmapped columns and proceeds with import
- **AND** the import report lists unmapped column names as informational warnings

#### Scenario: Regional format variations
- **WHEN** a 211 CSV uses a non-standard column naming convention
- **THEN** the system attempts fuzzy matching on column headers (case-insensitive, common synonyms)
- **AND** presents a column mapping preview for admin confirmation before importing

### Requirement: import-tenant-scoping
All imported data SHALL be scoped to the importing user's tenant.

#### Scenario: Import respects tenant boundary
- **WHEN** a CoC admin in tenant A imports shelter data
- **THEN** all created shelters belong to tenant A
- **AND** no data is visible to other tenants

#### Scenario: Import cannot overwrite other tenants
- **WHEN** an import file references shelter IDs from another tenant
- **THEN** the system ignores external IDs and creates new records within the importing tenant

### Requirement: csv-injection-prevention
All string fields in imported CSV and JSON data SHALL be sanitized before storage to prevent formula injection (CWE-1236) when data is later exported and opened in spreadsheet software.

#### Scenario: Dangerous prefix stripped
- **WHEN** a CSV field starts with `=`, `+` (non-digit follows), or `@`
- **THEN** the leading character is stripped and a warning is logged
- **AND** the sanitized value is stored in the database

#### Scenario: Legitimate values preserved
- **WHEN** a phone field contains `+1-919-555-0100` or an address contains `-123 Main St`
- **THEN** the value is stored unchanged (digit follows `+`, `-` is always preserved)

### Requirement: import-field-length-validation
Imported fields SHALL be validated against maximum lengths matching database column sizes. Rows exceeding limits are skipped with a row-level error.

### Requirement: import-mime-type-validation
The import controller SHALL validate the uploaded file's content type before processing. CSV endpoints accept `text/csv`, `text/plain`, `application/csv`, `application/octet-stream`. JSON endpoints accept `application/json`, `text/plain`, `application/octet-stream`. Null content types are accepted with a logged warning.

### Requirement: import-navigation
Admin panel import links SHALL use React Router client-side navigation (`<Link>`) instead of HTML anchor tags (`<a href>`) to ensure correct SPA routing.
