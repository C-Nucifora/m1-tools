#!/usr/bin/env bash
#
# eval-golden.test.sh — behavioural tests for eval-golden.sh.
#
# The summary derivation (parse the coverage schedule, compute base = lcm(rates)
# and per-function invocation counts, take each channel's final value, list the
# externally-driven channels) and the golden round-trip (--update writes,
# default diffs) are exercised with a stubbed m1-eval binary — no real eval, no
# corpus needed.
#
# Run: scripts/eval-golden.test.sh

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/scripts/eval-golden.sh"

fail=0
pass() { printf 'ok   - %s\n' "$1"; }
die() { printf 'FAIL - %s\n' "$1" >&2; fail=1; }

# A sandbox with a stub m1-eval that emits a canned coverage schedule (two rate
# groups, 100 + 50 Hz) and a canned 2-tick whole-project trace.
make_sandbox() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/corpus" "$dir/golden"
  cat >"$dir/bin/m1-eval" <<'STUB'
#!/usr/bin/env bash
out=""; prev=""; mode=""
for a in "$@"; do
  [ "$prev" = "--out" ] && out="$a"
  case "$a" in
    --coverage) mode=coverage ;;
    --whole-project) mode=whole ;;
  esac
  prev="$a"
done
if [ "$mode" = coverage ]; then
  cat <<'COV'
Supported:
  construct assignment_statement
Stubbed:
  (none)
Unsupported:
  (none)
Schedule:
  Root.A @ 100 Hz
  Root.B @ 50 Hz
COV
  exit 0
fi
if [ "$mode" = whole ]; then
  cat >"$out" <<'JSON'
{"time":[0,0.01],"channels":{"Root.X":[1,2],"Root.Y":[5,7]},"external":["Root.Y"]}
JSON
  exit 0
fi
exit 0
STUB
  chmod +x "$dir/bin/m1-eval"
  printf '%s' "$dir"
}

run() { # run <dir> [args...] -> RC, OUT, ERR (eval bin / corpus / golden implied)
  local dir="$1"
  shift
  OUT="$dir/out.txt"
  ERR="$dir/err.txt"
  set +e
  bash "$script" "$dir/bin/m1-eval" "$dir/corpus" "$dir/golden/g.txt" "$@" \
    >"$OUT" 2>"$ERR"
  RC=$?
  set -e
}

# 1. --update writes the golden and exits 0.
dir="$(make_sandbox)"
run "$dir" --update
if [ "$RC" -eq 0 ] && [ -f "$dir/golden/g.txt" ]; then
  pass "--update writes the golden"
else
  die "expected --update to write golden, exit 0 (rc=$RC, err: $(cat "$ERR"))"
fi

# 2. The golden encodes the derived counts, finals and externals.
if grep -q 'base_hz 100' "$dir/golden/g.txt" \
  && grep -q 'invocations Root.A @100Hz = 2' "$dir/golden/g.txt" \
  && grep -q 'invocations Root.B @50Hz = 1' "$dir/golden/g.txt" \
  && grep -q 'final Root.X = 2' "$dir/golden/g.txt" \
  && grep -q 'final Root.Y = 7' "$dir/golden/g.txt" \
  && grep -q 'external Root.Y' "$dir/golden/g.txt"; then
  pass "golden pins base, per-group invocation counts, finals and externals"
else
  die "golden missing expected derived content: $(cat "$dir/golden/g.txt")"
fi

# 3. A matching golden passes.
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'golden matches' "$OUT"; then
  pass "matching golden passes with exit 0"
else
  die "expected exit 0 + matches message (rc=$RC, out: $(cat "$OUT"))"
fi

# 4. A drifted golden fails with a non-zero exit and a regenerate hint.
printf 'tampered\n' >>"$dir/golden/g.txt"
run "$dir"
if [ "$RC" -ne 0 ] && grep -q -- '--update' "$ERR"; then
  pass "drifted golden fails and points at --update"
else
  die "expected non-zero exit + --update hint on drift (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 5. Too few arguments is a usage error (exit 2).
dir="$(make_sandbox)"
set +e
bash "$script" "$dir/bin/m1-eval" "$dir/corpus" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 2 ]; then
  pass "too few arguments exits 2"
else
  die "expected exit 2 on too few args (rc=$rc)"
fi

# 6. An unknown 4th argument is rejected (exit 2).
run "$dir" --bogus
if [ "$RC" -eq 2 ]; then
  pass "unknown flag exits 2"
else
  die "expected exit 2 on unknown flag (rc=$RC)"
fi
rm -rf "$dir"

if [ "$fail" -ne 0 ]; then
  echo "eval-golden.test.sh: FAILED" >&2
  exit 1
fi
echo "eval-golden.test.sh: all tests passed"
