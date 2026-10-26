///|
/// Resolution state after merging multiple payment status reports.
pub(all) enum TimelineState {
  TimelineAwaiting
  TimelineInProgress
  TimelineSettled
  TimelineRejected
  TimelineConflict
  TimelineUnknown
}

///|
pub fn TimelineState::name(self : TimelineState) -> String {
  match self {
    TimelineAwaiting => "AWAITING_STATUS"
    TimelineInProgress => "IN_PROGRESS"
    TimelineSettled => "SETTLED"
    TimelineRejected => "REJECTED"
    TimelineConflict => "STATUS_CONFLICT"
    TimelineUnknown => "UNKNOWN_STATUS"
  }
}

///|
pub(all) enum TimelineSeverity {
  TimelineInfo
  TimelineWarning
  TimelineError
}

///|
pub fn TimelineSeverity::name(self : TimelineSeverity) -> String {
  match self {
    TimelineInfo => "INFO"
    TimelineWarning => "WARNING"
    TimelineError => "ERROR"
  }
}

///|
/// One transaction-level status notification.
pub struct StatusEventRecord {
  message_id : String?
  creation_datetime : String?
  end_to_end_id : String
  status : String
  reason_code : String?
  original_amount : Decimal?
  original_currency : String?
}

///|
/// A transition or data-quality issue found in a status history.
pub struct TimelineIssue {
  code : String
  severity : TimelineSeverity
  message : String
}

///|
/// Merged history and resolved state for one payment.
pub struct StatusTimelineCase {
  end_to_end_id : String
  amount : Decimal
  currency : String
  events : Array[StatusEventRecord]
  latest_status : String?
  state : TimelineState
  issues : Array[TimelineIssue]
  action : String
}

///|
/// Result of merging one payment source with multiple status reports.
pub struct StatusTimelineReport {
  message_count : Int
  event_count : Int
  cases : Array[StatusTimelineCase]
  orphan_status_ids : Array[String]
  orphan_events : Array[StatusEventRecord]
  diagnostics : Array[Diagnostic]
}

///|
fn timeline_status_valid(value : String) -> Bool {
  value == "ACCP" ||
  value == "ACSC" ||
  value == "ACSP" ||
  value == "ACTC" ||
  value == "ACWC" ||
  value == "PDNG" ||
  value == "RCVD" ||
  value == "RJCT"
}

///|
fn timeline_terminal(value : String) -> Bool {
  value == "ACSC" || value == "RJCT"
}

///|
fn push_timeline_issue(
  issues : Array[TimelineIssue],
  code : String,
  severity : TimelineSeverity,
  message : String,
) -> Unit {
  issues.push({ code, severity, message, })
}

///|
/// Parse all transaction status events from pain.002 or pacs.002.
pub fn status_events(xml_text : String) -> Array[StatusEventRecord] raise XmlParseError {
  let reader = XmlReader::from_string(xml_text)
  let path : Array[String] = []
  let events : Array[StatusEventRecord] = []
  let mut message_id : String? = None
  let mut creation_datetime : String? = None
  let mut in_transaction = false
  let mut current_id : String? = None
  let mut current_status : String? = None
  let mut current_reason : String? = None
  let mut current_amount_text : String? = None
  let mut current_amount_currency : String? = None
  for ;; {
    match reader.read_event().kind {
      Start(element) => {
        path.push(element.name)
        let current_path = join_path(path)
        if current_path.has_suffix("/TxInfAndSts") {
          in_transaction = true
          current_id = None
          current_status = None
          current_reason = None
          current_amount_text = None
          current_amount_currency = None
        }
        if current_path.has_suffix("/OrgnlInstdAmt") ||
          current_path.has_suffix("/OrgnlIntrBkSttlmAmt") {
          current_amount_currency = element.get("Ccy")
        }
      }
      Empty(element) => {
        path.push(element.name)
        let current_path = join_path(path)
        if current_path.has_suffix("/OrgnlInstdAmt") ||
          current_path.has_suffix("/OrgnlIntrBkSttlmAmt") {
          current_amount_currency = element.get("Ccy")
        }
        let _ = path.remove(path.length() - 1)
      }
      Text(content) => {
        let current_path = join_path(path)
        if current_path.has_suffix("/GrpHdr/MsgId") {
          message_id = Some(content)
        } else if current_path.has_suffix("/GrpHdr/CreDtTm") {
          creation_datetime = Some(content)
        } else if current_path.has_suffix("/TxInfAndSts/OrgnlEndToEndId") {
          current_id = Some(content)
        } else if current_path.has_suffix("/TxInfAndSts/TxSts") {
          current_status = Some(content)
        } else if current_path.has_suffix("/TxInfAndSts/StsRsnInf/Rsn/Cd") {
          current_reason = Some(content)
        } else if current_path.has_suffix("/OrgnlInstdAmt") ||
          current_path.has_suffix("/OrgnlIntrBkSttlmAmt") {
          current_amount_text = Some(content)
        }
      }
      End(name) => {
        if name == "TxInfAndSts" && in_transaction {
          match (current_id, current_status) {
            (Some(id), Some(status)) =>
              events.push({
                message_id,
                creation_datetime,
                end_to_end_id: id,
                status,
                reason_code: current_reason,
                original_amount: match current_amount_text {
                  Some(value) => Decimal::parse(value)
                  None => None
                },
                original_currency: current_amount_currency,
              })
            _ => ()
          }
          in_transaction = false
        }
        if path.length() > 0 {
          let _ = path.remove(path.length() - 1)
        }
      }
      Eof => break
    }
  }
  events
}

