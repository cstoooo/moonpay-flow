# Architecture

## Goals

MoonPay Flow provides a MoonBit-native toolkit for validating ISO 20022 messages and connecting payment intent, status notifications and bank postings without hiding uncertainty.

## Module map

| Layer | Module | Responsibility |
| --- | --- | --- |
| XML | `xml_reader.mbt` | Project-local pull parser with entity, CDATA, comment and error handling |
| XML | `flat_xml.mbt` | Path-based field extraction helpers |
| Numeric | `decimal.mbt` | Fixed-point decimal parsing, addition, subtraction and comparison |
| Validation | `validation.mbt` | `pain.001` business rules and diagnostics |
| Validation | `message.mbt` | Message detection and common validation entry point |
| Reconciliation | `reconcile.mbt` | Payment/status matching and payment record parsing |
| Lifecycle | `lifecycle.mbt` | Compact payment lifecycle summary and statement entry parsing |
| Status | `status_timeline.mbt` | Multi-report chronology, terminal state and conflict detection |
| Statement | `statement_audit.mbt` | Balance, movement and exact duplicate audit |
| Statement | `statement_portfolio.mbt` | Per-`Stmt`, per-account audit |
| Returns | `return_ledger.mbt` | Directed refund/reversal graph and evidence completeness |
| Rules | `rules.mbt` | Queryable diagnostic catalog |
| CLI | `cmd/main` | File input and report rendering |

## Data flow

```text
ISO 20022 XML
    -> XML pull events / flat fields
    -> validation and typed records
    -> reconciliation, timeline, statement audit or return ledger
    -> text / JSON / Markdown report
```

## Core invariants

1. XML parsing and decimal arithmetic are implemented inside the project rather than delegated to another language runtime.
2. JSON monetary values are serialized as fixed-point strings.
3. A reversal is linked only by explicit references or a unique compatible candidate.
4. Ambiguous reversal targets are never resolved arbitrarily.
5. Refund conclusions require a complete observed original payment posting.
6. Incomplete history produces `EVIDENCE_INCOMPLETE` rather than a guessed partial/full state.
7. Duplicate statement detection is scoped by statement/account identity.
8. Multi-account results never combine balances or movements across accounts.

## Return ledger

The return ledger classifies legs as:

- `ORIGINAL_PAYMENT`
- `REFUND_CREDIT`
- `REVERSAL_OF_PAYMENT`
- `REVERSAL_OF_REFUND`
- `UNLINKED_REVERSAL`

Matching order:

```text
OrgnlNtryRef -> OrgnlTxId -> UETR -> unique amount/currency/opposite-direction candidate
```

The effective position is:

```text
effective payment = observed payment - reversed payment
effective refund  = observed refund  - reversed refund
remaining         = effective payment - effective refund
```

If the observed payment does not equal the declared payment amount, the effective position is not finalized.

## Error model

- Validation diagnostics use stable codes from `rule_catalog()`.
- Structured reports keep all cases and issues instead of returning only the first failure.
- `is_valid()` is suitable for automated gates.
- User-facing text reports include actions for operational handling.

## Scale boundaries

- Current `camt.053` support is for `camt.053.001.08` common fields.
- The project does not implement complete XSD validation, full bank-specific implementation guides, interest calculation or every ISO 20022 variant.
- `lifecycle` remains a compact summary API. `return-ledger` is the authoritative API for refund/reversal conclusions.
