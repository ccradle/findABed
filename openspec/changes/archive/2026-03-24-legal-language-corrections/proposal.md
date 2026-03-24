## Why

An AI-assisted review of public-facing documents identified language that could create legal exposure. The review was conducted using Claude (Anthropic) in a legal analysis persona — not by a licensed attorney. The findings are reasonable and precautionary, but have not been validated by qualified legal counsel.

The identified issues:

- The DV demo page states "VAWA/FVPSA compliant" — a bare compliance claim that could be read as a legal guarantee. State-level implementation varies beyond the federal baseline.
- Neither demo page (main or DV) has an as-is warranty disclaimer or a "not legal advice" notice.
- The DV-OPAQUE-REFERRAL.md technical document opens with a federal law compliance table but no disclaimer that it isn't legal advice. A DV shelter relying on it could argue they were given legal assurance.
- The warm handoff consent checklist item doesn't explain *why* verbal consent satisfies VAWA.
- The free-text "Special needs" field is acknowledged as stored data but the residual PII risk from user input isn't documented.
- The docs repo GitHub Pages site has no visible warranty language.

These corrections are precautionary — qualifying claims, adding disclaimers, and documenting reasoning. They should be applied before outreach conversations with DV shelter operators and city officials. The project should also seek review from qualified legal counsel before formal adoption conversations.

## What Changes

- **Correction 1**: Replace "VAWA/FVPSA compliant" with "Designed to support VAWA/FVPSA compliance requirements" + legal counsel advisory on `dvindex.html`
- **Correction 2**: Add as-is/not-legal-advice disclaimer footer to `dvindex.html`
- **Correction 3**: Add as-is/no-guarantee disclaimer footer to `demo/index.html`
- **Correction 4**: Add "Important Notice" disclaimer section to `docs/DV-OPAQUE-REFERRAL.md` between Purpose and Legal Basis
- **Correction 5**: Add VAWA consent reasoning blockquote to the compliance checklist in `docs/DV-OPAQUE-REFERRAL.md`
- **Correction 6**: Add free-text PII risk note below the stored/not-stored table in `docs/DV-OPAQUE-REFERRAL.md`
- **Correction 7**: Add disclaimer to License section of docs repo `README.md`

No functional changes. No architecture changes. No code changes. Documentation and public-facing text only.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
(none — documentation only)

## Impact

- **Modified files**: `findABed/demo/dvindex.html`, `findABed/demo/index.html`, `finding-a-bed-tonight/docs/DV-OPAQUE-REFERRAL.md`, `findABed/README.md`
- **Total files**: 4 files across 2 repos
- **No code changes**: Text corrections only
- **Risk**: None — additive text changes that reduce potential legal exposure
- **Note**: These corrections are based on an AI-assisted review, not licensed legal counsel. The project should seek qualified legal review before formal adoption conversations with city attorneys or CoC legal staff.
