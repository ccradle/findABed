## Tasks

### FOR-RESEARCHERS.md — Data Inventory

- [ ] T-1: Create `docs/FOR-RESEARCHERS.md` with document structure: Introduction, What FABT Captures, Data Access Tiers, Honest Limitations, IRB Guidance, Pilot Partnership Pathway, Free-Text Field Warning
- [ ] T-2: Write data inventory — Tier 1 (Open): bed_availability, daily_utilization_summary, bed_search_log, surge_event, shelter (no phone), shelter_constraints. For each: what it captures, sample research questions it could support, what it cannot answer, retention policy.
- [ ] T-3: Write data inventory — Tier 2 (Protected): reservation lifecycle, referral_token aggregates, audit_events aggregates, coordinator_assignment, import_log. Include minimum cell size (n≥5) note.
- [ ] T-4: Write data inventory — Tier 3 (Restricted): DV shelter identities, free-text fields (notes, special_needs, rejection_reason), individual referral records (24h window). Include DV protocol + IRB + data use agreement requirements.
- [ ] T-5: Write Honest Limitations section — no client demographics, no outcomes, no barriers, no service provision, no cost data, no discharge location. Frame as: "FABT is an operational coordination tool, not a client management system."
- [ ] T-6: Write IRB Guidance section — reference 45 CFR 46.104(d)(4), say "likely exempt" not "exempt," direct to institutional IRB. Casey Drummond review: no legal claims, only factual data characteristics.
- [ ] T-7: Write Pilot Partnership Pathway — steps without prescribing study design: identify CoC, obtain analytics access, IRB determination, DV committee if applicable, data export.
- [ ] T-8: Write Free-Text Field Warning — list all free-text fields, explain PII risk, recommend excluding from studies that don't require them.
- [ ] T-9: Write Data Retention table — all tables with retention policies (indefinite, 24h purge, cleanup schedules)
- [ ] T-10: Legal language review — scan document for "compliant," "certified," "guarantees," "zero PII" unqualified. Apply Casey Drummond guardrails.

### README + Landing Page Updates

- [ ] T-11: Add fifth row to README.md "Who It's For" table: "Researcher or evaluator → For Researchers — data inventory, access tiers, IRB guidance"
- [ ] T-12: Create findabed.org static HTML page for researchers — mirrors FOR-RESEARCHERS.md content, SEO-optimized
- [ ] T-13: Add researcher card to findabed.org landing page "Who It's For" section
- [ ] T-14: Add schema.org Dataset structured data (JSON-LD) to researcher page — title, description, distribution format, license
- [ ] T-15: SEO: meta title "Emergency Shelter Bed Availability Data for Researchers | Finding A Bed Tonight", meta description targeting long-tail academic keywords

### Verification

- [ ] T-16: Persona review — Dr. Yemi Okafor: does the document describe data without prescribing research? Dr. Kenji Watanabe: are HUD data standards correctly referenced? Casey: no legal claims? Nadia Petrova: SEO keywords present?
- [ ] T-17: Legal language scan — run `infra/scripts/legal-language-scan.sh` against the new document
- [ ] T-18: Verify findabed.org researcher page renders correctly, links work, dark mode compatible
- [ ] T-19: Google Search Console — submit new page for indexing after deploy
- [ ] T-20: Commit, push, deploy static content to findabed.org
