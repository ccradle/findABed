#!/usr/bin/env bash
#
# capture.sh — Regenerate demo screenshots using Playwright (v0.55.1-D3)
#
# Prerequisites:
#   - dev-start.sh running with --nginx (port 8081) — required for capture
#     specs to hit the same path the production smoke gate uses. Bare Vite
#     (port 5173) misses nginx-layer concerns (CORS, SSE buffering, etc.)
#     per feedback_test_with_nginx_in_dev.
#   - Optionally --observability for Grafana/Jaeger captures.
#   - Node.js + Playwright installed in e2e/playwright/.
#
# Usage:
#   ./demo/capture.sh                  # Run all 10 capture specs
#   ./demo/capture.sh reentry          # Run only specs whose filename
#                                      # contains 'reentry' (substring filter)
#   ./demo/capture.sh dark-mode        # Run only the dark-mode capture spec
#   BASE_URL=https://findabed.org \
#     ./demo/capture.sh                # Override target (NOT recommended;
#                                      # the default is local nginx per
#                                      # feedback_smoke_spec_default_target).
#
# Exit codes:
#   0 — all matched specs ran successfully
#   1 — stack not running, no specs matched filter, or capture failed
#
set -euo pipefail

# --- Default target: local nginx, NOT findabed.org. Per
# feedback_smoke_spec_default_target — capture specs must default to local;
# live-site captures are a separate operator workflow.
: "${BASE_URL:=http://localhost:8081}"
export BASE_URL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODE_REPO="$REPO_ROOT/finding-a-bed-tonight"
PLAYWRIGHT_DIR="$CODE_REPO/e2e/playwright"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[DEMO]${NC} $1"; }
err()  { echo -e "${RED}[DEMO]${NC} $1"; }
info() { echo -e "${BLUE}[DEMO]${NC} $1"; }

# --- Canonical capture-spec list ---
# Enumerated explicitly (NOT glob-discovered) so adding a capture spec is an
# explicit operator decision and the list cannot accidentally grow with
# verification/test specs that happen to share the directory.
CAPTURE_SPECS=(
    capture-screenshots.spec.ts
    capture-analytics-screenshots.spec.ts
    capture-dv-screenshots.spec.ts
    capture-hmis-screenshots.spec.ts
    capture-mobile-header.spec.ts
    capture-notification-screenshots.spec.ts
    capture-offline-screenshots.spec.ts
    capture-platform-operator-screenshots.spec.ts
    capture-reentry-screenshots.spec.ts
    capture-totp-screenshots.spec.ts
)

# --- Filter ---
filter="${1:-}"
matched=()
for spec in "${CAPTURE_SPECS[@]}"; do
    if [[ -z "$filter" || "$spec" == *"$filter"* ]]; then
        matched+=("$spec")
    fi
done

if [[ ${#matched[@]} -eq 0 ]]; then
    err "No capture specs matched filter '$filter'."
    err "Available specs:"
    for spec in "${CAPTURE_SPECS[@]}"; do
        info "  $spec"
    done
    exit 1
fi

if [[ -n "$filter" ]]; then
    log "Filter '$filter' → ${#matched[@]} of ${#CAPTURE_SPECS[@]} specs"
else
    log "Running all ${#matched[@]} capture specs"
fi

# --- Check stack is running (against BASE_URL when local) ---
log "Checking if the stack is running at $BASE_URL..."

# Health is on backend (8080) regardless of frontend port. The nginx setup
# proxies the same backend, so we hit it directly.
if ! curl -sf http://localhost:8080/actuator/health/liveness >/dev/null 2>&1; then
    # Try management port (when --observability is active, liveness is on 9091)
    if ! curl -sf http://localhost:9091/actuator/health/liveness >/dev/null 2>&1; then
        err "Backend is not running. Start with: cd finding-a-bed-tonight && ./dev-start.sh --nginx"
        exit 1
    fi
fi

if ! curl -sf "$BASE_URL" >/dev/null 2>&1; then
    err "Frontend is not running at $BASE_URL."
    err "For local capture, start with: cd finding-a-bed-tonight && ./dev-start.sh --nginx"
    exit 1
fi

log "Stack is running."

# --- Check Playwright dir ---
if [ ! -d "$PLAYWRIGHT_DIR" ]; then
    err "Playwright directory not found: $PLAYWRIGHT_DIR"
    exit 1
fi

# --- Clear stale auth (per feedback_stale_jwt_auth_cache) ---
rm -rf "$PLAYWRIGHT_DIR/auth"

# --- Run matched capture specs ---
log "Capturing screenshots..."
cd "$PLAYWRIGHT_DIR"

# Build the "tests/<spec>" path list for npx
spec_paths=()
for spec in "${matched[@]}"; do
    spec_paths+=("tests/$spec")
done

npx playwright test "${spec_paths[@]}" --reporter=line 2>&1

# --- Report ---
echo ""
SCREENSHOTS="$SCRIPT_DIR/screenshots"
if [ -d "$SCREENSHOTS" ]; then
    COUNT=$(ls -1 "$SCREENSHOTS"/*.png 2>/dev/null | wc -l)
    log "Captured $COUNT screenshots in $SCREENSHOTS:"
    ls -1 "$SCREENSHOTS"/*.png | while read -r f; do
        info "  $(basename "$f")"
    done
    echo ""
    log "Open demo/index.html in a browser to view the walkthrough."
else
    err "No screenshots directory found. Capture may have failed."
    exit 1
fi
