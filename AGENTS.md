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
  to the ecosystem means adding it here, to the README table, to the
  architecture diagram, and to the `.gitignore` sibling-repo list (which
  mirrors this manifest so `vcs import` output stays untracked). The
  `released/` + `m1-tools-release.repos` artifacts of the tag-pinned release
  flow are ignored separately and need no per-repo edit.
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
  phrasing over literal `@vX.Y.Z` tags in docs — with one exception: the
  README's m1-ci usage example carries a literal `check.yml@vX.Y.Z` pin on
  purpose, and the `m1-ci pin freshness` CI job fails when it lags the
  latest m1-ci release. Bumping it is part of every m1-ci release cascade.
- **CI also runs markdownlint and a link check** over all Markdown here;
  `.markdownlintignore` exempts the `CLAUDE.md` pointer file.
