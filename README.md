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
| [m1-lint](https://github.com/C-Nucifora/m1-lint) | Static analysis / linter (12 rules) |
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
- Syntax highlighting queries (`.scm`)
- Rust bindings via `m1_tree_sitter`
- Corpus gate: all 80 EV-M1 production scripts parse with 0 errors (`scripts/check-corpus.sh`)

### m1-core

The shared parsing and diagnostics library used by all other tools. Exposes:

```rust
use m1_core::{parse, Cst, Node, Kind, Diagnostic, Code, Severity, Range, Position};
```

All higher-level tools (`m1-typecheck`, `m1-lsp`, `m1-fmt`, `m1-lint`) depend on this crate.
Tree-sitter is fully confined to this crate — consumers never see it directly.

### m1-lint

A static analysis tool that enforces M1 style and correctness rules. Twelve rules ship in v1:

| Code | Rule |
| --- | --- |
| L001 | line-too-long (configurable, default 88) |
| L002 | trailing-whitespace |
| L003 | missing-final-newline |
| L004 | eq-operator-preferred (`==` → `eq`, `!=` → `neq`) |
| L005 | logical-operator-preferred (`&&` → `and`, `\|\|` → `or`, `!` → `not`) |
| L006 | float-eq-comparison (heuristic; suppressed when type model is loaded) |
| L007 | operator-spacing |
| L008 | nesting-too-deep (configurable, default 4) |
| L009 | cyclomatic-complexity (configurable, default 10) |
| L010 | tab-for-indentation |
| L011 | comment-style |
| L012 | unused-local |

Configure via `.m1lint.toml` in the project root. Rules can be individually enabled, disabled, and tuned.

### m1-lsp

A Language Server Protocol server for M1 script. Integrates `m1-core`, `m1-typecheck`, and `m1-lint` behind a single LSP binary. Capabilities:

| Category | Features |
| --- | --- |
| Diagnostics | Syntax errors, 12 lint rules, type diagnostics (when project loaded) |
| Navigation | Go-to-definition, find-all-references, document highlight, workspace symbol search |
| Editing | Completion (trigger: `.`), signature help, rename with prepare-rename, code actions |
| Display | Hover, inlay type-hints, semantic tokens (full), folding ranges, document outline |
| Formatting | `textDocument/formatting` + range formatting (stub — active once `m1-fmt` ships) |
| Project | Discovers and loads `Project.m1prj` + `.m1cfg` + `.m1dbc`; watches for changes |

> **Note:** Formatting returns no edits until `m1-fmt` is implemented. All other features are active.

### m1-vscode

The VS Code extension for M1 script. Bundles the `m1-lsp` binary for macOS (Apple Silicon), Linux (x86-64), and Windows (x86-64). Install from the [Releases page](https://github.com/nedlane/m1-vscode/releases):

```sh
code --install-extension m1-vscode-<platform>.vsix
```

Features: syntax highlighting, diagnostics, hover, completion, go-to-definition, find references, rename, inlay hints, semantic tokens, code actions, formatting, folding, and document/workspace symbol search.

### m1-typecheck

The type and symbol model for M1 script. Loads `Project.m1prj` symbol tables (channels, parameters, enums, DBC signals) and exposes them to `m1-lsp` for hover, completion, rename, and inlay hints.

### m1-fmt

An opinionated code formatter for `.m1scr` files, modelled on `rustfmt`.

---

## Command-line tools

`m1-fmt`, `m1-lint`, and `m1-typecheck` run standalone on `.m1scr` scripts
(no editor required) — ideal for CI. See **[docs/cli.md](docs/cli.md)** for a
per-tool quickstart and the shared conventions (exit codes, `--version`,
`--help`, and the layered `m1-tools.toml` / `.m1fmt.toml` / `.m1lint.toml`
configuration).

---

## Editor Setup

### VS Code

Install the [m1-vscode](https://github.com/nedlane/m1-vscode) extension — it bundles everything. No separate installs required.

### Neovim

Prerequisites: [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig). Optionally [conform.nvim](https://github.com/stevearc/conform.nvim) and [nvim-lint](https://github.com/mfussenegger/nvim-lint).

Add to your [lazy.nvim](https://github.com/folke/lazy.nvim) plugin spec (e.g. `~/.config/nvim/lua/plugins/m1.lua`):

```lua
return {
  -- 1. Tree-sitter grammar: syntax highlighting and indentation
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Register the m1 grammar before nvim-treesitter setup
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.m1 = {
        install_info = {
          url   = "https://github.com/C-Nucifora/tree-sitter-m1",
          files = { "src/parser.c", "src/scanner.c" },
          branch = "main",
        },
        filetype = "m1scr",
      }
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "m1" })
    end,
  },

  -- 2. LSP: diagnostics, hover, completion, rename, go-to-definition, inlay hints
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      local configs   = require("lspconfig.configs")

      -- Register m1-lsp (not yet upstream in nvim-lspconfig)
      if not configs.m1_lsp then
        configs.m1_lsp = {
          default_config = {
            cmd              = { "m1-lsp" },   -- must be on $PATH, or use full path
            filetypes        = { "m1scr" },
            root_dir         = lspconfig.util.root_pattern("Project.m1prj", ".git"),
            single_file_support = true,
          },
        }
      end
      lspconfig.m1_lsp.setup({})
    end,
  },

  -- 3. Format-on-save via conform.nvim (no-op until m1-fmt ships)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { m1scr = { "m1_fmt" } },
      formatters = {
        m1_fmt = {
          command = "m1-fmt",
          args    = { "--stdin-filepath", "$FILENAME" },
          stdin   = true,
        },
      },
    },
  },

  -- 4. Standalone lint via nvim-lint (supplements LSP diagnostics)
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")
      lint.linters.m1_lint = {
        cmd            = "m1-lint",
        stdin          = true,
        args           = { "--stdin-filepath", function() return vim.api.nvim_buf_get_name(0) end },
        stream         = "stdout",
        ignore_exitcode = true,
        parser         = require("lint.parser").from_pattern(
          "([^:]+):(%d+):(%d+): (%a+): %[([LT]%d+)%] (.+)",
          { "file", "lnum", "col", "severity", "code", "message" }
        ),
      }
      lint.linters_by_ft = { m1scr = { "m1_lint" } }
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
        callback = function() lint.try_lint() end,
      })
    end,
  },
}
```

Add `.m1scr` file type detection (e.g. in `~/.config/nvim/lua/vim-options.lua`):

```lua
vim.filetype.add({ extension = { m1scr = "m1scr" } })
```

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

### nvim-m1

A [lazy.nvim](https://github.com/folke/lazy.nvim) plugin that wires tree-sitter, nvim-lspconfig, conform.nvim, and nvim-lint together in a single `require("nvim-m1").setup({})` call — the Neovim equivalent of m1-vscode.

Install in your plugin spec:

```lua
{
  "C-Nucifora/nvim-m1",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "neovim/nvim-lspconfig",
    "stevearc/conform.nvim",
    "mfussenegger/nvim-lint",
  },
  opts = {},
}
```

### telescope-m1.nvim

A [Telescope](https://github.com/nvim-telescope/telescope.nvim) extension providing:

- **Workspace symbols** — fuzzy-search channels, parameters, and enums in the loaded project
- **Component browser** — browse the `.m1prj` component hierarchy
- **Lint rule picker** — toggle or navigate `m1-lint` rules

Install alongside `nvim-m1`:

```lua
{
  "C-Nucifora/telescope-m1.nvim",
  dependencies = { "nvim-telescope/telescope.nvim", "C-Nucifora/nvim-m1" },
  opts = {},
}
```

### m1-ci

Reusable GitHub Actions workflows for any M1 script project. Reference the shared workflow:

```yaml
# .github/workflows/check.yml
jobs:
  m1-check:
    uses: C-Nucifora/m1-ci/.github/workflows/check.yml@main
```

Runs: `m1-lint` on all `.m1scr` files, `m1-typecheck` project validation, and a corpus parse gate.

> **Tip:** pin to a release tag once published (for example `@v0.1.0`) to avoid workflow drift.

---

## Architecture

```text
tree-sitter-m1        ← grammar (C + Rust bindings)
      ↑
  m1-core            ← CST helpers + shared diagnostics
      ↑
  ┌───┴──────────┬──────────┐
m1-typecheck   m1-fmt    m1-lint    ← domain libraries
      ↑                    ↑
      └──────────┬──────────┘
             m1-lsp         ← LSP server (integrates all)
                 ↑
           m1-vscode        ← VS Code extension
```

`m1-core` and `m1-typecheck` are library crates. `m1-fmt` and `m1-lint` expose both a CLI and a library API. `m1-lsp` integrates all three behind a single LSP binary.

---

## License

Licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later) — see [LICENSE](LICENSE).

Copyright (C) 2026 The M1 Tools authors.
