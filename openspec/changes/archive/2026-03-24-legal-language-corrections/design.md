## Context

An AI-assisted review (Claude, in a legal analysis persona — not a licensed attorney) identified 7 corrections to public-facing documents. All are text edits — no code, no architecture, no functional changes. The corrections qualify compliance claims, add disclaimers, explain legal reasoning, and acknowledge residual risk.

These are reasonable precautionary measures but have not been validated by qualified legal counsel. The project should seek licensed legal review before formal adoption conversations.

## Goals / Non-Goals

**Goals:**
- Qualify bare compliance claims so they can't be read as legal guarantees
- Add visible as-is warranty disclaimers to all public-facing pages
- Add "not legal advice" notice to the DV technical document
- Document the reasoning for warm handoff consent approach
- Honestly acknowledge the free-text PII risk

**Non-Goals:**
- Privacy policy document (future change: `legal-privacy-policy`)
- Government adoption legal guide (future change: `legal-government-adoption-guide`)
- Developer Certificate of Origin (future change: `legal-contributor-dco`)
- Automated PII scrubbing of the special needs field (engineering change, not documentation)
- Replacing the need for qualified legal counsel review

## Decisions

### D1: Qualifying language pattern

Replace "X compliant" with "Designed to support X compliance requirements" throughout. This accurately describes the architecture's intent without making a legal guarantee that would require per-jurisdiction validation.

### D2: Disclaimer placement

Disclaimers go in footers (demo pages) and as a dedicated `## Important Notice` section (technical documents). Footers are visible without scrolling on most pages. The Important Notice section is placed before the legal content it qualifies, not after.

### D3: Consent explanation format

Use blockquote (`>`) formatting to visually associate the VAWA consent explanation with the checklist item it qualifies. This keeps the checklist scannable while providing the reasoning an auditor would need.

### D4: Free-text risk acknowledgment

Use blockquote formatting below the stored/not-stored table. Honestly state that the advisory label is the only control and that 24-hour hard deletion mitigates but does not eliminate the risk.

### D5: Cross-repo consistency

Both repos get disclaimers with consistent language: "provided as-is under the Apache 2.0 License, without warranty of any kind." The DV-specific pages add "does not constitute legal advice."

### D6: Source attribution

The `legal-language-corrections-prompt.md` attributes findings to "Casey Drummond" — this is a Claude AI persona, not a licensed attorney. All artifacts and commit messages must accurately reflect that these corrections are AI-assisted, not attorney-reviewed.
