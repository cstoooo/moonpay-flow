///|
fn ledger_statement_xml(
  statement_id : String,
  booking_date : String,
  entry_reference : String,
  direction : String,
  amount : String,
  currency : String,
  end_to_end_id : String,
  reversal : Bool,
  original_reference : String,
  account_iban : String,
) -> String {
  "<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:camt.053.001.08\"><BkToCstmrStmt>" +
  "<GrpHdr><MsgId>" +
  statement_id +
  "</MsgId><CreDtTm>" +
  booking_date +
  "T18:00:00Z</CreDtTm></GrpHdr>" +
  "<Stmt><Id>" +
  statement_id +
  "</Id><Acct><Id><IBAN>" +
  account_iban +
  "</IBAN></Id></Acct><Ntry><NtryRef>" +
  entry_reference +
  "</NtryRef>" +
  (if original_reference == "" {
    ""
  } else {
    "<OrgnlNtryRef>" + original_reference + "</OrgnlNtryRef>"
  }) +
  "<BookgDt><Dt>" +
  booking_date +
  "</Dt></BookgDt>" +
  (if reversal { "<RvslInd>true</RvslInd>" } else { "" }) +
  "<CdtDbtInd>" +
  direction +
  "</CdtDbtInd><Amt Ccy=\"" +
  currency +
  "\">" +
  amount +
  "</Amt><NtryDtls><TxDtls><Refs><EndToEndId>" +
  end_to_end_id +
  "</EndToEndId></Refs></TxDtls></NtryDtls></Ntry></Stmt></BkToCstmrStmt></Document>"
}

///|
test "return ledger classifies cross-day partial return" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let day2 = @fs.read_file_to_string("fixtures/returns_day2_partial.xml")
  let report = @moonpay_flow.return_ledger_report(pain, [day1, day2])
  assert_eq(report.cases.length(), 1)
  let case = report.cases[0]
  assert_eq(case.state.name(), "PARTIALLY_RETURNED")
  assert_eq(case.posted_payment.unwrap().to_string(), "100.00")
  assert_eq(case.effective_refund.unwrap().to_string(), "20.00")
  assert_eq(case.remaining.unwrap().to_string(), "80.00")
  assert_true(case.crossed_period)
  assert_true(report.is_valid())
}

///|
test "return ledger classifies final cross-day refund as fully returned" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let day2 = @fs.read_file_to_string("fixtures/returns_day2_partial.xml")
  let day3 = @fs.read_file_to_string("fixtures/returns_day3_final.xml")
  let report = @moonpay_flow.return_ledger_report(pain, [day1, day2, day3])
  assert_eq(report.cases[0].state.name(), "FULLY_RETURNED")
  assert_eq(report.cases[0].effective_refund.unwrap().to_string(), "100.00")
  assert_eq(report.cases[0].remaining.unwrap().to_string(), "0.00")
  assert_true(report.is_valid())
}

///|
test "return ledger applies explicit refund reversal" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let day2 = @fs.read_file_to_string("fixtures/returns_day2_partial.xml")
  let day3 = @fs.read_file_to_string("fixtures/returns_day3_final.xml")
  let day4 = @fs.read_file_to_string("fixtures/returns_day4_refund_reversal.xml")
  let report = @moonpay_flow.return_ledger_report(pain, [day1, day2, day3, day4])
  let case = report.cases[0]
  assert_eq(case.state.name(), "PARTIALLY_RETURNED")
  assert_eq(case.effective_refund.unwrap().to_string(), "20.00")
  assert_eq(case.remaining.unwrap().to_string(), "80.00")
  assert_true(report.to_json().contains("REFUND_REVERSAL_APPLIED"))
  let reversal = case.legs[3]
  assert_eq(reversal.kind.name(), "REVERSAL_OF_REFUND")
  assert_eq(reversal.link_quality.name(), "EXPLICIT")
  assert_eq(reversal.linked_to.unwrap(), "RET-80")
}

///|
test "return ledger refuses to infer state from incomplete history" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day2 = @fs.read_file_to_string("fixtures/returns_day2_partial.xml")
  let report = @moonpay_flow.return_ledger_report(pain, [day2])
  let case = report.cases[0]
  assert_eq(case.state.name(), "EVIDENCE_INCOMPLETE")
  assert_true(case.remaining is None)
  assert_true(case.posted_payment is None)
  assert_true(report.to_json().contains("RETURN_HISTORY_INCOMPLETE"))
  assert_false(report.is_valid())
}

///|
test "return ledger classifies explicit payment reversal" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let reversal = ledger_statement_xml(
    "REV-PAY",
    "2026-10-02",
    "REV-PAY-100",
    "CRDT",
    "100.00",
    "EUR",
    "TX-RET",
    true,
    "PAY-100",
    "DE89370400440532013000",
  )
  let report = @moonpay_flow.return_ledger_report(pain, [day1, reversal])
  let case = report.cases[0]
  assert_eq(case.state.name(), "PAYMENT_REVERSED")
  assert_eq(case.posted_payment.unwrap().to_string(), "0.00")
  assert_eq(case.remaining.unwrap().to_string(), "0.00")
  assert_true(report.to_json().contains("PAYMENT_REVERSAL_APPLIED"))
}

