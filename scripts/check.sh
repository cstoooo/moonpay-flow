#!/usr/bin/env bash
set -euo pipefail

moon check
moon test
moon run cmd/main -- fixtures/valid_pain001.xml
moon run cmd/main -- fixtures/invalid_pain001.xml
moon run cmd/main -- fixtures/invalid_identity_pain001.xml
moon run cmd/main -- fixtures/valid_pain002.xml
moon run cmd/main -- fixtures/valid_pacs008.xml
moon run cmd/main -- fixtures/valid_pacs002.xml
moon run cmd/main -- fixtures/valid_camt053.xml
moon run cmd/main -- reconcile fixtures/valid_pain001.xml fixtures/valid_pain002.xml
moon run cmd/main -- lifecycle fixtures/lifecycle_pain001.xml fixtures/lifecycle_pain002.xml fixtures/lifecycle_camt053.xml
moon run cmd/main -- audit fixtures/balanced_camt053.xml
moon run cmd/main -- audit fixtures/balance_mismatch_camt053.xml
moon run cmd/main -- audit fixtures/duplicate_camt053.xml
moon run cmd/main -- audit-portfolio fixtures/multi_account_camt053.xml
moon run cmd/main -- timeline fixtures/timeline_pain001.xml fixtures/timeline_status_1.xml fixtures/timeline_status_2.xml
moon run cmd/main -- return-ledger fixtures/returns_pain001.xml fixtures/returns_day1.xml fixtures/returns_day2_partial.xml fixtures/returns_day3_final.xml fixtures/returns_day4_refund_reversal.xml
