# AGENTS.md — m1-tools

Guidance for coding agents working in this repository.

## Purpose

The umbrella of the M1 toolchain: the
[vcstool](https://github.com/dirk-thomas/vcstool) manifest
(`m1-tools.repos`) that lays the tool repos out as siblings, plus the
ecosystem-level docs (the README map, `docs/cli.md`). There is no code here —
changes to tool behaviour belong in the tool repos; this repo changes when
the *shape* of the ecosystem changes (a repo added/renamed, the architecture
diagram, cross-tool conventions, editor setup).

## Things to know

- **`m1-tools.repos` is the source of truth for the checkout layout.** Every
  listed repo is cloned as a sibling of `m1-tools` on `main`. Adding a repo
  to the ecosystem means adding it here, to the README table, and to the
  architecture diagram.
- **Cross-tool conventions documented here must match the tools.** The
  config-precedence story (defaults < `m1-tools.toml` < tool-specific file <
  CLI flags) and the manual-by-default style policy are ecosystem-wide
  contracts; if a tool changes one, this repo's docs are part of that change.
- **Other repos' READMEs link to this README's `#configuration` anchor** as
  the canonical config documentation — keep that section (and its anchor)
  alive.
- **Don't duplicate per-tool docs.** The README table gives one line per
  repo and links out; feature lists live in each tool's own README so they
  can't drift here.
- **Version pins in examples go stale.** Prefer "pin the latest release"
  phrasing over literal `@vX.Y.Z` tags in docs; where a literal pin is
  unavoidable, expect to bump it as part of release cascades.
