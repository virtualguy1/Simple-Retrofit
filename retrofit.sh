#!/usr/bin/env bash
#
# retrofit.sh - Create a retrofit branch and open a PR.
#
# Workflow:
#   1. Checkout the base branch and pull latest.
#   2. Cut a new branch off the updated base.
#   3. Pull (merge) the target branch into the new branch.
#   4. Push the new branch to the remote.
#   5. Open a PR from the new branch into the base branch.
#
# Flags:
#   -B <base_branch>    Base branch to checkout and open the PR against (required)
#   -N <new_branch>     Name of the new branch to create (required)
#   -T <target_branch>  Branch to be merged into the new branch (required)
#   -t <github_token>   GitHub token for authentication (required)
#   -r <remote>         Remote to push to (optional, default: origin)
#   -v <reviewers>      Comma-separated GitHub usernames to request review from (optional)
#
# Exit codes:
#   0  success
#   1  usage / missing required argument
#   2  not a git repository
#   3  gh not installed / auth failure
#   4  fetch failure
#   5  checkout base failure
#   6  pull base failure
#   7  create new branch failure
#   8  pull target failure
#   9  push failure
#   10 PR creation failure

set -euo pipefail

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log() {
  printf '[retrofit] INFO: %s\n' "$*"
}

# fail <exit_code> <message>
fail() {
  local code="$1"; shift
  printf '[retrofit] ERROR: %s\n' "$*" >&2
  exit "$code"
}

usage() {
  cat >&2 <<'EOF'
Usage: retrofit.sh -B <base_branch> -N <new_branch> -T <target_branch> -t <github_token> [-r <remote>] [-v <reviewers>]

Required:
  -B <base_branch>    Base branch to checkout and open the PR against
  -N <new_branch>     Name of the new branch to create
  -T <target_branch>  Branch to be merged into the new branch
  -t <github_token>   GitHub token for authentication

Optional:
  -r <remote>         Remote to push to (default: origin)
  -v <reviewers>      Comma-separated GitHub usernames to request review from
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
BASE_BRANCH=""
NEW_BRANCH=""
TARGET_BRANCH=""
GITHUB_TOKEN=""
REMOTE="origin"
REVIEWERS=""

while getopts "B:N:T:r:t:v:h" opt; do
  case "$opt" in
    B) BASE_BRANCH="$OPTARG" ;;
    N) NEW_BRANCH="$OPTARG" ;;
    T) TARGET_BRANCH="$OPTARG" ;;
    t) GITHUB_TOKEN="$OPTARG" ;;
    r) REMOTE="$OPTARG" ;;
    v) REVIEWERS="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[ -n "$BASE_BRANCH" ]   || { usage; fail 1 "Missing required argument: -B <base_branch>"; }
[ -n "$NEW_BRANCH" ]    || { usage; fail 1 "Missing required argument: -N <new_branch>"; }
[ -n "$TARGET_BRANCH" ] || { usage; fail 1 "Missing required argument: -T <target_branch>"; }
[ -n "$GITHUB_TOKEN" ]  || { usage; fail 1 "Missing required argument: -t <github_token>"; }

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
log "Validating environment..."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || fail 2 "Not inside a git repository."

command -v gh >/dev/null 2>&1 \
  || fail 3 "GitHub CLI 'gh' is not installed. Install it from https://cli.github.com/ and retry."

# Authenticate gh using the provided token for all subsequent gh calls.
export GH_TOKEN="$GITHUB_TOKEN"

gh auth status >/dev/null 2>&1 \
  || fail 3 "GitHub authentication failed. Check that the provided token is valid."

log "Configuration: base=$BASE_BRANCH new=$NEW_BRANCH target=$TARGET_BRANCH remote=$REMOTE reviewers=${REVIEWERS:-<none>}"

# ---------------------------------------------------------------------------
# Workflow
# ---------------------------------------------------------------------------
log "Stage 1/6: Fetching from remote '$REMOTE'..."
git fetch "$REMOTE" \
  || fail 4 "Failed to fetch from remote '$REMOTE'."
log "Stage 1/6: Fetch complete."

log "Stage 2/6: Checking out base branch '$BASE_BRANCH'..."
git checkout "$BASE_BRANCH" \
  || fail 5 "Failed to checkout base branch '$BASE_BRANCH'."
log "Stage 2/6: Checked out '$BASE_BRANCH'."

log "Stage 3/6: Pulling latest '$BASE_BRANCH' from '$REMOTE'..."
git pull "$REMOTE" "$BASE_BRANCH" \
  || fail 6 "Failed to pull '$BASE_BRANCH' from '$REMOTE'."
log "Stage 3/6: '$BASE_BRANCH' is up to date."

log "Stage 4/6: Creating new branch '$NEW_BRANCH' off '$BASE_BRANCH'..."
git checkout -b "$NEW_BRANCH" \
  || fail 7 "Failed to create new branch '$NEW_BRANCH'."
log "Stage 4/6: Created and switched to '$NEW_BRANCH'."

log "Stage 5/6: Merging target branch '$TARGET_BRANCH' into '$NEW_BRANCH'..."
git pull "$REMOTE" "$TARGET_BRANCH" \
  || fail 8 "Failed to pull/merge target branch '$TARGET_BRANCH' into '$NEW_BRANCH'. Resolve conflicts and retry."
log "Stage 5/6: Merged '$TARGET_BRANCH' into '$NEW_BRANCH'."

log "Stage 6/6: Pushing '$NEW_BRANCH' to '$REMOTE'..."
git push -u "$REMOTE" "$NEW_BRANCH" \
  || fail 9 "Failed to push '$NEW_BRANCH' to '$REMOTE'."
log "Stage 6/6: Pushed '$NEW_BRANCH' to '$REMOTE'."

# ---------------------------------------------------------------------------
# Open the pull request
# ---------------------------------------------------------------------------
log "Opening pull request: $NEW_BRANCH -> $BASE_BRANCH..."

PR_TITLE="Retrofit: merge $TARGET_BRANCH into $BASE_BRANCH"
PR_BODY="Automated retrofit PR.

- Base branch: \`$BASE_BRANCH\`
- New branch:  \`$NEW_BRANCH\`
- Merged-in:   \`$TARGET_BRANCH\`"

pr_args=(
  --base "$BASE_BRANCH"
  --head "$NEW_BRANCH"
  --title "$PR_TITLE"
  --body "$PR_BODY"
)

if [ -n "$REVIEWERS" ]; then
  pr_args+=(--reviewer "$REVIEWERS")
  log "Requesting reviewers: $REVIEWERS"
fi

if ! PR_URL="$(gh pr create "${pr_args[@]}" 2>&1)"; then
  fail 10 "Failed to create pull request: $PR_URL"
fi

log "Pull request created successfully."
printf '%s\n' "$PR_URL"
exit 0
