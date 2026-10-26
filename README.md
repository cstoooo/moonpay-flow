![CI](https://github.com/cstoooo/moonpay-flow/actions/workflows/ci.yml/badge.svg)

# MoonPay Flow

MoonBit ISO 20022 payment lifecycle validator and reconciliation toolkit.

## Implementation

- Project-local XML pull reader in `xml_reader.mbt`
- Project-local fixed-point decimal module in `decimal.mbt`
- Flat XML field extractor in `flat_xml.mbt`
- Multi-message validation in `message.mbt`
- Payment reconciliation in `reconcile.mbt`
- Multi-report payment status timeline in `status_timeline.mbt`
- Bank statement balance and duplicate audit in `statement_audit.mbt`
- Per-account statement portfolio audit in `statement_portfolio.mbt`
- Cross-period refund and reversal ledger in `return_ledger.mbt`
- File input through `moonbitlang/x/fs`
- CLI in `cmd/main`
- 112 unit tests and 25 fixture messages

## Status

Version: 0.8.0

Current support: `pain.001`, `pain.002`, `pacs.008`, `pacs.002` and `camt.053`.

## Run

```bash
scripts/check.sh

# Or run the commands directly:
moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
moon run cmd/main -- --format json fixtures/valid_pain001.xml
moon run cmd/main -- --format markdown fixtures/invalid_pain001.xml
moon run cmd/main -- fixtures/valid_pain002.xml
moon run cmd/main -- fixtures/valid_camt053.xml
moon run cmd/main -- reconcile fixtures/valid_pain001.xml fixtures/valid_pain002.xml
moon run cmd/main -- --list-rules
moon run cmd/main -- lifecycle fixtures/lifecycle_pain001.xml fixtures/lifecycle_pain002.xml fixtures/lifecycle_camt053.xml
moon run cmd/main -- audit fixtures/balanced_camt053.xml
moon run cmd/main -- audit fixtures/balance_mismatch_camt053.xml --format json
moon run cmd/main -- audit fixtures/duplicate_camt053.xml --format markdown
moon run cmd/main -- audit-portfolio fixtures/multi_account_camt053.xml
moon run cmd/main -- timeline fixtures/timeline_pain001.xml fixtures/timeline_status_1.xml fixtures/timeline_status_2.xml
moon run cmd/main -- return-ledger fixtures/returns_pain001.xml fixtures/returns_day1.xml fixtures/returns_day2_partial.xml fixtures/returns_day3_final.xml fixtures/returns_day4_refund_reversal.xml
```

## Rules

- Message ID is required.
- Creation date time is required.
- At least one payment instruction is required.
- Payment instruction ID is required.
- Requested execution date is required.
- End-to-end ID is required, must not exceed 35 characters and must be unique.
- Payment instruction ID must not exceed 35 characters and must be unique.
- Instructed amount and currency are required.
- `NbOfTxs` must be an unsigned integer and match the parsed transaction count.
- Date, datetime, currency and amount formats are checked.
- Payment method and charge bearer values are checked.
- IBAN checksum and BIC format are checked when present.
- `CtrlSum` must match the sum of instructed amounts when present.
- Status reports validate `OrgnlEndToEndId`, `TxSts` and duplicate status entries.
- `pacs.008` validates end-to-end IDs, settlement amounts and currencies.
- `camt.053` validates statement entries, amounts and currencies.
- `reconcile` matches `pain.001` transactions with status report entries.
- `camt.053` validates the `CdtDbtInd` credit/debit indicator.
- `--list-rules` prints the rule catalog with codes and descriptions.
- `lifecycle` classifies payment state across initiation, status and statement messages, including account ownership, debit/credit direction, refunds, reversals and net posted amount.
- `audit` verifies that closing balance equals opening balance plus credits minus debits.
- Balance audit accepts `OPBD`/`PRCD` and `CLBD`/`ITBD`, checks balance currency and statement account scope, and reports the exact closing difference.
- Exact duplicate statement entries are grouped by account, end-to-end ID, amount, currency, direction and reversal flag.
- `audit` emits text, JSON or Markdown and keeps all monetary values as fixed-point strings.
- `audit-portfolio` groups entries and balances by both `Stmt/Id` and account IBAN, so one camt.053 file can contain multiple statements.
- `timeline` merges any number of `pain.002` / `pacs.002` reports in chronological order and supports `pain.001` or `pacs.008` as the payment source.
- Status timelines detect duplicate message IDs, duplicate events, same-time conflicting states, rejected/settled status regression, unknown status codes, orphan statuses, and original amount/currency mismatches.
- The rule catalog contains 82 queryable checks through `--list-rules`.
- `return-ledger` links each reversal to a prior payment or refund using `OrgnlNtryRef`, `OrgnlTxId`, `UETR`, or a unique amount/currency/direction candidate.
- Refund and reversal states are only finalized when the original payment posting is present in the provided statement history.
- If the original posting is outside the supplied periods or a reversal target is ambiguous, the result is `EVIDENCE_INCOMPLETE` or `CONFLICT`; `postedPayment`, `effectiveRefund` and `remaining` are not guessed from net amount.
- Cross-day partial returns, final refunds and refund reversals are covered by fixed fixtures and the `return-ledger` CLI.
- Version boundaries and feature examples are documented in `docs/version-scope-and-cases.md`, `docs/statement-audit-cases.md`, `docs/status-timeline-cases.md`, `docs/multi-account-audit.md` and `docs/return-ledger-cases.md`.

## License

Apache-2.0

## Project description

See [docs/proposal.md](docs/proposal.md).
