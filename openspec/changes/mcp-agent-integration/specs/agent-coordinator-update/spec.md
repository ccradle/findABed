## NEW Requirements

### Requirement: agent-coordinator-update
The reference agent SHALL demonstrate text/voice-driven bed count updates where a shelter coordinator describes changes in natural language and the agent translates to availability snapshots.

#### Scenario: Coordinator describes check-ins
- **WHEN** a coordinator says "Three families checked in tonight, one single adult left"
- **THEN** the agent parses: FAMILY_WITH_CHILDREN bedsOccupied +3, SINGLE_ADULT bedsOccupied -1
- **AND** calls `get_shelter_detail` to get current counts
- **AND** computes new values: current bedsOccupied + delta for each population type
- **AND** presents: "I'll update Oak City Shelter: Families occupied 31→34, Singles occupied 38→37. Confirm?"

#### Scenario: Agent requires confirmation before update
- **WHEN** the agent has computed the new bed counts
- **THEN** the agent presents the changes and waits for explicit confirmation
- **AND** only calls `submit_availability` after the coordinator confirms
- **AND** displays: "Updated. Families: 34 occupied of 40 total (6 available). Singles: 37 occupied of 50 (13 available)."

#### Scenario: Agent catches invariant violation
- **WHEN** the computed update would violate an invariant (e.g., bedsOccupied > bedsTotal)
- **THEN** the agent warns: "That would put families at 42 occupied but you only have 40 total beds. Did you mean something different?"
- **AND** does NOT submit the update

#### Scenario: Coordinator specifies shelter by name
- **WHEN** a coordinator assigned to multiple shelters says "At Women of Hope, five new guests tonight"
- **THEN** the agent matches "Women of Hope" to the shelter list
- **AND** calls `get_shelter_detail` for the matched shelter
- **AND** proceeds with the update flow

#### Scenario: Coordinator assigned to one shelter
- **WHEN** a coordinator assigned to a single shelter says "Two guests left"
- **THEN** the agent infers the shelter from the coordinator's assignment
- **AND** does not ask which shelter
