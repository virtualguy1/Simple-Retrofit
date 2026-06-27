# SimpleRetrofit

A small Bash toolkit to automate a **retrofit** workflow: take changes from one
branch into a fresh branch cut off a base branch, push it, and open a pull
request — either via command-line flags or a config file.

## What it does

Given a base branch, a target branch, and a new branch name, the script:

1. Fetches from the remote.
2. Checks out the **base branch** and pulls the latest.
3. Cuts a **new branch** off the updated base.
4. Pulls (merges) the **target branch** into the new branch.
5. Pushes the new branch to the remote.
6. Opens a PR from the new branch into the base branch (optionally requesting reviewers).
7. Prints the PR URL on success, or an error with the failure reason.

## Requirements

- **Bash**
- **git**
- **[GitHub CLI `gh`](https://cli.github.com/)** — used to create the pull request.
- A **GitHub token** with permission to push and open PRs on the repository.
- The script must be run from **inside the target git repository**.

## Files

| File                     | Purpose                                              |
| ------------------------ | ---------------------------------------------------- |
| `retrofit.sh`            | Core script driven by command-line flags.            |
| `simpleRetrofit.sh`      | Wrapper with options set directly in the script.     |

## Usage

### Option A — `retrofit.sh` (flags)

```bash
./retrofit.sh -B <base_branch> -N <new_branch> -T <target_branch> -t <github_token> [-r <remote>] [-v <reviewers>]
```

| Flag | Description                                             | Required | Default  |
| ---- | ------------------------------------------------------- | -------- | -------- |
| `-B` | Base branch to checkout and open the PR against         | Yes      | —        |
| `-N` | Name of the new branch to create                        | Yes      | —        |
| `-T` | Target branch to be merged into the new branch          | Yes      | —        |
| `-t` | GitHub token for authentication                         | Yes      | —        |
| `-r` | Remote to push to                                       | No       | `origin` |
| `-v` | Comma-separated GitHub usernames to request review from | No       | —        |

Example:

```bash
./retrofit.sh -B main -N retrofit/my-change -T feature/my-feature -t ghp_xxx -v alice,bob
```

### Option B — `simpleRetrofit.sh` (options set in the script)

Edit the **CONFIG** section near the top of `simpleRetrofit.sh`, then run it
(no flags or config file needed):

```bash
./simpleRetrofit.sh
```

CONFIG section to edit:

```bash
# Required
BASE_BRANCH="main"
NEW_BRANCH="retrofit/my-change"
TARGET_BRANCH="feature/my-feature"
GITHUB_TOKEN="ghp_replace_me"

# Optional (leave empty to use defaults)
REMOTE="origin"          # default: origin
REVIEWERS=""             # e.g. "alice,bob"
```

`simpleRetrofit.sh` must live in the same directory as `retrofit.sh`. It
validates the values, builds the flags, and delegates to `retrofit.sh`,
propagating its exit code.

## Exit codes

`retrofit.sh` uses a distinct exit code per stage so failures are easy to script against:

| Code | Meaning                          |
| ---- | -------------------------------- |
| `0`  | Success                          |
| `1`  | Usage / missing required argument |
| `2`  | Not a git repository             |
| `3`  | `gh` not installed / auth failure |
| `4`  | Fetch failure                    |
| `5`  | Checkout base failure            |
| `6`  | Pull base failure                |
| `7`  | Create new branch failure        |
| `8`  | Pull target failure              |
| `9`  | Push failure                     |
| `10` | PR creation failure              |

`simpleRetrofit.sh` exits `1` on config errors and otherwise propagates the code from `retrofit.sh`.

## Notes

- Keep your GitHub token secret. Prefer passing it via the config file (excluded
  from version control) rather than shell history.
- If the merge in step 4 produces conflicts, the script stops with exit code `8`;
  resolve conflicts and re-run as needed.
