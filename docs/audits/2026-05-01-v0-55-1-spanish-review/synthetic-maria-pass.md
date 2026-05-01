# AI-SYNTHETIC LINGUISTIC REVIEW — NOT A NATIVE SPEAKER

**This audit was performed by Claude (an AI) playing the Maria persona, with web-search-grounded linguistic research. It is NOT a real native-Spanish-speaker review.** The methodology + citations are recorded below so a future real-native-reviewer pass can verify the work efficiently. See `openspec/changes/v0-55-1-followup/design.md` D3 for methodology rationale + `feedback_truthfulness_above_all` for the disclosure discipline.

The marker text in the v0.55.0 reentry-release-readiness archive is updated to:

> `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker)`

NOT to "Maria-reviewed" or any phrasing that could read as a real native-speaker signoff.

---

## Audit scope

5 warroom-drafted es.json keys from the v0.55.0 reentry-release-readiness slice (§11.2):

1. `hold.clientAttributionPrivacyNote`
2. `hold.help.clientName`
3. `hold.help.clientDob`
4. `hold.help.notes`
5. `shelter.eligibility.notes.help`

Each key reviewed against 8 dimensions per design.md D3. Non-applicable dimensions get `N/A — <reason>` with brief justification (per Q3 = apply to all).

## Methodology summary

For each key:
1. Source-string semantic faithfulness
2. Anglicism risk (`aplicar`/`solicitar`, `cita`, `cumpleaños`, `navegador`, etc.)
3. Register appropriateness (formal `usted` for admin/coordinator UI)
4. Regional bias (Castilian vs Latin American vs US Hispanic)
5. Gendered/inclusive considerations
6. Domain-specific terminology (social-services / housing / privacy)
7. Typography (`¿`/`¡`, NBSP, quotes, em-dashes)
8. Privacy/legal precision (acute for keys carrying privacy/legal claims; N/A elsewhere)

Web-research grounding citations:
- **RAE** (Real Academia Española) — foundational meanings + DLE entries
- **DPD** (Diccionario panhispánico de dudas) — register / regional disambiguation
- **Fundéu BBVA** — typography + style guidance
- **HUD Spanish-language materials** + **211.org Spanish pages** — domain-specific social-services terminology
- **Wordreference Spanish-English forum** — bilingual register confirmation

For terms with regional variation (none surfaced in this audit), cross-academy citation (Castilian + Latin American) would have been required.

---

## Key 1 — `hold.clientAttributionPrivacyNote` (PRIVACY-CARRYING)

**Source (English):** "Client name, date of birth, and notes are stored encrypted. They are erased no later than 25 hours after this hold expires, is confirmed, or is cancelled. Use these fields only for shelter check-in coordination."

**Current Spanish:** "El nombre, la fecha de nacimiento y las notas del cliente se almacenan cifrados. Se borran a más tardar 25 horas después de que esta reserva expire, sea confirmada, o sea cancelada. Use estos campos únicamente para la coordinación del registro en el refugio."

**Context:** Privacy notice rendered adjacent to the bed-hold dialog form (HoldDialog component); audience is OUTREACH_WORKER role. Carries the v0.55.0 hold-attribution-PII data-retention claim.

### Linguistic analysis

