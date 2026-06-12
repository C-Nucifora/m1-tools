# M1 CLIs — quickstart & conventions

The toolchain ships five standalone command-line tools that work on M1
projects without an editor. They are the same engines the editor plugins drive
(over LSP or by spawning the CLI), so what you see in CI matches what you see
in your editor.

| Tool | Does | Typical use |
| --- | --- | --- |
| [`m1-fmt`](https://github.com/C-Nucifora/m1-fmt) | Formats scripts (tabs + Allman by default, per the M1 manual) | format-on-save, `--check` in CI |
| [`m1-lint`](https://github.com/C-Nucifora/m1-lint) | Static analysis / style rules (L0xx) | catch style + correctness issues |
| [`m1-typecheck`](https://github.com/C-Nucifora/m1-typecheck) | Type/symbol model + type rules (T0xx) | catch type mismatches against the project model |
| [`m1-project`](https://github.com/nedlane/m1-project) | Validated editor for `Project.m1prj` (create channels/groups, set type/unit/security/call-rate/tags, validate) | scripted project edits; `validate` as a pre-commit/CI gate |
| [`m1-cfg-export`](https://github.com/C-Nucifora/m1-typecheck#m1-cfg-export--export-the-expected-m1cfg-parameter-list) | Exports the expected `.m1cfg` parameter list from a project (ships with m1-typecheck) | calibration-file skeletons; `--missing-only` drift checks |

## Quickstart

Each tool reads one or more files (or `-`/stdin) and writes diagnostics to
stderr. Install the prebuilt binaries from each repo's Releases, or build from
source with `cargo build --release`.

### Format

```sh
m1-fmt Scripts/Engine.Update.m1scr            # formatted output to stdout
m1-fmt -i Scripts/*.m1scr                      # rewrite files in place
m1-fmt --check Scripts/*.m1scr                 # CI: non-zero if anything would change
m1-fmt --check .                               # same, over every .m1scr under a directory
m1-fmt --diff Scripts/Engine.Update.m1scr      # unified diff of the changes
cat Scripts/Engine.Update.m1scr | m1-fmt -     # read stdin
```

### Lint

```sh
m1-lint Scripts/*.m1scr                         # report L0xx findings
m1-lint .                                       # lint every .m1scr under a directory
m1-lint --fix Scripts/*.m1scr                   # apply the safe autofixes in place
m1-lint --select L007,L011 Scripts/Foo.m1scr    # only these rules
m1-lint --ignore L001 Scripts/Foo.m1scr         # all rules except these
m1-lint --rules                                 # print the rule catalogue
m1-lint --rules --format json                   # machine-readable catalogue
```

### Type-check

```sh
# Point at the project so channels/enums/units resolve. Without --project the
# checker still runs the project-independent rules.
m1-typecheck --project Project.m1prj Scripts/Engine.Update.m1scr
m1-typecheck --project Project.m1prj --select T030 Scripts/*.m1scr
```

### Edit / validate the project file

```sh
m1-project validate --project Project.m1prj          # structural invariants
m1-project list-components --project Project.m1prj --json
m1-project create-channel --project Project.m1prj --name Root.Engine.NewSignal --type f32
```

Run `m1-project --help` for the full verb list (create/delete/rename
components, set type/unit/quantity/security/call-rate/validation/format/tags).
The VS Code and Neovim project-editing commands shell out to these same verbs.

### Export the expected calibration list

```sh
m1-cfg-export Project.m1prj                                   # full .m1cfg XML skeleton
m1-cfg-export Project.m1prj --format csv -o params.csv        # spreadsheet-friendly
m1-cfg-export Project.m1prj --missing-only --baseline parameters.m1cfg   # CI drift check
```

A `.m1prj` (and, when present, a `.m1cfg` and `.m1dbc`) is auto-discovered by
walking up from the script; `--project` pins it explicitly. Some rules
(T041 calibration-coverage, T042 dbc-signal-range) are skipped with a note when
the project/DBC they need is absent.

## Conventions

The CLIs share one contract so scripting and CI behave predictably.

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success — no findings; nothing to report or change. |
| `1` | The tool ran and **has something to report**: lint/type findings, a script with syntax errors, a file that `--check`/`--diff` would reformat, or a file in a batch that could not be read (the others are still processed; the error is on stderr). |
| `2` | A **usage error** — an unrecognized flag or a bad argument (e.g. an invalid `--range`). |

So `$? != 0` means "do not proceed". A batch (`m1-lint Scripts/*.m1scr`) never
aborts on the first unreadable file — every readable file is still checked, and
the run exits `1` so the failure isn't hidden.

### `--version` / `-V`

Every tool reports its own version (e.g. `m1-fmt 0.11.0`) and exits `0`. Use
this to pin tool versions in CI.

### `--help`

Every tool prints usage and its flags. The standalone tools and the editors all
read the same configuration files (below), so a flag set on the CLI behaves the
same as the corresponding editor setting.

### Configuration & precedence

The script-facing tools and the LSP that backs the editors read the same
configuration files, but layer them differently. Lowest layer first; later
layers override earlier ones.

**CLI tools:**

1. built-in defaults (manual-conformant: tabs, Allman, etc.);
2. the unified **`m1-tools.toml`** (`[format]` / `[lint]` / `[diagnostics]`),
   discovered by walking up from the file — shared by VS Code, Neovim, and the
   CLIs;
3. the tool-specific file — **`.m1fmt.toml`** for `m1-fmt`, **`.m1lint.toml`**
   for `m1-lint` — which overrides the unified file;
4. explicit command-line flags, which win over everything.

**Editors (m1-lsp):**

1. built-in defaults;
2. editor settings (VS Code `m1.*` / nvim-m1 `settings`) — the personal layer;
3. the workspace **`m1-tools.toml`** — the committed project config
   deliberately outranks personal editor settings so the team style wins.

`m1-lsp --scaffold-config` writes a starter `m1-tools.toml`.