///|
test "return ledger infers a unique reversal target without explicit reference" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let refund = ledger_statement_xml(
    "REF-20",
    "2026-10-02",
    "REF-20",
    "CRDT",
    "20.00",
    "EUR",
    "TX-RET",
    false,
    "",
    "DE89370400440532013000",
  )
  let reversal = ledger_statement_xml(
    "REV-REF-20",
    "2026-10-03",
    "REV-REF-20",
    "DBIT",
    "20.00",
    "EUR",
    "TX-RET",
    true,
    "",
    "DE89370400440532013000",
  )
  let report = @moonpay_flow.return_ledger_report(pain, [day1, refund, reversal])
  let case = report.cases[0]
  assert_eq(case.state.name(), "PAID")
  assert_eq(case.effective_refund.unwrap().to_string(), "0.00")
  assert_eq(case.legs[2].link_quality.name(), "INFERRED_UNIQUE")
}

///|
test "return ledger rejects ambiguous reversal targets" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let refund1 = ledger_statement_xml(
    "REF-A",
    "2026-10-02",
    "REF-A",
    "CRDT",
    "20.00",
    "EUR",
    "TX-RET",
    false,
    "",
    "DE89370400440532013000",
  )
  let refund2 = ledger_statement_xml(
    "REF-B",
    "2026-10-03",
    "REF-B",
    "CRDT",
    "20.00",
    "EUR",
    "TX-RET",
    false,
    "",
    "DE89370400440532013000",
  )
  let reversal = ledger_statement_xml(
    "REV-AMB",
    "2026-10-04",
    "REV-AMB",
    "DBIT",
    "20.00",
    "EUR",
    "TX-RET",
    true,
    "",
    "DE89370400440532013000",
  )
  let report = @moonpay_flow.return_ledger_report(pain, [day1, refund1, refund2, reversal])
  assert_eq(report.cases[0].state.name(), "CONFLICT")
  assert_true(report.to_json().contains("REVERSAL_TARGET_AMBIGUOUS"))
  assert_eq(report.cases[0].legs[3].link_quality.name(), "AMBIGUOUS")
}

///|
test "return ledger reports incomplete payment posting amount" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let partial_posting = ledger_statement_xml(
    "PARTIAL-PAY",
    "2026-10-01",
    "PAY-90",
    "DBIT",
    "90.00",
    "EUR",
    "TX-RET",
    false,
    "",
    "DE89370400440532013000",
  )
  let report = @moonpay_flow.return_ledger_report(pain, [partial_posting])
  assert_eq(report.cases[0].state.name(), "EVIDENCE_INCOMPLETE")
  assert_true(report.to_json().contains("PAYMENT_POSTING_INCOMPLETE"))
}

///|
test "return ledger detects refund overpayment" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let refund = ledger_statement_xml(
    "OVER-REFUND",
    "2026-10-02",
    "OVER-REFUND",
    "CRDT",
    "130.00",
    "EUR",
    "TX-RET",
    false,
    "",
    "DE89370400440532013000",
  )
  let report = @moonpay_flow.return_ledger_report(pain, [day1, refund])
  assert_eq(report.cases[0].state.name(), "CONFLICT")
  assert_true(report.to_json().contains("REFUND_OVERPAYMENT"))
}

///|
test "return ledger handles creditor statement direction" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let receipt = ledger_statement_xml(
    "CREDITOR-RECEIPT",
    "2026-10-01",
    "RECEIPT-100",
    "CRDT",
    "100.00",
    "EUR",
    "TX-RET",
    false,
    "",
    "FR1420041010050500013M02606",
  )
  let refund = ledger_statement_xml(
    "CREDITOR-REFUND",
    "2026-10-02",
    "CREDITOR-REFUND-20",
    "DBIT",
    "20.00",
    "EUR",
    "TX-RET",
    false,
    "",
    "FR1420041010050500013M02606",
  )
  let report = @moonpay_flow.return_ledger_report(pain, [receipt, refund])
  let case = report.cases[0]
  assert_eq(case.account_role, "CREDITOR")
  assert_eq(case.state.name(), "PARTIALLY_RETURNED")
  assert_eq(case.remaining.unwrap().to_string(), "80.00")
}

///|
test "return ledger parses entry references and booking dates" {
  let xml = @fs.read_file_to_string("fixtures/returns_day4_refund_reversal.xml")
  let records = @moonpay_flow.statement_records(xml)
  assert_eq(records.length(), 1)
  assert_eq(records[0].entry_reference.unwrap(), "REV-RET-80")
  assert_eq(records[0].original_entry_reference.unwrap(), "RET-80")
  assert_eq(records[0].booking_date.unwrap(), "2026-10-04")
  assert_true(records[0].reversal)
}

///|
test "return ledger renders reports and identifies orphan entries" {
  let pain = @fs.read_file_to_string("fixtures/returns_pain001.xml")
  let day1 = @fs.read_file_to_string("fixtures/returns_day1.xml")
  let day2 = @fs.read_file_to_string("fixtures/returns_day2_partial.xml")
  let report = @moonpay_flow.return_ledger_report(pain, [day1, day2])
  assert_true(report.to_text().contains("Return and reversal ledger"))
  assert_true(report.to_json().contains("\"state\": \"PARTIALLY_RETURNED\""))
  assert_true(report.to_markdown().contains("| `TX-RET` | 100.00 EUR | `PARTIALLY_RETURNED`"))
  let orphan = ledger_statement_xml(
    "ORPHAN",
    "2026-10-02",
    "ORPHAN-1",
    "CRDT",
    "10.00",
    "EUR",
    "TX-OTHER",
    false,
    "",
    "DE89370400440532013000",
  )
  let orphan_report = @moonpay_flow.return_ledger_report(pain, [orphan])
  assert_eq(orphan_report.orphan_entries.length(), 1)
  assert_false(orphan_report.is_valid())
}
