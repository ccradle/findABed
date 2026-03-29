## ADDED Requirements

### Requirement: Coordinator quick-start card

The project SHALL provide a print-ready coordinator quick-start card usable with zero external training.

#### Scenario: Card covers the complete update flow

- **WHEN** a new coordinator receives the quick-start card
- **THEN** it explains: how to log in (including tenant slug), how to find their shelter, how to update occupied count, how to confirm save worked, and what to do if something goes wrong
- **AND** it fits on one page (front and back)

#### Scenario: Card is testable with target audience

- **WHEN** a person matching the coordinator persona (e.g., Reverend Monroe's volunteer) reads the card
- **THEN** they can complete a bed count update without any other support

### Requirement: Freshness badge explanation for users

The platform SHALL explain freshness badges (FRESH/AGING/STALE/UNKNOWN) in plain language accessible to non-technical users.

#### Scenario: User understands what STALE means

- **WHEN** a user encounters a STALE badge
- **THEN** guidance is available explaining: "This shelter hasn't updated their count in over 8 hours. The beds may still be available — call the shelter before driving there."

### Requirement: Admin onboarding checklist

The project SHALL provide a fillable onboarding checklist for CoC administrators, one per shelter.

#### Scenario: Checklist covers full onboarding lifecycle

- **WHEN** Marcus onboards a new shelter
- **THEN** the checklist includes: shelter profile creation (including 211 import option), coordinator account creation, coordinator assignment, quick-start card delivery, first login verification, first update verification, go-live confirmation
- **AND** each step has a date/name field for tracking completion

### Requirement: Error recovery guidance

User-facing documentation SHALL include plain-language troubleshooting for the three most common error scenarios.

#### Scenario: Coordinator can self-resolve common issues

- **WHEN** a coordinator encounters a problem (can't log in, unsure if saved, app says offline)
- **THEN** guidance is available on the quick-start card explaining what to do in each case
- **AND** the guidance includes who to contact if self-resolution fails
