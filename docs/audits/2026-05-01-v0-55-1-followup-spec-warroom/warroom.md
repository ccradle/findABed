# v0.55.1-followup — spec-content warroom (post Q1+Q5 revisions)

**Date:** 2026-05-01
**Scope:** Review the v0-55-1-followup OpenSpec change after Q1 (synthetic-Maria) and Q5 (defer seed-fix) revisions, before `/opsx:apply`.
**Inputs:** `openspec/changes/v0-55-1-followup/{proposal.md, design.md, tasks.md, specs/hmis-push/spec.md}`
**Convention:** 11 personas (Casey, Marcus, Tomás, Keisha, Maria, Demetrius, Simone, Devon, Riley, Alex, Sam).

---

## Verdict (one-line)

**Hold for fixes.** 2 BLOCKERs (one truthfulness-disclosure, one O1 test-correctness) need spec changes before `/opsx:apply`. 4 HIGHs are fixable in the same revision pass. The synthetic-Maria methodology is sound but the disclosure framing has gaps.

---

## BLOCKERs (must fix before /opsx:apply)

### B1 — `SYNTHETIC-MARIA-REVIEWED` marker text doesn't explicitly disclose "AI / not a human"

**Caught by:** Casey (legal/language/truthfulness), seconded by Riley + Marcus.

**Where:** design.md D3 + tasks.md §9.8. The marker text is `SYNTHETIC-MARIA-REVIEWED — see openspec/changes/archive/2026-05-01-v0-55-1-followup/audit/synthetic-maria-pass.md`.

**The problem:** "Synthetic-Maria" can plausibly read as "the synthetic persona named Maria reviewed it" — i.e., the Maria character in our internal warroom — which sounds (to a casual reader, future operator, or external auditor) like there is *some* real human named Maria involved. Per `feedback_truthfulness_above_all` and `feedback_persona_transparency`, persona names should NEVER appear in committed docs (commits, releases, external docs) as if they're real contributors. The marker as worded blurs the line.

**The softening from real-native-reviewer is real and should be transparent at the source.** Anyone reading the marker should see immediately: "this was an AI doing a structured linguistic review, NOT a human native speaker."

**Fix:** change the marker text to:

`AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker) — see openspec/changes/archive/2026-05-01-v0-55-1-followup/audit/synthetic-maria-pass.md`

Or shorter: `AI-SYNTHETIC-REVIEW — see audit/synthetic-maria-pass.md (Claude, web-cited; NOT native speaker)`.

The audit doc filename can keep `synthetic-maria-pass.md` for internal continuity, but the *marker text* in the public-facing tasks/archive/CHANGELOG must use the AI-SYNTHETIC framing.

Apply the same change to:
- design.md D3 (the description of the marker)
- design.md Risk #2 (the example marker text)
- tasks.md §9.8 (the marker write)
- tasks.md §9.10 (the commit message — should mention "AI-synthetic review" not "synthetic-Maria")
- tasks.md §11.4 + §12 (deploy + post-deploy hygiene if they reference the marker)
- proposal.md "What Changes" D2 bullet (the framing)

**And:** add a new task §12.5 — CHANGELOG entry must include a one-line disclosure: "Spanish review on v0.55.0 reentry keys was performed by AI (Claude with web-search grounded linguistic research), NOT by a native speaker. A real-native-reviewer pass remains a future option." Per Casey, this is the truthfulness floor.

### B2 — O1 contract test asserts null but a projection bug emitting empty strings would still pass

**Caught by:** Tomás + Marcus + Alex.

**Where:** specs/hmis-push/spec.md scenarios + tasks.md §5.2. All scenarios assert the 3 columns are `null`.

**The problem:** the projection layer could regress to emit empty strings (e.g., `COALESCE(held_for_client_name_encrypted, '')` or a Jackson `@JsonInclude(Include.NON_NULL)` config that quietly fills null with `""`). Empty strings on encrypted PII columns would still represent a leak vector — the column should be untouched/absent, not "present but blank." A test asserting strict `null` would pass on the empty-string regression and the gap would ship.

**Fix:** strengthen the assertion to "the column is null OR the column is absent from the projection at all (not present in the OutboxRecord schema for this event type)." Concrete test shape:

```java
assertThat(record.getColumn("held_for_client_name_encrypted")).isNull();
// OR if the projection schema differs:
assertThat(record.hasColumn("held_for_client_name_encrypted")).isFalse();
```

Update the spec scenarios + the task §5.2 to specify "null AND not empty-string AND not present-with-blank-value." The simplest assertion form is `assertThat(value).isNull()` combined with a guard that `value` was not coerced from `""` upstream — which can be done by reading the raw DB row directly via JdbcTemplate rather than going through any DTO/projection that might coerce.

