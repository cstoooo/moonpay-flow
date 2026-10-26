///|
test "statement portfolio audits every statement independently" {
  let xml = @fs.read_file_to_string("fixtures/multi_account_camt053.xml")
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_true(report.is_valid())
  assert_eq(report.message_id.unwrap(), "CAMT-MULTI-001")
  assert_eq(report.statements.length(), 2)
  assert_eq(report.statements[0].statement_id.unwrap(), "STMT-DEBTOR")
  assert_eq(report.statements[1].statement_id.unwrap(), "STMT-CREDITOR")
  assert_eq(report.statements[0].account_iban.unwrap(), "DE89370400440532013000")
  assert_eq(report.statements[1].account_iban.unwrap(), "FR1420041010050500013M02606")
  assert_eq(report.statements[0].balance_status.name(), "BALANCED")
  assert_eq(report.statements[1].balance_status.name(), "BALANCED")
}

///|
test "statement portfolio keeps account-specific totals" {
  let xml = @fs.read_file_to_string("fixtures/multi_account_camt053.xml")
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_eq(report.statements[0].total_credits.to_string(), "250.00")
  assert_eq(report.statements[0].total_debits.to_string(), "100.00")
  assert_eq(report.statements[0].net_movement.to_string(), "150.00")
  assert_eq(report.statements[1].total_credits.to_string(), "0.00")
  assert_eq(report.statements[1].total_debits.to_string(), "50.00")
  assert_eq(report.statements[1].net_movement.to_string(), "-50.00")
}

///|
test "statement portfolio detects mismatch only in the affected statement" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>MULTI-BAD</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>A</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
  #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|    <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>A1</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">10.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|  </Stmt>
  #|  <Stmt><Id>B</Id><Acct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></Acct>
  #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|    <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>B1</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">99.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|  </Stmt>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_false(report.is_valid())
  assert_eq(report.statements[0].balance_status.name(), "BALANCED")
  assert_eq(report.statements[1].balance_status.name(), "MISMATCH")
  assert_eq(report.statements[1].closing_difference.unwrap().to_string(), "89.00")
}

///|
test "statement portfolio scopes duplicate detection by statement and account" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>MULTI-DUP-SCOPE</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>A</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
  #|    <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>SHARED-ID</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|  </Stmt>
  #|  <Stmt><Id>B</Id><Acct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></Acct>
  #|    <Ntry><CdtDbtInd>CRDT</CdtDbtInd><Amt Ccy="EUR">10.00</Amt><NtryDtls><TxDtls><Refs><EndToEndId>SHARED-ID</EndToEndId></Refs></TxDtls></NtryDtls></Ntry>
  #|  </Stmt>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_eq(report.statements.length(), 2)
  assert_eq(report.statements[0].duplicate_entries.length(), 0)
  assert_eq(report.statements[1].duplicate_entries.length(), 0)
}

///|
test "statement portfolio reports duplicate statement IDs" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>MULTI-DUP-ID</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>DUP-STMT</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct></Stmt>
  #|  <Stmt><Id>DUP-STMT</Id><Acct><Id><IBAN>FR1420041010050500013M02606</IBAN></Id></Acct></Stmt>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_true(report.to_json().contains("STATEMENT_ID_DUPLICATE"))
  assert_false(report.is_valid())
}

///|
test "statement portfolio renders text JSON and Markdown" {
  let xml = @fs.read_file_to_string("fixtures/multi_account_camt053.xml")
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_true(report.to_text().contains("Bank statement portfolio audit"))
  assert_true(report.to_json().contains("\"statementCount\": 2"))
  assert_true(report.to_json().contains("\"statementId\": \"STMT-DEBTOR\""))
  assert_true(report.to_markdown().contains("# Bank statement portfolio audit"))
}

///|
test "single statement audit reports statement identifier" {
  let xml = @fs.read_file_to_string("fixtures/balanced_camt053.xml")
  let report = @moonpay_flow.statement_audit(xml)
  assert_eq(report.statement_id.unwrap(), "STMT-BAL-001")
  assert_true(report.to_json().contains("\"statementId\": \"STMT-BAL-001\""))
}

///|
test "statement portfolio detects duplicate entries inside one statement" {
  let xml = @fs.read_file_to_string("fixtures/duplicate_camt053.xml")
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_eq(report.statements.length(), 1)
  assert_eq(report.statements[0].duplicate_entries.length(), 1)
  assert_eq(report.statements[0].duplicate_entries[0].occurrences, 2)
  assert_false(report.is_valid())
}

///|
test "statement portfolio audits a balance-only statement" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>BALANCE-ONLY</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>BAL-ONLY</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
  #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">10.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">10.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|  </Stmt>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_eq(report.statements.length(), 1)
  assert_eq(report.statements[0].entry_count, 0)
  assert_eq(report.statements[0].balance_status.name(), "BALANCED")
  assert_true(report.is_valid())
}

///|
test "statement portfolio reports missing account in the affected statement" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>NO-ACCOUNT</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>NO-ACCOUNT-STMT</Id>
  #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|  </Stmt>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_true(report.to_json().contains("STATEMENT_ACCOUNT_MISSING"))
  assert_false(report.is_valid())
}

///|
test "statement portfolio keeps separate Stmt with the same account" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>SAME-ACCOUNT</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|  <Stmt><Id>PERIOD-1</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
  #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|  </Stmt>
  #|  <Stmt><Id>PERIOD-2</Id><Acct><Id><IBAN>DE89370400440532013000</IBAN></Id></Acct>
  #|    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">0.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
  #|  </Stmt>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_eq(report.statements.length(), 2)
  assert_eq(report.statements[0].statement_id.unwrap(), "PERIOD-1")
  assert_eq(report.statements[1].statement_id.unwrap(), "PERIOD-2")
  assert_true(report.is_valid())
}

///|
test "statement portfolio rejects a file without statements" {
  let xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08"><BkToCstmrStmt>
  #|  <GrpHdr><MsgId>NO-STATEMENT</MsgId><CreDtTm>2026-10-26T08:00:00Z</CreDtTm></GrpHdr>
  #|</BkToCstmrStmt></Document>
  let report = @moonpay_flow.statement_portfolio_audit(xml)
  assert_eq(report.statements.length(), 0)
  assert_true(report.to_json().contains("STATEMENT_MISSING"))
  assert_false(report.is_valid())
}
