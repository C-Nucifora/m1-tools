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

| Repo | Purpose | Status |
| --- | --- | --- |
| [tree-sitter-m1](https://github.com/C-Nucifora/tree-sitter-m1) | Tree-sitter grammar + Rust bindings | Stable |
| [m1-core](https://github.com/C-Nucifora/m1-core) | CST helpers and diagnostics library | Stable |
| [m1-typecheck](https://github.com/C-Nucifora/m1-typecheck) | Type/symbol model and type-rule diagnostics | In development |
| [m1-lsp](https://github.com/C-Nucifora/m1-lsp) | Language Server Protocol implementation | In development |
| [m1-fmt](https://github.com/C-Nucifora/m1-fmt) | Code formatter | In development |
| [m1-lint](https://github.com/C-Nucifora/m1-lint) | Static analysis / linter | In development |
| [m1-vscode](https://github.com/nedlane/m1-vscode) | VS Code extension | In development |

### tree-sitter-m1

A [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) grammar for M1 script. Provides:

- Incremental, error-recovering parsing
- Syntax highlighting queries
- Rust bindings via `m1_tree_sitter`

### m1-core

The shared parsing and diagnostics library used by all other tools. Exposes:

```rust
use m1_core::{parse, Cst, Node, Kind, Diagnostic, Code, Severity, Range, Position};
```

All higher-level tools (`m1-typecheck`, `m1-lsp`, `m1-fmt`, `m1-lint`) depend on this crate.

### m1-typecheck

The type and symbol model for M1 script, built on `m1-core`. Loads the project's
`Project.m1prj` symbol table (channels, parameters, functions) and infers local
variable types, surfacing type-rule diagnostics (`T001`–`T011`). It powers
`m1-lsp`'s hover, completion, rename, and inlay type-hints, and is also available
as a standalone `nvim-lint` plugin.

### m1-lsp

A Language Server Protocol server for M1 script. Provides diagnostics, hover, go-to-definition, completion, rename, and inlay type-hints to any LSP-capable editor.

### m1-fmt

An opinionated code formatter for `.m1scr` files, similar to `rustfmt` or `black`.

### m1-lint

A static analysis tool that enforces style and correctness rules. Rules include line length (88), operator conventions (`eq`/`neq`/`and`/`or`/`not`), trailing whitespace, nesting depth, and cyclomatic complexity.

---

## Editor Setup

### Neovim (LazyVim)

Add the following to your LazyVim plugins (e.g. `~/.config/nvim/lua/plugins/m1.lua`):

```lua
return {
    {
        "C-Nucifora/tree-sitter-m1",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
            local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
            parser_config.m1 = {
                install_info = {
                    url = "https://github.com/C-Nucifora/tree-sitter-m1",
                    files = { "src/parser.c" },
                    branch = "main",
                },
                filetype = "m1",
            }
            vim.cmd("TSInstall! m1")
        end,
    },
    {
        "C-Nucifora/m1-lsp",
        build = "cargo build --release",
        dependencies = { "neovim/nvim-lspconfig" },
        config = function()
            require("m1_lsp").setup({})
        end,
    },
    {
        "C-Nucifora/m1-fmt",
        build = "cargo build --release",
        dependencies = { "stevearc/conform.nvim" },
        config = function()
            require("m1_fmt").setup({})
        end,
    },
    {
        "C-Nucifora/m1-lint",
        build = "cargo build --release",
        dependencies = { "mfussenegger/nvim-lint" },
        config = function()
            require("m1_lint").setup({})
        end,
    },
}
```

This gives you:

- Syntax highlighting and indentation via Tree-sitter
- Diagnostics, hover, and go-to-definition via `m1-lsp`
- Format-on-save via `conform.nvim` + `m1-fmt`
- Lint diagnostics via `nvim-lint` + `m1-lint`

### VS Code

Use the [m1-vscode](https://github.com/nedlane/m1-vscode) extension. It bundles the
`m1-lsp` server and provides syntax highlighting, diagnostics, hover, formatting,
go-to-definition, completion, rename, and inlay type-hints — no separate install.

Download the VSIX for your platform from the
[Releases page](https://github.com/nedlane/m1-vscode/releases) and install it:

```sh
code --install-extension m1-vscode-linux-x64.vsix
```

Apple-Silicon macOS (`darwin-arm64`) and Windows (`win32-x64`) have their own VSIX.
Intel-Mac users install the `universal` VSIX and build the server themselves — see
the [m1-vscode README](https://github.com/nedlane/m1-vscode#intel-macos-x86_64-apple-darwin).

### Zed

Add to your Zed `settings.json` under `lsp`:

```json
{
    "lsp": {
        "m1-lsp": {
            "binary": {
                "path": "/path/to/m1-lsp/target/release/m1-lsp"
            }
        }
    },
    "languages": {
        "M1 Script": {
            "language_servers": ["m1-lsp"]
        }
    }
}
```

Tree-sitter grammar support in Zed requires the grammar to be registered; follow the [Zed extension guide](https://zed.dev/docs/extensions/languages) using the `tree-sitter-m1` repo as the grammar source.

### Helix

Add to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "m1scr"
scope = "source.m1scr"
file-types = ["m1scr"]
roots = [".m1prj"]
language-servers = ["m1-lsp"]

[language-server.m1-lsp]
command = "/path/to/m1-lsp/target/release/m1-lsp"
```

Place the `tree-sitter-m1` grammar under `~/.config/helix/runtime/grammars/` following Helix's [adding languages guide](https://docs.helix-editor.com/guides/adding_languages.html).

### Emacs (eglot)

```elisp
(add-to-list 'eglot-server-programs
             '(m1scr-mode . ("/path/to/m1-lsp/target/release/m1-lsp")))

(add-hook 'm1scr-mode-hook 'eglot-ensure)
```

---

## Building from Source

All tools require Rust (stable). Install via [rustup](https://rustup.rs/).

```sh
# Clone whichever tools you need
git clone https://github.com/C-Nucifora/tree-sitter-m1
git clone https://github.com/C-Nucifora/m1-core
git clone https://github.com/C-Nucifora/m1-lsp
git clone https://github.com/C-Nucifora/m1-fmt
git clone https://github.com/C-Nucifora/m1-lint

# Build (example for m1-lsp)
cd m1-lsp
cargo build --release
```

`tree-sitter-m1` additionally requires Node.js and the Tree-sitter CLI for grammar generation:

```sh
npm install -g tree-sitter-cli
cd tree-sitter-m1
tree-sitter generate
cargo build --release
```

---

## Architecture

```text
tree-sitter-m1   ← grammar (C + Rust bindings)
      ↑
   m1-core       ← CST helpers + diagnostics
      ↑
  ┌───┴──────────┬────────┐
m1-typecheck   m1-fmt   m1-lint   ← libraries built on m1-core
      ↑
   m1-lsp   ← integrates m1-core + m1-typecheck + m1-fmt + m1-lint
```

`m1-core` and `m1-typecheck` are library crates; `m1-fmt` and `m1-lint` expose both a CLI and an editor plugin API, and `m1-lsp` integrates the type model, formatter, and linter behind a single LSP server.

---

## License

Licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later) — see [LICENSE](LICENSE).

Copyright (C) 2026 The M1 Tools authors.
