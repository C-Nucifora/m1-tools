#!/usr/bin/env bash
#
# release-manifest.test.sh — behavioural tests for release-manifest.sh.
#
# The script resolves every repo to a release tag so the generated manifest
# reproduces "exactly what consumers install". A repo with no release yet is a
# legitimate fall-through to `main`; a *transient* gh failure (rate limit, 5xx,
# auth) is not — it must error out, never silently emit a main-pinned manifest.
# The same discipline applies to the m1-ci/tools.env pin source: it is read at
# the *latest m1-ci release tag* (?ref=), not main, and a transient failure on
# either the tag resolution or the tools.env read must error, never silently
# substitute main content. These tests stub `gh` to drive each failure mode and
# assert the contract.
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

  # gh stub. The script makes three kinds of call, in order:
  #   1. releases/latest for C-Nucifora/m1-ci  -> resolve the tools.env ref
  #   2. contents/tools.env?ref=<tag>          -> the frozen pins
  #   3. releases/latest for the manifest repo -> the per-repo tag under test
  # (1) and (2) succeed normally (a tag, then empty tools.env so pin_for finds
  # no pin and the per-repo lookup runs); the parameterised behaviour drives
  # only (3), the per-repo releases/latest call under test.
  cat >"$dir/bin/gh" <<EOF
#!/usr/bin/env bash
args="\$(printf '%s\n' "\$@")"
if printf '%s' "\$args" | grep -q 'C-Nucifora/m1-ci/releases/latest'; then
  echo "v0.0.0"; exit 0
fi
if printf '%s' "\$args" | grep -q 'contents/tools.env'; then
  exit 0
fi
if printf '%s' "\$args" | grep -q 'releases/latest'; then
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
args="\$(printf '%s\n' "\$@")"
if printf '%s' "\$args" | grep -q 'contents/tools.env'; then
  printf '%s\n' "$pin"
  exit 0
fi
if printf '%s' "\$args" | grep -q 'releases/latest'; then
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

# Build a sandbox parameterised on the two tools.env-source calls: the m1-ci
# releases/latest tag resolution and the contents/tools.env read. The per-repo
# (m1-doc) releases/latest call succeeds with a normal tag so the manifest
# completes when the tools.env source is healthy. Used to prove the script reads
# tools.env at the resolved release tag (?ref=) and errors — never silently
# substitutes main content — on a transient failure of either call.
make_tools_env_sandbox() { # make_tools_env_sandbox <ci_tag_behaviour> <tools_env_behaviour>
  local ci_behaviour="$1" env_behaviour="$2" dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/bin" "$dir/scripts"
  cat >"$dir/m1-tools.repos" <<'EOF'
repositories:
  m1-doc:
    type: git
    url: https://github.com/C-Nucifora/m1-doc.git
EOF
  cp "$script" "$dir/scripts/release-manifest.sh"
  cat >"$dir/bin/gh" <<EOF
#!/usr/bin/env bash
args="\$(printf '%s\n' "\$@")"
if printf '%s' "\$args" | grep -q 'C-Nucifora/m1-ci/releases/latest'; then
$ci_behaviour
fi
if printf '%s' "\$args" | grep -q 'contents/tools.env'; then
  # Record the ref the script asked for so a test can assert it (the resolved
  # release tag, not main).
  printf '%s\n' "\$args" | grep -o 'ref=[^ ]*' >>"$dir/asked-refs.txt"
$env_behaviour
fi
if printf '%s' "\$args" | grep -q 'releases/latest'; then
  echo "v0.6.0"; exit 0
fi
exit 0
EOF
  chmod +x "$dir/bin/gh"
  # curl must NOT be the escape hatch any more: if the script ever falls back to
  # curl-from-main, fail loudly so the test catches it.
  printf '#!/usr/bin/env bash\necho "curl-fallback-should-not-run" >&2\nexit 7\n' >"$dir/bin/curl"
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

# 8. tools.env is read at the resolved m1-ci release tag (?ref=<tag>), not main.
dir="$(make_tools_env_sandbox \
  '  echo "v1.5.0"; exit 0' \
  '  exit 0')"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'ref=v1.5.0' "$dir/asked-refs.txt"; then
  pass "reads tools.env at the latest m1-ci release tag (?ref=v1.5.0)"
else
  die "expected tools.env read at ?ref=v1.5.0 (rc=$RC, refs: $(cat "$dir/asked-refs.txt" 2>/dev/null))"
fi
rm -rf "$dir"

# 9. A transient failure resolving the m1-ci release tag must ERROR — never
#    silently fall back to reading tools.env from main.
dir="$(make_tools_env_sandbox \
  '  echo "gh: API rate limit exceeded (HTTP 403)" >&2; exit 1' \
  '  exit 0')"
run "$dir"
if [ "$RC" -ne 0 ] && grep -q 'HTTP 403' "$ERR" && ! grep -q 'version: main' "$OUT"; then
  pass "transient failure resolving the m1-ci tag exits non-zero (no main fallback)"
else
  die "expected non-zero exit + HTTP 403 on stderr resolving m1-ci tag (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 10. A transient failure *reading* tools.env (at the resolved tag) must ERROR,
#     not collapse into a curl-from-main read (the old 2>/dev/null || curl path).
dir="$(make_tools_env_sandbox \
  '  echo "v1.5.0"; exit 0' \
  '  echo "gh: Something went wrong (HTTP 502)" >&2; exit 1')"
run "$dir"
if [ "$RC" -ne 0 ] && ! grep -q 'curl-fallback-should-not-run' "$ERR" && ! grep -q 'version: main' "$OUT"; then
  pass "transient tools.env read failure exits non-zero (no curl-from-main fallback)"
else
  die "expected non-zero exit, no curl-from-main fallback on tools.env 502 (rc=$RC, err: $(cat "$ERR"))"
fi
rm -rf "$dir"

# 11. If m1-ci has no release yet (404), tools.env is read from main deliberately
#     (the only available pin source) — exit 0, with a note on stderr.
dir="$(make_tools_env_sandbox \
  '  echo "gh: Not Found (HTTP 404)" >&2; exit 1' \
  '  exit 0')"
run "$dir"
if [ "$RC" -eq 0 ] && grep -q 'ref=main' "$dir/asked-refs.txt" && grep -q 'no m1-ci release' "$ERR"; then
  pass "no m1-ci release (404) reads tools.env from main with a note"
else
  die "expected exit 0, tools.env ?ref=main, and a note on 404 (rc=$RC, refs: $(cat "$dir/asked-refs.txt" 2>/dev/null), err: $(cat "$ERR"))"
fi
rm -rf "$dir"

if [ "$fail" -ne 0 ]; then
  echo "release-manifest.test.sh: FAILED" >&2
  exit 1
fi
echo "release-manifest.test.sh: all tests passed"
