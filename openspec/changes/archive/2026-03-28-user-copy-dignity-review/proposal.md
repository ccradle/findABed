## Why

The platform's user-facing copy was written from an engineering perspective, not a communications or dignity perspective. As evaluated through the Simone Okafor AI persona (Brand Strategist) and Keisha Thompson AI persona (Lived Experience Advisor), both defined in PERSONAS.md: "DV_SURVIVOR" as a visible label in a search interface is a dignity concern — the outreach worker selects this to find beds for a person who may be sitting next to them. "STALE" as a freshness badge is technically accurate but clinical. The offline banner doesn't reassure users their work is preserved. These are brand touchpoints, not just UX elements.

## What Changes

- Replace `DV_SURVIVOR` display label in outreach search UI with "Safety Shelter" (internal enum unchanged)
- Add plain-text age description alongside freshness badges ("Last updated 9 hours ago")
- Enhance offline banner with "Your last search is still available" reassurance
- Review and update all user-facing error messages for human-readability
- Update i18n files (en.json, es.json) for all copy changes
- Add Playwright tests verifying the updated labels render correctly

## Capabilities

### New Capabilities
- `dignity-centered-copy`: User-facing labels, badges, and messages reviewed through lived experience and communications lenses

### Modified Capabilities
- `data-freshness-ui`: Freshness badges enhanced with plain-text age description
- `offline-behavior`: Offline banner enhanced with reassurance message
- `language-switching`: i18n files updated for all copy changes (EN + ES)

## Impact

- **Frontend**: OutreachSearch.tsx, OfflineBanner.tsx, DataAge.tsx, en.json, es.json
- **Backend**: None — display labels are frontend-only; enum values unchanged
- **Testing**: Updated Playwright tests for new label text, new Karate scenarios for API response labels if applicable
- **i18n**: Both EN and ES translations updated
- **DV safety**: "Safety Shelter" label prevents inadvertent disclosure of DV context when a client can see the screen
