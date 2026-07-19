#!/usr/bin/env bash
#
# check-skew.test.sh — behavioural tests for check-skew.sh.
#
# The skew comparison is pure over compat-bom.sh --json, so these tests stub
# compat-bom.sh on the sibling path to emit canned BOMs and assert: a matching
# graph passes, a lagging released pin fails with a precise message, a repo with
# no release is ignored, and a BOM-generation failure propagates (never mistaken
# for "no skew").
#
# Run: scripts/check-skew.test.sh

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/scripts/check-skew.sh"

fail=0
pass() { printf 'ok   - %s\n' "$1"; }
die() { printf 'FAIL - %s\n' "$1" >&2; fail=1; }

# make_sandbox <compat_bom_body> — a sandbox with check-skew.sh and a stub
# compat-bom.sh (whose body is the given shell) beside it.
make_sandbox() {
  local body="$1" dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/scripts"
  cp "$script" "$dir/scripts/check-skew.sh"
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$body"; } >"$dir/scripts/compat-bom.sh"
  chmod +x "$dir/scripts/compat-bom.sh"
  printf '%s' "$dir"
}

run() { # run <sandbox_dir> -> sets RC, OUT
  local dir="$1"
  OUT="$dir/out.txt"
  set +e
  bash "$dir/scripts/check-skew.sh" >"$OUT" 2>&1
  RC=$?
  set -e
}

# A healthy BOM: consumer pins the dependency's latest release.
healthy='cat <<JSON
{"repos":[
  {"name":"m1-core","lang":"rust","release_tag":"v0.15.0","released_pins":{}},
  {"name":"m1-lsp","lang":"rust","release_tag":"v0.47.0","released_pins":{"m1-core":"v0.15.0"}}
]}
JSON'

# A skewed BOM: released m1-lsp pins m1-eval v0.3.0 but m1-eval released v0.4.0.
skewed='cat <<JSON
{"repos":[
  {"name":"m1-eval","lang":"rust","release_tag":"v0.4.0","released_pins":{}},
  {"name":"m1-lsp","lang":"rust","release_tag":"v0.47.0","released_pins":{"m1-eval":"v0.3.0"}}
]}
JSON'

# A BOM where the lagging pin lives in an UNRELEASED repo (no release_tag): its
# pins ship to nobody, so it must be ignored (no false positive).
unreleased_consumer='cat <<JSON
{"repos":[
  {"name":"m1-eval","lang":"rust","release_tag":"v0.4.0","released_pins":{}},
  {"name":"m1-visualiser","lang":"rust","release_tag":"","released_pins":{"m1-eval":"v0.3.0"}}
]}
JSON'

# 1. A matching graph passes.
dir="$(make_sandbox "$healthy")"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'no undocumented cross-repo skew' "$OUT"; then
  pass "matching released pins pass with exit 0"
else
  die "expected exit 0 + no-skew message (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 2. A lagging released pin fails, naming repo, dep, pinned and latest.
dir="$(make_sandbox "$skewed")"
run "$dir"
if [ "$RC" -ne 0 ] \
  && grep -q 'm1-lsp' "$OUT" \
  && grep -q 'm1-eval' "$OUT" \
  && grep -q 'v0.3.0' "$OUT" \
  && grep -q 'v0.4.0' "$OUT"; then
  pass "lagging released pin exits non-zero, naming repo/dep/pinned/latest"
else
  die "expected non-zero exit naming the skew (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 3. A lagging pin in an unreleased repo is ignored (ships to nobody).
dir="$(make_sandbox "$unreleased_consumer")"
run "$dir"
if [ "$RC" -eq 0 ]; then
  pass "unreleased consumer's lagging pin is not flagged"
else
  die "expected exit 0 (unreleased consumer ignored) (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 4. A BOM-generation failure propagates — never mistaken for "no skew".
dir="$(make_sandbox 'echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1')"
run "$dir"
if [ "$RC" -ne 0 ] && ! grep -q 'no undocumented cross-repo skew' "$OUT"; then
  pass "BOM-generation failure propagates (not reported as no-skew)"
else
  die "expected non-zero exit without a no-skew message (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

if [ "$fail" -ne 0 ]; then
  echo "check-skew.test.sh: FAILED" >&2
  exit 1
fi
echo "check-skew.test.sh: all tests passed"
