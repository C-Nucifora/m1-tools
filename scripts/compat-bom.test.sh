#!/usr/bin/env bash
#
# compat-bom.test.sh — behavioural tests for compat-bom.sh.
#
# The BOM must: extract internal git-tag Cargo pins (both at the release tag and
# at main), mark non-Rust repos (no Cargo.toml -> 404) as lang "other" with no
# pins, still emit the development-main view for a repo with no release, and —
# like release-manifest.sh — treat a transient gh failure as an error rather
# than silently degrading the BOM. These tests stub `gh` per endpoint to drive
# each case; no network or token is needed.
#
# Run: scripts/compat-bom.test.sh

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/scripts/compat-bom.sh"

fail=0
pass() { printf 'ok   - %s\n' "$1"; }
die() { printf 'FAIL - %s\n' "$1" >&2; fail=1; }

# Sandbox: a two-repo manifest (one Rust, one non-Rust) plus a stub `gh` whose
# releases/latest behaviour for the Rust repo is parameterised (to drive the
# 404-vs-transient discipline). The Rust repo's Cargo.toml carries a git-tag pin
# on m1-core; the non-Rust repo returns 404 for Cargo.toml.
make_sandbox() { # make_sandbox <rust_releases_latest_behaviour>
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/scripts"
  cat >"$dir/m1-tools.repos" <<'EOF'
repositories:
  rust-tool:
    type: git
    url: https://github.com/C-Nucifora/rust-tool.git
  node-tool:
    type: git
    url: https://github.com/C-Nucifora/node-tool.git
EOF
  cp "$script" "$dir/scripts/compat-bom.sh"

  cat >"$dir/bin/gh" <<EOF
#!/usr/bin/env bash
args="\$(printf '%s ' "\$@")"

# Cargo.toml reads: rust-tool has one (with a git-tag pin), node-tool 404s.
if printf '%s' "\$args" | grep -q 'contents/Cargo.toml'; then
  if printf '%s' "\$args" | grep -q 'rust-tool'; then
    cat <<'TOML'
[package]
name = "rust-tool"
version = "0.9.0"

[dependencies]
m1-core = { git = "https://github.com/C-Nucifora/m1-core.git", tag = "v0.15.0" }
serde = "1"
TOML
    exit 0
  fi
  echo "gh: Not Found (HTTP 404)" >&2; exit 1
fi

# Commit resolution: any ref resolves to a canned sha.
if printf '%s' "\$args" | grep -q 'commits/'; then
  echo "abcdef1234567890abcdef1234567890abcdef12"; exit 0
fi

# releases/latest: node-tool has a normal release; rust-tool is parameterised.
if printf '%s' "\$args" | grep -q 'releases/latest'; then
  if printf '%s' "\$args" | grep -q 'rust-tool'; then
$1
  fi
  echo "v2.0.0"; exit 0
fi
exit 0
EOF
  chmod +x "$dir/bin/gh"
  printf '%s' "$dir"
}

run() { # run <sandbox_dir> [args...] -> sets RC, OUT, ERR
  local dir="$1"
  shift
  OUT="$dir/out.txt"
  ERR="$dir/err.txt"
  set +e
  PATH="$dir/bin:$PATH" bash "$dir/scripts/compat-bom.sh" "$@" >"$OUT" 2>"$ERR"
  RC=$?
  set -e
}

# 1. --json extracts the internal git-tag pin for the Rust repo.
dir="$(make_sandbox '  echo "v1.0.0"; exit 0')"
run "$dir" --json
if [ "$RC" -eq 0 ] && python3 -c '
import json, sys
bom = json.load(open(sys.argv[1]))
r = {x["name"]: x for x in bom["repos"]}
assert r["rust-tool"]["lang"] == "rust", r["rust-tool"]["lang"]
assert r["rust-tool"]["released_pins"] == {"m1-core": "v0.15.0"}, r["rust-tool"]["released_pins"]
assert r["rust-tool"]["main_pins"] == {"m1-core": "v0.15.0"}, r["rust-tool"]["main_pins"]
assert r["rust-tool"]["release_tag"] == "v1.0.0", r["rust-tool"]["release_tag"]
' "$OUT"; then
  pass "--json extracts internal git-tag pins for a Rust repo"
else
  die "expected rust-tool pin m1-core=v0.15.0 in JSON (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 2. A non-Rust repo (Cargo.toml 404) is lang "other" with no internal pins.
dir="$(make_sandbox '  echo "v1.0.0"; exit 0')"
run "$dir" --json
if [ "$RC" -eq 0 ] && python3 -c '
import json, sys
bom = json.load(open(sys.argv[1]))
r = {x["name"]: x for x in bom["repos"]}
assert r["node-tool"]["lang"] == "other", r["node-tool"]["lang"]
assert r["node-tool"]["released_pins"] == {}, r["node-tool"]["released_pins"]
' "$OUT"; then
  pass "non-Rust repo (Cargo.toml 404) is lang=other with no pins"
else
  die "expected node-tool lang=other, no pins (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 3. A repo with no release (404 on releases/latest) still gets a main-graph row
#    (empty release_tag) rather than aborting the whole BOM.
dir="$(make_sandbox '  echo "gh: Not Found (HTTP 404)" >&2; exit 1')"
run "$dir" --json
if [ "$RC" -eq 0 ] && python3 -c '
import json, sys
bom = json.load(open(sys.argv[1]))
r = {x["name"]: x for x in bom["repos"]}
assert r["rust-tool"]["release_tag"] == "", r["rust-tool"]["release_tag"]
assert r["rust-tool"]["main_commit"], "main_commit should still be resolved"
assert r["rust-tool"]["main_pins"] == {"m1-core": "v0.15.0"}, r["rust-tool"]["main_pins"]
' "$OUT"; then
  pass "no-release repo still appears with a main-graph row"
else
  die "expected rust-tool empty release_tag but present main graph (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 4. A transient failure (rate limit) on releases/latest must ERROR, not degrade.
dir="$(make_sandbox '  echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1')"
run "$dir" --json
if [ "$RC" -ne 0 ] && grep -q 'HTTP 403' "$ERR"; then
  pass "transient releases/latest failure exits non-zero"
else
  die "expected non-zero exit + HTTP 403 on stderr (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 5. The default (table) mode renders both graphs.
dir="$(make_sandbox '  echo "v1.0.0"; exit 0')"
run "$dir"
if [ "$RC" -eq 0 ] \
  && grep -q 'Released consumer graph' "$OUT" \
  && grep -q 'Development main graph' "$OUT" \
  && grep -q 'm1-core=v0.15.0' "$OUT"; then
  pass "table mode renders both the released and main graphs"
else
  die "expected both graphs + pin in table (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 6. An unknown flag is rejected (exit 2).
dir="$(make_sandbox '  echo "v1.0.0"; exit 0')"
run "$dir" --bogus
if [ "$RC" -eq 2 ]; then
  pass "unknown flag exits 2"
else
  die "expected exit 2 on unknown flag (rc=$RC)"
fi
rm -rf "$dir"

if [ "$fail" -ne 0 ]; then
  echo "compat-bom.test.sh: FAILED" >&2
  exit 1
fi
echo "compat-bom.test.sh: all tests passed"
