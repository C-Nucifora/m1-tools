#!/usr/bin/env bash
#
# check-skew.sh — fail on undocumented cross-repo dependency skew (#60).
#
# A released repo's internal m1-* / tree-sitter-m1 git-tag pin should reference
# the LATEST release of the crate it depends on. When it lags (e.g. m1-lsp's
# released Cargo.toml pins m1-eval v0.3.0 while m1-eval has since released
# v0.4.0), consumers installing the released graph get an older transitive
# dependency than the one shipped — "undocumented skew". This check reports
# every such lag and exits non-zero.
#
# Skew is EXPECTED transiently mid-cascade (an upstream release bump reaches its
# consumers as follow-up PRs over the following minutes), so this runs on a
# schedule + workflow_dispatch, NOT as a PR gate — see .github/workflows/
# skew-guard.yml. A scheduled failure is the signal that a cascade stalled.
#
# All the data comes from compat-bom.sh --json: for each RELEASED repo it
# compares each released_pins[dep] against that dep's own latest release_tag
# (both already resolved in the BOM). Because the comparison is pure over the
# BOM, its logic is unit-tested by stubbing compat-bom.sh (see
# check-skew.test.sh); here it errors out if the BOM itself cannot be produced.
#
# Requires: gh (authenticated, via compat-bom.sh), python3.

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"

bom_json="$(mktemp "${TMPDIR:-/tmp}/check-skew.bom.XXXXXX")"
trap 'rm -f "$bom_json"' EXIT

# A non-zero exit from compat-bom.sh (e.g. a transient gh failure) aborts here
# under `set -e` rather than being mistaken for "no skew".
"$here/scripts/compat-bom.sh" --json >"$bom_json"

python3 - "$bom_json" <<'PY'
import json
import sys

bom = json.load(open(sys.argv[1]))
repos = bom["repos"]
latest = {r["name"]: r["release_tag"] for r in repos}

skews = []
for r in repos:
    # Only the released consumer graph matters: a repo with no release ships
    # nothing, and main pins are the in-flight fix, not what consumers install.
    if not r["release_tag"]:
        continue
    for dep, pinned in r["released_pins"].items():
        dep_latest = latest.get(dep, "")
        if dep_latest and pinned != dep_latest:
            skews.append((r["name"], r["release_tag"], dep, pinned, dep_latest))

if not skews:
    print("OK — no undocumented cross-repo skew: every released repo pins the "
          "latest release of each internal dependency.")
    sys.exit(0)

print("Undocumented cross-repo dependency skew detected:")
for repo, reltag, dep, pinned, dep_latest in skews:
    print(f"  {repo} {reltag} pins {dep} {pinned}, but the latest {dep} "
          f"release is {dep_latest}")
print()
print("A released repo pins an older release of an internal dependency than the "
      "latest. This is expected transiently mid-cascade; a sustained failure "
      "means a dependency-bump PR is missing. Open the consumer bump PR(s) to "
      "clear it.")
sys.exit(1)
PY
