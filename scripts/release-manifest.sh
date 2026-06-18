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

# Resolve a repo's latest release tag, distinguishing "no release yet" (a
# legitimate 404 -> empty output, exit 0) from a transient failure (rate limit,
# 5xx, auth -> error out). Collapsing both into "" would let a flaky run emit a
# main-pinned manifest with exit 0 — the exact "works for me != works for users"
# divergence this script exists to prevent. A unique mktemp file avoids
# clobbering a concurrent run's stderr capture.
latest_release_tag() { # latest_release_tag owner/repo -> tag (empty on 404)
  local repo="$1" gherr tag
  gherr="$(mktemp "${TMPDIR:-/tmp}/release-manifest.gherr.XXXXXX")"
  if tag=$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>"$gherr"); then
    printf '%s' "$tag"
  elif grep -q '(HTTP 404)' "$gherr"; then
    : # no release yet — caller falls through to main
  else
    echo "error: gh api failed resolving the latest release for $repo:" >&2
    cat "$gherr" >&2
    rm -f "$gherr"
    exit 1
  fi
  rm -f "$gherr"
}

# The canonical frozen pins: m1-ci/tools.env on the latest m1-ci release. Read
# tools.env *at that release tag* — not the repo default branch — so the pins
# match what consumers actually install. (A bare contents/tools.env with no
# ?ref= resolves to main, which can carry an in-development pin nobody can yet
# install.) Apply the same transient-failure discipline as the per-repo lookups:
# never let a flaky gh outage silently substitute main content. If m1-ci has no
# release yet, fall back to main deliberately (the only available pin source).
ci_tag=$(latest_release_tag C-Nucifora/m1-ci)
if [ -n "$ci_tag" ]; then
  ci_ref="$ci_tag"
else
  echo "warning: no m1-ci release found; reading tools.env from main" >&2
  ci_ref="main"
fi
tools_env=$(gh api "repos/C-Nucifora/m1-ci/contents/tools.env?ref=$ci_ref" \
  -H "Accept: application/vnd.github.raw")

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
  # Derive the tools.env pin variable from the repo name, mirroring m1-ci's
  # naming convention (m1-fmt -> M1_FMT_VERSION): uppercase and map '-' to '_'.
  # pin_for returns empty for an unpinned repo, so anything without a pin falls
  # through to releases/latest — and any tool that *gains* a pin later (e.g. an
  # eventual M1_DOC_VERSION) is picked up automatically, no list to keep in sync.
  var="$(printf '%s' "$name" | tr 'a-z-' 'A-Z_')_VERSION"
  tag=$(pin_for "$var")
  if [ -z "$tag" ]; then
    repo="${url#https://github.com/}"
    repo="${repo%.git}"
    # Unpinned repos resolve to their latest release tag (empty on a 404 "no
    # release yet", error on a transient failure — see latest_release_tag).
    tag=$(latest_release_tag "$repo")
  fi
  if [ -z "$tag" ]; then
    echo "warning: no release found for $name; keeping main" >&2
    tag=main
  fi
  printf '  %s:\n    type: git\n    url: %s\n    version: %s\n' "$name" "$url" "$tag"
done
