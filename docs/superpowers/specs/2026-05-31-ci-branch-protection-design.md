---
name: ci-branch-protection
description: CI workflow and branch protection design for the m1-tools overview repo
metadata:
  type: project
---

# CI & Branch Protection Design — m1-tools

## Scope

This spec covers the `m1-tools` documentation/overview repo only. The five sub-repos (`tree-sitter-m1`, `m1-core`, `m1-lsp`, `m1-fmt`, `m1-lint`) are out of scope.

---

## CI Workflow

**File:** `.github/workflows/ci.yml`

**Triggers:** `push` to `main`, `pull_request` targeting `main`.

**Jobs (run in parallel):**

### `lint`

- Tool: `markdownlint-cli` (via `npx markdownlint-cli`)
- Target: `README.md`
- Enforces: heading style, consistent code fences, trailing whitespace, and other default markdownlint rules
- Runner: `ubuntu-latest`

### `link-check`

- Tool: `lychee` (via `lychee-action`)
- Target: `README.md`
- Checks all URLs for 4xx/5xx responses
- Uses `GITHUB_TOKEN` to avoid rate-limiting on GitHub repo links
- Retries: 1 retry on timeout to reduce flakiness
- Runner: `ubuntu-latest`

Both jobs use only `actions/checkout` plus the respective tool's official action. No third-party actions.

---

## Branch Protection

Configured in GitHub Settings → Branches → Add rule for `main`.

| Setting | Value |
|---------|-------|
| Require pull request before merging | Enabled |
| Required approving reviews | 1 |
| Require status checks to pass | `lint`, `link-check` |
| Require branch to be up to date | Enabled |
| Allow bypassing by admins | Disabled |

Branch protection is applied manually after the CI workflow is pushed and has run at least once (so the status check names are registered with GitHub).

---

## Future Work (out of scope for this spec)

- Git submodules or `vcstool` config pointing to the five sub-repos, so cloning `m1-tools` pulls all child repos at their `main` heads.
