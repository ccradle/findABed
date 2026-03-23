# Privacy-Preserving Referral Systems for DV Shelters: Research Findings

**Research Date:** 2026-03-23
**Purpose:** Inform the design of a privacy-preserving DV shelter referral system in the FABT open-source bed availability platform.

---

## 1. Federal Laws Governing DV Shelter Data Protection

### 1.1 VAWA Confidentiality Provisions (34 U.S.C. 12291(b)(2))

VAWA's confidentiality provision is the cornerstone federal protection. It applies to **all grantees and subgrantees** receiving VAWA funding from the DOJ Office on Violence Against Women.

**Core requirements:**
- Grantees must protect the confidentiality and privacy of persons receiving services
- Non-disclosure of **personally identifying information (PII)** is mandated
- Release requires **informed, written, reasonably time-limited consent**
- Programs **cannot** make signing a release a condition of service
- Information **cannot** be disclosed "regardless of whether the information has been encoded, encrypted, hashed, or otherwise protected" (this is critical for any technical system design)

**Exceptions are narrow:**
- Compelled by specific court order or statute
- If release is required, grantee must notify the victim and take steps to protect safety and privacy
- Permissive child abuse reporting is **not** a mandate and is **not** allowed under VAWA

**VAWA 2022 Reauthorization updates:**
- Added definitions for "technological abuse" and "economic abuse"
- Strengthened: "Any information submitted...shall be maintained in confidence and may not be entered into any shared database or disclosed to any other entity or individual"
- Added a new data collection component with stronger confidentiality measures

