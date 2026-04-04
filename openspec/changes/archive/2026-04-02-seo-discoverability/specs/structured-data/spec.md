## ADDED Requirements

### Requirement: Organization schema on landing page
The root `index.html` SHALL include a JSON-LD `<script>` block with `@type: Organization` containing: name, URL, logo, description, and sameAs links to the GitHub repositories.

#### Scenario: Google recognizes organization
- **WHEN** Google crawls `https://findabed.org/`
- **THEN** the page contains valid JSON-LD with `@type: "Organization"` that passes Google's Rich Results Test

### Requirement: SoftwareApplication schema on landing page
The root `index.html` SHALL include a JSON-LD `<script>` block with `@type: SoftwareApplication` containing: name, applicationCategory (WebApplication), operatingSystem, license (Apache-2.0), offers (free), and sourceCode URL.

#### Scenario: Software listed in search results
- **WHEN** Google indexes the landing page
- **THEN** the structured data enables rich result display showing the application name, category, and free price

### Requirement: FAQPage schema on for-cities page
The `demo/for-cities.html` page SHALL include a JSON-LD `<script>` block with `@type: FAQPage` containing each H2 section as a Question with its content as the Answer.

#### Scenario: FAQ rich results
- **WHEN** someone searches for "open source shelter software for cities"
- **THEN** Google MAY display FAQ-style rich snippets from the for-cities page questions (Who Owns the Data?, Accessibility, Security Posture, Licensing, Support Model, What's Different)

#### Scenario: Schema validates
- **WHEN** the for-cities page JSON-LD is tested with Google's Rich Results Test
- **THEN** zero errors are reported

### Requirement: HowTo schema on shelter-onboarding page
The `demo/shelter-onboarding.html` page SHALL include a JSON-LD `<script>` block with `@type: HowTo` containing the three-act onboarding process as steps (Import, Correct, Protect) with descriptions and images.

#### Scenario: How-to rich results
- **WHEN** someone searches for "how to onboard a shelter to a bed management system"
- **THEN** Google MAY display step-by-step rich snippets from the shelter-onboarding page

#### Scenario: HowTo schema validates
- **WHEN** the shelter-onboarding page JSON-LD is tested with Google's Rich Results Test
- **THEN** zero errors are reported
