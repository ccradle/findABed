# i18n Legal-Review Strings — Casey Drummond pass

**Reviewer:** Casey Drummond (synthetic warroom legal/i18n persona)
**Date:** 2026-04-28
**Status:** Reviewed — implementor SHOULD use these strings verbatim. Any deviation requires a follow-up legal pass.

## Context

The proposal explicitly required this review BEFORE implementation starts (Open Question #7 and task 0.6) — task 15.6 ("legal review at merge time") was deemed too late because reworded strings cascade into every JSX file rendering them. This artifact closes that pre-flight gate.

Three keys are in scope:

1. `shelter.criminalRecordPolicyDisclaimer` — non-dismissable disclaimer rendered everywhere a `criminal_record_policy` field is shown (search results, shelter detail, shelter edit form).
2. `shelter.vawaNoteDisclaimer` — additional disclaimer rendered when `vawa_protections_apply = true` on the shelter (search-side, navigator-facing).
3. `shelter.vawaProtectionsApplyNote` — admin-facing form-level contextual note shown next to the `vawa_protections_apply` checkbox in the shelter edit form.
4. `hold.clientAttributionPrivacyNote` — privacy note shown adjacent to the third-party hold attribution fields in the hold creation dialog.

## Casey's review principles (applied)

- **No certification language.** Platform represents what shelters say they do, not what they should do. Avoid "compliant", "certified", "verified by FABT", "FABT-approved".
- **No platform policy advocacy.** Avoid "should accept", "must consider", "are required to" — those are legal claims the platform isn't qualified to make.
- **Active voice + concrete verbs.** Navigators reading these on a phone in the field have ~3 seconds. "Confirm with the shelter" beats "verification is recommended".
- **Reading level.** ~9th grade. The reentry navigator persona (Demetrius) and outreach worker persona (Darius) include staff with high-school equivalency education; the disclaimer must be readable.
- **VAWA citation accuracy.** "Violence Against Women Act" is the federal statutory name; "VAWA" is the common abbreviation. Both must appear on first mention.
- **No legal advice.** The disclaimer flags a possibility ("may apply"), it does not adjudicate.
- **PII transparency for hold notes.** Tasks 6.4 explicitly requires plain-language statement of the 24h purge. Plain language = state the trigger condition (expire/confirm/cancel) and the time window in one sentence.

## Reviewed strings

### `shelter.criminalRecordPolicyDisclaimer`

**EN:**
> Criminal record policies shown here are self-reported by the shelter and may change without notice. Always confirm eligibility directly with the shelter before referring or transporting a client.

**ES:**
> Las políticas sobre antecedentes penales mostradas aquí son auto-reportadas por el refugio y pueden cambiar sin aviso. Confirme siempre la elegibilidad directamente con el refugio antes de referir o transportar a un cliente.

### `shelter.vawaNoteDisclaimer`

Shown in addition to the base disclaimer above when `vawa_protections_apply = true` on the shelter being displayed.

**EN:**
> This shelter indicates that federal Violence Against Women Act (VAWA) protections may apply to survivors of domestic violence whose criminal record relates to the violence they experienced. Confirm with the shelter how this is applied in their intake.

**ES:**
> Este refugio indica que las protecciones federales de la Ley contra la Violencia hacia las Mujeres (VAWA) pueden aplicarse a sobrevivientes de violencia doméstica cuyos antecedentes penales se relacionan con la violencia que experimentaron. Confirme con el refugio cómo aplican esto en su proceso de admisión.

### `shelter.vawaProtectionsApplyNote`

Admin-facing form-level note next to the `vawa_protections_apply` checkbox in the shelter edit form. Distinct from the navigator-facing `shelter.vawaNoteDisclaimer` above.

**EN:**
> Enable this if your shelter recognizes VAWA protections: survivors of domestic violence whose criminal record relates to the violence they experienced may be admitted regardless of categorical exclusions. The platform does not verify how you apply this in practice.

**ES:**
> Active esto si su refugio reconoce las protecciones de VAWA: las sobrevivientes de violencia doméstica cuyos antecedentes penales se relacionan con la violencia que experimentaron pueden ser admitidas independientemente de exclusiones categóricas. La plataforma no verifica cómo aplica esto en la práctica.

### `hold.clientAttributionPrivacyNote`

Shown adjacent to the third-party hold attribution fields in the hold creation dialog (the optional "Add client details" section).

**EN:**
> Client name, date of birth, and notes are stored encrypted. They are automatically deleted 24 hours after this hold expires, is confirmed, or is cancelled. Use these fields only for shelter check-in coordination.

**ES:**
> El nombre, la fecha de nacimiento y las notas del cliente se almacenan cifrados. Se eliminan automáticamente 24 horas después de que esta reserva expire, sea confirmada, o sea cancelada. Use estos campos únicamente para la coordinación del registro en el refugio.

## Casey's flags for the implementor

- **Do not abbreviate to "Verify before referring"** — the explicit "directly with the shelter" matters. A navigator who calls a CoC central line and gets generic info HAS NOT verified with the shelter.
- **Do not paraphrase "may apply"** in the VAWA disclaimer to "applies" or "do apply". The platform is flagging a possibility for the navigator to investigate, not making a legal determination.
- **The 24h hold-note purge text is load-bearing.** A navigator reading "Use these fields only for shelter check-in coordination" understands that the hold note is not a permanent record. Without that line, a navigator might paste case notes into the hold note. Don't drop it.
- **VAWA Spanish translation.** "Ley contra la Violencia hacia las Mujeres" is the most-recognized translation in U.S. Latine community resources (Casa de Esperanza, ALDA). Other translations exist (e.g., "Ley sobre Violencia contra la Mujer"); Casey explicitly chose this one for community recognition.
- **Reading level check.** Both EN strings clock at ~grade 9-10 on Flesch-Kincaid; ES strings clock at ~grade 8-9. Acceptable for the navigator persona.

## Implementation reference

When task 6.2 (i18n keys for criminal-record disclaimer) and task 6.4 (i18n keys for hold attribution privacy note) are written:
- Use these strings verbatim in `frontend/src/locales/en.json` and `frontend/src/locales/es.json`.
- Reference this artifact in the i18n key JSDoc / comment block: `// Casey-reviewed 2026-04-28; see openspec/changes/transitional-reentry-support/i18n-legal-review-strings.md`.
- Any change to these strings during implementation requires a Casey re-review (capture as a new section in this artifact).

---

## Pending Casey re-review (slice 4 §8/§9 warroom H4 — added 2026-04-29)

Slice 4 §8/§9 surfaced a new user-facing string that was NOT in the original review batch but ships with the same legal-review posture. Captured here so a Casey re-review pass at v0.55 release prep (or sooner if Corey requests) covers it. Text below is the implementor's draft using Casey's documented principles (no certification language, active voice, ~9th grade, flag possibility not adjudicate, plain-language remediation).

### `search.acceptsFeloniesEmptyHint`

Shown when the bed-search results are empty AND the operator has the `acceptsFelonies` filter set to true. Per slice-2 warroom carryover §17.M1, the empty result is a UX landmine at launch: most shelters have null `eligibility_criteria`, so a coordinator filtering for "accepts felonies" sees zero results and misreads it as "no shelters accept" instead of "we have no data on most shelters." The banner has to explain WHY the filter excluded shelters and HOW to surface them.

**EN (implementor draft, awaits Casey re-review):**
> No matching shelters. The 'accepts felonies' filter excludes shelters with no eligibility data on file. Ask your CoC admin to set 'requires verification call' on shelters whose policy is unknown — those will appear with a 'call to verify' badge.

**ES (implementor draft, awaits Casey re-review):**
> No hay refugios coincidentes. El filtro 'acepta condenas por delitos graves' excluye los refugios sin datos de elegibilidad registrados. Pida a su administrador del CoC que active 'requiere llamada de verificación' en los refugios cuya política sea desconocida — aparecerán con una insignia 'llamar para verificar'.

**Casey-principle self-check:**
- ✓ Active voice ("Ask your CoC admin to set"; "those will appear")
- ✓ Concrete remediation ("set 'requires verification call'")
- ✓ No certification language
- ✓ ~9th-grade reading level (verified: short sentences, common vocabulary)
- ⚠ Mentions an internal mechanism ("eligibility data on file") — Casey may prefer a plainer phrase like "no information about their criminal record policy"; flagging.
- ⚠ Spanish "registrados" is technical; Casey may prefer "que tengan información"; flagging.

Track in §15.6 final pre-merge sign-off.
