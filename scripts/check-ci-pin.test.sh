#!/usr/bin/env bash
#
# check-ci-pin.test.sh — behavioural tests for check-ci-pin.sh.
#
# The check fails the build whenever the README's check.yml@vX.Y.Z pin is wrong.
# Three failure shapes must each be reported clearly:
#   - the pin is STALE   (present, but != latest m1-ci release)
#   - the pin is MISSING  (the snippet was removed/rephrased -> empty match)
#   - the pin is AMBIGUOUS (more than one distinct tag in the README)
# The missing case is the regression under guard: a previous version let the
# empty match fall through to the stale comparison, printing a confusing
# double-spaced "README pins m1-ci  but the latest release is <tag>" message.
# A stub `gh` on PATH supplies the latest tag, so no network/token is needed.
#
# Run: scripts/check-ci-pin.test.sh   (no network, no gh required)

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/scripts/check-ci-pin.sh"

fail=0
pass() { printf 'ok   - %s\n' "$1"; }
die() { printf 'FAIL - %s\n' "$1" >&2; fail=1; }

# make_sandbox <readme_contents> <latest_tag> -> echoes the sandbox dir.
# Builds an isolated README plus a stub `gh` that returns <latest_tag> for the
# m1-ci releases/latest call.
make_sandbox() {
  local readme="$1" latest="$2" dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin"
  printf '%s\n' "$readme" >"$dir/README.md"
  cat >"$dir/bin/gh" <<EOF
#!/usr/bin/env bash
echo "$latest"
exit 0
EOF
  chmod +x "$dir/bin/gh"
  printf '%s' "$dir"
}

run() { # run <sandbox_dir> -> sets RC, OUT
  local dir="$1"
  OUT="$dir/out.txt"
  set +e
  PATH="$dir/bin:$PATH" bash "$script" "$dir/README.md" >"$OUT" 2>&1
  RC=$?
  set -e
}

# 1. A matching pin passes, exit 0.
dir="$(make_sandbox 'Use check.yml@v0.23.0 in your workflow.' 'v0.23.0')"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'matches latest' "$OUT"; then
  pass "a pin matching the latest release passes"
else
  die "expected exit 0 and 'matches latest' (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 2. A stale pin fails with the stale-pin message naming both tags.
dir="$(make_sandbox 'Use check.yml@v0.22.0 in your workflow.' 'v0.23.0')"
run "$dir"
if [ "$RC" -ne 0 ] && grep -q 'README pins m1-ci v0.22.0 but the latest release is v0.23.0' "$OUT"; then
  pass "a stale pin fails with both tags named"
else
  die "expected non-zero exit and stale-pin message (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 3. A MISSING pin (snippet removed/rephrased -> empty match) fails with the
#    dedicated missing-pin message — NOT the confusing empty stale comparison.
dir="$(make_sandbox 'Use check.yml@main in your workflow.' 'v0.23.0')"
run "$dir"
if [ "$RC" -ne 0 ] \
  && grep -q 'README no longer pins a check.yml@vX.Y.Z tag' "$OUT" \
  && ! grep -q 'but the latest release is' "$OUT"; then
  pass "a missing pin fails with the missing-pin message, not the stale comparison"
else
  die "expected non-zero exit and missing-pin message (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 4. Multiple distinct pins fail with the ambiguous-pin message.
dir="$(make_sandbox 'check.yml@v0.22.0 here, and check.yml@v0.23.0 there.' 'v0.23.0')"
run "$dir"
if [ "$RC" -ne 0 ] && grep -q 'README pins multiple m1-ci tags' "$OUT"; then
  pass "multiple distinct pins fail with the ambiguous-pin message"
else
  die "expected non-zero exit and multiple-pins message (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

if [ "$fail" -ne 0 ]; then
  echo "check-ci-pin.test.sh: FAILED" >&2
  exit 1
fi
echo "check-ci-pin.test.sh: all tests passed"
