#!/usr/bin/env bash
#
# compat-bom.sh — emit a compatibility bill of materials for the toolchain (#60).
#
# The ecosystem review found that consumers cannot tell "development main" from
# "released consumer graph": at review time m1-doc, m1-vscode and tree-sitter-m1
# had post-release commits on main, m1-lsp's m1-eval pin trailed the current
# release, and m1-visualiser had no release at all — all normal development, but
# invisible. This script publishes both graphs. For every repo in
# m1-tools.repos it resolves:
#
#   - the latest release tag and the commit that tag points at (the RELEASED
#     view),
#   - the commit on main (the DEVELOPMENT view),
#   - the repo's internal m1-* / tree-sitter-m1 git-tag Cargo dependency pins,
#     read from Cargo.toml BOTH at the release tag and at main.
#
# Non-Rust repos (nvim-m1, telescope-m1.nvim, m1-vscode, m1-ci) have no
# Cargo.toml; their internal pins are marked n/a (their pin sources —
# tools.env, sync-server.yml, bundled toolchains — are guarded elsewhere).
#
# Output:
#   scripts/compat-bom.sh           # human-readable table (both graphs)
#   scripts/compat-bom.sh --json    # machine JSON (consumed by check-skew.sh)
#
# Generated on demand (it queries GitHub) rather than committed, so it cannot
# go stale in-tree. The 404-vs-transient-failure discipline of
# release-manifest.sh applies: a genuine 404 (no release / no Cargo.toml) is a
# legitimate empty result; a rate-limit / 5xx / auth failure errors out, never
# silently degrading the BOM.
#
# Requires: gh (authenticated), python3.

set -euo pipefail

mode=table
while [ $# -gt 0 ]; do
  case "$1" in
    --json) mode=json; shift ;;
    -h | --help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1 (accepted: --json)" >&2
      exit 2
      ;;
  esac
done

here="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$here/m1-tools.repos"

# Resolve a repo's latest release tag, distinguishing "no release yet" (a
# legitimate 404 -> empty output, exit 0) from a transient failure (rate limit,
# 5xx, auth -> error out). See release-manifest.sh for the rationale: collapsing
# both into "" would let a flaky run emit a misleading BOM with exit 0.
latest_release_tag() { # latest_release_tag owner/repo -> tag (empty on 404)
  local repo="$1" gherr tag
  gherr="$(mktemp "${TMPDIR:-/tmp}/compat-bom.gherr.XXXXXX")"
  if tag=$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>"$gherr"); then
    printf '%s' "$tag"
  elif grep -q '(HTTP 404)' "$gherr"; then
    : # no release yet — caller records an empty tag
  else
    echo "error: gh api failed resolving the latest release for $repo:" >&2
    cat "$gherr" >&2
    rm -f "$gherr"
    exit 1
  fi
  rm -f "$gherr"
}

# The commit a ref (tag or branch) resolves to. A 404 (ref absent) yields an
# empty sha; a transient failure errors out.
commit_for() { # commit_for owner/repo ref -> sha (empty on 404)
  local repo="$1" ref="$2" gherr sha
  gherr="$(mktemp "${TMPDIR:-/tmp}/compat-bom.gherr.XXXXXX")"
  if sha=$(gh api "repos/$repo/commits/$ref" --jq .sha 2>"$gherr"); then
    printf '%s' "$sha"
  elif grep -q '(HTTP 404)' "$gherr"; then
    : # ref absent — record empty
  else
    echo "error: gh api failed resolving commit $repo@$ref:" >&2
    cat "$gherr" >&2
    rm -f "$gherr"
    exit 1
  fi
  rm -f "$gherr"
}

# The raw Cargo.toml at a ref. A 404 (no Cargo.toml -> non-Rust repo, or the ref
# has none) yields empty output; a transient failure errors out.
cargo_at() { # cargo_at owner/repo ref -> raw Cargo.toml (empty on 404)
  local repo="$1" ref="$2" gherr body
  gherr="$(mktemp "${TMPDIR:-/tmp}/compat-bom.gherr.XXXXXX")"
  if body=$(gh api "repos/$repo/contents/Cargo.toml?ref=$ref" \
    -H "Accept: application/vnd.github.raw" 2>"$gherr"); then
    printf '%s' "$body"
  elif grep -q '(HTTP 404)' "$gherr"; then
    : # no Cargo.toml at this ref — non-Rust or absent
  else
    echo "error: gh api failed reading Cargo.toml $repo@$ref:" >&2
    cat "$gherr" >&2
    rm -f "$gherr"
    exit 1
  fi
  rm -f "$gherr"
}