**Sources:**
- [DOJ FAQ on VAWA Confidentiality Provision](https://www.justice.gov/ovw/page/file/1006896/download)
- [Safety Net Project: Confidentiality in VAWA, FVPSA, and VOCA](https://www.techsafety.org/confidentiality-in-vawa-fvpsa)
- [VAWA, VOCA, and FVPSA Comparison Chart](https://victimrights.org/wp-content/uploads/2022/07/VAWA-VOCA-FVPSA-Comparison-Chart.pdf)

### 1.2 FVPSA (Family Violence Prevention and Services Act)

FVPSA adds additional protections specifically for shelter programs:

- Individual identifiers **must not** be used when providing statistical data on program activities
- Confidentiality of records pertaining to any individual provided family violence services must be **strictly maintained**
- **Shelter location confidentiality**: The address or location of any shelter supported under FVPSA may not be made public without written authorization of the person(s) operating the shelter
- States and subgrantees may share information that has been **aggregated and does not identify individuals**

**Sources:**
- [45 CFR Part 1370 - FVPSA Programs](https://www.ecfr.gov/current/title-45/subtitle-B/chapter-XIII/subchapter-H/part-1370)
- [Federal Register: FVPSA Programs Final Rule](https://www.federalregister.gov/documents/2016/11/02/2016-26063/family-violence-prevention-and-services-programs)

### 1.3 HMIS DV Exceptions

HUD explicitly prohibits DV providers from entering client data into shared HMIS:

- **Victim Service Providers (VSPs)** that are recipients or subrecipients of CoC/ESG funds are **prohibited from recording survivor information in HMIS**
- VSPs must instead use a **Comparable Database** (see Section 2)
- This prohibition stems directly from VAWA and FVPSA confidentiality provisions
- NNEDV helped draft provisions in VAWA 2005 that protect shelters from requirements to share PII with third-party databases including HMIS

**History:** In 2004, HUD published a clarification notice acknowledging that DV providers needed special treatment. The original HMIS mandate (effective August 2004) created safety concerns because "victims are at greatest risk of further violence immediately after fleeing an abusive relationship" and abusers could potentially locate them through HMIS via employee disclosure, law enforcement exemptions, or database security problems.

**Sources:**
- [HUD Exchange: HMIS Comparable Database Manual](https://www.hudexchange.info/resource/6305/hmis-comparable-database-manual/)
- [HUD Exchange: When to Use a Comparable Database](https://www.hudexchange.info/resource/5743/hmis-when-to-use-a-comparable-database/)
- [2004 HMIS Clarification for DV Shelters](https://www.hudexchange.info/resource/1319/2004-hmis-standards-final-notice-and-provisions-domestic-violence/)
- [EPIC Coalition Comments on HMIS](https://archive.epic.org/privacy/poverty/hmiscomments.html)

### 1.4 42 CFR Part 2 Overlap (Substance Abuse Confidentiality)

42 CFR Part 2 becomes relevant when DV shelters provide substance abuse treatment:

- Applies to **any federally assisted program** that provides SUD diagnosis, treatment, or referral for treatment
- "Federally assisted" is defined broadly to include indirect federal aid such as tax-exempt status
- The determining factor is "the kind of services provided, not the label" of the program
- When a DV shelter provides SUD services, it must comply with **both** VAWA/FVPSA **and** 42 CFR Part 2 -- the stricter standard applies
- The 2024 final rule aligns Part 2 more closely with HIPAA but maintains stronger protections for SUD records
- Compliance with updated Part 2 rules was required by **February 16, 2026**

**Design implication:** If FABT ever handles referrals to DV shelters that also provide SUD treatment, the system must be designed to the strictest standard (Part 2), which prohibits disclosure without consent even to other treating providers.

**Sources:**
- [42 CFR Part 2 (eCFR)](https://www.ecfr.gov/current/title-42/chapter-I/subchapter-A/part-2)
- [NCBI Bookshelf: Federal Confidentiality Regulations - Substance Abuse and DV](https://www.ncbi.nlm.nih.gov/books/NBK64435/)
- [HHS: Understanding Part 2](https://www.hhs.gov/hipaa/for-professionals/special-topics/hipaa-part-2/index.html)

### 1.5 HIPAA Applicability

HIPAA applies to **covered entities** (health plans, clearinghouses, health care providers). Most DV shelters are **not** covered entities unless they operate healthcare services.

- DV shelters generally are **not** subject to HIPAA unless they have a direct relationship with healthcare facilities or operate as healthcare providers
- However, HIPAA's Privacy Rule at **164.512(c)** allows covered entities to disclose PHI about abuse victims to authorized government authorities -- this is a **permissive** disclosure, not mandatory
- HUD's HMIS privacy standards were developed after careful review of HIPAA standards and in many cases exceed HIPAA requirements for DV data

**Design implication:** FABT should not assume HIPAA covers DV shelters, but should design to VAWA/FVPSA standards which are generally **stricter** than HIPAA for DV data.

**Sources:**
- [HIPAA Privacy Call for DV and SA Advocates](https://vawnet.org/material/hipaa-privacy-call-domestic-violence-and-sexual-assault-advocates)
- [2004 Federal Register: HMIS Special Provisions for DV](https://www.federalregister.gov/documents/2004/10/19/04-23438/homeless-management-information-systems-hmis-data-and-technical-standards-final-notice-clarification)

---

## 2. HUD-Specific Guidance

### 2.1 Comparable Databases vs. HMIS

A **Comparable Database** is "an alternative system that victim service providers use to collect client-level data over time and to generate aggregate reports." It is the **mandatory** system for any VSP receiving CoC or ESG funding.

**Key differences from HMIS:**

| Aspect | HMIS | Comparable Database |
|--------|------|-------------------|
| Data sharing | Shared among CoC providers | VSP maintains exclusive access/control |
| PII in shared systems | Entered into shared database | **Prohibited** -- data stays isolated |
| Access control | CoC-level administration | VSP controls all access |
| Vendor contracts | CoC-level | Must include binding agreements ensuring program control over client data |
| Standards | HMIS Data Standards | Must meet or **exceed** HMIS privacy/security standards |

**Technical requirements for Comparable Databases:**
- Relational database meeting all HMIS Data Standards
- Must meet minimum HMIS privacy and security requirements (may use stricter standards)
- Must de-duplicate client records within the system
- Must generate CSV files for SAGE APR reporting
- Must produce all HUD-required reports (APR, CAPER)
- Compatible systems include: Bitfocus Clarity, ServicePoint, Osnium WS, Empower DB

**Sources:**
- [Safety Net: Comparable Database 101](https://www.techsafety.org/comparable-database-101)
- [HUD Exchange: HMIS Comparable Database Manual](https://www.hudexchange.info/resource/6305/hmis-comparable-database-manual/)

### 2.2 Data Sharing Rules

**What CANNOT be shared:**
- Any PII of survivors
- Information that could identify individuals even when aggregated
- HIV/AIDS status, DV history, behavioral health/substance use information via HMIS
- Shelter location (without written authorization of the operator)

**What CAN be shared:**
- Non-personally-identifying aggregate data and demographics
- De-identified assessment scores for prioritization lists
- Aggregate bed counts for HIC/PIT reporting

**De-identification requirements:**
- Suppress aggregate data on specific client characteristics if they would be personally identifying (small numbers problem)
- DV providers exempt from entering address information; only required to enter ZIP code and geocode
- Individual survivor data must be "routinely destroyed as soon as the program no longer needs it"

**Sources:**
- [Safety Net: Comparable Database 101](https://www.techsafety.org/comparable-database-101)
- [COHHIO: DV Data Collection Protocols](https://cohhio.org/wp-content/uploads/2021/04/DV-Data-Collection-Protocols.pdf)

---

## 3. State-by-State Variations

### 3.1 States with Stricter Laws Than Federal

Many states have enacted protections that **exceed** federal requirements:

- **19 states** treat information on the location of safe houses as confidential by statute, including California, New York, and Texas
- A significant majority of states have statutes protecting communications between DV/SA service providers and victims (advocate-victim privilege)
- Even without a state confidentiality statute, federal VAWA/FVPSA requirements still apply

### 3.2 Address Confidentiality Programs (ACPs)

ACPs allow survivors to use a substitute address in government records. The ACP landscape as of 2024:

- **40+ states** have Address Confidentiality Programs
- 23 states require the survivor to demonstrate fear for safety for eligibility
- Programs are typically administered by the Secretary of State or Attorney General
- ACP substitute addresses are legally valid for voter registration, school enrollment, and other government interactions
- Certification typically lasts **4 years** and is renewable

**Comprehensive state listing:** [ACP Programs by State (Arizona SoS, 2024)](https://azsos.gov/sites/default/files/docs/ACP_Throughout_the_United_States.pdf)

**Source:** [State Address Confidentiality Statutes (BWJP, 2023)](https://bwjp.org/wp-content/uploads/2024/05/NCPOFFC-State-Address-Confidentality-Statutes.pdf)

### 3.3 No States Prohibit Digital Referral Systems

Research found **no state that explicitly prohibits** digital referral systems for DV shelters. However:

- All digital systems must comply with federal VAWA/FVPSA confidentiality requirements
- Systems must not reveal shelter locations
- Digital consent has specific requirements (see Section 4.5)
- COVID-19 accelerated adoption of digital tools for DV services, and the trend continued post-pandemic

### 3.4 State-Specific Details

#### North Carolina (FABT's Operating State)

NC has multiple layers of DV data protection:

1. **G.S. 8-53.12 -- Advocate Privilege**: Communications between DV program agents and victims are privileged. An "agent" must complete minimum 20 hours of training. No agent shall be required to disclose information acquired during provision of services. Privilege terminates upon death of the victim.

2. **Chapter 15C -- Address Confidentiality Program**: Operated by the NC Attorney General. Provides substitute addresses for 4-year renewable terms. Actual address/phone are "not a public record." Law enforcement and courts can access actual addresses. School districts must use actual addresses for admission but substitute in records.

3. **Chapter 50B -- Domestic Violence**: Establishes protective orders, shelter immunity provisions, and related protections.

4. **Counselor confidentiality exceptions** (narrowly defined):
   - To protect victim or someone else from immediate danger
   - Sharing with other employees at the DV program
   - Statistical/research use without PII
   - Upon death of the victim

**Sources:**
- [NC G.S. 8-53.12](https://www.ncleg.net/enactedlegislation/statutes/html/bysection/chapter_8/gs_8-53.12.html)
- [NC Chapter 15C - Address Confidentiality](https://ncleg.gov/EnactedLegislation/Statutes/HTML/ByChapter/Chapter_15C.html)
- [WomensLaw: NC Confidentiality](https://www.womenslaw.org/laws/nc/confidentiality)
- [NC Privacy, Privilege, and Confidentiality (NCVLI)](https://ncvli.org/wp-content/uploads/2024/01/Privacy-Privilege-and-Confidentiality-North-Carolina.pdf)

#### California

- **Evidence Code 1037-1037.8**: Establishes a strong **DV Counselor-Victim Privilege**. A victim can refuse to disclose and prevent others from disclosing confidential communications. DV counselor must have at least 40 hours of training. Courts may review claims of privilege in chambers. If privileged, neither the judge nor any other person may disclose.
- **Safe at Home (ACP)**: Run by the Secretary of State, provides substitute addresses

**Source:** [CA Evidence Code 1037](https://law.justia.com/codes/california/code-evid/division-8/chapter-4/article-8-7/section-1037/)

#### New York

- **Social Services Law 459-g**: Addresses confidentiality of residential program location, including in funding applications
- If a party has resided in a residential DV program, **neither the party's address nor the program's address may be revealed** in court proceedings
- Courts must authorize parties to keep addresses confidential where disclosure would pose unreasonable risk
- ACP administered by the Department of State

**Sources:**
- [Empire Justice Center: NY DV Confidentiality Laws](https://empirejustice.org/resources_post/new-york-laws-involving-the-confidentiality-of-domestic-violence-victim-relates-information/)
- [NY ACP FAQ](https://dos.ny.gov/system/files/documents/2018/09/address-confidentiality-program-frequently-asked-questions-participant.pdf)

#### Texas

- **Penal Code 42.075**: Makes it a **criminal offense** (Class A misdemeanor) to disclose or publicize the location or physical layout of a family violence shelter center with intent to threaten the safety of inhabitants. Penalty: up to 1 year in jail and $4,000 fine.
- Locations and physical layouts of DV centers are explicitly **confidential by statute**

**Source:** [TX Penal Code 42.075](https://texas.public.law/statutes/tex._penal_code_section_42.075)

---

## 4. Technology Patterns for Privacy-Preserving Referrals

### 4.1 How Existing HMIS Vendors Handle DV Referrals

**Bitfocus Clarity Human Services:**
- Can operate as a fully compliant, standalone comparable database for VSPs
- Privacy features include:
  - Client names can be made private, known only by a **system-assigned unique identifier**
  - Contact information can be made entirely private
  - Program and service history can be removed/hidden
  - Role-based access control (read/write/edit/delete per area)
  - Client notes restricted to authorized users
  - Assessments and referral history toggleable for privacy
- Compliance: VAWA, HIPAA, VOCA, exceeds HUD HMIS standards
- Generates CSV for SAGE APR reporting

**WellSky (formerly Mediware/Bowman Systems):**
- Offers ServicePoint as HMIS-compliant software
- Available as a comparable database option in some jurisdictions
- Specific DV referral workflow details not publicly documented

**CaseWorthy:**
- Markets specific DV/survivor services modules
- Provides seamless client referrals with support organization communication
- Tools for hotline intake, demographics tracking, crisis communication

**Sources:**
- [Bitfocus: Domestic Violence Solutions](https://www.bitfocus.com/domestic-violence-solutions)
- [CaseWorthy: Survivor Services](https://caseworthy.com/who-we-serve/survivor-services/)

### 4.2 The "Warm Handoff" Pattern

The warm handoff is the standard referral pattern for DV services. It requires **human intermediation** rather than automated placement:

1. **Access point** (hotline, 211, walk-in) receives initial contact
2. Staff performs safety screening and determines DV situation
3. Staff **contacts the DV provider directly** (phone call) rather than sending client information electronically
4. DV provider confirms availability and suitability
5. Client is connected with DV provider, who conducts their own intake
6. Referring party does **not** receive the shelter location

This is fundamentally different from general homeless services referrals where automated placement from a prioritization list is common.

### 4.3 Opaque Referral Patterns

For coordinated entry systems that include DV:

- **De-identified prioritization**: Only de-identified information and assessment score are provided for inclusion on prioritization lists. The **referring agency** maintains identifying information so appropriate placement can be made.
- Victims of DV have **no PII on the by-name list** in coordinated entry systems
- DV clients' information is **never entered into HMIS** even for internal CE purposes
- The DV provider acts as a **black box** -- the CoC knows beds exist and aggregate utilization, but not who occupies them

**Design pattern for FABT:**
```
Referring Worker --> [score only, no PII] --> Prioritization List
                                                    |
                                            [match to DV provider]
                                                    |
DV Provider <-- [phone/secure channel] <-- Referring Worker
     |
     v
[DV provider confirms availability]
     |
     v
[Warm handoff: client connected to DV provider directly]
```

### 4.4 Token-Based and Time-Limited Access Patterns

No widely documented token-based referral system was found in the DV field specifically. However, the principles from VAWA and FVPSA directly inform what such a system must look like:

**Time-limited access requirements (from VAWA):**
- Consent releases must be "reasonably time-limited" -- determined by circumstances based on survivor needs
- Typical durations: **2 weeks to 1 month** for most disclosures
- Emergency situations might justify 30-day releases with regular contact
- Survivors determine the appropriate length
- Advocates should regularly check whether circumstances have changed
- Survivors can **revoke consent at any time**, orally or in writing, effective immediately

**Design implications for FABT tokens/referrals:**
- Any referral token must have an **expiration** (recommend 24-48 hours for initial referral)
- Token should contain **minimum necessary information** (no PII if possible -- only an opaque reference)
- System must support **revocation** at any time
- Expired/revoked tokens must be cryptographically invalidated, not just soft-deleted

### 4.5 Consent Management Workflows

Federal requirements mandate specific consent elements:

**A valid release must be:**
- Written (digital signatures acceptable in urgent situations with identity verification)
- Informed (survivor understands all possible consequences)
- Reasonably time-limited (specific expiration date)
- Voluntary (never a condition of service)
- Specific about what information is shared, with whom, and by what method

**Digital consent protocols:**
- In-person signatures are best practice
- Emailed/digitally signed releases are acceptable in urgent situations
- **Critical**: Verify survivor identity by phone before sharing information (abusers can access emails or create fraudulent digital signatures)
- Oral releases are not recommended; if used, read form aloud, document oral consent, obtain written signature at next opportunity

**Per-agency releases:**
- A **separate release form** is recommended for each organization receiving information
- Multi-disciplinary team contexts require individual releases per partner agency
- Cooperative agreements alone do **not** satisfy confidentiality requirements

**Special populations:**
- Minors: Both minor and non-abusive parent/guardian sign (unless minor can access services independently)
- Persons with disabilities: Only court-appointed guardians can sign; always attempt individual consent first

**Sources:**
- [Safety Net: Releases FAQ](https://www.techsafety.org/releasesfaq)
- [Safety Net: Confidentiality Toolkit](https://www.techsafety.org/confidentiality)
- [Safety Net: Confidentiality Templates](https://www.techsafety.org/confidentiality-templates)

---

## 5. Lessons Learned from Real Implementations

### 5.1 Early HMIS Implementation Failures

The early HMIS rollout (2003-2005) exposed critical problems with DV data:

- **EPIC and ACLU** filed formal comments against the HMIS mandate, specifically citing DV risks
- Key concern: "Violent family members and others may be able to locate individuals in shelters through the HMIS database through employees who have access and improperly disclose information, through broad law enforcement exemptions, or through database security problems"
- Research cited: **50% of homeless women and children were fleeing abuse**; 46% of cities identified DV as a primary cause of homelessness
- HUD's initial attempt to exempt only "domestic violence shelters" was inadequate because victims seek help from **many types of providers**, not just specialized DV shelters
- The coalition argued that real-time transmission of victim location data to central servers was inherently dangerous

**Result:** VAWA 2005 codified the prohibition on DV providers entering PII into HMIS, and HUD created the comparable database requirement.

**Sources:**
- [EPIC Coalition Comments on HMIS](https://archive.epic.org/privacy/poverty/hmiscomments.html)
- [ACLU Comments Against HMIS](https://www.aclu.org/documents/comments-arguing-against-hmis)
- [NNEDV: Confidentiality](https://nnedv.org/content/confidentiality/)

### 5.2 No Documented Major Data Breaches (But Risks Are Real)

Research found **no publicly documented major data breaches** that disclosed DV shelter locations through HMIS or comparable databases. This likely reflects:
- The effectiveness of the HMIS prohibition for VSPs
- The seriousness with which DV providers treat confidentiality
- Under-reporting (breaches may occur but not be publicly documented)

However, threats identified include:
- Stalker spyware (EPIC filed FTC complaints against CyberSpy Software in 2008)
- Insider threats from employees with database access
- Law enforcement access that could be exploited
- IoT devices giving abusers new surveillance tools

### 5.3 NNEDV Safety Net Project Best Practices

The Safety Net Project (founded 2002, trained 100,000+ professionals) provides authoritative guidance:

**Database best practices for DV programs:**
1. Understand how the database system actually works
2. Retain control over who can see survivor information
3. Choose database systems that do **not** give IT personnel outside the program's control access to survivor information
4. Cloud-based databases must have data encrypted with **only program staff holding the encryption key**

**Agency technology toolkit covers:**
- Tips for technology generally
- Best practices for devices and hardware
- Guidance for providing services via technology
- Materials for assessing secure client information database options
- Data breach response policies and notification procedures
- Record retention and deletion best practices

**Sources:**
- [NNEDV: Safety Net Project](https://nnedv.org/content/technology-safety/)
- [Safety Net: Resources for Agency Use](https://www.techsafety.org/resources-agencyuse)
- [Safety Net: Selecting a Database](https://www.techsafety.org/selecting-a-database)
- [Safety Net: Confidentiality Toolkit](https://www.techsafety.org/confidentiality)

---

## 6. Human-in-the-Loop Requirements

### 6.1 Why Human Confirmation Is Required

Automated placement is inappropriate for DV referrals for multiple safety-critical reasons:

1. **Safety screening**: DV intake requires assessing whether the abuser could track the survivor to the shelter (e.g., through shared phone plans, GPS tracking, social media monitoring)
2. **Shelter location protection**: Automated systems that route clients to specific shelters create digital trails that could be discovered by abusers
3. **Compatibility assessment**: DV shelters often screen for compatibility factors (children, pets, substance use, mental health needs) that require human judgment
4. **Abuser infiltration risk**: Abusers sometimes pose as victims to locate shelters -- trained staff can screen for this
5. **Technology safety planning**: Advocates must help survivors secure their devices before sharing any location information
6. **Legal requirement**: VAWA requires informed consent for any information sharing, which requires human explanation of risks and alternatives

### 6.2 The Confirmation Workflow

Based on coordinated entry practices and DV program operations:

```
1. INTAKE: Client contacts access point (hotline, 211, walk-in)
2. SCREEN: Staff screens for DV situation and immediate safety needs
3. ASSESS: If DV identified, staff performs DV-specific assessment
4. REFER: Staff contacts DV provider DIRECTLY (phone, not electronic)
   - Shares only minimum necessary information
   - Does NOT share client PII electronically
5. CONFIRM: DV provider staff confirms:
   - Bed availability
   - Suitability for client's specific needs
   - Safety (no conflicts with other residents, e.g., client's abuser's other victims)
6. CONNECT: Client is connected to DV provider
   - DV provider conducts their own full intake
   - Referring party receives confirmation of placement (not location)
7. CLOSE: Referring worker closes referral as "accepted" without location details
```

### 6.3 Who Confirms

**Both parties** play a role:
- **Referring worker**: Initiates referral, shares minimum necessary info, confirms client wants DV-specific services
- **DV shelter staff**: Confirms availability, screens for safety/suitability, accepts or declines referral
- **The survivor**: Must consent to any information sharing at each step

**What the confirming DV shelter staff NEEDS:**
- Number of people (adults, children)
- Any immediate safety concerns
- Basic needs (accessibility, pets, language)
- Whether the abuser has any connection to the shelter or its current residents

**What the confirming DV shelter staff should NOT receive:**
- Full name (first name or alias sufficient for initial contact)
- Social security number
- Detailed abuse history
- Abuser's full identifying information (only enough to check for conflicts)

**Sources:**
- [HUD Exchange: Coordinated Entry and VSP FAQs](https://www.hudexchange.info/resource/4831/coordinated-entry-and-victim-service-providers-faqs/)
- [Eccovia: Why VSPs Should Participate in CE](https://eccovia.com/blog/vsps-participate-coordinated-entry/)
- [HUD: Separate CE Process for DV](https://www.hudexchange.info/faqs/2692/if-our-coc-chooses-to-create-a-separate-coordinated-entry-process-for/)

---

## 7. Aggregate Reporting Requirements

### 7.1 Housing Inventory Count (HIC)

- DV shelters **must** be included in the HIC as sheltered projects targeted to survivors of domestic violence
- The HIC counts **beds and units** dedicated to serving people experiencing homelessness
- DV beds are categorized as Emergency Shelter (typically)
- Data submitted is **aggregate**: total beds, total units, target population -- no client-level data
- CoCs submit HIC data through the HUD HDX website

### 7.2 Point-in-Time (PIT) Count

- Annual count of sheltered persons on a single night in January
- HUD has made data collection on DV survivors **optional** but "strongly encourages" communities to work with DV providers
- DV providers report **aggregate counts only** (number of persons sheltered on that night)
- PII is never shared for PIT counting purposes
- Best practice: DV providers count their own clients and report only aggregate numbers to the CoC

### 7.3 Annual Performance Report (APR) and CAPER

- CoC-funded VSPs must submit APRs through HUD's SAGE HMIS Reporting Repository
- Reports are generated from the **comparable database** (not HMIS)
- All PII in reports is **hashed** before submission
- Reports contain aggregate performance data: persons served, exits to permanent housing, length of stay, etc.
- VSPs can validate their comparable database's ability to produce compliant reports through HUD's vendor validation process

### 7.4 What FABT Can Report

Based on these requirements, FABT could safely provide:
- **Aggregate bed counts** by shelter type (DV vs. general)
- **Aggregate utilization rates** (X of Y beds occupied, no identification of who)
- **Aggregate demographics** (with small-number suppression)
- **Wait list counts** (number of people waiting, not who they are)
- **Trend data** over time (aggregate only)

FABT must **never** report or store:
- Which specific survivor is at which specific DV shelter
- Any trail connecting a referral to a specific DV shelter location
- Individual-level data that could be correlated across systems

**Sources:**
- [HUD Exchange: PIT and HIC](https://www.hudexchange.info/programs/hdx/pit-hic/)
- [HUD: PIT and DV - Partnering with CoCs](https://files.hudexchange.info/resources/documents/PIT-and-DV-Partnering-With-CoCs.pdf)
- [HUD Exchange: CoC APR Submission Guidance](https://www.hudexchange.info/programs/sage/coc-apr/)

---

## 8. Design Implications for FABT

Based on this research, the following architectural principles emerge for FABT's DV shelter support:

### 8.1 Mandatory Requirements

1. **No DV client PII in FABT's central database** -- FABT must never store identifying information about DV shelter clients
2. **No shelter location disclosure** -- FABT must never expose DV shelter addresses through its API or UI
3. **Human-in-the-loop for all DV referrals** -- automated placement is not acceptable
4. **Time-limited, revocable consent** -- any data sharing must have explicit expiration and support immediate revocation
5. **Separate data path** -- DV data must be architecturally isolated from general shelter data (comparable database pattern)
6. **Aggregate-only reporting** -- only de-identified aggregate data may flow from DV shelters to FABT's central reporting
7. **Small-number suppression** -- aggregate reports must suppress data that could identify individuals

### 8.2 Recommended Architecture

```
FABT Central System
├── General Shelters (full HMIS-style data)
├── DV Shelter Module (aggregate only)
│   ├── Bed counts (total available, not specific beds)
│   ├── Aggregate utilization (occupied/total)
│   └── Wait list count (number only)
└── DV Referral Channel
    ├── Opaque referral tokens (no PII, time-limited)
    ├── Human confirmation workflow
    ├── No shelter location in referral
    └── Confirmation receipt (accepted/declined only)
```

### 8.3 The Referral Token Pattern

```
1. Referring worker creates referral request in FABT
   - Contains: # adults, # children, basic needs, assessment score
   - Does NOT contain: names, SSN, detailed history
   - FABT assigns opaque token (UUID)

2. FABT notifies DV provider(s) with availability
   - Notification contains: token ID, basic needs summary
   - DV provider sees: "Referral request #[token] for 1 adult, 2 children"
   - DV provider does NOT see: who made referral or client identity

3. DV provider contacts referring worker via phone (out-of-band)
   - Uses token ID as reference
   - Warm handoff occurs outside FABT system
   - DV provider confirms/declines in FABT

4. Token expires after 48 hours if not acted upon
5. Accepted referrals show only: "Referral [token] accepted by [provider type]"
   - No location, no shelter name visible to referring party
```

### 8.4 Compliance Checklist

- [ ] VAWA 34 U.S.C. 12291(b)(2) -- no PII in shared databases
- [ ] FVPSA -- shelter location confidentiality
- [ ] NC G.S. 8-53.12 -- advocate privilege compliance
- [ ] NC Chapter 15C -- ACP compatibility
- [ ] HUD Comparable Database standards
- [ ] Time-limited consent (2 weeks to 1 month)
- [ ] Consent revocation support
- [ ] Small-number suppression in aggregates
- [ ] Data destruction when no longer needed
- [ ] Audit trail (who accessed what, when)
- [ ] Role-based access control
- [ ] Encryption at rest and in transit
- [ ] No DV client PII in logs or error messages
