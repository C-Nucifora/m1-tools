# CI & Branch Protection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-job CI workflow (markdown lint + link check) and configure branch protection on `main` requiring 1 approval and both CI jobs to pass.

**Architecture:** A single GitHub Actions workflow file runs two parallel jobs on every push/PR to `main`. A `.markdownlint.json` config file pins rule overrides. Branch protection is applied manually in GitHub Settings after CI runs once to register the status check names.

**Tech Stack:** GitHub Actions, `markdownlint-cli` (npm), `lychee` (link checker via `lychee-action`)

---

### Task 1: Add markdownlint config

**Files:**
- Create: `.markdownlint.json`

- [ ] **Step 1: Create the config file**

  Create `.markdownlint.json` at the repo root with the following content. This keeps all default rules on but relaxes line length (MD013) which is noisy for README tables and code blocks, and allows inline HTML (MD033) used in the architecture ASCII diagram area:

  ```json
  {
    "default": true,
    "MD013": false,
    "MD033": false
  }
  ```

- [ ] **Step 2: Verify markdownlint passes locally**

  Run:
  ```bash
  npx markdownlint-cli README.md --config .markdownlint.json
  ```

  Expected: no output, exit code 0. If violations appear, fix them in `README.md` before continuing.

- [ ] **Step 3: Commit**

  ```bash
  git add .markdownlint.json
  git commit -m "ci: add markdownlint config"
  ```

---

### Task 2: Create the CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create the workflow directory**

  ```bash
  mkdir -p .github/workflows
  ```

- [ ] **Step 2: Write the workflow file**

  Create `.github/workflows/ci.yml`:

  ```yaml
  name: CI

  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]

  jobs:
    lint:
      name: lint
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Run markdownlint
          run: npx markdownlint-cli README.md --config .markdownlint.json

    link-check:
      name: link-check
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Check links
          uses: lycheeverse/lychee-action@v2
          with:
            args: --retry-wait-time 5 --max-retries 1 README.md
            fail: true
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ```

- [ ] **Step 3: Commit and push**

  ```bash
  git add .github/workflows/ci.yml
  git commit -m "ci: add markdown lint and link check workflow"
  git push origin main
  ```

- [ ] **Step 4: Confirm both jobs pass**

  Go to `https://github.com/C-Nucifora/m1-tools/actions` and confirm the workflow run triggered by the push shows both `lint` and `link-check` jobs green.

  If `lint` fails: fix the reported `README.md` violations, commit, and push again.

  If `link-check` fails: inspect the job output for dead URLs. Either fix the URLs in `README.md` or add an exclusion pattern to the `args` line, e.g. `--exclude 'example\.com'`.

---

### Task 3: Configure branch protection on `main`

This task is performed in the GitHub UI. There is no config file — GitHub does not support branch protection via committed files without a third-party action.

- [ ] **Step 1: Open branch protection settings**

  Navigate to:
  `https://github.com/C-Nucifora/m1-tools/settings/branches`

  Click **Add branch protection rule** (or **Add classic branch protection rule** if rulesets are not available on your plan).

- [ ] **Step 2: Set the branch name pattern**

  In the **Branch name pattern** field enter:
  ```
  main
  ```

- [ ] **Step 3: Enable pull request requirement**

  Check **Require a pull request before merging**.

  Under the expanded options, set **Required number of approvals before merging** to `1`.

  Leave **Dismiss stale pull request approvals when new commits are pushed** unchecked (optional — enable if you want reviews invalidated by new commits).

- [ ] **Step 4: Enable status check requirement**

  Check **Require status checks to pass before merging**.

  Check **Require branches to be up to date before merging**.

  In the search box under **Status checks that are required**, search for and add both:
  - `lint`
  - `link-check`

  These names only appear after CI has run at least once (Task 2, Step 4 must be complete first).

- [ ] **Step 5: Disable admin bypass**

  Check **Do not allow bypassing the above settings**.

- [ ] **Step 6: Save**

  Click **Create** (or **Save changes**). The `main` branch is now protected.

- [ ] **Step 7: Verify protection is active**

  On the repo's main page, the `main` branch should show a lock icon next to the branch name. Attempting to push directly to `main` should now fail with:

  ```
  remote: error: GH006: Protected branch update failed for refs/heads/main.
  ```
