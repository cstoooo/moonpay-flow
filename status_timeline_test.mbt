///|
fn timeline_status_doc(
  message_id : String,
  creation_datetime : String,
  end_to_end_id : String,
  status : String,
) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
  "<Document xmlns=\"urn:iso:std:iso:20022:tech:xsd:pain.002.001.03\">\n" +
  "  <CstmrPmtStsRpt><GrpHdr><MsgId>" +
  message_id +
  "</MsgId><CreDtTm>" +
  creation_datetime +
  "</CreDtTm></GrpHdr>\n" +
  "    <TxInfAndSts><OrgnlEndToEndId>" +
  end_to_end_id +
  "</OrgnlEndToEndId><TxSts>" +
  status +
  "</TxSts></TxInfAndSts>\n" +
  "  </CstmrPmtStsRpt></Document>"
}

///|
test "status events parse message time and reason code" {
  let xml = @fs.read_file_to_string("fixtures/timeline_status_2.xml")
  let events = @moonpay_flow.status_events(xml)
  assert_eq(events.length(), 2)
  assert_eq(events[0].message_id.unwrap(), "TIMELINE-STATUS-002")
  assert_eq(events[0].creation_datetime.unwrap(), "2026-10-26T10:00:00Z")
  assert_eq(events[1].status, "RJCT")
  assert_eq(events[1].reason_code.unwrap(), "AC01")
  assert_eq(events[0].original_amount.unwrap().to_string(), "100.00")
  assert_eq(events[0].original_currency.unwrap(), "EUR")
}

///|
test "status timeline resolves latest reports and terminal states" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let first = @fs.read_file_to_string("fixtures/timeline_status_1.xml")
  let second = @fs.read_file_to_string("fixtures/timeline_status_2.xml")
  let report = @moonpay_flow.status_timeline_report(pain, [first, second])
  assert_eq(report.message_count, 2)
  assert_eq(report.event_count, 4)
  assert_eq(report.cases.length(), 2)
  let states : Map[String, String] = Map([])
  let latest : Map[String, String] = Map([])
  for case in report.cases {
    states.set(case.end_to_end_id, case.state.name())
    latest.set(case.end_to_end_id, case.latest_status.unwrap())
  }
  assert_eq(states.get("TL-TX-A").unwrap(), "SETTLED")
  assert_eq(states.get("TL-TX-B").unwrap(), "REJECTED")
  assert_eq(latest.get("TL-TX-A").unwrap(), "ACSC")
  assert_eq(latest.get("TL-TX-B").unwrap(), "RJCT")
  assert_true(report.is_valid())
}

///|
test "status timeline reports awaiting and in-progress states" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let awaiting = @moonpay_flow.status_timeline_report(pain, [])
  assert_eq(awaiting.cases[0].state.name(), "AWAITING_STATUS")
  let pending = timeline_status_doc("M-P", "2026-10-26T09:00:00Z", "TL-TX-A", "PDNG")
  let in_progress = @moonpay_flow.status_timeline_report(pain, [pending])
  assert_eq(in_progress.cases[0].state.name(), "IN_PROGRESS")
  assert_eq(in_progress.cases[1].state.name(), "AWAITING_STATUS")
}

///|
test "status timeline detects terminal regression" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let settled = timeline_status_doc("M-1", "2026-10-26T09:00:00Z", "TL-TX-A", "ACSC")
  let pending = timeline_status_doc("M-2", "2026-10-26T10:00:00Z", "TL-TX-A", "PDNG")
  let report = @moonpay_flow.status_timeline_report(pain, [pending, settled])
  assert_eq(report.cases[0].state.name(), "STATUS_CONFLICT")
  assert_true(report.to_json().contains("TERMINAL_STATUS_REGRESSION"))
  assert_false(report.is_valid())
}

///|
test "status timeline detects conflicting statuses at the same time" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let accepted = timeline_status_doc("M-A", "2026-10-26T09:00:00Z", "TL-TX-A", "ACSC")
  let rejected = timeline_status_doc("M-B", "2026-10-26T09:00:00Z", "TL-TX-A", "RJCT")
  let report = @moonpay_flow.status_timeline_report(pain, [accepted, rejected])
  assert_eq(report.cases[0].state.name(), "STATUS_CONFLICT")
  assert_true(report.to_json().contains("STATUS_TIMELINE_CONFLICT"))
}

