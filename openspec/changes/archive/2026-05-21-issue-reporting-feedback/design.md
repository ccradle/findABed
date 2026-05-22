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
- Give users across the app a visible, low-friction path to report problems from wherever they are in the app
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

**Constraint (Marcus):** URL pre-fill values SHALL be compile-time constants (`template`, `labels`), version-derived values (`fabt_version` from `/api/v1/version`), or `useContactInfo()`-derived addresses (the mailto fallback's `href`). The URL builder SHALL NOT read from `window.location.search`, `window.location.hash`, `document.title`, route parameters, JWT claim values (other than `dv_policy_enabled`, which is a render-time switch, not a URL parameter), or any user-supplied input. This guards against label-injection (a hostile share link cannot pre-fill `?labels=spam,wontfix,duplicate`) and against accidentally surfacing PII via reused `window.location` values.

### 3. Footer link (all pages) + kebab menu item (mobile)

The footer is the conventional location for "Report a Problem" in web apps (WCAG pattern: consistent location, consistently located in the footer). On mobile, the footer scrolls away — adding "Help" to the kebab menu keeps it one tap away from the kebab dropdown.

**Alternative considered:** Floating action button (FAB). Rejected: adds visual clutter, competes with "Hold This Bed" which is the primary action on mobile (Darius's 3-tap rule).

### 4. Landing page section with three paths

Public visitors (Teresa Nguyen evaluating the platform, Priya Anand reviewing for funding) need a visible feedback mechanism. Three paths:
- "Report a Problem" → `report-a-problem.yml` template
- "Request a Feature" → `feature-request.yml` template
- "Ask a Question" → GitHub Discussions Q&A

### 5. Open in new tab

All feedback links open in `target="_blank"` with `rel="noopener noreferrer"`. The user should not lose their place in the app when reporting an issue — especially Darius mid-hold or Sandra mid-update.

### 6. Privacy: what we deliberately do NOT pre-fill

URL pre-fill is allowed for: `template` (constant), `labels=triage` (constant), and `fabt_version` (read from `/api/v1/version`). URL pre-fill SHALL NEVER include: user role, tenant slug, tenant ID, user ID, user email, current page path, `window.location` parameters, route parameters, JWT claim values, or anything that could identify a survivor's location or a specific in-progress action. The earlier draft of this design listed "role" and "page context" as pre-fill values; that was retracted post info-email-contact archive (Casey veto: any PII-shaped funnel into a world-readable GitHub issue is unacceptable, since FABT cannot redact post-submit and the issue body is durably indexed by search engines).

### 7. Fallback for users without a GitHub account

The `useContactInfo()` hook shipped in info-email-contact (archived 2026-05-12) exposes the platform contact email at every authenticated render. The "Report a Problem" footer SHALL render a secondary `<a href="mailto:{platformEmail}">` link beneath the primary GitHub link when the hook returns a non-empty `resolvedEmail`. When the hook returns null/empty (env var unset, fetch failed), the secondary link is omitted (do NOT render a broken `mailto:` or a stale value). A `<noscript>` block renders a static link to the GitHub issues index as the no-JS path. Non-technical users (per Rev. Monroe / Devon personas) reach the platform-contact email without a GitHub account; technical users use the primary link.

**Constraint (Marcus, round 2):** The `mailto:` URL builder SHALL emit `mailto:{resolvedEmail}` with NO query parameters — no `?subject=`, no `?body=`, no `?cc=`. Some mail clients pre-populate the compose window from those parameters; a hostile backend response (or a compromised admin overriding `tenant.email`) could inject `mailto:victim@example.com?subject=phish&body=...`. The compile-time-constant rule from §2 applies here transitively: pre-fill values into the URL builder are addresses only.

### 8. DV-policy tenant treatment

When the authenticated user's tenant has `dv_policy_enabled === true`, the "Report a Problem" footer SHALL replace the GitHub-Issues link with the `mailto:` link from `useContactInfo()`. The mobile kebab "Help" item SHALL similarly route to the mailto link, not the GitHub issues chooser. The landing-page "Feedback & Support" section is public (no auth) and continues to expose the GitHub paths — the DV-policy gate is authenticated-context only.

**Source of truth (resolved 2026-05-12 round-2 warroom):** The frontend reads `tenant.dvPolicyEnabled` from the `useContactInfo()` hook's response, NOT from the JWT. Rationale: the JWT decode (`AuthContext.tsx`) does not currently carry the flag, and `GET /api/v1/tenants/{id}/config` is `@PreAuthorize("hasRole('COC_ADMIN')")` so OUTREACH and COORDINATOR (the bulk of authenticated footer renders) cannot read it. The existing public `GET /api/v1/public/contact-info` endpoint (info-email-contact, archived 2026-05-12) already evaluates `Tenant.isDvPolicyEnabled` at `ContactInfoController.java:189` for read-side suppression — we surface the boolean alongside the existing `tenant.email` field. **Invariant:** landing-page surface SHALL remain anonymous-only; any future addition of authenticated context to landing requires a re-evaluation of this exemption.

**Platform-operator treatment:** A platform-operator session (no bound tenant) SHALL fall through to default GitHub-link behavior — the response's `tenant` block is absent, `useContactInfo()` returns no `dvPolicyEnabled`, and the gate defaults to false.

Rationale (Casey): a survivor borrowing a coordinator's screen, or the coordinator herself, must not have the path-of-least-resistance be "type into a world-readable GitHub issue". A direct mailto to the project team is operationally redactable; a public GitHub issue is not.

## Risks / Trade-offs

- **GitHub account required** — Non-technical users (Rev. Monroe's volunteers) may not have GitHub accounts. Mitigation: the Discussions Q&A is lower-barrier, and we can add a "no GitHub account?" note directing to a CoC admin contact. A future OpenSpec could add email-based submission.
- **GitHub UI may change** — Template URL parameter format is undocumented but stable. Mitigation: links degrade gracefully to the template chooser if parameters are invalid.
- **i18n of GitHub content** — Issue templates are English-only. Spanish-speaking users will see a Spanish in-app link leading to an English form. Mitigation: acceptable for now; GitHub does not support localized issue templates.
