## MODIFIED Requirements

### Requirement: analytics-admin-dashboard
MODIFY: Add accessibility support to the analytics dashboard.

#### Scenario: Charts have accessible table alternative
- **WHEN** a screen reader user views the utilization trends section
- **THEN** a "Show as table" toggle renders the chart data as an accessible HTML table

#### Scenario: Map has accessible table alternative
- **WHEN** a screen reader user views the geographic section
- **THEN** map tiles are hidden from screen readers via aria-hidden
- **AND** a toggle button provides the table fallback regardless of tile load status

#### Scenario: Chart animations respect motion preference
- **WHEN** the user's OS has prefers-reduced-motion: reduce set
- **THEN** Recharts chart animations are disabled
