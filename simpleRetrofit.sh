#!/usr/bin/env bash
#
# simpleRetrofit.sh - Run retrofit.sh with options set directly below.
#
# Edit the values in the CONFIG section, then run:
#   ./simpleRetrofit.sh
#
# Exit codes are propagated from retrofit.sh.

set -euo pipefail

# ============================================================================
# CONFIG - edit these values
# ============================================================================

# Required
BASE_BRANCH="main"
NEW_BRANCH="retrofit/my-change"
TARGET_BRANCH="feature/my-feature"
GITHUB_TOKEN="ghp_replace_me"

# Optional (leave empty to use defaults)
REMOTE="origin"          # default: origin
REVIEWERS=""             # e.g. "alice,bob"

# ============================================================================
# Do not edit below this line
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RETROFIT="$SCRIPT_DIR/retrofit.sh"

fail() {
  printf '[simpleRetrofit] ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[simpleRetrofit] INFO: %s\n' "$*"
}

[ -f "$RETROFIT" ] || fail "retrofit.sh not found at '$RETROFIT'."

[ -n "$BASE_BRANCH" ]   || fail "Missing required option: BASE_BRANCH"
[ -n "$NEW_BRANCH" ]    || fail "Missing required option: NEW_BRANCH"
[ -n "$TARGET_BRANCH" ] || fail "Missing required option: TARGET_BRANCH"
[ -n "$GITHUB_TOKEN" ]  || fail "Missing required option: GITHUB_TOKEN"

args=(-B "$BASE_BRANCH" -N "$NEW_BRANCH" -T "$TARGET_BRANCH" -t "$GITHUB_TOKEN")
[ -n "$REMOTE" ]    && args+=(-r "$REMOTE")
[ -n "$REVIEWERS" ] && args+=(-v "$REVIEWERS")

log "Running retrofit: base=$BASE_BRANCH new=$NEW_BRANCH target=$TARGET_BRANCH remote=${REMOTE:-origin} reviewers=${REVIEWERS:-<none>}"

exec bash "$RETROFIT" "${args[@]}"
