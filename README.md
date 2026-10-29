# MoonPay Flow

[![CI](https://github.com/cstoooo/moonpay-flow/actions/workflows/ci.yml/badge.svg)](https://github.com/cstoooo/moonpay-flow/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-0.8.2-blue.svg)](https://mooncakes.io/docs/cstoooo/moonpay_flow@0.8.2)

MoonPay Flow is a MoonBit-native ISO 20022 validation, status timeline, statement audit and reconciliation toolkit. It connects payment instructions, status reports and bank statement postings while making incomplete evidence explicit.

## Highlights

- Project-local XML pull reader and fixed-point decimal implementation.
- Validation for `pain.001`, `pain.002`, `pacs.008`, `pacs.002` and `camt.053`.
- Multi-report status timelines with terminal-state and conflict detection.
- Balance, movement, currency, account and duplicate-entry audit for `camt.053`.
- Per-`Stmt`, per-account portfolio audit.
- Cross-period refund and reversal ledger with explicit evidence boundaries.
- Text, JSON and Markdown reports.
- 112 tests, 25 synthetic fixtures and 82 queryable rules.

## Install

```bash
moon add cstoooo/moonpay_flow@0.8.2
```

Add the package alias to the consuming package's `moon.pkg`:

```text
import {
  "cstoooo/moonpay_flow" @moonpay_flow,
}
```

Mooncakes documentation: <https://mooncakes.io/docs/cstoooo/moonpay_flow@0.8.2>

## Quick start

Run from a clone of this repository:

```bash
moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
moon run cmd/main -- --format json fixtures/valid_pain001.xml
moon run cmd/main -- --list-rules
```

Full acceptance-style verification:

```bash
scripts/check.sh
```

## CLI

| Command | Purpose |
| --- | --- |
| `<message.xml>` | Validate one supported ISO 20022 message |
| `reconcile <pain.001> <status>` | Match payment instructions with status entries |
| `lifecycle <payment> <status> <statement>` | Compact payment, status and posting summary |
| `audit <camt.053>` | Single-account balance and duplicate-entry audit |
| `audit-portfolio <camt.053>` | Audit every `Stmt` and account separately |
| `timeline <payment> [status ...]` | Merge multiple status reports by timestamp |
| `return-ledger <payment> <statement ...>` | Authoritative cross-period refund/reversal ledger |
| `--list-rules` | Print all 82 rule codes and descriptions |

Report formats:

```bash
moon run cmd/main -- --format text fixtures/valid_pain001.xml
moon run cmd/main -- --format json fixtures/valid_pain001.xml
moon run cmd/main -- --format markdown fixtures/invalid_pain001.xml
```

### Return and reversal example

```bash
moon run cmd/main -- return-ledger \
  fixtures/returns_pain001.xml \
  fixtures/returns_day1.xml \
  fixtures/returns_day2_partial.xml \
  fixtures/returns_day3_final.xml \
  fixtures/returns_day4_refund_reversal.xml
```

The example crosses four booking days:

```text
2026-10-01  DBIT 100.00  original payment
2026-10-02  CRDT  20.00  partial refund
2026-10-03  CRDT  80.00  final refund
2026-10-04  DBIT  80.00  reversal of the final refund
```

Result:

```text
state=PARTIALLY_RETURNED
Posted payment: 100.00
Effective refund: 20.00
Remaining: 80.00
```

If only the refund statement is supplied, the result is `EVIDENCE_INCOMPLETE`; `postedPayment`, `effectiveRefund` and `remaining` are `null`. The tool does not guess a partial or full return from net amount alone.

## Library API

```moonbit
let validation = @moonpay_flow.validate_message(xml_text)
let timeline = @moonpay_flow.status_timeline_report(payment_xml, status_xmls)
let portfolio = @moonpay_flow.statement_portfolio_audit(camt_xml)
let ledger = @moonpay_flow.return_ledger_report(payment_xml, statement_xmls)
```

All major reports provide:

- structured case/leg objects;
- stable diagnostic codes;
- `is_valid()` for automated gates;
- `to_text()`, `to_json()` and `to_markdown()`.

See the [usage guide](docs/usage.md) for complete API examples.

## Reliability model

1. XML parsing and decimal arithmetic are implemented in MoonBit.
2. JSON monetary values are serialized as fixed-point strings.
3. Reversals are linked by `OrgnlNtryRef`, `OrgnlTxId`, `UETR`, or a unique compatible candidate.
4. Ambiguous reversal targets produce an error instead of an arbitrary match.
5. Refund states require the original payment posting in the supplied history.
6. Incomplete history produces `EVIDENCE_INCOMPLETE`, not a guessed conclusion.
7. Multi-account audits never combine movements across account scopes.

## Supported versions

| Message | Supported version |
| --- | --- |
| `pain.001` | `pain.001.001.03` |
| `pain.002` | `pain.002.001.03` |
| `pacs.008` | `pacs.008.001.08` |
| `pacs.002` | `pacs.002.001.10` |
| `camt.053` | `camt.053.001.08` |

The project implements common fields and explicit business rules, not complete ISO 20022 XSD validation or every bank-specific implementation guide. See [version scope](docs/version-scope-and-cases.md).

## Quality and compliance

- Tests: 112 passing.
- Fixtures: 25 synthetic ISO 20022 messages.
- Rule catalog: 82 codes.
- CI: GitHub Actions runs `moon check`, `moon test` and a validation example.
- License: Apache-2.0.
- Data policy and security reporting: [SECURITY.md](SECURITY.md).
- Contribution rules: [CONTRIBUTING.md](CONTRIBUTING.md).
- Copyright and third-party notice: [NOTICE](NOTICE).
- Release history: [CHANGELOG.md](CHANGELOG.md).

## Documentation

- [Usage guide](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Test matrix](docs/test-matrix.md)
- [Acceptance checklist](docs/acceptance-checklist.md)
- [Version scope and lifecycle cases](docs/version-scope-and-cases.md)
- [Balance audit cases](docs/statement-audit-cases.md)
- [Status timeline cases](docs/status-timeline-cases.md)
- [Multi-account audit](docs/multi-account-audit.md)
- [Cross-period return ledger](docs/return-ledger-cases.md)

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