work="$(mktemp -d "${TMPDIR:-/tmp}/compat-bom.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# Walk the manifest's repo/url pairs (same YAML-light parse as
# release-manifest.sh) so the repo list can never drift from the manifest.
i=0
while IFS=$'\t' read -r name url; do
  slug="${url#https://github.com/}"
  slug="${slug%.git}"

  reltag="$(latest_release_tag "$slug")"
  printf '%s' "$name" >"$work/$i.name"
  printf '%s' "$slug" >"$work/$i.slug"
  printf '%s' "$reltag" >"$work/$i.reltag"

  if [ -n "$reltag" ]; then
    commit_for "$slug" "$reltag" >"$work/$i.relcommit"
    cargo_at "$slug" "$reltag" >"$work/$i.relcargo"
  else
    : >"$work/$i.relcommit"
    : >"$work/$i.relcargo"
  fi

  commit_for "$slug" main >"$work/$i.maincommit"
  cargo_at "$slug" main >"$work/$i.maincargo"

  i=$((i + 1))
done < <(python3 - "$manifest" <<'PY'
import sys

name = None
for line in open(sys.argv[1]):
    stripped = line.strip()
    if line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
        name = stripped[:-1]
    elif stripped.startswith("url:") and name:
        print(f"{name}\t{stripped.split(None, 1)[1]}")
PY
)
printf '%s' "$i" >"$work/count"

# Assemble the BOM. Pin extraction (parsing git-tag Cargo deps) and JSON
# escaping are done in python; gh + the 404 discipline stay in bash above.
python3 - "$work" "$mode" <<'PY'
import json
import re
import sys

work, mode = sys.argv[1], sys.argv[2]

with open(f"{work}/count") as fh:
    count = int(fh.read())


def read(idx, ext):
    try:
        with open(f"{work}/{idx}.{ext}") as fh:
            return fh.read()
    except FileNotFoundError:
        return ""


# A git-tag dependency on an internal crate, e.g.
#   m1-core = { git = "https://github.com/C-Nucifora/m1-core.git", tag = "v0.15.0" }
# git= and tag= may appear in either order; the crate name is the internal one.
DEP = re.compile(
    r'^\s*(?P<name>(?:m1-[A-Za-z0-9_-]+|tree-sitter-m1))\s*=\s*\{[^}]*\}',
    re.MULTILINE,
)
TAG = re.compile(r'\btag\s*=\s*"(?P<tag>[^"]+)"')
GIT = re.compile(r'\bgit\s*=\s*"[^"]*github\.com')


def pins(cargo):
    out = {}
    for m in DEP.finditer(cargo):
        body = m.group(0)
        if not GIT.search(body):
            continue
        t = TAG.search(body)
        if t:
            out[m.group("name")] = t.group("tag")
    return dict(sorted(out.items()))


repos = []
for idx in range(count):
    reltag = read(idx, "reltag")
    relcargo = read(idx, "relcargo")
    maincargo = read(idx, "maincargo")
    lang = "rust" if (relcargo.strip() or maincargo.strip()) else "other"
    repos.append(
        {
            "name": read(idx, "name"),
            "slug": read(idx, "slug"),
            "lang": lang,
            "release_tag": reltag,
            "release_commit": read(idx, "relcommit"),
            "main_commit": read(idx, "maincommit"),
            "released_pins": pins(relcargo),
            "main_pins": pins(maincargo),
        }
    )

if mode == "json":
    print(json.dumps({"generated_by": "scripts/compat-bom.sh", "repos": repos}, indent=2))
    sys.exit(0)


def short(sha):
    return sha[:9] if sha else "-"


def fmt_pins(p):
    return ", ".join(f"{k}={v}" for k, v in p.items()) if p else "-"


def fmt_row(name, ref, commit, pins_map):
    return f"  {name:<20} {ref:<14} {short(commit):<10} {fmt_pins(pins_map)}"


header = f"  {'repo':<20} {'ref':<14} {'commit':<10} internal m1-* pins"

print("Toolchain compatibility BOM")
print("=" * len(header))
print()
print("Released consumer graph (latest release tag; internal pins AT that tag)")
print("-" * len(header))
print(header)
for r in repos:
    if r["release_tag"]:
        print(fmt_row(r["name"], r["release_tag"], r["release_commit"], r["released_pins"]))
    else:
        print(f"  {r['name']:<20} {'(no release)':<14} {'-':<10} -")
print()
print("Development main graph (HEAD of main; internal pins AT main)")
print("-" * len(header))
print(header)
for r in repos:
    print(fmt_row(r["name"], "main", r["main_commit"], r["main_pins"]))
PY