///|
fn compare_status_events(left : StatusEventRecord, right : StatusEventRecord) -> Int {
  let left_time = match left.creation_datetime {
    Some(value) => value
    None => ""
  }
  let right_time = match right.creation_datetime {
    Some(value) => value
    None => ""
  }
  let time_order = left_time.compare(right_time)
  if time_order != 0 {
    return time_order
  }
  let left_message = match left.message_id {
    Some(value) => value
    None => ""
  }
  let right_message = match right.message_id {
    Some(value) => value
    None => ""
  }
  let message_order = left_message.compare(right_message)
  if message_order != 0 {
    return message_order
  }
  left.status.compare(right.status)
}

///|
fn sort_status_events(events : Array[StatusEventRecord]) -> Array[StatusEventRecord] {
  let sorted : Array[StatusEventRecord] = []
  for event in events {
    let mut position = sorted.length()
    for i = 0; i < sorted.length(); i = i + 1 {
      if compare_status_events(event, sorted[i]) < 0 {
        position = i
        break
      }
    }
    sorted.insert(position, event)
  }
  sorted
}

///|
fn event_timestamp(event : StatusEventRecord) -> String {
  match event.creation_datetime {
    Some(value) => value
    None => ""
  }
}

///|
fn event_message_id(event : StatusEventRecord) -> String {
  match event.message_id {
    Some(value) => value
    None => ""
  }
}

///|
fn valid_non_terminal(status : String) -> Bool {
  status != "ACSC" && status != "RJCT" && timeline_status_valid(status)
}

///|
fn timeline_action(state : TimelineState) -> String {
  match state {
    TimelineAwaiting => "Request a status report from the payment provider."
    TimelineInProgress => "Wait for the next status report or query the provider again."
    TimelineSettled => "Archive the status history as settlement evidence."
    TimelineRejected => "Review the rejection reason and decide whether to resend with a new end-to-end ID."
    TimelineConflict => "Suspend automated completion and reconcile the conflicting status notifications manually."
    TimelineUnknown => "Correct the unsupported status code before using the payment as settled."
  }
}