Apply to:
- specs/hmis-push/spec.md — update the 3 scenarios to assert null + not-empty-string + (ideally) absent-from-schema.
- tasks.md §5.2 — add explicit "read the raw DB row, do not go through a DTO that might coerce nulls."
- tasks.md §5.3 — note that the parameterized test must run the same strict assertion in both branches.

---

## HIGHs (should fix in the same revision pass)

### H1 — Citation source list is Castilian-skewed (RAE-heavy); add Latin American academies for pan-Latin neutrality

**Caught by:** Maria (self-review).

**Where:** design.md D3 — the "Web-research grounding" source list cites RAE + DPD as the primary dictionary references. RAE is the Spanish (Castilian) Royal Academy. The user base spans Latin America + US Hispanic communities; pan-Latin neutrality requires cross-academy reference for any term where regional usage diverges.

**Fix:** add to the source list:
- **ASALE** (Asociación de Academias de la Lengua Española — RAE + 22 Latin American academies, joint normative authority).
- **Academia Mexicana de la Lengua** — for Mexican Spanish, the largest Spanish-speaking population; includes the *Diccionario del español de México* (DEM).
- **Banco de Datos de la Academia** — corpus query for real frequency of regional variants.
- **Wordreference Spanish-English forum** — crowd-sourced register/usage from real bilingual speakers.

Also flag: when a term has divergent Latin American vs Castilian usage (e.g., `ordenador` vs `computadora`), the synthetic-Maria pass MUST cite both and choose the pan-Latin neutral form, with a forum/corpus citation showing real frequency in social-services contexts.

### H2 — Methodology missing typography dimension

**Caught by:** Maria (self-review).

**Where:** design.md D3 — 6-dimension framework. Spanish typography has specific conventions that the framework misses:
- Inverted opening punctuation (`¿` `¡`).
- Smart quotes vs straight (`«»` for Spanish-style; `""` US-style is acceptable in tech UI but should be consistent).
- Non-breaking space between number + unit (`25 horas` should ideally be `25 horas` with NBSP — common social-services style guides require it).
- Em-dash vs en-dash usage in dialogue/clauses.

**Fix:** add a 7th dimension to the methodology:

> 7. **Typography** — inverted opening punctuation (`¿`/`¡`) where applicable; quote-style consistency; non-breaking spaces between numbers and units; em-dash usage. Cite a style guide (RAE *Ortografía*, Fundéu, or Texas A&M Coastal Bend AHEC if a US-Hispanic context applies).

Apply to design.md D3 + tasks.md §9.3 (the audit-doc structure).

### H3 — `hold.clientAttributionPrivacyNote` needs extra precision-check (legal-language register)

**Caught by:** Riley + Casey.

**Where:** tasks.md §9.3 — all 5 keys get the same 6-dimension (now 7) treatment. But `hold.clientAttributionPrivacyNote` carries privacy-claim semantics ("a más tardar 25 horas" means "no later than 25 hours") — a softening to "about 25 hours" or "around 25 hours" would weaken the legal-precision of the original English. This is the same class of concern that surfaced in v0.55.0's Casey legal-language review: privacy claims must not drift in translation.

**Fix:** add an explicit 8th dimension or a special sub-pass for keys flagged as privacy-or-legal copy:

> 8. **Privacy/legal precision (apply when key carries a privacy or legal claim)** — does the Spanish preserve the strict semantics of the English? Soft-quantifiers ("about", "around", "approximately") MUST NOT replace strict ones ("no later than", "exactly", "at most"). Cite the original source-string + the proposed Spanish + a side-by-side semantic comparison.

`hold.clientAttributionPrivacyNote` is the only key in the current scope that triggers this dimension, but the framework should be reusable for future privacy/legal keys.

Apply to design.md D3 + tasks.md §9.3 + add a §9.3a sub-task: "If the key is `hold.clientAttributionPrivacyNote` (or any future key carrying privacy/legal semantics), apply dimension 8 explicitly + cite Riley/Casey concurrence in the audit doc."

### H4 — CHANGELOG truthfulness disclosure is implicit, should be explicit

**Caught by:** Casey.

**Where:** tasks.md §12 — post-deploy hygiene. There's a memory update for `project_v055_1_backlog.md` but no explicit CHANGELOG entry requirement.

**The problem:** the v0.55.1 CHANGELOG entry needs to disclose, in user-facing release notes, that the Spanish review was AI-synthetic. Per `feedback_truthfulness_above_all`, this is the most-public surface where the softening from real-native must be visible.