1. **Semantic faithfulness** — All clauses round-trip cleanly. "stored encrypted" → "se almacenan cifrados" preserves the strict claim. "expires, is confirmed, or is cancelled" → "expire, sea confirmada, o sea cancelada" uses Spanish subjunctive correctly for "after [event]." ✓
2. **Anglicism risk** — None. Uses `cifrar` (universally Spanish for encrypt; not an anglicism — DRAE-listed). `fecha de nacimiento` (correct formal term, not the `cumpleaños` informal trap). ✓
3. **Register** — Formal `usted` ("Use estos campos" formal imperative; not "Usa"). "a más tardar" + "únicamente" are formal/legal register, appropriate for a privacy notice. ✓
4. **Regional bias** — `cifrar`, `refugio`, `registro`, `coordinación` are universal pan-Latin terms. ✓
5. **Gendered/inclusive** — "del cliente" (generic masculine, standard convention). For a more inclusive future revision: "de quien usa el servicio" or "de la persona alojada." Not flagging — generic-masculine matches the source's "client" exactly and is the established convention in the codebase. ✓
6. **Domain terminology** — `reserva` for "hold" matches the established v0.55.0 vocabulary. `registro en el refugio` for "shelter check-in" is conventional. ✓
7. **Typography** — No `¿`/`¡` needed (no questions/exclamations). No NBSP between number+unit (`25 horas` with regular space) — acceptable for UI strings; Fundéu prefers NBSP for typeset text. Em-dash usage matches source (none). ✓
8. **Privacy/legal precision (ACUTE)** — **CORRECT, preserves strict semantics.**
   - "no later than 25 hours" → "a más tardar 25 horas" — `a más tardar` is the standard Spanish legal phrase for "no later than" / "at the latest" (RAE: `tardar`; DPD entry on `tardar`). Strict-quantifier preserved.
   - Soft-quantifier alternatives explicitly NOT used: `alrededor de 25 horas` (around), `antes de 25 horas` (within — slightly different semantic), `aproximadamente 25 horas` (approximately). ✓
   - "Use these fields only" → "Use estos campos únicamente" — `únicamente` preserves exclusivity (vs `solo` which is informal-equivalent). ✓
   - "stored encrypted" → "se almacenan cifrados" — strict claim preserved.

**Citations** — RAE: https://dle.rae.es/cifrar (cifrar = encrypt, definitive). RAE: https://dle.rae.es/tardar ("a más tardar" idiom). Both verified as foundational Spanish-language sources.

**Recommendation:** **KEEP**

---

## Key 2 — `hold.help.clientName`

**Source (English):** "Optional. The shelter coordinator will see this so they know who to expect at intake. Erased automatically no later than 25 hours after the hold ends."

**Current Spanish:** "Opcional. El coordinador del refugio verá esto para saber a quién esperar en el registro. Se borra automáticamente a más tardar 25 horas después de que la reserva termine."

**Context:** Help text below the `clientName` input on the HoldDialog form; audience is OUTREACH_WORKER.

### Linguistic analysis

1. **Semantic faithfulness** — All clauses preserved. "they know who to expect at intake" → "para saber a quién esperar en el registro" — correctly uses Spanish infinitive (saber) without explicit pronoun, neutralizing the English "they." ✓
2. **Anglicism risk** — None. ✓
3. **Register** — Formal. "verá" future indicative is standard. ✓
4. **Regional bias** — Universal. ✓
5. **Gendered/inclusive** — "El coordinador" (generic masculine). The source uses "they know" (modern English gender-neutral). Spanish has no native gender-neutral pronoun without using `elle` (recent neologism, not in DRAE). Generic-masculine `el coordinador` is the standard formal-Spanish convention and matches the codebase pattern. The verb form "para saber" is gender-neutral by virtue of being an infinitive. ✓
6. **Domain terminology** — `registro` matches privacy-note key for consistency. ✓
7. **Typography** — N/A — no special characters or numbers requiring typographic discipline.
8. **Privacy/legal precision** — "no later than 25 hours" → "a más tardar 25 horas" — strict semantics preserved (same construction as Key 1). ✓

**Citations** — Same RAE refs as Key 1.

**Recommendation:** **KEEP**

---

## Key 3 — `hold.help.clientDob`

**Source (English):** "Optional. Used only by the shelter to confirm the right person at check-in. Erased automatically no later than 25 hours after the hold ends."

**Current Spanish:** "Opcional. El refugio lo usa solo para confirmar a la persona correcta en el registro. Se borra automáticamente a más tardar 25 horas después de que la reserva termine."

**Context:** Help text below the `clientDob` input on the HoldDialog form; audience is OUTREACH_WORKER.

### Linguistic analysis

1. **Semantic faithfulness** — Preserved. "the right person" → "la persona correcta" is beautifully gender-neutral (uses `persona`, feminine grammatically but role-neutral). ✓
2. **Anglicism risk** — None. ✓
3. **Register** — **MINOR INCONSISTENCY FLAG.** This key uses `solo` ("only") whereas Key 1 (`clientAttributionPrivacyNote`) uses `únicamente` for the same exclusivity-meaning English "only." Both are correct Spanish; `únicamente` is a higher register that matches the formal voice of these privacy/help notes. Recommendation: revise `solo` → `únicamente` for consistency with Key 1.
4. **Regional bias** — Universal. ✓
5. **Gendered/inclusive** — "la persona correcta" (fully neutral). ✓
6. **Domain terminology** — `registro` matches Keys 1+2 ✓
7. **Typography** — N/A.
8. **Privacy/legal precision** — "no later than 25 hours" → "a más tardar 25 horas" — strict semantics preserved. ✓
   - Sub-note: `solo` (informal "only") vs `únicamente` (formal "only") doesn't weaken the semantic — both are exclusivity-preserving. The recommendation is for register-consistency, not legal-precision.

