#!/usr/bin/env bash
#
# check-ci-pin.sh — assert README.md pins the latest m1-ci release.
#
# The README's quickstart pins the shared CI workflow as check.yml@vX.Y.Z.
# Nothing else guards that snippet, so it goes stale the moment m1-ci releases
# (#26) — and, just as bad, it can silently *disappear* if a future edit
# rephrases or drops the snippet (e.g. switches the example to @main, or
# restructures the YAML block). This check fails on both: a stale pin and a
# missing pin. The missing-pin case gets its own actionable message rather than
# falling through to the stale-pin comparison with an empty value (which would
# read "README pins m1-ci  but the latest release is vX.Y.Z" — a confusing
# double-spaced, empty-pin diagnostic that masks the real problem).
#
# Args (optional, for testing): <readme_path>. Defaults to README.md relative
# to the repo root. The latest tag is resolved via `gh`; stub it on PATH to test
# without network/token.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
readme="${1:-$here/README.md}"

# grep exits non-zero on no match; under `set -e` (and `set -o pipefail`) that
# would abort before the empty-pin guard runs. Tolerate it so a missing pin
# reaches the explicit check below.
pinned=$(grep -oP 'check\.yml@\Kv[0-9.]+' "$readme" | sort -u) || true

# An empty result means the pin snippet is gone, not merely stale. The multi-pin
# guard below does NOT catch this: `echo "" | wc -l` is 1, so it would pass and
# the comparison would print an empty, double-spaced pin. Report it explicitly.
if [ -z "$pinned" ]; then
  echo "README no longer pins a check.yml@vX.Y.Z tag (the snippet was removed or rephrased)"
  exit 1
fi

if [ "$(printf '%s\n' "$pinned" | wc -l)" -ne 1 ]; then
  echo "README pins multiple m1-ci tags: $pinned"
  exit 1
fi

latest=$(gh api repos/C-Nucifora/m1-ci/releases/latest -q .tag_name)

if [ "$pinned" != "$latest" ]; then
  echo "README pins m1-ci $pinned but the latest release is $latest"
  exit 1
fi

echo "README pin $pinned matches latest m1-ci release"
