# DvPolicySettings UI copy — EN draft for Casey + Keisha review

**Status:** DRAFT 2026-05-02 — pending Casey (legal) + Keisha (community) review per task §0.2 + §13.3.

**Guardrails applied** (from warroom round 1):
- Survivor-respectful framing
- Avoid jargon: no "flag", "policy enabled", "infrastructure"
- Lead with purpose, not the noun
- Disable-path error leads with empathy not procedure
- Never expose the literal `dv_policy_enabled` field name in user copy
- Never reference shelter names or IDs — count only

---

## Panel — `DvPolicySettings.tsx`

**Panel heading:**
> Domestic Violence Shelter Operations

**Panel description (when enabled):**
> This Continuum of Care operates Domestic Violence (DV) shelters. DV shelters are protected with additional safeguards: address redaction, restricted access, and audit-suppressed referrals. Shelters can be marked as DV shelters individually from the Shelters tab.

**Panel description (when disabled):**
> This Continuum of Care does not currently operate any Domestic Violence (DV) shelters. To begin operating DV shelters, enable DV shelter operations below; this acknowledges the additional protections and review responsibilities that come with DV-shelter management.

**Toggle label:**
> DV shelter operations enabled

**Current-state text (when enabled, near the toggle):**
> Currently enabled. DV shelters can be created and managed by this CoC.

**Current-state text (when disabled, near the toggle):**
> Currently disabled. No DV shelters are configured for this CoC.

**Helpful link below toggle:**
> Learn more about DV shelter operations →
(links to `for-coc-admins.html#dv-policy`)

---

## Modal — Enable case (false → true)

**Modal title:**
> Enable DV shelter operations for this CoC?

**Modal body:**
> Enabling DV shelter operations means this Continuum of Care can mark individual shelters as DV shelters. DV shelters are protected with address redaction, restricted access controls, and audit-suppressed referrals to protect survivor confidentiality.
>
> By enabling, you acknowledge that this CoC has the necessary review processes and trained staff in place to manage DV shelters responsibly.
>
> This change is auditable and takes effect immediately. You can disable DV shelter operations later only after deactivating all DV shelters.

**Confirm button:**
> Enable DV shelter operations

**Cancel button:**
> Cancel

---

## Modal — Disable case (true → false)

**Modal title:**
> Disable DV shelter operations for this CoC?

**Modal body:**
> Disabling DV shelter operations means this Continuum of Care can no longer create or manage DV shelters.
>
> Before this can take effect, every active DV shelter at this CoC must be deactivated first. If any active DV shelters remain, the request will be rejected and you'll see how many remain.
>
> This change is auditable and takes effect immediately once allowed. You can re-enable DV shelter operations at any time.

**Confirm button:**
> Disable DV shelter operations

**Cancel button:**
> Cancel

---

## Disable-rejection error (when N active DV shelters block the disable)

**Error message (single shelter):**
> This CoC currently operates 1 active Domestic Violence shelter. To turn off DV shelter operations, deactivate the DV shelter first, then return to this setting.

**Error message (multiple shelters, e.g. N=3):**
> This CoC currently operates 3 active Domestic Violence shelters. To turn off DV shelter operations, deactivate each DV shelter first, then return to this setting.

**Inline link in error:**
> View active DV shelters →
(links to admin Shelters tab filtered to `?dvShelter=true&active=true`)

---

## Inventory-link label (within the error UI)

**Aria label / accessible name:**
> View this CoC's active DV shelters

---

## Tone notes for reviewers

- "Continuum of Care" used in full once at the top of each modal body, then "this CoC" thereafter to keep prose readable while remaining specific.
- Avoid "DV policy" and "DV-policy flag" in user-facing copy entirely (per Keisha guardrail).
- "Domestic Violence shelter operations" is the user-facing concept name; the implementation detail (`dv_policy_enabled` JSONB key) never surfaces.
- Disable error leads with the operational reality ("this CoC currently operates N active DV shelters") rather than with the rule violation ("you can't disable while…"), per Keisha's empathy-first framing.
- Pluralization handled per-locale at the i18n layer (English: "1 active …shelter" / "N active …shelters"; Spanish will need its own forms — Maria review).
- No DV shelter names, addresses, or identifiers anywhere — only counts (Casey guardrail).

---

## Synthetic Casey + Keisha review verdicts (2026-05-02)

Five open questions resolved via synthetic warroom review. **Real Casey + Keisha sign-off still required at task §13.3 before merge.**

1. **Term choice → "DV shelter operations" (kept)** — Casey: neutral, describes what the CoC does; "management" sounds like a DB admin task; "capability" implies a "qualified?" judgment we don't intend. Keisha: agree.
2. **"acknowledges" in enable-modal body → kept** — Casey: this IS formal (auditable, immediate effect, governs DV shelter creation); softening it would underplay the commitment. Keisha: appropriately serious without being scary.
3. **"safeguard survivor privacy" → changed to "protect survivor confidentiality"** — Casey: more accurate to what the protections actually do (address redaction + restricted access + audit suppression); "privacy" is broader than the implementation. Keisha: more concrete.
4. **Disable-modal body → pre-warn the constraint** — Simone (UX) + Demetrius (ops) + Keisha all argue: the constraint shouldn't be a surprise at submit time. Body now mentions the deactivation prerequisite up-front.
5. **"propagates immediately" → changed to "takes effect immediately"** — Simone: dev jargon vs user-friendly.

This file becomes the source of truth for §8.1 (EN strings) and the basis for §8.2 (Maria's ES translation pass).
