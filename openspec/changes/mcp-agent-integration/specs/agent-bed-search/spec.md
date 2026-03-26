## NEW Requirements

### Requirement: agent-bed-search
The reference agent SHALL demonstrate natural language bed search where an outreach worker describes a client's needs in plain English and the agent translates to a structured search, presents results, and facilitates bed holds.

#### Scenario: Natural language search with constraints
- **WHEN** a worker says "I need a bed for a mom and two kids, she has a service dog, we're near Capital Blvd"
- **THEN** the agent parses: populationType=FAMILY_WITH_CHILDREN, constraints.petsAllowed=true, location near Capital Blvd (geocoded)
- **AND** calls `search_beds` with parsed parameters
- **AND** presents ranked results with shelter name, beds available, distance, and data freshness
- **AND** warns if any results have STALE or AGING data freshness

#### Scenario: Agent handles zero results gracefully
- **WHEN** the agent's `search_beds` call returns zero results
- **THEN** the agent suggests relaxing constraints (e.g., "No pet-friendly family shelters found within 5 miles. Would you like me to expand the search to 10 miles or remove the pet requirement?")
- **AND** offers to set up a proactive alert for when a matching bed opens

#### Scenario: Agent facilitates bed hold
- **WHEN** the worker selects a shelter from the results
- **THEN** the agent calls `create_reservation` for the selected shelter and population type
- **AND** displays: "Bed held at {shelter_name}. You have {minutes} minutes. Address: {address}. Phone: {phone}."
- **AND** starts a countdown reminder at the halfway mark

#### Scenario: Agent handles hold failure
- **WHEN** `create_reservation` returns 409 (no beds available)
- **THEN** the agent informs the worker: "That bed was just taken. Let me search again."
- **AND** automatically re-runs the search and presents updated results

#### Scenario: Agent uses person-first language
- **WHEN** presenting search results or hold confirmations
- **THEN** the agent uses person-first language throughout (e.g., "a family with children" not "family-type homeless")
- **AND** does not expose internal enum values (SINGLE_ADULT, DV_SURVIVOR) in user-facing text
