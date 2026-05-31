# vcstool Sub-repos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `m1-tools.repos` vcstool file and a "Getting Started" README section so developers can clone all five sub-repos in one command.

**Architecture:** A single `m1-tools.repos` YAML file at the repo root lists all five sub-repos tracking `main`. A new "Getting Started" section in `README.md` documents the install-and-clone workflow. No code — config and docs only.

**Tech Stack:** vcstool YAML format, Markdown

---

### Task 1: Add `m1-tools.repos`

**Files:**
- Create: `m1-tools.repos`

- [ ] **Step 1: Create the file**

  Create `m1-tools.repos` at the repo root with this exact content:

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

- [ ] **Step 2: Verify the YAML is valid**

  Run:
  ```bash
  python3 -c "import yaml; yaml.safe_load(open('m1-tools.repos'))" && echo "OK"
  ```

  Expected output: `OK`

  If a `yaml` module error appears, install it: `pip install pyyaml`

- [ ] **Step 3: Commit**

  ```bash
  git add m1-tools.repos
  git commit -m "feat: add vcstool repos file for all sub-repos"
  ```

---

### Task 2: Add "Getting Started" section to README

**Files:**
- Modify: `README.md`

The new section goes **between** the opening paragraph (ending `...across all major editors.`) and the `## Tools` heading.

- [ ] **Step 1: Insert the section**

  Open `README.md`. After the line:

  ```
  A suite of developer tools for the MoTeC M1 scripting language (`.m1scr`), providing syntax highlighting, language server support, formatting, and linting across all major editors.
  ```

  And before:

  ```
  ## Tools
  ```

  Insert the following block (preserving the blank line before `## Tools`):

  ```markdown
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
  ```

- [ ] **Step 2: Verify markdownlint passes**

  Run:
  ```bash
  npx markdownlint-cli README.md --config .markdownlint.json
  ```

  Expected: no output, exit code 0. Fix any reported violations before continuing.

- [ ] **Step 3: Commit and push**

  ```bash
  git add README.md
  git commit -m "docs: add Getting Started section with vcstool workflow"
  git push origin main
  ```
