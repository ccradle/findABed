## NEW Requirements

### Requirement: agent-proactive-alerting
The reference agent SHALL demonstrate webhook-driven proactive alerting where an outreach worker requests notification when a bed matching specific criteria becomes available.

#### Scenario: Worker sets up a bed watch
- **WHEN** a worker says "Notify me when a wheelchair-accessible family bed opens within 5 miles of Moore Square"
- **THEN** the agent parses the criteria and calls `subscribe_to_events` with event type `availability.updated`, population type filter, constraint filter, and bounding box
- **AND** confirms: "I'll notify you when a wheelchair-accessible family bed opens near Moore Square. This watch expires in 24 hours."

#### Scenario: Agent receives webhook and notifies worker
- **WHEN** a shelter updates availability and the webhook fires
- **AND** the updated availability matches the subscription criteria (beds_available > 0, constraints match)
- **THEN** the agent notifies the worker: "{shelter_name} just reported {n} family beds available. Wheelchair accessible. Data updated {minutes} ago."
- **AND** offers: "Would you like me to hold one?"

#### Scenario: Agent handles subscription expiry
- **WHEN** a subscription reaches its expiry time
- **THEN** the agent notifies the worker: "Your bed watch for wheelchair-accessible family beds near Moore Square has expired. Would you like me to renew it?"

#### Scenario: Worker cancels a watch
- **WHEN** a worker says "Cancel my bed watch"
- **THEN** the agent calls `list_subscriptions` to find active watches
- **AND** if multiple, asks which to cancel
- **AND** calls the backend to deactivate the subscription
- **AND** confirms: "Bed watch cancelled."