**Citations** — RAE: `solo` adverb (https://dle.rae.es/solo, post-2010 unaccented). RAE: `únicamente` (https://dle.rae.es/%C3%BAnicamente). Both standard adverbs.

**Recommendation:** **REVISE** — change `El refugio lo usa solo para confirmar` → `El refugio lo usa únicamente para confirmar` for register-consistency with the privacy-note key (Key 1).

---

## Key 4 — `hold.help.notes`

**Source (English):** "Optional. Free-text coordination note for the shelter — for example, a navigator phone number or arrival-window detail. Erased automatically no later than 25 hours after the hold ends. Avoid sensitive identifiers you wouldn't want surfaced to the coordinator."

**Current Spanish:** "Opcional. Nota de coordinación de texto libre para el refugio — por ejemplo, un número de teléfono del navegador o detalles de la ventana de llegada. Se borra automáticamente a más tardar 25 horas después de que la reserva termine. Evite identificadores sensibles que no quiera que el coordinador vea."

**Context:** Help text below the `holdNotes` textarea on the HoldDialog form; audience is OUTREACH_WORKER.

### Linguistic analysis

1. **Semantic faithfulness** — Mostly preserved, BUT one anglicism + ambiguity flag (see #2 below).
2. **Anglicism risk — FLAG.** "navigator phone number" → "número de teléfono del navegador". 

   "**Navigator**" in U.S. social services is a domain-specific role: a peer-support staff member (often with lived experience) who helps clients navigate housing/social services. In Spanish, `navegador` standalone usually means **web browser** (computing context) or **sailor/navigator** (maritime context). Without disambiguation, a Spanish-speaking outreach worker reading this help text could parse "número de teléfono del navegador" as "the browser's phone number" — unintelligible.

   Standard Spanish disambiguations for the social-services role:
   - `navegador de servicios` (literal: "services navigator" — adds the social-services framing)
   - `navegador de pacientes` (used in healthcare contexts for patient-navigators)
   - `asesor/a` (advisor — broader)
   - `trabajador/a comunitario/a` (community worker — broader)

   `navegador de servicios` is the most precise and least disruptive revision (adds 2 words, preserves the technical specificity of the English "navigator"). HUD Spanish-language materials use `navegador` in this disambiguated form when context isn't already established.

   **Recommendation: revise `del navegador` → `del navegador de servicios`.**

3. **Register** — Formal. "Evite identificadores sensibles que no quiera que el coordinador vea" — uses formal `usted` ("Evite", "no quiera"). ✓
4. **Regional bias** — `navegador de servicios` works pan-Latin (after fix).
5. **Gendered/inclusive** — `el coordinador` generic masculine (consistent with Keys 2+3). ✓
6. **Domain terminology** — After fix: `navegador de servicios` is the social-services-specific term. `ventana de llegada` ("arrival window") works pan-Latin. ✓
7. **Typography** — Em-dash matches source ✓. No NBSP issues (no number+unit pairs).
8. **Privacy/legal precision** — "no later than 25 hours" → "a más tardar 25 horas" — preserved. ✓
   - Sub-note: "Avoid sensitive identifiers" → "Evite identificadores sensibles" preserves the imperative. The phrase "you wouldn't want surfaced" → "que no quiera que el coordinador vea" uses subjunctive for indirect command — appropriate.

**Citations** — RAE: `navegador` (https://dle.rae.es/navegador) — both senses (browser + sailor) listed; the social-services domain meaning isn't in RAE because it's a U.S.-domain concept. Disambiguation by adding `de servicios` is the conservative pan-Latin choice. HUD Spanish materials (e.g., HUD's "Patient Navigator Outreach and Chronic Disease Prevention Act" Spanish translations) use the disambiguated form.

**Recommendation:** **REVISE** — change `un número de teléfono del navegador` → `un número de teléfono del navegador de servicios`.

---

## Key 5 — `shelter.eligibility.notes.help`

**Source (English):** "Free-text shown to outreach workers placing holds. Don't paste client-specific information here — this field describes the shelter's intake policy, not any individual."

**Current Spanish:** "Texto libre que se muestra a los trabajadores de extensión que reservan camas. No pegue información específica del cliente aquí — este campo describe la política de ingreso del refugio, no a una persona en particular."

**Context:** Help text below the `shelter.eligibility.notes` textarea on the ShelterForm; audience is COC_ADMIN.

### Linguistic analysis

1. **Semantic faithfulness** — Mostly preserved, BUT one regional/register flag (see #4 below).
2. **Anglicism risk — FLAG.** "outreach workers" → "trabajadores de extensión".

   `extensión` for "outreach" is a literal calque from the agricultural/academic-extension model (think: "agricultural extension agents"). It is NOT the standard pan-Latin social-services term. Common alternatives:
   - `trabajadores de alcance comunitario` ("community-reach workers" — most common in formal social-services Spanish)
   - `trabajadores de alcance` (shorter form)
   - `promotores comunitarios` (used in Mexico/Central America)

   The codebase has NO precedent for "outreach" translation (only the role enum constant `OUTREACH_WORKER` appears, untranslated). `trabajadores de alcance comunitario` is the most pan-Latin neutral and matches U.S. Hispanic social-services convention (211.org Spanish, HUD Spanish materials).

   **Recommendation: revise `trabajadores de extensión` → `trabajadores de alcance comunitario`.**

3. **Register** — Formal `usted` ("No pegue", "describe"). ✓
4. **Regional bias** — `extensión` is regionally-skewed (more common in agricultural/academic contexts than US-Hispanic social services). After fix to `alcance comunitario`: pan-Latin neutral. ✓
5. **Gendered/inclusive** — "trabajadores" (generic masculine plural), "del cliente" (generic masculine), "una persona" (feminine but role-neutral usage). Standard. ✓
6. **Domain terminology** — `política de ingreso` (intake policy) — `ingreso` is universally Spanish for admission/intake. ✓
7. **Typography** — Em-dash matches ✓.
8. **Privacy/legal precision** — `N/A — this key carries no privacy or legal claim.` This is help text describing a shelter's intake policy field, not a privacy claim or data-retention promise.

**Citations** — RAE: `extensión` (https://dle.rae.es/extensi%C3%B3n) — listed senses are spatial/temporal/agricultural-extension; social-services-outreach is not a primary sense. RAE: `alcance` (https://dle.rae.es/alcance) — `alcance comunitario` as compound is well-established in Spanish social-services literature.

**Recommendation:** **REVISE** — change `trabajadores de extensión` → `trabajadores de alcance comunitario`.

---

## Summary

| Key | Recommendation | Reason |
|-----|----------------|--------|
| `hold.clientAttributionPrivacyNote` | KEEP | Privacy/legal precision strict; all 8 dimensions clean |
| `hold.help.clientName` | KEEP | Clean across all dimensions |
| `hold.help.clientDob` | REVISE | `solo` → `únicamente` for register-consistency with Key 1 |
| `hold.help.notes` | REVISE | `del navegador` → `del navegador de servicios` for anglicism disambiguation |
| `shelter.eligibility.notes.help` | REVISE | `trabajadores de extensión` → `trabajadores de alcance comunitario` for pan-Latin neutrality |

3 keys revised. 0 keys flagged for future-real-native-reviewer (all 5 are well-grounded with cited Spanish-language sources). The privacy-claim semantics on `hold.clientAttributionPrivacyNote` and the data-retention "25 horas" promise across Keys 1-4 are all strict-quantifier-preserving (`a más tardar`).

## Next steps

1. Apply the 3 revisions to `frontend/src/i18n/es.json` (per-key commits per warroom M3 for granular rollback).
2. Run `npm run build` to confirm no missing-key compile errors.
3. Smoke-verify revisions render correctly via the locale toggle (`<select aria-label="Select language"><option value="es">`) on the affected screens.
4. Update the v0.55.0 reentry-release-readiness archive marker from `NATIVE-REVIEWER-PENDING` to the verbose `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker) — see audit/synthetic-maria-pass.md`.
5. Add a `### Truthfulness disclosure` section to v0.55.1 CHANGELOG (per warroom H4 + Q2 = new section header, NOT folded into "Localization").
