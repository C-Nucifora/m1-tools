---
name: vcstool-submodules
description: vcstool .repos file and README documentation for cloning all m1 sub-repos in one step
metadata:
  type: project
---

# vcstool Sub-repos Design — m1-tools

## Goal

Allow a developer to clone `m1-tools` and then pull all five sub-repos in a single command, always tracking `main` on each.

## Scope

- Add `m1-tools.repos` at the repo root
- Add a "Getting Started" section to `README.md` documenting the workflow

The five sub-repos are:
- `tree-sitter-m1` — `https://github.com/C-Nucifora/tree-sitter-m1.git`
- `m1-core` — `https://github.com/C-Nucifora/m1-core.git`
- `m1-lsp` — `https://github.com/C-Nucifora/m1-lsp.git`
- `m1-fmt` — `https://github.com/C-Nucifora/m1-fmt.git`
- `m1-lint` — `https://github.com/C-Nucifora/m1-lint.git`

---

## `.repos` File

**Path:** `m1-tools.repos` (repo root)

**Format:** vcstool YAML

```yaml
repositories:
  tree-sitter-m1:
    type: git
    url: https://github.com/C-Nucifora/tree-sitter-m1.git
    version: main
  m1-core:
    type: git
    url: https://github.com/C-Nucifora/m1-core.git
    version: main
  m1-lsp:
    type: git
    url: https://github.com/C-Nucifora/m1-lsp.git
    version: main
  m1-fmt:
    type: git
    url: https://github.com/C-Nucifora/m1-fmt.git
    version: main
  m1-lint:
    type: git
    url: https://github.com/C-Nucifora/m1-lint.git
    version: main
```

Each entry clones into the directory named by its key, relative to the import target. Using `vcs import ..` places each sub-repo as a sibling of `m1-tools`, matching the flat workspace layout implied by the architecture diagram.

---

## README Changes

A new "Getting Started" section is inserted **before** the existing "Editor Setup" section. It covers:

1. Installing vcstool (`pip install vcstool`)
2. Cloning this repo and importing all sub-repos (`vcs import .. < m1-tools.repos`)
3. Updating all sub-repos to latest `main` (`vcs pull .. < m1-tools.repos`)

---

## Workflow Summary

| Command | Effect |
|---------|--------|
| `pip install vcstool` | Install vcstool once |
| `git clone https://github.com/C-Nucifora/m1-tools.git && cd m1-tools` | Clone overview repo |
| `vcs import .. < m1-tools.repos` | Clone all five sub-repos as siblings |
| `vcs pull .. < m1-tools.repos` | Pull latest `main` on all sub-repos |
