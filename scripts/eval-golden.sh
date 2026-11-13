#!/usr/bin/env bash
#
# eval-golden.sh — run m1-eval whole-project over the acceptance corpus and diff
# the result against a committed golden (#59 fast-follow).
#
# The compat workflow already builds the released m1-eval; this proves its
# multi-rate scheduler still produces the exact same deterministic result over
# the synthetic corpus. The golden pins, for the 100 / 50 / 10 Hz groups:
#   - each scheduled function's observed invocation count, and
#   - each channel's final value,
# plus the base tick rate, tick count, and which channels were externally
# driven / defaulted (the allow_default_inputs substitution).
#
# m1-eval is deterministic, so a mismatch is a real behavioural change: either a
# regression, or an intended change — regenerate with --update and commit.
#
# Usage:
#   scripts/eval-golden.sh <eval-bin> <corpus-dir> <golden-file> [--update]
#
# Requires: Python 3.11+ (stdlib tomllib). The eval binary is passed in (not resolved) so the logic is
# unit-testable with a stub (see eval-golden.test.sh).

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: eval-golden.sh <eval-bin> <corpus-dir> <golden-file> [--update]" >&2
  exit 2
fi

eval_bin="$1"
corpus="$2"
golden="$3"
update="${4:-}"

if [ -n "$update" ] && [ "$update" != "--update" ]; then
  echo "error: unknown argument: $update (accepted: --update)" >&2
  exit 2
fi

project="$corpus/Project.m1prj"
config="$corpus/parameters.m1cfg"
scenario="$corpus/whole-project.scenario.toml"

work="$(mktemp -d "${TMPDIR:-/tmp}/eval-golden.XXXXXX")"
trap 'rm -rf "$work"' EXIT

coverage="$work/coverage.txt"
trace="$work/trace.json"
generated="$work/generated.txt"

# Coverage gives the per-function schedule (rate per function); the whole-project
# trace gives per-channel value series and the externally-driven channel list.
"$eval_bin" --project "$project" --config "$config" --coverage >"$coverage"
"$eval_bin" --project "$project" --config "$config" --scenario "$scenario" \
  --whole-project --out "$trace" 2>"$work/eval.stderr"

# Assemble the compact golden summary (counts + finals + externals) from the
# coverage schedule and the trace. Validate actual execution records — this is the
# part the unit test exercises via a stubbed eval binary.
python3 - "$coverage" "$trace" "$scenario" >"$generated" <<'PY'
import json
import math
import re
import sys
from functools import reduce
from collections import Counter
import tomllib

coverage = open(sys.argv[1]).read()
trace = json.load(open(sys.argv[2]))

# Parse the "Schedule:" section, including optional execution-order prefixes.
# Names may contain spaces and dots, so match the rate/Hz suffix and take the
# rest as the function path.
schedule = {}
in_schedule = False
for line in coverage.splitlines():
    if line.startswith("Schedule:"):
        in_schedule = True
        continue
    if in_schedule:
        m = re.match(r"\s+(?:[0-9]+\.\s+)?(.*\S)\s+@\s+([0-9.]+)\s+Hz\s*$", line)
        if m:
            rate = float(m.group(2))
            if not math.isfinite(rate) or rate <= 0 or not rate.is_integer():
                sys.exit("acceptance golden requires positive integer scheduled rates")
            if m.group(1) in schedule:
                sys.exit("duplicate function in coverage schedule")
            schedule[m.group(1)] = int(rate)

if not schedule:
    sys.exit("no Schedule section found in coverage output")

rates = sorted(set(schedule.values()))
base = reduce(lambda a, b: a * b // math.gcd(a, b), rates)
ticks = len(trace["time"])
with open(sys.argv[3], "rb") as f:
    scenario = tomllib.load(f)
base = scenario.get("base_rate_hz", 0) or base
if type(base) not in (int, float) or not math.isfinite(base) or base <= 0 or int(base) != base:
    sys.exit("acceptance golden requires a positive integer base rate")
base = int(base)
duration = scenario["duration_s"]
if type(duration) not in (int, float) or not math.isfinite(duration) or duration <= 0:
    sys.exit("acceptance golden requires a finite positive duration")
periods = {}
for fn, rate in schedule.items():
    if base % rate:
        sys.exit("scheduled rates must divide the base exactly")
    periods[fn] = base // rate
# The evaluator's documented interval is [0, duration), including tick zero.
if (ticks == 0 or (ticks - 1) / base >= duration or ticks / base < duration or any(
    type(t) not in (int, float) or not math.isfinite(t) or
    not math.isclose(t, i / base, rel_tol=0, abs_tol=1e-12)
    for i, t in enumerate(trace["time"])
)):
    sys.exit("invalid acceptance trace time grid")
if any(len(values) != ticks for values in trace["channels"].values()):
    sys.exit("channel lengths differ from the time grid")
expected = Counter((fn, tick) for fn, period in periods.items()
                   for tick in range(0, ticks, period))
actual = Counter()
for event in trace["schedule_executions"]:
    fn, tick = event["function"], event["base_tick"]
    if (fn not in schedule or type(tick) is not int or
        event["phase"] != "periodic" or
        not math.isclose(event["elapsed_s"], tick / base, rel_tol=0, abs_tol=1e-12)):
        sys.exit("invalid schedule execution record")
    actual[fn, tick] += 1
if actual != expected:
    sys.exit("actual executions differ from the declared schedule")
counts = Counter()
for (fn, _), n in actual.items():
    counts[fn] += n


def fmt(v):
    # Integers stay integers; floats keep full round-trip precision (repr).
    return repr(v) if isinstance(v, float) else str(v)


print("# m1-eval whole-project golden over tests/acceptance-corpus")
print("# regenerate with: scripts/eval-golden.sh <eval-bin> <corpus> <golden> --update")
print(f"ticks {ticks}")
print(f"base_hz {base}")
print("# invocations counted from schedule execution records")
for fn in sorted(schedule):
    rate = schedule[fn]
    print(f"invocations {fn} @{rate}Hz = {counts[fn]}")
print("# final channel values (last tick)")
for ch in sorted(trace["channels"]):
    print(f"final {ch} = {fmt(trace['channels'][ch][-1])}")
print("# externally driven / defaulted channels")
for ch in sorted(trace.get("external", [])):
    print(f"external {ch}")
PY

if [ "$update" = "--update" ]; then
  cp "$generated" "$golden"
  echo "updated golden: $golden"
  exit 0
fi

if ! diff -u "$golden" "$generated"; then
  echo "eval golden mismatch: m1-eval whole-project output changed." >&2
  echo "If the change is intended, regenerate with --update and commit." >&2
  exit 1
fi
echo "m1-eval whole-project golden matches"
