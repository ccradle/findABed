## Why

When a DV-authorized outreach worker loses connectivity, the "Request Referral" button stays enabled, the modal opens, the worker fills out sensitive data (callback number, household size, urgency), and the submit fails silently — the error renders behind the modal with no visible feedback. This is the worst possible UX for a crisis interaction (Keisha: "the survivor sees the worker struggling with technology").

DV referrals are intentionally NOT queued offline because the referral contains sensitive operational data (callback number, household size) that would persist in browser IndexedDB. Casey (legal): storing this on a device that could be lost, seized, or accessed by an abuser undermines the zero-PII threat model. VAWA/FVPSA don't address device-level storage directly, but the spirit is clear. No DV platform in the sector has solved this — we're ahead of the field by even asking the question.

The fix: be honest about the limitation and give the worker an actionable alternative, not a silent failure.

## What Changes

- "Request Referral" button uses `aria-disabled="true"` when offline (preserves keyboard focus per Adrian Roselli's accessibility guidance — never use `disabled` attribute)
- Tapping the button offline shows an inline action-oriented message: "Call the shelter to request a referral" (crisis UX: action first, explanation second)
- Referral modal does NOT open when offline (prevents sensitive data entry on a potentially compromisable device)
- Offline banner copy updated to explicitly mention referrals: "Bed holds and updates will be queued. DV referral requests require a connection."
- i18n: English and Spanish translations for all new messages
- FOR-COORDINATORS.md: "What works offline" section updated with referral limitation
- Training card content: green/red checklist of offline-capable vs connection-required features

## Capabilities

### New Capabilities
_None._

### Modified Capabilities
- `offline-behavior`: Add DV referral offline guard (button state, inline message, banner copy)
- `dv-referral-token`: Document that referral requests are intentionally not queued offline (security rationale)

## Impact

- **Frontend:** `OutreachSearch.tsx` — referral button and modal gating on `navigator.onLine` + `online`/`offline` event listeners
- **Frontend:** `OfflineBanner.tsx` or i18n messages — updated banner copy
- **Frontend:** `en.json` + `es.json` — new i18n keys for offline referral messages
- **Docs:** `FOR-COORDINATORS.md` — "What works offline" section
- **No backend changes**
- **No database changes**
- **No API changes**
