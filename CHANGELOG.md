# Changelog

All notable changes are documented here. The project follows semantic versioning for its public MoonBit API.

## 0.8.2

- Align README, Mooncakes documentation and GitHub CI descriptions.
- No code or API changes.

## 0.8.1

- Add a complete acceptance-oriented README with installation, CLI, library API, architecture, quality and limitation information.
- Add `docs/usage.md`, `docs/architecture.md`, `docs/test-matrix.md` and `docs/acceptance-checklist.md`.
- Add contribution, security, third-party notice and changelog files.
- Clarify that fixtures are synthetic and contain no customer data.
- No behavior-breaking changes.

## 0.8.0

- Add the cross-period refund and reversal ledger.
- Parse entry references, booking dates, transaction IDs, UETR and original entry references.
- Link reversal entries to prior payment or refund entries with explicit and inferred matching.
- Add evidence-completeness states and prevent net-amount guessing when history is incomplete.
- Add cross-day partial return, final refund, refund reversal, payment reversal, ambiguous target and over-refund cases.
- Add the `return-ledger` CLI command.

## 0.7.0

- Add multi-report payment status timelines for `pain.002` and `pacs.002`.
- Support `pain.001` and `pacs.008` as payment sources.
- Detect duplicate status messages/events, terminal regressions, same-time conflicts and amount/currency mismatches.
- Add per-`Stmt`, per-account `camt.053` portfolio auditing.
- Add `timeline` and `audit-portfolio` CLI commands.

## 0.6.1

- Add `camt.053` opening/closing balance reconciliation.
- Add credit/debit movement totals, closing difference and balance status.
- Add exact duplicate statement entry detection.
- Add the `audit` CLI command and balance audit examples.

## 0.6.0

- Rename the module to `cstoooo/moonpay_flow`.
- Add account ownership, debit/credit direction, refund, reversal and net posting analysis.
- Add lifecycle classification across payment, status and statement data.

## Earlier versions

- Add ISO 20022 message detection and validation.
- Add `pain.001`, `pain.002`, `pacs.008`, `pacs.002` and `camt.053` parsing.
- Add the project-local XML pull reader and fixed-point decimal module.
- Add text, JSON and Markdown reports.
- Add the queryable rule catalog and CI checks.
