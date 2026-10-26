///|
test "fixtures match expected message type and validity" {
  let cases : Array[(String, @moonpay_flow.MessageKind, Bool)] = [
    ("fixtures/valid_pain001.xml", @moonpay_flow.MessageKind::Pain001, true),
    ("fixtures/invalid_pain001.xml", @moonpay_flow.MessageKind::Pain001, false),
    ("fixtures/invalid_format_pain001.xml", @moonpay_flow.MessageKind::Pain001, false),
    ("fixtures/invalid_control_sum_pain001.xml", @moonpay_flow.MessageKind::Pain001, false),
    ("fixtures/invalid_identity_pain001.xml", @moonpay_flow.MessageKind::Pain001, false),
    ("fixtures/valid_pain002.xml", @moonpay_flow.MessageKind::Pain002, true),
    ("fixtures/valid_pacs008.xml", @moonpay_flow.MessageKind::Pacs008, true),
    ("fixtures/valid_pacs002.xml", @moonpay_flow.MessageKind::Pacs002, true),
    ("fixtures/valid_camt053.xml", @moonpay_flow.MessageKind::Camt053, true),
    ("fixtures/multi_account_camt053.xml", @moonpay_flow.MessageKind::Camt053, true),
    ("fixtures/timeline_pain001.xml", @moonpay_flow.MessageKind::Pain001, true),
    ("fixtures/timeline_status_1.xml", @moonpay_flow.MessageKind::Pain002, true),
    ("fixtures/timeline_status_2.xml", @moonpay_flow.MessageKind::Pain002, true),
    ("fixtures/timeline_pacs008.xml", @moonpay_flow.MessageKind::Pacs008, true),
    ("fixtures/returns_pain001.xml", @moonpay_flow.MessageKind::Pain001, true),
    ("fixtures/returns_day1.xml", @moonpay_flow.MessageKind::Camt053, true),
    ("fixtures/returns_day2_partial.xml", @moonpay_flow.MessageKind::Camt053, true),
    ("fixtures/returns_day3_final.xml", @moonpay_flow.MessageKind::Camt053, true),
    ("fixtures/returns_day4_refund_reversal.xml", @moonpay_flow.MessageKind::Camt053, true),
  ]
  for item in cases {
    let path = item.0
    let expected_kind = item.1
    let expected_valid = item.2
    let xml = @fs.read_file_to_string(path)
    let report = @moonpay_flow.validate_message(xml)
    assert_eq(report.info.kind.name(), expected_kind.name())
    assert_eq(report.is_valid(), expected_valid)
  }
}
