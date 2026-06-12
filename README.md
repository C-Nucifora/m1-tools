# M1 Toolchain

A suite of developer tools for the MoTeC M1 scripting language (`.m1scr`), providing syntax highlighting, language server support, formatting, and linting across all major editors.

## Getting Started

Install [vcstool](https://github.com/dirk-thomas/vcstool):

```sh
pip install vcstool
```

Clone this repo and all sub-repos:

```sh
git clone https://github.com/C-Nucifora/m1-tools.git
cd m1-tools
vcs import .. < m1-tools.repos
```

Each sub-repo is cloned as a sibling of `m1-tools`. To update all sub-repos to latest `main`:

```sh
vcs pull .. < m1-tools.repos
```

## Tools

| Repo | Purpose |
| --- | --- |
| [tree-sitter-m1](https://github.com/C-Nucifora/tree-sitter-m1) | Tree-sitter grammar + Rust bindings |
| [m1-core](https://github.com/C-Nucifora/m1-core) | CST helpers and diagnostics library |
| [m1-workspace](https://github.com/nedlane/m1-workspace) | Shared filesystem/path conventions library that the tools depend on |
| [m1-lint](https://github.com/C-Nucifora/m1-lint) | Static analysis / linter (run `m1-lint --rules` for the catalogue) |
| [m1-lsp](https://github.com/C-Nucifora/m1-lsp) | Language Server Protocol implementation |
| [m1-vscode](https://github.com/nedlane/m1-vscode) | VS Code extension |
| [m1-typecheck](https://github.com/C-Nucifora/m1-typecheck) | Type/symbol model and type-rule diagnostics |
| [m1-fmt](https://github.com/C-Nucifora/m1-fmt) | Code formatter |
| [m1-project](https://github.com/nedlane/m1-project) | Validated CLI editor for `Project.m1prj` (create channels, set permissions/unit/type, set call rate) — invoked by the editors |
| [nvim-m1](https://github.com/C-Nucifora/nvim-m1) | Neovim plugin (LSP + tree-sitter + lint + fmt) |
| [telescope-m1.nvim](https://github.com/C-Nucifora/telescope-m1.nvim) | Telescope extension: symbol picker, component browser |
| [m1-ci](https://github.com/C-Nucifora/m1-ci) | Reusable GitHub Actions workflows for M1 projects |

### tree-sitter-m1

A [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) grammar for M1 script. Provides:

- Incremental, error-recovering parsing
- Editor queries (`.scm`): highlights, folds, indents, injections, locals, textobjects
- Rust bindings via `m1_tree_sitter`
- Corpus gate: every script in the example corpus parses with 0 errors (`scripts/check-corpus.sh`)

### m1-core

The shared parsing and diagnostics library used by all other tools. Exposes:

```rust
use m1_core::{parse, Cst, Node, Kind, Diagnostic, Code, Severity, Range, Position};
```

All higher-level tools (`m1-typecheck`, `m1-lsp`, `m1-fmt`, `m1-lint`) depend on this crate.
Tree-sitter is fully confined to this crate — consumers never see it directly.

### m1-lint

A static analysis tool that enforces the M1 Development Manual's style and
correctness rules (L0xx), with safe autofixes (`--fix`), SARIF output for code
scanning, stdin support, and baseline files for incremental adoption. The rule
catalogue is the tool's own output — run `m1-lint --rules` (add `--format json`
for the machine-readable form) or see the
[m1-lint README](https://github.com/C-Nucifora/m1-lint) — so it never drifts
from the binary you have installed. `m1-lint --explain L007` gives one rule's
full rationale and manual reference.

Configure via the unified `m1-tools.toml` (shared with the editors and the
other CLIs); a tool-specific `.m1lint.toml` overrides it, and CLI flags win
over both. Rules can be individually enabled, disabled, and tuned.

### m1-lsp

A Language Server Protocol server for M1 script. Integrates `m1-core`,
`m1-typecheck`, `m1-lint`, and `m1-fmt` behind a single LSP binary:

| Category | Features |
| --- | --- |
| Diagnostics | Syntax errors, lint rules, project-aware type diagnostics (push + pull, with quick-fixes and `@m1:allow` suppression) |
| Navigation | Go-to-definition/declaration/type-definition/implementation, references, document highlight, workspace symbols, call hierarchy, document links |
| Editing | Completion (trigger: `.`), signature help, rename with prepare-rename (incl. cross-file and file-rename cascades), code actions / fix-all |
| Display | Hover (per-segment, with class docs), inlay hints, semantic tokens (full + delta), folding/selection ranges, document outline, code lens (call rates) |
| Formatting | Full document, range, and on-type formatting via the embedded `m1-fmt` |
| Project | Discovers and loads `Project.m1prj` + `.m1cfg` + `.m1dbc`; watches `m1-tools.toml` and project files for changes |

See the [m1-lsp README](https://github.com/C-Nucifora/m1-lsp) for the complete,
current capability list.

### m1-vscode

The VS Code extension for M1 script. Bundles the `m1-lsp` binary for macOS (Apple Silicon), Linux (x86-64), and Windows (x86-64). Install from the [Releases page](https://github.com/nedlane/m1-vscode/releases):

```sh
code --install-extension m1-vscode-<platform>.vsix
```

Features: syntax highlighting, diagnostics, hover, completion, go-to-definition, find references, rename, inlay hints, semantic tokens, code actions, formatting, folding, and document/workspace symbol search.

### m1-typecheck

The type and symbol model for M1 script. Loads `Project.m1prj` symbol tables
(channels, parameters, enums, DBC signals, built-in intrinsics) and exposes
them to `m1-lsp` for hover, completion, rename, and inlay hints. The standalone
CLI runs the T0xx type rules (catalogue via `m1-typecheck --rules`; SARIF
output for code scanning), can explain a channel's units or invalid-value
provenance (`--explain`), and ships a second binary, `m1-cfg-export`, that
exports the expected `.m1cfg` parameter list from a project (CI drift checks
via `--missing-only`).

### m1-fmt

An opinionated code formatter for `.m1scr` files, modelled on `rustfmt`.
Defaults follow the M1 Development Manual (tabs, Allman braces) and are
configurable via `m1-tools.toml` / `.m1fmt.toml` for teams that diverge.
Supports `--check`/`--diff`/`-i`, stdin, `@m1:fmt(off|on)` regions, range
formatting (`--range`, backing editor format-on-selection), and directory
arguments.

---

## Command-line tools

`m1-fmt`, `m1-lint`, `m1-typecheck`, `m1-project`, and `m1-cfg-export` run
standalone (no editor required) — ideal for CI. See
**[docs/cli.md](docs/cli.md)** for a per-tool quickstart and the shared
conventions (exit codes, `--version`, `--help`, and the layered
`m1-tools.toml` / `.m1fmt.toml` / `.m1lint.toml` configuration).

---

## Editor Setup

### VS Code

Install the [m1-vscode](https://github.com/nedlane/m1-vscode) extension — it bundles everything. No separate installs required.

### Neovim

Install [nvim-m1](https://github.com/C-Nucifora/nvim-m1) — it registers the
grammar, the LSP, format-on-save, and lint, and downloads the pinned prebuilt
toolchain for your platform on install/update (no manual binary management):

```lua
-- lazy.nvim
{
  "C-Nucifora/nvim-m1",
  dependencies = {
    "C-Nucifora/tree-sitter-m1", -- the m1 grammar + queries (required)
    { "nvim-treesitter/nvim-treesitter", optional = true },
    { "neovim/nvim-lspconfig", optional = true }, -- only needed on Neovim 0.10
    { "stevearc/conform.nvim", optional = true },
    { "mfussenegger/nvim-lint", optional = true },
  },
  -- Downloads the bundled M1 toolchain (m1-lsp/fmt/lint/project) for your
  -- platform on install + update. Same as running :M1Install.
  build = function()
    require("nvim-m1.install").install()
  end,
  ft = { "m1scr", "m1prj" },
  opts = {},
}
```

Run `:checkhealth nvim-m1` to verify the setup. For symbol, component, and rule
pickers, add the [telescope-m1.nvim](https://github.com/C-Nucifora/telescope-m1.nvim)
extension alongside it:

```lua
{
  "C-Nucifora/telescope-m1.nvim",
  dependencies = { "nvim-telescope/telescope.nvim", "C-Nucifora/nvim-m1" },
  opts = {},
}
```

See the [nvim-m1 README](https://github.com/C-Nucifora/nvim-m1) for all options.

**Want just one piece?** Each tool also ships a standalone Neovim plugin, documented in that tool's repo: [tree-sitter-m1](https://github.com/C-Nucifora/tree-sitter-m1#neovim-setup) (grammar), [m1-lsp](https://github.com/C-Nucifora/m1-lsp/blob/main/editors/nvim/README.md) (LSP), [m1-fmt](https://github.com/C-Nucifora/m1-fmt/blob/main/editors/nvim/README.md) (formatter), and [m1-lint](https://github.com/C-Nucifora/m1-lint/blob/main/editors/nvim/README.md) (linter). `nvim-m1` is the supported way to combine them.

### Zed

Add to `settings.json`:

```json
{
  "lsp": {
    "m1-lsp": {
      "binary": { "path": "/path/to/m1-lsp/target/release/m1-lsp" }
    }
  },
  "languages": {
    "M1 Script": { "language_servers": ["m1-lsp"] }
  }
}
```

Tree-sitter grammar support in Zed requires the grammar to be registered; follow the [Zed extension guide](https://zed.dev/docs/extensions/languages) using `tree-sitter-m1` as the grammar source.

### Helix

Add to `~/.config/helix/languages.toml`:

```toml
[[language]]
name             = "m1scr"
scope            = "source.m1scr"
file-types       = ["m1scr"]
roots            = ["Project.m1prj"]
language-servers = ["m1-lsp"]
formatter        = { command = "m1-fmt", args = ["--stdin-filepath", "%"] }

[language-server.m1-lsp]
command = "/path/to/m1-lsp/target/release/m1-lsp"
```

Place the Tree-sitter grammar under `~/.config/helix/runtime/grammars/` following Helix's [adding languages guide](https://docs.helix-editor.com/guides/adding_languages.html).

### Emacs (eglot)

```elisp
(add-to-list 'auto-mode-alist '("\\.m1scr\\'" . prog-mode))
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(prog-mode . ("/path/to/m1-lsp/target/release/m1-lsp"))))
(add-hook 'prog-mode-hook
  (lambda ()
    (when (string= (file-name-extension (or buffer-file-name "")) "m1scr")
      (eglot-ensure))))
```

---

## Building from Source

All Rust tools require stable Rust via [rustup](https://rustup.rs/).

```sh
git clone https://github.com/C-Nucifora/m1-lsp
cd m1-lsp
cargo build --release
# Binary: ./target/release/m1-lsp
```

`tree-sitter-m1` additionally requires Node.js and the Tree-sitter CLI:

```sh
npm install -g tree-sitter-cli
cd tree-sitter-m1
tree-sitter generate
cargo build --release
```

> The Neovim plugins (`nvim-m1`, `telescope-m1.nvim`) are installed through your
> plugin manager, not built from source — see [Editor Setup → Neovim](#neovim).

### m1-ci

Reusable GitHub Actions workflows for any M1 script project. Reference the shared workflow:

```yaml
# .github/workflows/check.yml
jobs:
  m1-check:
    uses: C-Nucifora/m1-ci/.github/workflows/check.yml@v0.19.0
```

Runs `m1-fmt --check`, `m1-lint`, `m1-typecheck`, and `m1-project validate`
against pinned tool versions, with inline PR annotations and SARIF upload
for code scanning. The same gates run locally as
[pre-commit](https://pre-commit.com) hooks — see the
[m1-ci README](https://github.com/C-Nucifora/m1-ci).

> **Tip:** pin to the latest release tag (as above) rather than `@main` to avoid workflow drift.

---

## Architecture

```text
tree-sitter-m1                     ← grammar (C + Rust bindings)
      ↑
  m1-core      m1-workspace        ← CST helpers + diagnostics; shared fs/config/path conventions
      ↑             ↑
  ┌───┴───────┬─────┴────┬─────────────┐
m1-typecheck  m1-fmt   m1-lint   m1-project   ← domain libraries / CLIs
      ↑          ↑        ↑           ↑
      └──────────┴───┬────┘           │ (spawned by the editors)
                  m1-lsp              │      ← LSP server (integrates all)
                     ↑                │
        ┌────────────┼────────────────┘
   m1-vscode   nvim-m1 (+ telescope-m1.nvim)  ← editor clients
                     ·
                  m1-ci               ← reusable CI for M1 script projects
```

`m1-core`, `m1-workspace`, and `m1-typecheck` are library crates. `m1-fmt`,
`m1-lint`, and `m1-project` expose both a CLI and a library API. `m1-lsp`
integrates them behind a single LSP binary; the editor plugins bundle
pinned prebuilt binaries. Repos depend on each other via versioned git
tags, propagated by consumer-bump PRs on every upstream release.

---

## License

Licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later) — see [LICENSE](LICENSE).

Copyright (C) 2026 The M1 Tools authors.
