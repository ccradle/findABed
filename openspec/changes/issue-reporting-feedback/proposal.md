## Why

Users who encounter problems in the application have no way to report them from within the app or the public-facing site. External testers (like Harry) go directly to GitHub, but the primary users — shelter coordinators, outreach workers, faith community volunteers — will never navigate to a GitHub repository. Sandra Kim at 2am, Rev. Monroe's 67-year-old volunteer coordinator, and Dr. Whitfield on a locked-down hospital laptop all need an obvious, low-friction path to report problems and ask questions. The GitHub issue templates are now in place (#52 commit), but they are unreachable from the product itself.

## What Changes

- Add a **"Report a Problem" link** in the authenticated app footer, visible on all pages, linking to the GitHub `report-a-problem` issue template with pre-filled context (version, role)
- Add a **"Feedback & Support" section** on the public landing page with links to GitHub Issues (report a problem, request a feature) and Discussions (questions)
- Add a **"Help" item** in the mobile kebab overflow menu linking to the same feedback entry point
- Ensure all links open in a new tab and pre-fill what context they can (app version, current page)

## Capabilities

### New Capabilities
- `issue-reporting`: In-app and landing page links to GitHub issue templates and Discussions, with pre-filled context for non-technical users

### Modified Capabilities
- `mobile-header-overflow-menu`: Add "Help" menu item to the kebab dropdown
- `story-landing-page`: Add "Feedback & Support" section with links to GitHub Issues and Discussions

## Impact

- **Frontend**: `Layout.tsx` (footer link), `Layout.tsx` kebab menu (Help item), landing page HTML
- **No backend changes**: All links point to GitHub — no new API endpoints
- **No new dependencies**: Standard `<a>` tags with `target="_blank"`
- **Accessibility**: New links must meet existing WCAG standards (focus visible, keyboard navigable, descriptive link text)
- **i18n**: Link text and section headings need en/es translations
