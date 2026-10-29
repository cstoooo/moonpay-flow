# Acceptance Checklist

This document maps the final repository state to the evaluation criteria in the organizer's initial-review notice.

## 1. Completion

| Requirement | Evidence |
| --- | --- |
| Working MoonBit implementation | 10 source modules and a MoonBit CLI under `cmd/main` |
| Reproducible tests | 112 tests, 25 fixtures, `scripts/check.sh` |
| Released package | Mooncakes `cstoooo/moonpay_flow@0.8.2` |
| Declared direction | ISO 20022 validation, status timeline, statement audit and return/reversal reconciliation |
| Future maintainability | Version boundaries, architecture, changelog and test matrix documented |

## 2. Code quality

| Requirement | Evidence |
| --- | --- |
| Project-local XML parsing | `xml_reader.mbt` |
| Project-local fixed-point arithmetic | `decimal.mbt` |
| Stable diagnostics | 82-entry `rule_catalog()` |
| Deterministic monetary output | Fixed-point strings in JSON |
| Evidence uncertainty is explicit | `EVIDENCE_INCOMPLETE` and `CONFLICT` states |
| Cross-period correctness | Directed ledger in `return_ledger.mbt` |
| Multi-account correctness | `statement_portfolio.mbt` |
| Repeatable verification | `scripts/check.sh` and GitHub Actions |

## 3. Open-source compliance

| Requirement | Evidence |
| --- | --- |
| License | Apache-2.0 `LICENSE` |
| Copyright and third-party notice | `NOTICE` |
| Contribution rules | `CONTRIBUTING.md` |
| Security and data-handling policy | `SECURITY.md` |
| Synthetic data only | Stated in README, NOTICE and proposal |
| Public repository | https://github.com/cstoooo/moonpay-flow |

## 4. MoonBit ecosystem relevance

| Requirement | Evidence |
| --- | --- |
| MoonBit-native library | Public MoonBit API and package metadata |
| Package-manager installation | `moon add cstoooo/moonpay_flow@0.8.2` |
| Generated Mooncakes documentation | Mooncakes module page |
| MoonBit CLI usage | `moon run cmd/main -- ...` |
| Compatible dependency use | `moonbitlang/x/fs` |
| CI verification | GitHub Actions runs against the MoonBit toolchain |

## 5. Required repository materials

- [README](../README.md): installation, usage, features, CLI, limitations and document index
- [LICENSE](../LICENSE): Apache License 2.0
- [Usage guide](usage.md)
- [Architecture](architecture.md)
- [Version scope and cases](version-scope-and-cases.md)
- [Test matrix](test-matrix.md)
- [Changelog](../CHANGELOG.md)
- [Contribution guide](../CONTRIBUTING.md)
- [Security policy](../SECURITY.md)

## Final verification commands

```bash
moon check
moon test
scripts/check.sh
```

Expected test result:

```text
Total tests: 112, passed: 112, failed: 0.
```
