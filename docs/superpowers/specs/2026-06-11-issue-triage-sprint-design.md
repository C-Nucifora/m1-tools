# Issue triage sprint — execution design

**Date:** 2026-06-11
**Scope:** 10 open issues across 7 toolchain repos, worked as four tracks.

## Goal

Close out the bulk of the open issues filed across the m1 toolchain (mostly
nedlane's 2026-06-11 triage pass) via one branch + one PR per issue.

## Workspace setup

Clone the needed repos into `~/Documents/GitHub/` alongside m1-tools:
m1-typecheck, m1-ci, m1-lint, telescope-m1.nvim, m1-fmt, tree-sitter-m1,
m1-lsp. All work happens on feature branches; `main` stays clean in every
clone.

## Branch and PR conventions

- Branch per issue: `fix/<issue-number>-<short-slug>` (e.g.
  `fix/185-sarif-format`).
- One PR per issue, targeting `main`, body includes `Closes #N`.
- No AI attribution in commits or PRs (per repo owner's commit policy).
- Tests run locally and passing before any push.

## Tracks

### Track 1 — SARIF pipeline (hands-on)

1. **m1-typecheck #185** — add `--format sarif`. Crib the SARIF schema and
   emitter structure from m1-lint's existing implementation for consistency
   across tools.
2. **m1-ci #37** — extend the sarif-upload workflow to also collect
   m1-typecheck findings. Depends on #185 being released; the PR notes the
   dependency and references the typecheck PR.

### Track 2 — independent quick wins (parallel subagents)

Dispatched while Track 1 is in progress; one agent per repo:

- **m1-fmt #102** — honour `@m1:fmt(off)` / `@m1:fmt(on)` region markers.
- **tree-sitter-m1 #44 + #45** — ship `queries/textobjects.scm`; refresh the
  stale PLAN.md/STATUS.md. Same repo, one agent, two branches/PRs.
- **m1-lint #118 + #119** — add severity/summary to `--rules --format json`;
  accept stdin (`-`, `--stdin-filename`). Same repo, one agent, two
  branches/PRs.

### Track 3 — telescope-m1.nvim #14 (after m1-lint #118 merges)

Read the rule catalogue from `m1-lint --rules --format json` at runtime and
retire the hand-synced `rules.lua` table. Blocked on #118's new fields.

### Track 4 — LSP features (hands-on, last)

- **m1-lsp #249** — quick-fix to insert `@m1:allow(CODE)` suppression for a
  lint/typecheck diagnostic.
- **m1-lsp #250** — `workspace/willRenameFiles`: renaming a `.m1scr` updates
  `.m1prj` and cross-script references.

## Out of scope

- m1-tools #19 (m1-doc proposal) and #10 (m1-cfg-export proposal) — design
  discussions, not fixes.
- m1-vscode #92 and nvim-m1 #61 (surface m1-project v0.4.0 CLI) — large
  editor-feature pair, separate effort.
- m1-vscode #79 (Marketplace/Open VSX decision) — a decision, not code.
- tree-sitter-m1 #46 (cargo-fuzz harness) — deferred.

## Error handling

If a subagent's tests fail or an issue turns out to be underspecified, it
reports back instead of pushing a broken PR, and we triage together. Cross-
repo ordering (Tracks 1 and 3) is enforced by sequencing, not automation.
