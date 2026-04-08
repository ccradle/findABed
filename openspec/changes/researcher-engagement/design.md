## Context

The FABT platform captures 18 database tables of operational shelter data across bed availability, search demand, reservations, DV referrals, surge events, HMIS integration, and administrative audit trails — all with zero client PII by design. Researchers need to understand what data exists, how to access it, what it can and cannot tell them, and what ethical/IRB considerations apply.

The platform does not prescribe research questions or metrics. It describes the data available and lets researchers bring their own domain expertise, study designs, and questions. Independence produces more credible research than confirmation of the platform's own hypotheses.

## Goals / Non-Goals

**Goals:**
- Create a comprehensive FOR-RESEARCHERS.md that a university PI can hand to their IRB
- Provide a complete data inventory: every table, what it captures, what it doesn't, retention policies
- Define three data access tiers (open aggregate, minimum-cell-protected, restricted DV)
- State IRB implications honestly — "likely exempt" not "exempt"
- Describe honest limitations — what the platform cannot tell you
- Add researcher row to "Who It's For" on README and findabed.org
- Target SEO keywords researchers actually search for

**Non-Goals:**
- Prescribing research questions, metrics, or study designs (researchers innovate, we provide data)
- Building a researcher data portal or API (access via CoC admin exports)
- Creating a data use agreement template (deploying CoC's legal counsel handles this)
- Publishing any FABT data directly (data belongs to the deploying CoC, not the project)
- Anonymization infrastructure (data is de-identified by design — no client PII exists)

## Design Decisions

### D1: Data Inventory, Not Research Agenda

The FOR-RESEARCHERS document describes what data exists and how to access it. It does not suggest what to study, what metrics to track, or what hypotheses to test. Researchers bring domain expertise; we provide the instrument. This produces independent, credible research — not confirmation of platform claims.

### D2: Three Data Access Tiers

| Tier | Content | Access | IRB Implication |
|------|---------|--------|----------------|
| **Open** | Bed availability snapshots, daily utilization summaries, search demand logs (zero-result counts), surge events, shelter metadata (no phone numbers, DV shelter addresses excluded) | CoC admin export, analytics dashboard | Likely exempt — de-identified aggregate, no human subjects |
| **Protected** | Reservation lifecycle data (conversion/expiry rates by population type), referral aggregates (urgency splits, response times), audit event counts | CoC admin export with minimum cell size (n≥5) | May require expedited review — aggregate but population-type-specific |
| **Restricted** | DV shelter identities, free-text fields (notes, special_needs, rejection_reason), individual referral records within 24h retention window | DV protocol + CoC DV committee approval + researcher IRB full review | Full IRB review required; data use agreement mandatory |

### D3: Honest Limitations

The document must explicitly state what FABT cannot tell researchers:
- No client demographics beyond population type
- No outcome data (did the person remain housed?)
- No barrier/eligibility data (what prevented placement?)
- No service provision data (mental health, substance abuse treatment)
- No cost/budget data
- No discharge location data
- DV referral terminal states hard-deleted within 24 hours
- Free-text fields (notes, special_needs) may contain inadvertent PII — require content review before research use
- Append-only bed_availability grows indefinitely — query performance at scale not yet characterized in production

### D4: IRB Guidance Framing

Frame as: "FABT stores no client PII by design. The platform captures operational shelter data — bed counts, search demand, hold lifecycle — not client records. For most research designs using aggregate FABT exports, IRB review is likely to be expedited or exempt under 45 CFR 46.104(d)(4) (secondary analysis of de-identified data). Researchers should consult their institution's IRB for determination."

Do NOT claim IRB exemption — say "likely exempt" and direct to their institution. This is Casey Drummond's guidance: no legal claims, only factual descriptions.

### D5: Pilot Partnership Pathway

Describe the pathway without prescribing the study:
1. Researcher identifies a deploying CoC willing to participate
2. CoC admin grants researcher a COC_ADMIN account with analytics access
3. Researcher's institution obtains IRB determination
4. If DV data needed: CoC DV committee review + data use agreement
5. Data export via analytics dashboard or API (CSV, JSON)
6. FABT project team available for technical questions about data model — not study design

### D6: SEO Strategy (Nadia Petrova)

Target keywords for academic discoverability:
- "real-time shelter bed availability data"
- "homeless shelter coordination system evaluation"
- "emergency shelter bed tracking open source"
- "CoC system performance data"
- "unmet demand homelessness data"
- "shelter bed utilization research"

Page structure optimized for academic search: H1 with primary keyword, structured data (schema.org Dataset markup), clear methodology section that Google Scholar can index.

### D7: Findabed.org Integration

Add to the "Who It's For" table:
- Row: "Researcher or evaluator → For Researchers — data inventory, access tiers, IRB guidance, pilot partnership"
- Static HTML page on findabed.org mirroring the GitHub doc with SEO markup
- No authentication required — public-facing, discoverable