///|
test "status timeline warns on duplicated event without invalidating settlement" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let settled = timeline_status_doc("M-DUP", "2026-10-26T09:00:00Z", "TL-TX-A", "ACSC")
  let report = @moonpay_flow.status_timeline_report(pain, [settled, settled])
  assert_eq(report.cases[0].state.name(), "SETTLED")
  assert_true(report.to_json().contains("STATUS_EVENT_DUPLICATE"))
  assert_true(report.to_json().contains("STATUS_MESSAGE_ID_DUPLICATE"))
  assert_false(report.is_valid())
}

///|
test "status timeline reports unknown status codes" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let unknown = timeline_status_doc("M-U", "2026-10-26T09:00:00Z", "TL-TX-A", "MYSTERY")
  let report = @moonpay_flow.status_timeline_report(pain, [unknown])
  assert_eq(report.cases[0].state.name(), "UNKNOWN_STATUS")
  assert_true(report.to_json().contains("STATUS_CODE_INVALID"))
  assert_false(report.is_valid())
}

///|
test "status timeline separates statuses without payment" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let orphan = timeline_status_doc("M-ORPHAN", "2026-10-26T09:00:00Z", "TL-ORPHAN", "PDNG")
  let report = @moonpay_flow.status_timeline_report(pain, [orphan])
  assert_eq(report.orphan_status_ids.length(), 1)
  assert_eq(report.orphan_status_ids[0], "TL-ORPHAN")
  assert_false(report.is_valid())
}

///|
test "status timeline sorts reports supplied out of order" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let early = timeline_status_doc("M-EARLY", "2026-10-26T09:00:00Z", "TL-TX-A", "PDNG")
  let late = timeline_status_doc("M-LATE", "2026-10-26T11:00:00Z", "TL-TX-A", "ACSC")
  let report = @moonpay_flow.status_timeline_report(pain, [late, early])
  assert_eq(report.cases[0].events[0].status, "PDNG")
  assert_eq(report.cases[0].events[1].status, "ACSC")
  assert_eq(report.cases[0].state.name(), "SETTLED")
}

///|
test "status timeline renders text JSON and Markdown" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let first = @fs.read_file_to_string("fixtures/timeline_status_1.xml")
  let second = @fs.read_file_to_string("fixtures/timeline_status_2.xml")
  let report = @moonpay_flow.status_timeline_report(pain, [first, second])
  assert_true(report.to_text().contains("Payment status timeline"))
  assert_true(report.to_json().contains("\"state\": \"SETTLED\""))
  assert_true(report.to_markdown().contains("| `TL-TX-A` | 100.00 EUR | ACSC | `SETTLED` | 2 | 0 |"))
}

///|
test "status timeline accepts pacs.002 transaction status" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.002.001.10">
  #|  <FIToFIPmtStsRpt>
  #|    <GrpHdr><MsgId>PACS-STATUS-1</MsgId><CreDtTm>2026-10-26T12:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TL-TX-A</OrgnlEndToEndId><TxSts>ACSC</TxSts></TxInfAndSts>
  #|  </FIToFIPmtStsRpt>
  #|</Document>
  let report = @moonpay_flow.status_timeline_report(pain, [xml])
  assert_eq(report.cases[0].latest_status.unwrap(), "ACSC")
  assert_eq(report.cases[0].state.name(), "SETTLED")
}

///|
test "status timeline accepts pacs.008 as payment source" {
  let payment = @fs.read_file_to_string("fixtures/timeline_pacs008.xml")
  let status = timeline_status_doc("M-PACS", "2026-10-26T09:00:00Z", "TL-PACS-A", "ACSC")
  let report = @moonpay_flow.status_timeline_report(payment, [status])
  assert_eq(report.cases.length(), 1)
  assert_eq(report.cases[0].amount.to_string(), "125.00")
  assert_eq(report.cases[0].currency, "EUR")
  assert_eq(report.cases[0].state.name(), "SETTLED")
}

///|
test "status timeline reports missing metadata and empty report" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr></GrpHdr></CstmrPmtStsRpt>
  #|</Document>
  let report = @moonpay_flow.status_timeline_report(pain, [xml])
  assert_true(report.to_json().contains("STATUS_REPORT_ID_MISSING"))
  assert_true(report.to_json().contains("STATUS_REPORT_TIME_MISSING"))
  assert_true(report.to_json().contains("STATUS_REPORT_EMPTY"))
  assert_false(report.is_valid())
}

///|
test "status timeline detects duplicate message IDs across reports" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let first = timeline_status_doc("SAME-MESSAGE", "2026-10-26T09:00:00Z", "TL-TX-A", "PDNG")
  let second = timeline_status_doc("SAME-MESSAGE", "2026-10-26T10:00:00Z", "TL-TX-A", "ACSC")
  let report = @moonpay_flow.status_timeline_report(pain, [first, second])
  assert_true(report.to_json().contains("STATUS_MESSAGE_ID_DUPLICATE"))
  assert_false(report.is_valid())
}

