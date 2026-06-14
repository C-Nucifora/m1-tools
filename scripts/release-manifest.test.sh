#!/usr/bin/env bash
#
# release-manifest.test.sh — behavioural tests for release-manifest.sh.
#
# The script resolves every repo to a release tag so the generated manifest
# reproduces "exactly what consumers install". A repo with no release yet is a
# legitimate fall-through to `main`; a *transient* gh failure (rate limit, 5xx,
# auth) is not — it must error out, never silently emit a main-pinned manifest.
# These tests stub `gh` to drive each failure mode and assert the contract.
#
# Run: scripts/release-manifest.test.sh   (no network, no gh required)

set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/scripts/release-manifest.sh"

fail=0
pass() { printf 'ok   - %s\n' "$1"; }
die() { printf 'FAIL - %s\n' "$1" >&2; fail=1; }

# Build an isolated sandbox: a one-repo manifest plus a stub `gh` (and `curl`)
# on PATH whose behaviour for the releases/latest call is parameterised.
make_sandbox() { # make_sandbox <releases_latest_behaviour_script>
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/scripts"
  cat >"$dir/m1-tools.repos" <<'EOF'
repositories:
  m1-doc:
    type: git
    url: https://github.com/C-Nucifora/m1-doc.git
EOF
  cp "$script" "$dir/scripts/release-manifest.sh"

  # tools.env stub: succeed but emit nothing, so pin_for finds no pin and the
  # script falls through to the gh releases/latest lookup under test.
  cat >"$dir/bin/gh" <<EOF
#!/usr/bin/env bash
if printf '%s\n' "\$@" | grep -q 'contents/tools.env'; then
  exit 0
fi
if printf '%s\n' "\$@" | grep -q 'releases/latest'; then
$1
fi
exit 0
EOF
  chmod +x "$dir/bin/gh"
  # curl fallback for tools.env — never the subject under test.
  printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/bin/curl"
  chmod +x "$dir/bin/curl"
  printf '%s' "$dir"
}

run() { # run <sandbox_dir> -> sets RC, OUT, ERR
  local dir="$1"
  OUT="$dir/out.repos"
  ERR="$dir/err.txt"
  set +e
  PATH="$dir/bin:$PATH" bash "$dir/scripts/release-manifest.sh" >"$OUT" 2>"$ERR"
  RC=$?
  set -e
}

# Build a sandbox whose tools.env carries a pin for the manifest's repo, so the
# repo->pin-variable derivation (not a hardcoded name list) is exercised. The
# releases/latest stub deliberately returns a *different* tag: a passing test
# proves the pin won, i.e. the variable was derived and matched.
make_pinned_sandbox() { # make_pinned_sandbox <repo_name> <PIN_VAR=tag>
  local repo="$1" pin="$2" dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/scripts"
  cat >"$dir/m1-tools.repos" <<EOF
repositories:
  $repo:
    type: git
    url: https://github.com/C-Nucifora/$repo.git
EOF
  cp "$script" "$dir/scripts/release-manifest.sh"
  cat >"$dir/bin/gh" <<EOF
#!/usr/bin/env bash
if printf '%s\n' "\$@" | grep -q 'contents/tools.env'; then
  printf '%s\n' "$pin"
  exit 0
fi
if printf '%s\n' "\$@" | grep -q 'releases/latest'; then
  echo "v9.9.9"
  exit 0
fi
exit 0
EOF
  chmod +x "$dir/bin/gh"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/bin/curl"
  chmod +x "$dir/bin/curl"
  printf '%s' "$dir"
}

# 1. A real release tag is emitted verbatim.
dir="$(make_sandbox '  echo "v0.6.0"; exit 0')"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'version: v0.6.0' "$OUT"; then
  pass "resolves a published release to its tag"
else
  die "expected exit 0 and version: v0.6.0 (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 2. A genuine 404 (no release yet) falls through to main, exit 0, with a note.
dir="$(make_sandbox '  echo "gh: Not Found (HTTP 404)" >&2; exit 1')"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'version: main' "$OUT"; then
  pass "404 (no release) falls back to main and exits 0"
else
  die "expected exit 0 and version: main on 404 (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 3. A transient/non-404 failure (rate limit) must ERROR, not pin main.
dir="$(make_sandbox '  echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1')"
run "$dir"
if [ "$RC" -ne 0 ] && ! grep -q 'version: main' "$OUT"; then
  pass "403 rate limit exits non-zero without pinning main"
else
  die "expected non-zero exit and no version: main on 403 (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 4. A 5xx/server failure must also ERROR, not pin main.
dir="$(make_sandbox '  echo "gh: Something went wrong (HTTP 502)" >&2; exit 1')"
run "$dir"
if [ "$RC" -ne 0 ] && ! grep -q 'version: main' "$OUT"; then
  pass "502 server error exits non-zero without pinning main"
else
  die "expected non-zero exit and no version: main on 502 (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 5. The error path surfaces gh's own message on stderr (not swallowed).
dir="$(make_sandbox '  echo "gh: Bad credentials (HTTP 401)" >&2; exit 1')"
run "$dir"
if [ "$RC" -ne 0 ] && grep -q 'HTTP 401' "$ERR"; then
  pass "401 surfaces gh error detail on stderr"
else
  die "expected non-zero exit and HTTP 401 on stderr (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 6. The pin variable is derived from the repo name, not a hardcoded list: a
#    repo with no case-arm but a matching tools.env pin still gets pinned (a
#    hardcoded map would silently fall through to releases/latest -> v9.9.9).
dir="$(make_pinned_sandbox m1-doc 'M1_DOC_VERSION=v1.2.3')"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'version: v1.2.3' "$OUT"; then
  pass "derives the pin variable from the repo name (m1-doc -> M1_DOC_VERSION)"
else
  die "expected version: v1.2.3 from derived pin (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

# 7. The derivation still matches the existing four CLI tools (regression).
dir="$(make_pinned_sandbox m1-typecheck 'M1_TYPECHECK_VERSION=v0.37.0')"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'version: v0.37.0' "$OUT"; then
  pass "derives the pin variable for an existing CLI tool (m1-typecheck)"
else
  die "expected version: v0.37.0 from derived pin (rc=$RC, out: $(cat "$OUT"))"
fi
rm -rf "$dir"

if [ "$fail" -ne 0 ]; then
  echo "release-manifest.test.sh: FAILED" >&2
  exit 1
fi
echo "release-manifest.test.sh: all tests passed"
