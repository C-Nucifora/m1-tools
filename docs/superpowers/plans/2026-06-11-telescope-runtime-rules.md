# telescope-m1.nvim #14 — Runtime rule catalogue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the lint-rules picker's registry at runtime from `m1-lint --rules --format json` (catalogue v2: code/name/severity/fixable/summary), so new m1-lint releases appear in the picker with zero plugin changes and CI stops breaking on every lint release.

**Architecture:** `rules.lua` keeps only presentation concerns (docs URL, severity→highlight mapping) plus a static fallback snapshot used when the binary is missing. `M.all()` resolves the binary (nvim-m1-bundled first, then `$PATH`), parses the v2 catalogue (synthesising severity/summary for v1 output), caches per session, and falls back to the snapshot. `rules_spec.lua` asserts schema shape, not an exhaustive rule list.

**Tech Stack:** Lua (Neovim), plenary-busted via `scripts/test.sh`.

**Repo:** `/Users/christiannucifora/Documents/GitHub/telescope-m1.nvim`, branch `fix/14-runtime-rule-catalogue`, PR closes #14.

---

### Task 1: Runtime catalogue in rules.lua

**Files:**
- Modify: `lua/telescope-m1/rules.lua`
- Modify: `lua/telescope-m1/pickers/lint_rules.lua` (severity column via new helpers)
- Test: `tests/rules_spec.lua`

- [ ] **Step 1: Rewrite tests to the schema-shape contract** — replace the exhaustive code/fixability lists with: `parse_catalogue` unit tests (v2 sample → full fields; v1 sample → severity defaults to `warning`, summary synthesised from name; garbage/empty/`{}` → nil), `M.all()` shape test (every entry: `code:match("^L%d+$")`, non-empty name/severity/summary, boolean fixable), cache-identity test (`all()` returns the same table twice; `_invalidate()` resets), and severity helper tests (`error`→`DiagnosticError`, `warning`→`DiagnosticWarn`, unknown → default).
- [ ] **Step 2: Run tests, verify the new ones fail** — `scripts/test.sh` (export `TELESCOPE_PATH` to a fetched telescope.nvim if not in the lazy dir). Expected: failures for missing `severity_hl`/`_invalidate`/v2 parse.
- [ ] **Step 3: Rewrite `rules.lua`** — keep `docs_url`; demote the hand-synced table to `local fallback` (clearly commented as a non-load-bearing snapshot); `M.parse_catalogue` returns an `M1LintRule[]` (v1-tolerant as above); `M.binary_catalogue()` returns the parsed array; `M.all()` = cached `binary_catalogue() or fallback`; add `M.severity_hl(s)` + `M.severity_label(s)` and `M._invalidate()`.
- [ ] **Step 4: Point the picker at the helpers** — in `lint_rules.lua` replace the inline `rule.severity == "error" and …` pair with `rules.severity_label(rule.severity)` / `rules.severity_hl(rule.severity)`.
- [ ] **Step 5: Run the full suite + stylua** — `scripts/test.sh` green, `stylua --check lua/ tests/` clean.
- [ ] **Step 6: Commit, push, PR** — branch `fix/14-runtime-rule-catalogue`, PR body `Closes #14`, no AI attribution.