///|
test "status event parser ignores incomplete transaction entries" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>M-INCOMPLETE</MsgId><CreDtTm>2026-10-26T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>ONLY-ID</OrgnlEndToEndId></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let events = @moonpay_flow.status_events(xml)
  assert_eq(events.length(), 0)
}

///|
test "pacs008 payment records support multiple transactions" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
  #|  <FIToFICstmrCdtTrf><GrpHdr><MsgId>PACS-MULTI</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|    <CdtTrfTxInf><PmtId><EndToEndId>P-A</EndToEndId></PmtId><IntrBkSttlmAmt Ccy="EUR">10.00</IntrBkSttlmAmt></CdtTrfTxInf>
  #|    <CdtTrfTxInf><PmtId><EndToEndId>P-B</EndToEndId></PmtId><IntrBkSttlmAmt Ccy="USD">20.00</IntrBkSttlmAmt></CdtTrfTxInf>
  #|  </FIToFICstmrCdtTrf>
  #|</Document>
  let records = @moonpay_flow.pacs008_payment_records(xml)
  assert_eq(records.length(), 2)
  assert_eq(records[0].end_to_end_id, "P-A")
  assert_eq(records[1].currency, "USD")
  assert_eq(records[1].amount.to_string(), "20.00")
}

///|
test "payment records auto rejects unsupported sources without inventing payments" {
  let xml = @fs.read_file_to_string("fixtures/valid_camt053.xml")
  let records = @moonpay_flow.payment_records_auto(xml)
  assert_eq(records.length(), 0)
}

///|
test "status timeline prioritizes conflict when unknown and regression coexist" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let settled = timeline_status_doc("C-1", "2026-10-26T09:00:00Z", "TL-TX-A", "ACSC")
  let unknown = timeline_status_doc("C-2", "2026-10-26T10:00:00Z", "TL-TX-A", "MYSTERY")
  let report = @moonpay_flow.status_timeline_report(pain, [settled, unknown])
  assert_eq(report.cases[0].state.name(), "STATUS_CONFLICT")
  assert_true(report.to_json().contains("TERMINAL_STATUS_REGRESSION"))
  assert_true(report.to_json().contains("STATUS_CODE_INVALID"))
}

///|
test "status timeline detects original amount mismatch" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>M-AMOUNT</MsgId><CreDtTm>2026-10-26T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TL-TX-A</OrgnlEndToEndId><OrgnlInstdAmt Ccy="EUR">99.00</OrgnlInstdAmt><TxSts>ACSC</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @moonpay_flow.status_timeline_report(pain, [xml])
  assert_eq(report.cases[0].state.name(), "STATUS_CONFLICT")
  assert_true(report.to_json().contains("STATUS_AMOUNT_MISMATCH"))
  assert_false(report.is_valid())
}

///|
test "status timeline detects original currency mismatch" {
  let pain = @fs.read_file_to_string("fixtures/timeline_pain001.xml")
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.002.001.03">
  #|  <CstmrPmtStsRpt><GrpHdr><MsgId>M-CCY</MsgId><CreDtTm>2026-10-26T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TL-TX-A</OrgnlEndToEndId><OrgnlInstdAmt Ccy="USD">100.00</OrgnlInstdAmt><TxSts>ACSC</TxSts></TxInfAndSts>
  #|  </CstmrPmtStsRpt>
  #|</Document>
  let report = @moonpay_flow.status_timeline_report(pain, [xml])
  assert_eq(report.cases[0].state.name(), "STATUS_CONFLICT")
  assert_true(report.to_json().contains("STATUS_CURRENCY_MISMATCH"))
}

///|
test "status events parse pacs002 settlement amount" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.002.001.10">
  #|  <FIToFIPmtStsRpt><GrpHdr><MsgId>P-AMOUNT</MsgId><CreDtTm>2026-10-26T09:00:00Z</CreDtTm></GrpHdr>
  #|    <TxInfAndSts><OrgnlEndToEndId>TL-TX-A</OrgnlEndToEndId><OrgnlIntrBkSttlmAmt Ccy="EUR">100.00</OrgnlIntrBkSttlmAmt><TxSts>ACSC</TxSts></TxInfAndSts>
  #|  </FIToFIPmtStsRpt>
  #|</Document>
  let events = @moonpay_flow.status_events(xml)
  assert_eq(events.length(), 1)
  assert_eq(events[0].original_amount.unwrap().to_string(), "100.00")
  assert_eq(events[0].original_currency.unwrap(), "EUR")
}
