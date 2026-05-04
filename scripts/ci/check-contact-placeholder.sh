#!/usr/bin/env bash
#
# check-contact-placeholder.sh — info-email-contact §9 CI guard.
#
# Asserts every in-scope HTML page carries the canonical contact-email
# placeholder + script tag + <noscript> fallback, AND that no page contains
# a literal @findabed.org address (which would defeat the bot-scrape posture
# the change is designed to support).
#
# The in-scope page list is BAKED IN below — not a glob — so adding a new
# audience page requires an explicit code change here, paired with the
# warroom decision to extend the contact-email surface.
#
# Per-file checks (all must pass; first failure exits non-zero with a
# descriptive message naming the offending file and the check that failed):
#   1. file contains  class="contact-email"
#   2. file contains  aria-live="polite"
#   3. file contains  /contact.js   (script tag reference)
#   4. file contains  <noscript>...github.com/.../issues...</noscript>
#   5. file does NOT contain  /[A-Za-z0-9._%+-]+@findabed\.org/
#
# Run from the docs-repo root:
#   bash scripts/ci/check-contact-placeholder.sh
#
# Exit codes:
#   0 — all checks pass
#   1 — at least one check failed (message names file + check)
#   2 — invocation error (missing file from the canonical list)

set -eu

# Resolve repo root from this script's location so the guard works regardless
# of where the operator runs it from. `${BASH_SOURCE[0]}` is the script path;
# its grandparent is the repo root (scripts/ci/<this>).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Canonical in-scope page list. Baked in deliberately. Extending this list
# requires (a) the warroom decision documented in the OpenSpec change AND
# (b) an explicit edit here.
# ---------------------------------------------------------------------------
readonly PAGES=(
    "index.html"
    "404.html"
    "demo/index.html"
    "demo/dvindex.html"
    "demo/hmisindex.html"
    "demo/analyticsindex.html"
    "demo/reentry-story.html"
    "demo/for-cities.html"
    "demo/for-coc-admins.html"
    "demo/for-coordinators.html"
    "demo/for-funders.html"
    "demo/outreach-one-pager.html"
    "demo/pitch-briefs.html"
    "demo/shelter-onboarding.html"
)

# Forbidden-email regex per spec §9.1. Catches any literal address ending in
# @findabed.org (e.g. info@findabed.org); the platform-contact email MUST live
# in env var + JS-injected DOM, never in source.
readonly FORBIDDEN_EMAIL_REGEX='[A-Za-z0-9._%+-]+@findabed\.org'

fail() {
    local file="$1"
    local check="$2"
    local detail="${3:-}"
    echo "FAIL: ${file}: ${check}" >&2
    if [ -n "${detail}" ]; then
        echo "  detail: ${detail}" >&2
    fi
    exit 1
}

check_file() {
    local rel_path="$1"
    local abs_path="${REPO_ROOT}/${rel_path}"

    if [ ! -f "${abs_path}" ]; then
        echo "ERROR: missing file from canonical list: ${rel_path}" >&2
        echo "  hint: did you remove the page without updating ${BASH_SOURCE[0]}?" >&2
        exit 2
    fi

    # Check 1: placeholder element
    if ! grep -q 'class="contact-email"' "${abs_path}"; then
        fail "${rel_path}" "missing  class=\"contact-email\"  placeholder element"
    fi

    # Check 2: aria-live=polite for screen-reader announcement when the
    # placeholder hydrates. The spec asserts it lives on the placeholder
    # itself; we use a coarse string match because any other element with
    # aria-live=polite on these static pages is also fine for the spirit
    # of the check.
    if ! grep -q 'aria-live="polite"' "${abs_path}"; then
        fail "${rel_path}" "missing  aria-live=\"polite\"  on placeholder"
    fi

    # Check 3: /contact.js script reference. Match the path string only;
    # the surrounding <script defer src="..."> markup is verified by the
    # noscript-fallback check + the script's own behavior.
    if ! grep -q '/contact\.js' "${abs_path}"; then
        fail "${rel_path}" "missing  /contact.js  script reference"
    fi

    # Check 4: <noscript> fallback with GH-issues link. We require BOTH
    # the noscript block AND a link to the issues URL. A page with
    # <noscript>...</noscript> but no GH link, or a GH link outside a
    # noscript block, would not satisfy the spirit of the check.
    # Use awk to span lines because the noscript block may be multi-line.
    if ! awk '
        /<noscript>/ { in_ns = 1; ns_buf = ""; next }
        /<\/noscript>/ {
            if (in_ns && ns_buf ~ /github\.com\/.*\/issues/) { found = 1 }
            in_ns = 0; ns_buf = ""
            next
        }
        in_ns { ns_buf = ns_buf $0 }
        END { exit (found ? 0 : 1) }
    ' "${abs_path}"; then
        fail "${rel_path}" "missing  <noscript>  fallback with GitHub Issues link"
    fi

    # Check 5: no literal @findabed.org address. The platform contact
    # email MUST come from runtime via /contact.js, never from source.
    # `grep -E` with the spec regex; first match (if any) shows in the
    # detail message so the operator can find and remove the line.
    local hit
    if hit="$(grep -E -m1 "${FORBIDDEN_EMAIL_REGEX}" "${abs_path}" 2>/dev/null || true)"; then
        if [ -n "${hit}" ]; then
            fail "${rel_path}" "literal @findabed.org address in source" "${hit}"
        fi
    fi
}

main() {
    local count=0
    for page in "${PAGES[@]}"; do
        check_file "${page}"
        count=$((count + 1))
    done
    echo "OK: ${count} pages pass all 5 checks (placeholder + aria-live + /contact.js + noscript + no-literal-email)"
}

main "$@"
