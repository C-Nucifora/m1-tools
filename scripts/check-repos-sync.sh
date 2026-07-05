#!/usr/bin/env bash
#
# check-repos-sync.sh — assert the repo list in m1-tools.repos is mirrored in
# .gitignore and the README repo table. Adding a repo to the manifest without
# updating the other two silently drifts the docs and the vcs-ignore list (the
# m1-mcp addition did exactly this); this gate fails such a PR.
#
# Args (optional, for testing): <repos_file> <gitignore> <readme>.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
repos="${1:-$here/m1-tools.repos}"
gitignore="${2:-$here/.gitignore}"
readme="${3:-$here/README.md}"

# The manifest lists each repo as a 2-space-indented `  <name>:` key under
# `repositories:`. Extract those names.
names="$(sed -n 's/^  \([A-Za-z0-9._-]*\):$/\1/p' "$repos")"
if [ -z "$names" ]; then
  echo "::error::no repo names found in $repos" >&2
  exit 1
fi

fail=0
while IFS= read -r name; do
  [ -z "$name" ] && continue
  if ! grep -qxF "$name/" "$gitignore"; then
    echo "::error file=.gitignore::repo '$name' is in m1-tools.repos but missing '$name/' in .gitignore" >&2
    fail=1
  fi
  # The README repo table links each repo as `[<name>](…)`.
  if ! grep -qF "[$name]" "$readme"; then
    echo "::error file=README.md::repo '$name' is in m1-tools.repos but not linked in the README repo table" >&2
    fail=1
  fi
done <<<"$names"

if [ "$fail" -eq 0 ]; then
  echo "OK — every m1-tools.repos entry is mirrored in .gitignore and README."
fi
exit "$fail"