///|
fn build_timeline_case(
  payment : PaymentRecord,
  unsorted_events : Array[StatusEventRecord],
) -> StatusTimelineCase {
  let events = sort_status_events(unsorted_events)
  let issues : Array[TimelineIssue] = []
  let seen_events : Map[String, Bool] = Map([])
  let mut latest_status : String? = None
  for event in events {
    if !timeline_status_valid(event.status) {
      push_timeline_issue(
        issues,
        "STATUS_CODE_INVALID",
        TimelineError,
        "Unsupported transaction status " + event.status + ".",
      )
    }
    match event.original_amount {
      Some(amount) =>
        if amount.compare(payment.amount) != 0 {
          push_timeline_issue(
            issues,
            "STATUS_AMOUNT_MISMATCH",
            TimelineError,
            "Status report original amount " +
            amount.to_string() +
            " does not match payment amount " +
            payment.amount.to_string() +
            ".",
          )
        }
      None => ()
    }
    match event.original_currency {
      Some(currency) =>
        if currency != payment.currency {
          push_timeline_issue(
            issues,
            "STATUS_CURRENCY_MISMATCH",
            TimelineError,
            "Status report original currency " +
            currency +
            " does not match payment currency " +
            payment.currency +
            ".",
          )
        }
      None => ()
    }
    let duplicate_key = event_message_id(event) +
      "|" +
      event_timestamp(event) +
      "|" +
      event.status
    if seen_events.contains(duplicate_key) {
      push_timeline_issue(
        issues,
        "STATUS_EVENT_DUPLICATE",
        TimelineWarning,
        "The same status event appears more than once at " +
        event_timestamp(event) +
        ".",
      )
    } else {
      seen_events.set(duplicate_key, true)
    }
    latest_status = Some(event.status)
  }
  for i = 1; i < events.length(); i = i + 1 {
    let previous = events[i - 1]
    let current = events[i]
    if timeline_terminal(previous.status) && previous.status != current.status {
      push_timeline_issue(
        issues,
        "TERMINAL_STATUS_REGRESSION",
        TimelineError,
        "Terminal status " +
        previous.status +
        " is followed by " +
        current.status +
        " at " +
        event_timestamp(current) +
        ".",
      )
    }
    if event_timestamp(previous) == event_timestamp(current) &&
      previous.status != current.status {
      push_timeline_issue(
        issues,
        "STATUS_TIMELINE_CONFLICT",
        TimelineError,
        "Conflicting statuses " +
        previous.status +
        " and " +
        current.status +
        " share timestamp " +
        event_timestamp(current) +
        ".",
      )
    }
  }
  let mut unknown = false
  let mut conflict = false
  for issue in issues {
    if issue.code == "STATUS_CODE_INVALID" {
      unknown = true
    } else if issue.severity is TimelineError {
      conflict = true
    }
  }
  let state = if events.length() == 0 {
    TimelineAwaiting
  } else if conflict {
    TimelineConflict
  } else if unknown {
    TimelineUnknown
  } else {
    match latest_status {
      Some(value) =>
        if value == "ACSC" {
          TimelineSettled
        } else if value == "RJCT" {
          TimelineRejected
        } else if valid_non_terminal(value) {
          TimelineInProgress
        } else {
          TimelineUnknown
        }
      None => TimelineAwaiting
    }
  }
  {
    end_to_end_id: payment.end_to_end_id,
    amount: payment.amount,
    currency: payment.currency,
    events,
    latest_status,
    state,
    issues,
    action: timeline_action(state),
  }
}

///|
/// Merge multiple status reports and detect conflicting or regressive histories.
pub fn status_timeline_report(
  payment_xml : String,
  status_xmls : Array[String],
) -> StatusTimelineReport raise XmlParseError {
  let payments = payment_records_auto(payment_xml)
  let all_events : Array[StatusEventRecord] = []
  let diagnostics : Array[Diagnostic] = []
  let status_message_counts : Map[String, Int] = Map([])
  for status_xml in status_xmls {
    let fields = flatten_xml(status_xml)
    let message_id = first_text_by_suffix(fields, "/GrpHdr/MsgId")
    let creation_datetime = first_text_by_suffix(fields, "/GrpHdr/CreDtTm")
    match message_id {
      Some(value) => {
        let count = match status_message_counts.get(value) {
          Some(number) => number
          None => 0
        }
        status_message_counts.set(value, count + 1)
      }
      None =>
        push_diagnostic(
          diagnostics,
          "STATUS_REPORT_ID_MISSING",
          "GrpHdr/MsgId",
          "Status report message ID is required.",
        )
    }
    if creation_datetime is None {
      push_diagnostic(
        diagnostics,
        "STATUS_REPORT_TIME_MISSING",
        "GrpHdr/CreDtTm",
        "Status report creation time is required for chronological merging.",
      )
    }
    let events = status_events(status_xml)
    if events.length() == 0 {
      push_diagnostic(
        diagnostics,
        "STATUS_REPORT_EMPTY",
        "TxInfAndSts",
        "Status report contains no complete transaction status entry.",
      )
    }
    for event in events {
      all_events.push(event)
    }
  }
  for pair in status_message_counts {
    if pair.1 > 1 {
      push_diagnostic(
        diagnostics,
        "STATUS_MESSAGE_ID_DUPLICATE",
        "GrpHdr/MsgId",
        "Status report message ID is repeated " + pair.1.to_string() + " times: " + pair.0 + ".",
      )
    }
  }
  let payment_ids : Map[String, Bool] = Map([])
  let events_by_id : Map[String, Array[StatusEventRecord]] = Map([])
  for payment in payments {
    payment_ids.set(payment.end_to_end_id, true)
  }
  for event in all_events {
    let records = match events_by_id.get(event.end_to_end_id) {
      Some(value) => value
      None => {
        let value : Array[StatusEventRecord] = []
        events_by_id.set(event.end_to_end_id, value)
        value
      }
    }
    records.push(event)
  }
  let cases : Array[StatusTimelineCase] = []
  for payment in payments {
    let events = match events_by_id.get(payment.end_to_end_id) {
      Some(value) => value
      None => []
    }
    cases.push(build_timeline_case(payment, events))
  }
  let orphan_ids : Array[String] = []
  let orphan_seen : Map[String, Bool] = Map([])
  let orphan_events : Array[StatusEventRecord] = []
  for event in all_events {
    if !payment_ids.contains(event.end_to_end_id) {
      orphan_events.push(event)
      if !orphan_seen.contains(event.end_to_end_id) {
        orphan_seen.set(event.end_to_end_id, true)
        orphan_ids.push(event.end_to_end_id)
      }
    }
  }
  {
    message_count: status_xmls.length(),
    event_count: all_events.length(),
    cases,
    orphan_status_ids: orphan_ids,
    orphan_events: sort_status_events(orphan_events),
    diagnostics,
  }
}

