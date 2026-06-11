# m1-ci #37 — typecheck SARIF upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `sarif-upload: true` consumers get m1-typecheck findings in GitHub code scanning under their own category, alongside the existing m1-lint upload.

**Architecture:** Mirror the lint job's render/upload tail in check.yml's `typecheck` job: render `m1-typecheck --format sarif` (with the same `--project` plumbing as the check step) to `$RUNNER_TEMP/m1-typecheck.sarif`, guard against empty output, upload with `category: m1-typecheck`. A new ci.yml self-test job runs the pinned binary on a fixture with a known T002 (float-equality, project-independent) finding and asserts the SARIF contains it.

**Tech Stack:** GitHub Actions reusable workflow (check.yml), ci.yml self-tests, shell.

**Repo:** `/Users/christiannucifora/Documents/GitHub/m1-ci`, branch `fix/37-typecheck-sarif`, DRAFT PR closes #37.

**Blocked-on:** a m1-typecheck release containing `--format sarif` (PR #186 merged after v0.33.0; waiting on nedlane to cut it). The final commit bumps `M1_TYPECHECK_VERSION` in tools.env + the `typecheck-version` default in check.yml; until then the PR stays draft and its self-tests fail (expected — v0.33.0 has no `--format sarif`).

---

### Task 1: check.yml typecheck job — render + upload steps

- [ ] Append to the `typecheck` job, mirroring lint's steps verbatim (incl. the `!cancelled()` condition and empty-output guard): `Render SARIF (m1-typecheck --format sarif)` building the same `proj=(--project "$PROJECT_FILE")` array, then `Upload SARIF to code scanning` via `github/codeql-action/upload-sarif@v3` with `sarif_file: ${{ runner.temp }}/m1-typecheck.sarif`, `category: m1-typecheck`.

### Task 2: fixture + self-test

- [ ] Add `tests/fixture-typecheck-bad/T002.m1scr`: `local f = 1.5;` / `if (f == 2.5) { }` — validated locally: fires `error[T002]` and SARIF result `("T002","error")` in project-less mode.
- [ ] Add ci.yml job `self-test-typecheck-sarif` (style of `self-test-fail`): read `M1_TYPECHECK_VERSION` from tools.env, install via `./.github/actions/install-m1-tool`, run `m1-typecheck --format sarif` over the fixture, assert exit-nonzero semantics unchanged and the document contains `"ruleId":"T002"`.

### Task 3 (deferred until the release exists): version bump

- [ ] Bump `M1_TYPECHECK_VERSION` in tools.env and the `typecheck-version` default in check.yml to the first SARIF-bearing release; verify `tools-pins` job logic agrees; mark PR ready for review.
