# m1-typecheck T097 — recursive-call Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new default-on, Error-severity rule T097 `recursive-call` that flags cycles in the user-function call graph (a script calling its own function, or mutual recursion through other user functions) — the "blocking recursion" check requested on 2026-06-11.

**Why typecheck, not lint:** M1 scripts define no in-file functions (grammar: locals/assignments/if/when/expand only), so recursion only exists across project components — analysable only with the project model. Distinct from T088, which covers write/read *data* cycles, not *call* cycles.

**Architecture:** Extend `schedule.rs`'s per-script `ScriptIo` with a `calls: BTreeSet<String>` of callee symbol paths that resolve to `SymbolKind::Function | Method` (collected in the existing `collect` walk, with the same `expand` substitution as channel paths). In `check()`, build call edges between scripts' `fn_path`s (keeping self-edges, unlike T088's deps) and run the same DFS cycle report, once per cycle via its lexicographically-smallest member, as `make_project_for(T097, Severity::Error, …)`.

**Repo:** `/Users/christiannucifora/Documents/GitHub/m1-typecheck`, branch `feat/t097-recursive-call`. No tracking issue — direct request; PR without `Closes`.

---

### Task 1: failing tests (tests/big_semantics.rs)

- [ ] Extend `tests/fixtures/semantics.m1prj` with a second callable: `<Component Classname="BuiltIn.FuncUserParam" Filename="Ctrl.Helper.m1scr" Name="Root.Ctrl.Helper"><Signature Name="" ReturnType="f32"><Params><Param Name="Input" Type="f32" Attrs="0"/></Params></Signature></Component>` (additive; usage audits only consider Channel/Parameter, so existing tests stay green).
- [ ] Tests: self-recursion (`Ctrl.Scale.m1scr` containing `A Out = Scale(In.Input, 2);` flags T097), mutual recursion (`Scale` calls `Helper(1.0)`, `Helper` calls `Scale(1.0, 2)` → T097 reported once), and clean non-recursive calls (`Alpha` calls `Scale` → no T097). Drive via `schedule::check` with the new flag.
- [ ] `cargo test big_semantics` → new tests fail to compile/fail (no `t097` param yet).

### Task 2: implementation

- [ ] `diagnostics.rs`: add `T097, // recursive-call (cycle in the user-function call graph)` to the enum, `as_str`, `name` (`"recursive-call"`), `all_codes`.
- [ ] `schedule.rs`: `ScriptIo.calls`; in `collect`'s `CallExpression` branch resolve the substituted callee path and insert `Function|Method` symbol paths into `calls` (before the existing `Set`/`Get` receiver logic; do not early-return); in `check(…, t097: bool)` map `fn_path → index`, build call edges (self-edges kept), DFS exactly like T088's, emitting `T097` `Severity::Error` `"recursive user-function call cycle: A -> B -> A"` anchored at the smallest member.
- [ ] `main.rs`: pass `true` for `t097` (default-on; global `--select`/`--ignore` filtering applies downstream as for T088).
- [ ] README.md rules table: T097 row.
- [ ] `cargo test` full suite green; commit, push, PR (no AI attribution).
