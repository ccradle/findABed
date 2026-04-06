## Context

The platform has GitHub issue templates (bug report, report a problem, feature request, documentation) and Discussions enabled, but no links from the application or public site to reach them. The primary users are non-technical (shelter coordinators, outreach workers, faith community volunteers) who will never discover `github.com/ccradle/finding-a-bed-tonight/issues` on their own.

Current state:
- GitHub issue templates: 4 YAML forms + config (committed 2026-04-06)
- Discussions Q&A: enabled on repo
- In-app: no help, feedback, or issue reporting links anywhere
- Landing page: no feedback section
- Mobile kebab menu: 4 items (username, language, password, security, sign out)

## Goals / Non-Goals

**Goals:**
- Give every user a visible, low-friction path to report problems from wherever they are in the app
- Pre-fill issue context (app version, user role) to reduce friction and improve triage quality
- Surface the GitHub Discussions Q&A as a support channel for questions that aren't bugs
- Ensure the feedback path works for both technical users (GitHub-native) and non-technical users (the "Report a Problem" plain-language template)

**Non-Goals:**
- In-app issue submission (no embedded form — GitHub handles the form UI)
- In-app notifications or status tracking of submitted issues
- A custom support/ticketing system
- Analytics or telemetry on issue submission rates

## Decisions

### 1. Link to GitHub issue templates, don't embed a form

GitHub's YAML form templates provide structured input, required fields, and label auto-assignment. Embedding a form would require a backend endpoint, CORS handling, GitHub API integration, and duplicate validation — all for inferior UX compared to GitHub's native form renderer.

**Alternative considered:** Embedded feedback widget (e.g., Canny, UserVoice). Rejected: adds a dependency, requires an account, and the project already has GitHub Issues as the canonical tracker.

### 2. Pre-fill issue URL parameters for context

GitHub issue templates support URL parameters: `template`, `title`, `labels`, and field values via query params. The app can construct a URL like:

```
https://github.com/ccradle/finding-a-bed-tonight/issues/new?template=report-a-problem.yml&title=[Problem]:+&labels=bug,triage
```

This reduces user effort and improves triage. App version and page context can be appended to the URL.

### 3. Footer link (all pages) + kebab menu item (mobile)

The footer is the conventional location for "Report a Problem" in web apps (WCAG pattern: consistent location, always reachable). On mobile, the footer scrolls away — adding "Help" to the kebab menu ensures it's always one tap away.

**Alternative considered:** Floating action button (FAB). Rejected: adds visual clutter, competes with "Hold This Bed" which is the primary action on mobile (Darius's 3-tap rule).

### 4. Landing page section with three paths

Public visitors (Teresa Nguyen evaluating the platform, Priya Anand reviewing for funding) need a visible feedback mechanism. Three paths:
- "Report a Problem" → `report-a-problem.yml` template
- "Request a Feature" → `feature-request.yml` template
- "Ask a Question" → GitHub Discussions Q&A

### 5. Open in new tab

All feedback links open in `target="_blank"` with `rel="noopener noreferrer"`. The user should not lose their place in the app when reporting an issue — especially Darius mid-hold or Sandra mid-update.

## Risks / Trade-offs

- **GitHub account required** — Non-technical users (Rev. Monroe's volunteers) may not have GitHub accounts. Mitigation: the Discussions Q&A is lower-barrier, and we can add a "no GitHub account?" note directing to a CoC admin contact. A future OpenSpec could add email-based submission.
- **GitHub UI may change** — Template URL parameter format is undocumented but stable. Mitigation: links degrade gracefully to the template chooser if parameters are invalid.
- **i18n of GitHub content** — Issue templates are English-only. Spanish-speaking users will see a Spanish in-app link leading to an English form. Mitigation: acceptable for now; GitHub does not support localized issue templates.