///|
pub fn StatusTimelineReport::is_valid(self : StatusTimelineReport) -> Bool {
  if self.diagnostics.length() > 0 || self.orphan_status_ids.length() > 0 {
    return false
  }
  for case in self.cases {
    for issue in case.issues {
      if issue.severity is TimelineError {
        return false
      }
    }
  }
  true
}

///|
fn status_event_to_json(event : StatusEventRecord) -> Json {
  let message_id : Json = match event.message_id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let creation_datetime : Json = match event.creation_datetime {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let reason_code : Json = match event.reason_code {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let original_amount : Json = match event.original_amount {
    Some(value) => Json::string(value.to_string())
    None => Json::null()
  }
  let original_currency : Json = match event.original_currency {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  {
    "messageId": message_id,
    "creationDateTime": creation_datetime,
    "status": event.status,
    "reasonCode": reason_code,
    "originalAmount": original_amount,
    "originalCurrency": original_currency,
  }
}

///|
pub fn StatusTimelineReport::to_text(self : StatusTimelineReport) -> String {
  let output = StringBuilder()
  output.write_string("Payment status timeline\n")
  output.write_string("Status reports: ")
  output.write_string(self.message_count.to_string())
  output.write_string("\nEvents: ")
  output.write_string(self.event_count.to_string())
  for case in self.cases {
    output.write_string("\n\n")
    output.write_string(case.end_to_end_id)
    output.write_string(" | ")
    output.write_string(case.amount.to_string())
    output.write_string(" ")
    output.write_string(case.currency)
    output.write_string(" | latest=")
    output.write_string(match case.latest_status {
      Some(value) => value
      None => "(missing)"
    })
    output.write_string(" | state=")
    output.write_string(case.state.name())
    output.write_string("\nAction: ")
    output.write_string(case.action)
    for event in case.events {
      output.write_string("\n  - ")
      output.write_string(match event.creation_datetime {
        Some(value) => value
        None => "(no time)"
      })
      output.write_string(" ")
      output.write_string(event.status)
      match event.reason_code {
        Some(value) => {
          output.write_string(" reason=")
          output.write_string(value)
        }
        None => ()
      }
      output.write_string(" message=")
      output.write_string(match event.message_id {
        Some(value) => value
        None => "(missing)"
      })
    }
    for issue in case.issues {
      output.write_string("\n  [")
      output.write_string(issue.severity.name())
      output.write_string("] ")
      output.write_string(issue.code)
      output.write_string(": ")
      output.write_string(issue.message)
    }
  }
  if self.diagnostics.length() > 0 {
    output.write_string("\n\nStatus report diagnostics:")
    for diagnostic in self.diagnostics {
      output.write_string("\n- [")
      output.write_string(diagnostic.code)
      output.write_string("] ")
      output.write_string(diagnostic.path)
      output.write_string(": ")
      output.write_string(diagnostic.message)
    }
  }
  if self.orphan_status_ids.length() > 0 {
    output.write_string("\n\nStatus IDs without payment:")
    for id in self.orphan_status_ids {
      output.write_string("\n- ")
      output.write_string(id)
    }
  }
  output.to_string()
}

///|
pub fn StatusTimelineReport::to_json(self : StatusTimelineReport) -> String {
  let cases : Array[Json] = []
  for case in self.cases {
    let events : Array[Json] = []
    for event in case.events {
      events.push(status_event_to_json(event))
    }
    let issues : Array[Json] = []
    for issue in case.issues {
      issues.push({
        "code": issue.code,
        "severity": issue.severity.name(),
        "message": issue.message,
      })
    }
    let latest_status : Json = match case.latest_status {
      Some(value) => Json::string(value)
      None => Json::null()
    }
    cases.push({
      "endToEndId": case.end_to_end_id,
      "amount": case.amount.to_string(),
      "currency": case.currency,
      "latestStatus": latest_status,
      "state": case.state.name(),
      "action": case.action,
      "events": Json::array(events),
      "issues": Json::array(issues),
    })
  }
  let orphan_ids : Array[Json] = []
  for id in self.orphan_status_ids {
    orphan_ids.push(Json::string(id))
  }
  let orphan_events : Array[Json] = []
  for event in self.orphan_events {
    orphan_events.push(status_event_to_json(event))
  }
  let root = Map([])
  root.set("valid", Json::boolean(self.is_valid()))
  root.set("statusReportCount", Json::number(self.message_count.to_double()))
  root.set("eventCount", Json::number(self.event_count.to_double()))
  root.set("cases", Json::array(cases))
  root.set("orphanStatusIds", Json::array(orphan_ids))
  root.set("orphanEvents", Json::array(orphan_events))
  let diagnostics : Array[Json] = []
  for diagnostic in self.diagnostics {
    diagnostics.push({
      "code": diagnostic.code,
      "path": diagnostic.path,
      "message": diagnostic.message,
    })
  }
  root.set("diagnostics", Json::array(diagnostics))
  Json::object(root).stringify(indent=2)
}

///|
pub fn StatusTimelineReport::to_markdown(self : StatusTimelineReport) -> String {
  let output = StringBuilder()
  output.write_string("# Payment status timeline\n\n")
  output.write_string("- Status reports: ")
  output.write_string(self.message_count.to_string())
  output.write_string("\n- Events: ")
  output.write_string(self.event_count.to_string())
  output.write_string("\n- Result: ")
  if self.is_valid() {
    output.write_string("VALID\n")
  } else {
    output.write_string("ISSUES FOUND\n")
  }
  output.write_string("\n## Transactions\n\n")
  output.write_string("| EndToEndId | Amount | Latest status | State | Events | Issues |\n")
  output.write_string("|---|---|---|---|---|---|\n")
  for case in self.cases {
    output.write_string("| `")
    output.write_string(case.end_to_end_id)
    output.write_string("` | ")
    output.write_string(case.amount.to_string())
    output.write_string(" ")
    output.write_string(case.currency)
    output.write_string(" | ")
    output.write_string(match case.latest_status {
      Some(value) => value
      None => "(missing)"
    })
    output.write_string(" | `")
    output.write_string(case.state.name())
    output.write_string("` | ")
    output.write_string(case.events.length().to_string())
    output.write_string(" | ")
    output.write_string(case.issues.length().to_string())
    output.write_string(" |\n")
  }
  output.write_string("\n## Actions and issues\n\n")
  for case in self.cases {
    output.write_string("### `")
    output.write_string(case.end_to_end_id)
    output.write_string("`\n\n")
    output.write_string(case.action)
    output.write_string("\n")
    for issue in case.issues {
      output.write_string("\n- `")
      output.write_string(issue.code)
      output.write_string("`: ")
      output.write_string(issue.message)
    }
    output.write_string("\n")
  }
  if self.diagnostics.length() > 0 {
    output.write_string("\n## Status report diagnostics\n\n")
    for diagnostic in self.diagnostics {
      output.write_string("- `")
      output.write_string(diagnostic.code)
      output.write_string("`: ")
      output.write_string(diagnostic.message)
      output.write_string("\n")
    }
  }
  output.write_string("\n## Orphan statuses\n\n")
  if self.orphan_status_ids.length() == 0 {
    output.write_string("None.\n")
  } else {
    for id in self.orphan_status_ids {
      output.write_string("- `")
      output.write_string(id)
      output.write_string("`\n")
    }
  }
  output.to_string()
}
