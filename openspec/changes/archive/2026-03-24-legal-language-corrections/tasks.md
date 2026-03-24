## 1. Correction 1 — DV Demo Page: Qualify Compliance Claim

- [x] 1.1 In `findABed/demo/dvindex.html`: replace "VAWA/FVPSA compliant. Human-in-the-loop safety screening." with "Designed to support VAWA/FVPSA compliance requirements. Human-in-the-loop safety screening. DV shelter operators should consult qualified legal counsel regarding their specific compliance obligations."
- [x] 1.2 Style the legal counsel advisory as a secondary line if needed for visual fit

## 2. Correction 2 — DV Demo Page: Disclaimer Footer

- [x] 2.1 In `findABed/demo/dvindex.html` footer: add disclaimer text — "Finding A Bed Tonight is provided as-is under the Apache 2.0 License, without warranty of any kind. This documentation does not constitute legal advice. Organizations deploying FABT for DV referrals should consult qualified legal counsel regarding applicable federal, state, and local confidentiality requirements."
- [x] 2.2 Style consistently with existing footer text, placed below the existing footer line

## 3. Correction 3 — Main Demo Page: Disclaimer Footer

- [x] 3.1 In `findABed/demo/index.html` footer: add disclaimer text — "Finding A Bed Tonight is provided as-is under the Apache 2.0 License, without warranty of any kind. Availability data is supplied by shelter operators and may not reflect current conditions. This platform is not a guarantee of shelter availability."
- [x] 3.2 Style consistently with existing footer text

## 4. Correction 4 — DV-OPAQUE-REFERRAL.md: Important Notice Section

- [x] 4.1 In `finding-a-bed-tonight/docs/DV-OPAQUE-REFERRAL.md`: insert new `## Important Notice` section between Purpose and Legal Basis
- [x] 4.2 Content: technical reference disclaimer, bold "This document does not constitute legal advice." statement, counsel advisory, jurisdiction variability note, independent verification recommendation

## 5. Correction 5 — DV-OPAQUE-REFERRAL.md: Consent Reasoning

- [x] 5.1 In `finding-a-bed-tonight/docs/DV-OPAQUE-REFERRAL.md`: after the consent checklist item, insert blockquote explaining why verbal consent at warm handoff satisfies VAWA (warm handoff is not a disclosure to outside entities, no PII flows through FABT, consent obtained during call itself)
- [x] 5.2 Include advisory that organizations with specific consent policy requirements should consult their VAWA administrator or legal counsel

## 6. Correction 6 — DV-OPAQUE-REFERRAL.md: Free-Text PII Risk Note

- [x] 6.1 In `finding-a-bed-tonight/docs/DV-OPAQUE-REFERRAL.md`: below the stored/not-stored table, insert blockquote acknowledging that the special needs field accepts free text and the UI advisory is the only control
- [x] 6.2 Note that 24-hour hard deletion mitigates but does not eliminate the risk, and that staff training should cover this field

## 7. Correction 7 — Docs Repo README: License Disclaimer

- [x] 7.1 In `findABed/README.md`: add blockquote disclaimer in the License section — as-is warranty, data accuracy disclaimer, link to Apache 2.0 License
- [x] 7.2 Ensure the disclaimer is visible on the GitHub Pages rendered page

## 8. Commit and Push

- [x] 8.1 Commit docs repo changes (dvindex.html, index.html, README.md) with accurate attribution (AI-assisted review, not attorney-reviewed)
- [x] 8.2 Commit code repo changes (DV-OPAQUE-REFERRAL.md) with accurate attribution
- [x] 8.3 Push both repos to GitHub
