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

All higher-level tools (`m1-lsp`, `m1-fmt`, `m1-lint`) depend on this crate.

### m1-lsp

A Language Server Protocol server for M1 script. Provides diagnostics, hover, go-to-definition, and completion to any LSP-capable editor.

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

> Extension coming soon. In the meantime, use the generic LSP client extension and point it at the `m1-lsp` binary.

Install `m1-lsp`:

```sh
git clone https://github.com/C-Nucifora/m1-lsp
cd m1-lsp
cargo build --release
# Binary is at target/release/m1-lsp
```

Install the [generic LSP client](https://marketplace.visualstudio.com/items?itemName=genericlsp.genericlsp) extension, then add to your `settings.json`:

```json
{
    "genericlsp.configs": [
        {
            "name": "m1-lsp",
            "command": "/path/to/m1-lsp/target/release/m1-lsp",
            "filetypes": ["m1scr"]
        }
    ]
}
```

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
  ┌───┴───────────────┐
m1-lsp   m1-fmt   m1-lint
```

All tools are independent binaries. `m1-core` is a library crate; the others expose both a CLI and (where applicable) a plugin API for editor integration.

---

## License

MIT
