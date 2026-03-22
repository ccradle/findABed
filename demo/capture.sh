#!/usr/bin/env bash
#
# capture.sh — Regenerate demo screenshots using Playwright
#
# Prerequisites:
#   - dev-start.sh running (optionally with --observability for Grafana/Jaeger shots)
#   - Node.js + Playwright installed in e2e/playwright/
#
# Usage:
#   ./demo/capture.sh
#
set -euo pipefail

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

# --- Check stack is running ---
log "Checking if the stack is running..."

if ! curl -sf http://localhost:8080/actuator/health/liveness >/dev/null 2>&1; then
    # Try management port (when --observability is active, liveness is on 9091)
    if ! curl -sf http://localhost:9091/actuator/health/liveness >/dev/null 2>&1; then
        err "Backend is not running. Start with: cd finding-a-bed-tonight && ./dev-start.sh"
        exit 1
    fi
fi

if ! curl -sf http://localhost:5173 >/dev/null 2>&1; then
    err "Frontend is not running. Start with: cd finding-a-bed-tonight && ./dev-start.sh"
    exit 1
fi

log "Stack is running."

# --- Check Playwright ---
if [ ! -d "$PLAYWRIGHT_DIR" ]; then
    err "Playwright directory not found: $PLAYWRIGHT_DIR"
    exit 1
fi

# --- Clear stale auth ---
rm -rf "$PLAYWRIGHT_DIR/auth"

# --- Run capture ---
log "Capturing screenshots..."
cd "$PLAYWRIGHT_DIR"
npx playwright test tests/capture-screenshots.spec.ts --reporter=line 2>&1

# --- Report ---
echo ""
SCREENSHOTS="$SCRIPT_DIR/screenshots"
if [ -d "$SCREENSHOTS" ]; then
    COUNT=$(ls -1 "$SCREENSHOTS"/*.png 2>/dev/null | wc -l)
    log "Captured $COUNT screenshots:"
    ls -1 "$SCREENSHOTS"/*.png | while read -r f; do
        info "  $(basename "$f")"
    done
    echo ""
    log "Open demo/index.html in a browser to view the walkthrough."
else
    err "No screenshots directory found. Capture may have failed."
    exit 1
fi
