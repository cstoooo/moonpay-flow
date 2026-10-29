# Usage Guide

## Requirements

- MoonBit CLI toolchain
- Network access for the first `moon add` or `moon update`

## Install the library

```bash
moon add cstoooo/moonpay_flow@0.8.1
```

Add the package alias to `moon.pkg`:

```text
import {
  "cstoooo/moonpay_flow" @moonpay_flow,
}
```

Mooncakes documentation:

```text
https://mooncakes.io/docs/cstoooo/moonpay_flow@0.8.1
```

## Run the CLI from the repository

```bash
moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
```

## CLI commands

| Command | Purpose |
| --- | --- |
| `<message.xml>` | Validate one supported ISO 20022 message |
| `reconcile <pain.001> <status>` | Match payment instructions with status entries |
| `lifecycle <payment> <status> <statement>` | Compact payment/status/posting lifecycle summary |
| `audit <camt.053>` | Single-account balance and duplicate-entry audit |
| `audit-portfolio <camt.053>` | Audit multiple `Stmt` and account scopes separately |
| `timeline <payment> [status ...]` | Merge multiple status reports chronologically |
| `return-ledger <payment> <statement ...>` | Authoritative cross-period refund/reversal ledger |
| `--list-rules` | Print all diagnostic rule codes |

Global report options:

```text
--format text
--format json
--format markdown
```

## Library examples

### Validate a message

```moonbit
test "validate pain.001" {
  let xml = "<Document>...</Document>"
  let report = @moonpay_flow.validate_message(xml)
  assert_true(report.is_valid())
}
```

### Merge status reports

```moonbit
let report = @moonpay_flow.status_timeline_report(
  payment_xml,
  [status_xml_1, status_xml_2],
)
println(report.to_json())
```

### Audit multiple statements

```moonbit
let report = @moonpay_flow.statement_portfolio_audit(camt_xml)
for statement in report.statements {
  println(statement.statement_id.unwrap())
  println(statement.balance_status.name())
}
```

### Build a refund/reversal ledger

```moonbit
let report = @moonpay_flow.return_ledger_report(
  payment_xml,
  [day1_xml, day2_xml, day3_xml],
)
for case in report.cases {
  println(case.end_to_end_id + " " + case.state.name())
}
```

## Return-ledger example

```bash
moon run cmd/main -- return-ledger \
  fixtures/returns_pain001.xml \
  fixtures/returns_day1.xml \
  fixtures/returns_day2_partial.xml \
  fixtures/returns_day3_final.xml \
  fixtures/returns_day4_refund_reversal.xml
```

Expected final state:

```text
PARTIALLY_RETURNED
Posted payment: 100.00
Effective refund: 20.00
Remaining: 80.00
```

If the original posting is omitted, the state is `EVIDENCE_INCOMPLETE`; the tool does not infer a refund state from a net amount.

## Output contracts

- Amounts in JSON are fixed-point strings, not floating-point numbers.
- Diagnostics contain a stable code, a field path and a human-readable message.
- `status_timeline_report` and `return_ledger_report` expose `valid`, structured cases, issues and orphan records.
- `is_valid()` returns false for conflicts and missing evidence that prevent a reliable conclusion.

## Compatibility

Supported message versions are listed in [version-scope-and-cases.md](version-scope-and-cases.md). This project is not a substitute for complete ISO 20022 XSD validation or bank-specific implementation-guide validation.
