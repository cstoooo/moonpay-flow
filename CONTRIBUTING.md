# Contributing

## Scope

Contributions should preserve these project boundaries:

- MoonBit is the implementation language.
- ISO 20022 field paths and supported message versions are explicit.
- Return and reversal conclusions require traceable statement evidence.
- Incomplete history must not be converted into a guessed refund state.
- Test fixtures must be synthetic and contain no customer or production data.

## Local checks

Run the complete verification script before submitting changes:

```bash
scripts/check.sh
```

Equivalent base commands:

```bash
moon check
moon test
```

## Change requirements

- Add tests for every new rule or state transition.
- Update the rule catalog when adding a diagnostic code.
- Update the relevant file in `docs/` when behavior or supported fields change.
- Keep public monetary values as fixed-point decimal strings in JSON output.
- Avoid committing build output, package caches or private submission documents.

## Commit style

Use a short imperative subject, for example:

```text
feat: add cross-period refund matching
fix: reject ambiguous reversal targets
docs: document statement audit outputs
test: cover incomplete return history
```

## Compatibility

The project follows semantic versioning. New public types or CLI commands use a minor version. Documentation-only changes use a patch version. Behavior-breaking API changes require a major version.
