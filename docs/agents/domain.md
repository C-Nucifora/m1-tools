# Domain docs

Use this repository's domain documentation when exploring the codebase.

## Read before relevant codebase work

- Read `CONTEXT.md` at the repository root.
- If `CONTEXT-MAP.md` exists, use it to find and read each relevant context's `CONTEXT.md`.
- Read ADRs under `docs/adr/` that affect the work. In a multi-context repository, also check `src/<context>/docs/adr/`.

Proceed silently when these files do not exist. The `domain-modeling` skill creates them when the project resolves terms or records decisions.

## File structure

This repository uses the single-context layout:

```text
/
├── CONTEXT.md
├── docs/adr/
└── src/
```

A repository with multiple contexts uses a root `CONTEXT-MAP.md`, system-wide ADRs under `docs/adr/`, and context-specific `CONTEXT.md` and ADR files beneath each context.

## Use glossary terms

Use the terms defined in `CONTEXT.md` in issue titles, refactor proposals, hypotheses, and test names. Avoid synonyms that the glossary rejects.

If a needed concept is absent, reconsider whether the project uses that concept. Record a genuine terminology gap for `domain-modeling`.

## Report ADR conflicts

State when proposed work conflicts with an existing ADR and name the ADR.

