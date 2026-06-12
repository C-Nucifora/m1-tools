#!/usr/bin/env bash
#
# release-manifest.sh — emit a tag-pinned vcstool manifest reproducing the
# *published* toolchain (#32).
#
# m1-tools.repos deliberately tracks every repo at `main`: the umbrella
# checkout exists to work on the toolchain itself. But CI and consumers run
# the frozen versions pinned in m1-ci/tools.env, so "works in my umbrella
# checkout" and "works for users" can diverge. This script resolves the same
# repo list to release tags — the four CLI tools from the canonical
# m1-ci/tools.env pins, everything else from its latest GitHub release — so
#
#   scripts/release-manifest.sh > m1-tools-release.repos
#   mkdir released && cd released && vcs import .. < ../m1-tools-release.repos
#
# reproduces exactly what consumers install. Generated on demand (it queries
# GitHub) rather than committed, so it cannot go stale in-tree.
#
# Requires: gh (authenticated), python3 (YAML-light parsing of the manifest).

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$here/m1-tools.repos"

# The canonical frozen pins: m1-ci/tools.env on the latest m1-ci release.
tools_env=$(gh api repos/C-Nucifora/m1-ci/contents/tools.env \
  -H "Accept: application/vnd.github.raw" 2>/dev/null ||
  curl -fsSL https://raw.githubusercontent.com/C-Nucifora/m1-ci/main/tools.env)

pin_for() { # pin_for M1_FMT_VERSION -> v0.12.0 (empty when absent)
  printf '%s\n' "$tools_env" | sed -n "s/^$1=//p"
}

echo "repositories:"
# Walk the dev manifest's repo/url pairs so the repo list can never drift.
python3 - "$manifest" <<'PY' | while IFS=$'\t' read -r name url; do
import sys

name = None
for line in open(sys.argv[1]):
    stripped = line.strip()
    if line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
        name = stripped[:-1]
    elif stripped.startswith("url:") and name:
        print(f"{name}\t{stripped.split(None, 1)[1]}")
PY
  case "$name" in
    m1-fmt) tag=$(pin_for M1_FMT_VERSION) ;;
    m1-lint) tag=$(pin_for M1_LINT_VERSION) ;;
    m1-typecheck) tag=$(pin_for M1_TYPECHECK_VERSION) ;;
    m1-project) tag=$(pin_for M1_PROJECT_VERSION) ;;
    *) tag="" ;;
  esac
  if [ -z "$tag" ]; then
    repo="${url#https://github.com/}"
    repo="${repo%.git}"
    tag=$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null || echo "")
  fi
  if [ -z "$tag" ]; then
    echo "warning: no release found for $name; keeping main" >&2
    tag=main
  fi
  printf '  %s:\n    type: git\n    url: %s\n    version: %s\n' "$name" "$url" "$tag"
done