**Fix:** add task §12.5 (folded into B1's CHANGELOG fix above):

> §12.5 — Update `CHANGELOG.md` for v0.55.1 with an entry under "Localization": "Spanish translation review on v0.55.0 reentry keys was performed by AI (Claude with web-search grounded linguistic research), NOT by a native speaker. A real-native-reviewer pass remains a future option. See audit doc at openspec/changes/archive/2026-05-01-v0-55-1-followup/audit/synthetic-maria-pass.md."

This is the same disclosure that the marker carries (B1) but in the user-visible release notes channel.

---

## MEDIUMs (fix during apply or in v1.x)

### M1 — T2 per-page test naming convention should match project conventions

**Caught by:** Tomás.

`tasks.md §4.2` says "create 4 individual `test(...)` blocks (one per page: login, outreach, coordinator, admin)". Confirm the naming convention against existing Playwright tests (probably `test('color contrast on login page', ...)` or similar). Easy to defer to apply-time judgment but worth flagging.

### M2 — `?lang=es` Playwright smoke harness may not exist; manual visual is the floor

**Caught by:** Keisha.

`tasks.md §9.7` says "Run a quick Playwright smoke against the affected screens with `?lang=es`". Audit before relying — if no existing locale-toggle harness, manual visual via dev-start.sh stack is the floor. Flag in the task as conditional.

**Fix:** rewrite §9.7 to: "Audit existing Playwright tests for any locale-toggle harness (`?lang=es` or equivalent). If found, run it on affected screens. If not found, manually toggle locale in the dev-start.sh stack and visually verify the revised strings render without truncation/wrapping issues."

### M3 — D2 revision granular rollback path

**Caught by:** Demetrius.

`tasks.md §11.4` says rollback is "revert the i18n edit." But if 3 of 5 keys revise and only 1 revision is later judged wrong, the rollback granularity is per-commit. If §9.10 commits all D2 work in one commit, granular rollback requires multiple commits.

**Fix:** add to §9.10 — "If revisions span multiple keys with different rationales, prefer one commit per key (or per coherent group) so a single-key revert is possible without unwinding all D2 work."

### M4 — T1 sanity-assertion threshold is too lenient

**Caught by:** Alex.

`tasks.md §3.3` says "assert the scoped probe found `>= 1` freshness-badge match." For a seed with multiple shelters of different freshness states, `>= 1` is barely defensive — a regression that finds only the very first card would pass. Recommend `>= 3` or "at least 50% of the shelters in the result region have a freshness badge surfaced."

**Fix:** rewrite §3.3 to: "Add a paired sanity assertion: `>= 3` distinct freshness-badge matches in the scoped probe (or whatever count corresponds to ≥50% of seeded shelters in the default search)."

---

## SUGGESTIONs (NITs)

### N1 — Q5 deferral note should also reference seed-fix in `project_v055_1_backlog.md` update

**From:** Demetrius.

`tasks.md §12.3` already does this. Confirm the wording explicitly carries the deferral rationale ("recently shipped seed changes; not a priority") so a future operator doesn't pick it up cold without context.

### N2 — Audit doc filename can stay `synthetic-maria-pass.md` (internal continuity)

**From:** Casey.

The doc filename is fine as `synthetic-maria-pass.md` for internal tracking. It's the public-facing marker text (B1) and CHANGELOG (H4) that need the AI-SYNTHETIC framing. The audit doc itself can have an explicit header note: "This audit was performed by Claude (AI) playing the Maria persona, with web-search grounded linguistic research. NOT a real native-speaker review." That keeps the file readable to future agents without re-reading the marker chain.

### N3 — Pre-flight §1.3 (`dev-start.sh --fresh` baseline) gets harder if Q5-deferred reentry-shelters fix isn't in place

**From:** Devon.

§8.1 already calls this out ("V95+V96 reentry shelters will need manual replay after `--fresh` per the deferred Q5"). Worth duplicating in §1.3 so the operator knows up-front that the dev-start baseline includes the manual replay step.

---

## Persona positions (one paragraph each)

**Casey (legal/language/truthfulness)** — The synthetic-Maria methodology is real linguistic effort with grounding; it's materially better than what shipped v0.55.0. But the marker text (B1) and CHANGELOG entry (H4) absolutely must disclose AI-not-human, both internally to future operators and externally in release notes. The persona-name "Maria" carries baggage from the warroom convention; "AI-SYNTHETIC-REVIEW" or similar is the correct framing for committed disclosure surfaces. Otherwise the methodology is sound and citation discipline is appropriate.

**Maria (i18n/Spanish review, self-review)** — The 6-dimension framework is good but missing typography (H2). Citation sources are RAE-heavy; need Latin American academies (H1) for pan-Latin neutrality. Otherwise the methodology aligns with how a real linguistic reviewer approaches social-services Spanish — formality register, anglicism flags, regional bias, gendered/inclusive considerations, domain terminology. The privacy-note key (H3) deserves a separate dimension since legal-precision drift is a real risk class. With H1+H2+H3 fixes, the methodology is defensible.

**Tomás (backend architecture)** — B2 is the substantive backend issue. Asserting `null` is necessary but insufficient — empty-string regressions would slip past. Need to assert "null AND not empty-string AND ideally absent from projection schema." The fix is small: read the raw DB row via JdbcTemplate rather than through a DTO that might coerce. The T2 split + helper-extraction approach is fine; M1 is just about matching naming conventions. O1 IT shape (column-level not payload-level) per design D4 remains the right call.

**Keisha (frontend)** — D2 mechanics are sound. M2 is mine — `?lang=es` smoke depends on existing harness; audit before relying. Vitest discipline doesn't apply here (no React component changes likely from D2 revisions). Forward-compat with future `useContactInfo()` consumers is unaffected by this slice.

**Marcus (security/observability)** — B2 doubles for me. Beyond test correctness, the underlying concern is "PII absence is enforced by a contract test, not by trust" — and the contract test must be strict. Empty-string vs null differential matters for any downstream consumer that treats present-but-blank as "we have a value, just empty." Audit-row coverage on the IT runs is overkill for v1; standard test logging is fine.

**Demetrius (ops/DevOps)** — Deploy-shape is clear after Q5 deferral simplified the slice. M3 (granular rollback for D2) is mine. Worth flagging that the §11 split (static-only / code-repo / D2-revisions) decision tree is operator-friendly given the Q5 simplification removed the seed-data ride-along path.

**Simone (UX)** — Minimal involvement. S1 dark-mode re-captures should pair with light-mode visually; standard discipline. S2 semantic markup elevation is hygiene, not user-facing UX change.

**Riley (DV/safety)** — H3 is mine. The privacy-note key (`hold.clientAttributionPrivacyNote`) carries weight that the other 4 don't — survivors' data deletion timing is a real safety claim. Soft-quantifier drift in Spanish would be a real regression. Adding the 8th dimension (privacy/legal precision) is cheap and matches how Casey + I reviewed v0.55.0 English copy.

**Sam (performance)** — Minimal involvement. T2 per-context overhead (~2s across 4 tests) is acceptable. O1 IT runs once per CI cycle; not a perf concern.

**Devon (training/onboarding)** — N3 is mine. Pre-flight §1.3 should up-front the `--fresh` reentry-shelters manual-replay step so operators don't get blindsided. D3 capture.sh ergonomics improve onboarding for the demo workflow.

**Alex (testing/QA)** — M4 (T1 sanity-assertion threshold) is mine. `>= 1` is too lenient; `>= 3` or 50%-of-seeded-shelters is the right defensive bar. T2 split improves attribution. O1 parameterized assertion is solid (modulo B2 strengthening).

---

## Open questions to operator

**Q1 — B1 marker phrasing:** which exact phrasing for the marker?
- **(α)** `AI-SYNTHETIC-LINGUISTIC-REVIEW (Claude with web-citation grounding, NOT a native speaker)`
- **(β)** `AI-SYNTHETIC-REVIEW (Claude, web-cited; NOT native speaker)`
- **(γ)** other

Casey leans α (verbose-but-unambiguous). Maria leans β (short-and-clear). Either is acceptable per `feedback_truthfulness_above_all`.

**Q2 — H4 CHANGELOG section header:** under "Localization" (per H4 fix) or under a new "Truthfulness disclosure" section header? Casey suggests "Localization" with the disclosure as part of the entry; clean and discoverable.

**Q3 — H3 8th-dimension scope:** apply to *all* keys (every audit-doc section gets a "Privacy/legal precision: N/A" line if the key isn't privacy-flavored) or only to flagged keys? Riley leans only-flagged for keep-it-tight; Casey leans all-keys for consistency. Either works.

**Q4 — B2 strict-assertion shape:** is the simpler "read raw DB row via JdbcTemplate, assert null" the preferred form, or do we want the more thorough "absent from projection schema entirely" form? Tomás recommends the simpler form; the more thorough form is a v0.55.2 hardening if a regression ever surfaces.

**Q5 — M2 `?lang=es` harness audit:** does that harness exist? If yes, §9.7 stays as-is. If no, §9.7 rewords to manual-only floor. Resolve before §9 starts (operator-side check, not blocking the warroom).

---

## Recommended next step

Apply the 2 BLOCKERs + 4 HIGHs as a single revision pass to the spec files, then re-validate via `openspec status --change v0-55-1-followup`. Persona consensus is that B1+B2 are non-negotiable; H1-H4 are all spec-reachable in the same pass. MEDIUMs (M1-M4) and SUGGESTIONs can ride the implementation `/opsx:apply`.
