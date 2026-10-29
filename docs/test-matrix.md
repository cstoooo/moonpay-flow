# Test Matrix

## Summary

- Total tests: 112
- Fixed XML fixtures: 25
- Queryable rules: 82
- Full verification: `scripts/check.sh`

## Test distribution

| Area | File | Tests |
| --- | --- | ---: |
| XML reader | `xml_reader_test.mbt` | 4 |
| XML edge cases | `xml_reader_edge_test.mbt` | 5 |
| Decimal | `decimal_test.mbt` | 3 |
| Decimal edge cases | `decimal_edge_test.mbt` | 2 |
| `pain.001` validation | `validation_test.mbt` | 6 |
| Validation edge cases | `validation_edge_test.mbt` | 5 |
| Pain summary | `pain001_test.mbt` | 1 |
| Multi-message validation | `message_test.mbt` | 3 |
| Multi-message edge cases | `message_edge_test.mbt` | 7 |
| Reconciliation | `reconcile_test.mbt` | 2 |
| Reconciliation edge cases | `reconcile_edge_test.mbt` | 2 |
| Lifecycle | `lifecycle_test.mbt` | 3 |
| Statement balance audit | `statement_audit_test.mbt` | 18 |
| Statement portfolio | `statement_portfolio_test.mbt` | 12 |
| Status timeline | `status_timeline_test.mbt` | 21 |
| Return ledger | `return_ledger_test.mbt` | 12 |
| Rule catalog | `rules_test.mbt` | 1 |
| Fixture integration | `fixture_integration_test.mbt` | 1 |
| Property tests | `property_test.mbt` | 3 |
| Version marker | `version_test.mbt` | 1 |

## Behavior coverage

### Validation

- Required fields and identifier length
- Date, datetime, currency and amount formats
- IBAN checksum and BIC format
- `NbOfTxs` and `CtrlSum`
- Duplicate identifiers
- Message-type detection

### Reconciliation and lifecycle

- Payment/status matching
- Missing status and orphan status
- Missing payment and orphan statement entries
- Account ownership and normal debit/credit direction
- Partial and full refunds
- Refund reversals
- Incomplete-history boundaries

### Statement audit

- Opening/closing balance reconciliation
- Debit/credit movement totals
- Currency and account consistency
- Exact duplicate entries
- Multiple `Stmt` and account scopes
- Balance-only statements and missing balances

### Status timelines

- Chronological merge
- Pending, settled and rejected outcomes
- Duplicate status messages/events
- Same-time conflicts
- Terminal status regression
- Unknown statuses and orphan statuses
- Original amount/currency mismatch

### Return ledger

- Cross-day partial return
- Final refund completing a full return
- Refund reversal restoring the remaining refundable amount
- Payment reversal
- Explicit, inferred and ambiguous reversal links
- Incomplete original posting
- Refund overpayment
- Debtor and creditor statement directions
- Orphan statement entries

## CI

GitHub Actions runs:

```text
moon update
./scripts/check.sh
```

The script executes `moon check`, `moon test`, validation examples, reconciliation, lifecycle, balance audit, multi-account audit, status timeline and return-ledger examples.
