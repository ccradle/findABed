## ADDED Requirements

### Requirement: public-facing-legal-disclaimers
All public-facing pages and DV-related technical documents SHALL include appropriate disclaimers qualifying compliance claims, stating as-is warranty posture, and noting that the documentation does not constitute legal advice. These disclaimers are based on an AI-assisted review and should be validated by qualified legal counsel before formal adoption conversations.

#### Scenario: DV demo page compliance claim is qualified
- **WHEN** a visitor views `dvindex.html`
- **THEN** the tagline reads "Designed to support VAWA/FVPSA compliance requirements" (not "VAWA/FVPSA compliant")
- **AND** a note advises DV shelter operators to consult qualified legal counsel

#### Scenario: DV demo page has disclaimer footer
- **WHEN** a visitor scrolls to the footer of `dvindex.html`
- **THEN** they see an as-is warranty notice and a "does not constitute legal advice" statement

#### Scenario: Main demo page has disclaimer footer
- **WHEN** a visitor scrolls to the footer of `index.html`
- **THEN** they see an as-is warranty notice and a data accuracy disclaimer

#### Scenario: DV addendum has Important Notice section
- **WHEN** a reader opens `docs/DV-OPAQUE-REFERRAL.md`
- **THEN** an "Important Notice" section appears between Purpose and Legal Basis
- **AND** it states the document does not constitute legal advice

#### Scenario: Warm handoff consent reasoning is documented
- **WHEN** a reader reviews the VAWA Compliance Checklist in `docs/DV-OPAQUE-REFERRAL.md`
- **THEN** the consent checklist item includes a blockquote explaining the reasoning for verbal consent at warm handoff

#### Scenario: Free-text PII risk is acknowledged
- **WHEN** a reader reviews the stored/not-stored table in `docs/DV-OPAQUE-REFERRAL.md`
- **THEN** a risk note below the table acknowledges that the special needs field cannot guarantee PII-free content

#### Scenario: Docs repo has visible warranty disclaimer
- **WHEN** a visitor views the docs repo README on GitHub Pages
- **THEN** a disclaimer is visible in the License section stating as-is warranty posture
