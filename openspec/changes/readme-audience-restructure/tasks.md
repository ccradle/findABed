## Tasks

### Setup

- [x] T-0: Create branch `feature/readme-audience-restructure` from `main` in the **code repo** (`finding-a-bed-tonight`). IMPORTANT: branch the code repo, NOT the docs repo (`findABed`).

### Content Extraction

- [x] T-1: Extracted 1,175 lines (Architecture through Troubleshooting) into `docs/FOR-DEVELOPERS.md` — architecture, module boundaries, database schema, API reference, running tests, observability, OAuth2 technical details, glossary, project structure, troubleshooting. Preserve all existing content without loss.
- [x] T-2: Verified — all 20 technical sections present in FOR-DEVELOPERS.md contains every section that was in the original README (checklist comparison)

### Audience Pages (Code Repo)

- [x] T-3: Write `docs/FOR-COORDINATORS.md` (109 lines) — plain English, zero jargon. Cover: what does this do, what does it cost, how to update bed count (3-tap flow), offline mode, who to call, how to get added. Written for Sandra Kim and Reverend Monroe's volunteers. (REQ-AUD-1)
- [x] T-4: Write `docs/FOR-COC-ADMINS.md` (146 lines) — HUD reporting, shelter onboarding (7-day workflow), DV protection in plain English, HMIS connectivity, deployment cost, support model. Written for Marcus Okafor. (REQ-AUD-2)
- [x] T-5: Write `docs/FOR-CITIES.md` (134 lines) — data ownership, WCAG conformance (link to ACR), security posture (link to ZAP baseline), Apache 2.0 procurement, support model, comparison to alternatives. Written for Teresa Nguyen and her city attorney. Draw from existing government-adoption-guide.md. (REQ-AUD-3)
- [x] T-6: Write `docs/FOR-FUNDERS.md` (86 lines) — parking lot story first, theory of change, sustainability model, who uses it, what funding enables, contact for letters of support. Written for Priya Anand's foundation board. Draw from existing theory-of-change.md and sustainability-narrative.md. (REQ-AUD-5)

### README Restructure (Code Repo)

- [x] T-7: Restructured README from 1,300 to 123 lines — parking lot story first, audience routing in 25 lines to ~200 lines — parking lot story, "No more midnight phone calls," What It Does, Who It's For (5 audience links), Quick Start (condensed), Demo Walkthroughs, Project Status (condensed), Tech Stack, License. (REQ-NAV-1 through REQ-NAV-5)
- [x] T-8: Verified — each page has 7-12 sections answering its audience's key questions — each answers its audience's questions without requiring other pages (REQ-AUD-6)

### Docs Repo Updates

- [x] T-9: Updated docs repo README — parking lot story + "No more midnight phone calls" added before badges — lead with parking lot story and "No more midnight phone calls" before OpenSpec workflow (REQ-NAV-7)
- [x] T-10: Written PITCH-BRIEFS.md — 4 audience briefs + universal headline in docs repo — 90-second briefs for coordinator, CoC admin, city official, funder audiences (content from COMMUNICATIONS-RECOMMENDATIONS.md Part 4) (REQ-AUD-7)

### Verification

- [x] T-11: All 17 links verified (15 file links OK, 2 anchor links verified) in the restructured README and all 5 audience pages
- [ ] T-12: Commit, push, CI green
- [ ] T-13: Merge to main, tag
