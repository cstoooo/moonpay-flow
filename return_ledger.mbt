///|
/// Authoritative post-posting state for refunds and reversals.
pub(all) enum ReturnLedgerState {
  LedgerNotPosted
  LedgerPaid
  LedgerPartiallyReturned
  LedgerFullyReturned
  LedgerPaymentReversed
  LedgerEvidenceIncomplete
  LedgerConflict
}

///|
pub fn ReturnLedgerState::name(self : ReturnLedgerState) -> String {
  match self {
    LedgerNotPosted => "NOT_POSTED"
    LedgerPaid => "PAID"
    LedgerPartiallyReturned => "PARTIALLY_RETURNED"
    LedgerFullyReturned => "FULLY_RETURNED"
    LedgerPaymentReversed => "PAYMENT_REVERSED"
    LedgerEvidenceIncomplete => "EVIDENCE_INCOMPLETE"
    LedgerConflict => "CONFLICT"
  }
}

///|
pub(all) enum LedgerLinkQuality {
  LedgerExplicitLink
  LedgerInferredLink
  LedgerAmbiguousLink
  LedgerMissingLink
}

///|
pub fn LedgerLinkQuality::name(self : LedgerLinkQuality) -> String {
  match self {
    LedgerExplicitLink => "EXPLICIT"
    LedgerInferredLink => "INFERRED_UNIQUE"
    LedgerAmbiguousLink => "AMBIGUOUS"
    LedgerMissingLink => "MISSING"
  }
}

///|
pub(all) enum LedgerLegKind {
  OriginalPayment
  RefundCredit
  ReversalOfPayment
  ReversalOfRefund
  UnlinkedReversal
}

///|
pub fn LedgerLegKind::name(self : LedgerLegKind) -> String {
  match self {
    OriginalPayment => "ORIGINAL_PAYMENT"
    RefundCredit => "REFUND_CREDIT"
    ReversalOfPayment => "REVERSAL_OF_PAYMENT"
    ReversalOfRefund => "REVERSAL_OF_REFUND"
    UnlinkedReversal => "UNLINKED_REVERSAL"
  }
}

///|
pub struct LedgerIssue {
  code : String
  severity : String
  message : String
}

///|
pub struct ReturnLedgerLeg {
  statement_id : String?
  booking_date : String?
  entry_reference : String?
  transaction_id : String?
  uetr : String?
  original_entry_reference : String?
  original_transaction_id : String?
  amount : Decimal
  currency : String
  credit_debit : String
  reversal : Bool
  kind : LedgerLegKind
  linked_to : String?
  link_quality : LedgerLinkQuality
}

///|
pub struct ReturnLedgerCase {
  end_to_end_id : String
  declared_amount : Decimal
  currency : String
  account_role : String
  state : ReturnLedgerState
  observed_payment : Decimal
  observed_refund : Decimal
  posted_payment : Decimal?
  effective_refund : Decimal?
  remaining : Decimal?
  crossed_period : Bool
  legs : Array[ReturnLedgerLeg]
  issues : Array[LedgerIssue]
  action : String
}

///|
pub struct ReturnLedgerReport {
  statement_count : Int
  cases : Array[ReturnLedgerCase]
  orphan_entries : Array[ReturnLedgerLeg]
  diagnostics : Array[Diagnostic]
}

///|
fn ledger_option_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => ""
  }
}

///|
fn ledger_payment_role(record : StatementRecord, payment : PaymentRecord) -> String {
  match record.account_iban {
    Some(account) => {
      match payment.debtor_iban {
        Some(debtor) =>
          if account == debtor {
            return "DEBTOR"
          }
        None => ()
      }
      match payment.creditor_iban {
        Some(creditor) =>
          if account == creditor {
            return "CREDITOR"
          }
        None => ()
      }
    }
    None => ()
  }
  "UNKNOWN"
}

///|
fn ledger_base_direction(role : String) -> String {
  if role == "CREDITOR" {
    "CRDT"
  } else {
    "DBIT"
  }
}

///|
fn ledger_leg_label(record : StatementRecord, index : Int) -> String {
  match record.entry_reference {
    Some(value) => value
    None =>
      match record.transaction_id {
        Some(value) => value
        None => "ENTRY-" + index.to_string()
      }
  }
}

///|
fn ledger_date_key(record : StatementRecord) -> String {
  match record.booking_date {
    Some(value) => value
    None => ""
  }
}

///|
fn ledger_statement_key(record : StatementRecord) -> String {
  match record.statement_id {
    Some(value) => value
    None => ""
  }
}

///|
fn compare_ledger_records(left : StatementRecord, right : StatementRecord) -> Int {
  let date_order = ledger_date_key(left).compare(ledger_date_key(right))
  if date_order != 0 {
    return date_order
  }
  let statement_order = ledger_statement_key(left).compare(ledger_statement_key(right))
  if statement_order != 0 {
    return statement_order
  }
  ledger_leg_label(left, 0).compare(ledger_leg_label(right, 0))
}

///|
fn sort_ledger_records(records : Array[StatementRecord]) -> Array[StatementRecord] {
  let sorted : Array[StatementRecord] = []
  for record in records {
    let mut position = sorted.length()
    for i = 0; i < sorted.length(); i = i + 1 {
      if compare_ledger_records(record, sorted[i]) < 0 {
        position = i
        break
      }
    }
    sorted.insert(position, record)
  }
  sorted
}

///|
fn push_ledger_issue(
  issues : Array[LedgerIssue],
  code : String,
  severity : String,
  message : String,
) -> Unit {
  issues.push({ code, severity, message, })
}

///|
fn ledger_action(state : ReturnLedgerState) -> String {
  match state {
    LedgerNotPosted => "Load the statement containing the original payment posting before deciding the refund state."
    LedgerPaid => "Archive the posting and retain the statement reference."
    LedgerPartiallyReturned => "Track the remaining amount and require later refund or reversal evidence."
    LedgerFullyReturned => "Do not treat the payment as completed; retain the linked refund chain as evidence."
    LedgerPaymentReversed => "Mark the original payment as reversed and close it only after checking the reversal reference."
    LedgerEvidenceIncomplete => "Load prior and later statement periods; do not infer full or partial return from net amount alone."
    LedgerConflict => "Freeze automated settlement and investigate the conflicting refund/reversal chain."
  }
}

///|
fn ledger_target_candidates(
  records : Array[StatementRecord],
  reversal : StatementRecord,
  current_index : Int,
  already_used : Array[Bool],
  explicit_only : Bool,
) -> Array[Int] {
  let candidates : Array[Int] = []
  for i = 0; i < current_index; i = i + 1 {
    let candidate = records[i]
    if already_used[i] || candidate.reversal {
      continue
    }
    if candidate.currency != reversal.currency {
      continue
    }
    if candidate.amount.compare(reversal.amount) != 0 {
      continue
    }
    if candidate.credit_debit == reversal.credit_debit {
      continue
    }
    let entry_match = match reversal.original_entry_reference {
      Some(reference) =>
        match candidate.entry_reference {
          Some(value) => reference == value
          None => false
        }
      None => false
    }
    let transaction_match = match reversal.original_transaction_id {
      Some(reference) =>
        match candidate.transaction_id {
          Some(value) => reference == value
          None => false
        }
      None => false
    }
    let uetr_match = match reversal.uetr {
      Some(reference) =>
        match candidate.uetr {
          Some(value) => reference == value
          None => false
        }
      None => false
    }
    let explicit_match = entry_match || transaction_match || uetr_match
    if explicit_only {
      if explicit_match {
        candidates.push(i)
      }
    } else if !explicit_match {
      candidates.push(i)
    }
  }
  candidates
}

///|
fn has_ledger_explicit_reference(record : StatementRecord) -> Bool {
  record.original_entry_reference is Some(_) ||
  record.original_transaction_id is Some(_) ||
  record.uetr is Some(_)
}

///|
fn ledger_leg_from_record(
  record : StatementRecord,
  kind : LedgerLegKind,
  linked_to : String?,
  quality : LedgerLinkQuality,
) -> ReturnLedgerLeg {
  {
    statement_id: record.statement_id,
    booking_date: record.booking_date,
    entry_reference: record.entry_reference,
    transaction_id: record.transaction_id,
    uetr: record.uetr,
    original_entry_reference: record.original_entry_reference,
    original_transaction_id: record.original_transaction_id,
    amount: record.amount,
    currency: record.currency,
    credit_debit: record.credit_debit,
    reversal: record.reversal,
    kind,
    linked_to,
    link_quality: quality,
  }
}

///|
fn ledger_optional_decimal(value : Decimal?) -> Json {
  match value {
    Some(number) => Json::string(number.to_string())
    None => Json::null()
  }
}

///|
fn build_return_ledger_case(
  payment : PaymentRecord,
  records : Array[StatementRecord],
  role : String,
) -> ReturnLedgerCase {
  let sorted = sort_ledger_records(records)
  let issues : Array[LedgerIssue] = []
  let base_direction = ledger_base_direction(role)
  let already_used : Array[Bool] = []
  let target_indexes : Array[Int?] = []
  let link_qualities : Array[LedgerLinkQuality] = []
  let kinds : Array[LedgerLegKind] = []
  for i = 0; i < sorted.length(); i = i + 1 {
    already_used.push(false)
    target_indexes.push(None)
    link_qualities.push(LedgerMissingLink)
    kinds.push(UnlinkedReversal)
  }
  for i = 0; i < sorted.length(); i = i + 1 {
    let record = sorted[i]
    if !record.reversal {
      if record.credit_debit == base_direction {
        kinds[i] = OriginalPayment
      } else {
        kinds[i] = RefundCredit
      }
    } else {
      let explicit = has_ledger_explicit_reference(record)
      let candidates = ledger_target_candidates(
        sorted, record, i, already_used, explicit,
      )
      if candidates.length() == 1 {
        let target = candidates[0]
        target_indexes[i] = Some(target)
        already_used[target] = true
        link_qualities[i] = if explicit { LedgerExplicitLink } else { LedgerInferredLink }
        let target_kind = kinds[target]
        if target_kind is OriginalPayment {
          kinds[i] = ReversalOfPayment
          push_ledger_issue(
            issues,
            "PAYMENT_REVERSAL_APPLIED",
            "INFO",
            "Reversal is linked to original payment entry " +
            ledger_leg_label(sorted[target], target) +
            ".",
          )
        } else if target_kind is RefundCredit {
          kinds[i] = ReversalOfRefund
          push_ledger_issue(
            issues,
            "REFUND_REVERSAL_APPLIED",
            "INFO",
            "Reversal is linked to refund entry " +
            ledger_leg_label(sorted[target], target) +
            ".",
          )
        }
      } else if candidates.length() > 1 {
        link_qualities[i] = LedgerAmbiguousLink
        kinds[i] = UnlinkedReversal
        push_ledger_issue(
          issues,
          "REVERSAL_TARGET_AMBIGUOUS",
          "ERROR",
          "Reversal has multiple matching prior entries; explicit original reference is required.",
        )
      } else {
        kinds[i] = UnlinkedReversal
        if explicit {
          push_ledger_issue(
            issues,
            "REVERSAL_REFERENCE_NOT_FOUND",
            "ERROR",
            "Reversal names an original entry but no matching prior entry exists in the provided history.",
          )
        } else {
          push_ledger_issue(
            issues,
            "REVERSAL_TARGET_NOT_FOUND",
            "ERROR",
            "Reversal cannot be linked to a prior payment or refund entry.",
          )
        }
      }
    }
  }
  let mut observed_payment = Decimal::zero()
  let mut observed_refund = Decimal::zero()
  let mut reversed_payment = Decimal::zero()
  let mut reversed_refund = Decimal::zero()
  for i = 0; i < sorted.length(); i = i + 1 {
    let kind = kinds[i]
    if kind is OriginalPayment {
      observed_payment = observed_payment.add(sorted[i].amount)
    } else if kind is RefundCredit {
      observed_refund = observed_refund.add(sorted[i].amount)
    } else if kind is ReversalOfPayment {
      reversed_payment = reversed_payment.add(sorted[i].amount)
    } else if kind is ReversalOfRefund {
      reversed_refund = reversed_refund.add(sorted[i].amount)
    }
  }
  if role == "UNKNOWN" {
    push_ledger_issue(
      issues,
      "ACCOUNT_UNMATCHED",
      "ERROR",
      "Statement account does not match debtor or creditor account in the payment record.",
    )
  }
  let history_complete = observed_payment.compare(payment.amount) == 0
  if observed_payment.compare(Decimal::zero()) == 0 {
    push_ledger_issue(
      issues,
      "RETURN_HISTORY_INCOMPLETE",
      "ERROR",
      "Original payment posting is outside the provided statement history.",
    )
  } else if observed_payment.compare(payment.amount) < 0 {
    push_ledger_issue(
      issues,
      "PAYMENT_POSTING_INCOMPLETE",
      "ERROR",
      "Observed payment postings are less than the declared payment amount.",
    )
  } else if observed_payment.compare(payment.amount) > 0 {
    push_ledger_issue(
      issues,
      "PAYMENT_AMOUNT_MISMATCH",
      "ERROR",
      "Observed payment postings exceed the declared payment amount.",
    )
  }
  let posted_payment = if history_complete {
    Some(observed_payment.subtract(reversed_payment))
  } else {
    None
  }
  let effective_refund = if history_complete {
    Some(observed_refund.subtract(reversed_refund))
  } else {
    None
  }
  let remaining = match (posted_payment, effective_refund) {
    (Some(paid), Some(refunded)) => Some(paid.subtract(refunded))
    _ => None
  }
  let mut conflict = false
  for issue in issues {
    if issue.severity == "ERROR" &&
      issue.code != "RETURN_HISTORY_INCOMPLETE" &&
      issue.code != "PAYMENT_POSTING_INCOMPLETE" {
      conflict = true
    }
  }
  let state = if sorted.length() == 0 {
    LedgerNotPosted
  } else if !history_complete {
    if conflict {
      LedgerConflict
    } else {
      LedgerEvidenceIncomplete
    }
  } else {
    match (posted_payment, effective_refund, remaining) {
      (Some(paid), Some(refunded), Some(left)) =>
        if left.compare(Decimal::zero()) < 0 {
          push_ledger_issue(
            issues,
            "REFUND_OVERPAYMENT",
            "ERROR",
            "Effective refunds exceed the effective payment amount.",
          )
          LedgerConflict
        } else if conflict {
          LedgerConflict
        } else if paid.compare(Decimal::zero()) == 0 &&
          refunded.compare(Decimal::zero()) == 0 {
          LedgerPaymentReversed
        } else if left.compare(Decimal::zero()) == 0 && refunded.compare(Decimal::zero()) > 0 {
          LedgerFullyReturned
        } else if refunded.compare(Decimal::zero()) > 0 {
          LedgerPartiallyReturned
        } else {
          LedgerPaid
        }
      _ => LedgerEvidenceIncomplete
    }
  }
  let statement_ids : Map[String, Bool] = Map([])
  let booking_dates : Map[String, Bool] = Map([])
  for record in sorted {
    match record.statement_id {
      Some(value) => statement_ids.set(value, true)
      None => ()
    }
    match record.booking_date {
      Some(value) => booking_dates.set(value, true)
      None => ()
    }
  }
  let crossed_period = statement_ids.length() > 1 || booking_dates.length() > 1
  let legs : Array[ReturnLedgerLeg] = []
  for i = 0; i < sorted.length(); i = i + 1 {
    let linked_to = match target_indexes[i] {
      Some(target) => Some(ledger_leg_label(sorted[target], target))
      None => None
    }
    legs.push(ledger_leg_from_record(sorted[i], kinds[i], linked_to, link_qualities[i]))
  }
  {
    end_to_end_id: payment.end_to_end_id,
    declared_amount: payment.amount,
    currency: payment.currency,
    account_role: role,
    state,
    observed_payment,
    observed_refund,
    posted_payment,
    effective_refund,
    remaining,
    crossed_period,
    legs,
    issues,
    action: ledger_action(state),
  }
}

///|
/// Build a cross-statement return/reversal ledger for every payment.
pub fn return_ledger_report(
  payment_xml : String,
  statement_xmls : Array[String],
) -> ReturnLedgerReport raise XmlParseError {
  let payments = payment_records_auto(payment_xml)
  let all_records : Array[StatementRecord] = []
  for statement_xml in statement_xmls {
    for record in statement_records(statement_xml) {
      all_records.push(record)
    }
  }
  let payment_ids : Map[String, Bool] = Map([])
  for payment in payments {
    payment_ids.set(payment.end_to_end_id, true)
  }
  let cases : Array[ReturnLedgerCase] = []
  for payment in payments {
    let payment_records : Array[StatementRecord] = []
    let mut has_debtor = false
    let mut has_creditor = false
    for record in all_records {
      if record.end_to_end_id == payment.end_to_end_id {
        payment_records.push(record)
        let role = ledger_payment_role(record, payment)
        if role == "DEBTOR" {
          has_debtor = true
        } else if role == "CREDITOR" {
          has_creditor = true
        }
      }
    }
    let role = if has_debtor {
      "DEBTOR"
    } else if has_creditor {
      "CREDITOR"
    } else {
      "UNKNOWN"
    }
    let selected : Array[StatementRecord] = []
    for record in payment_records {
      if ledger_payment_role(record, payment) == role {
        selected.push(record)
      }
    }
    cases.push(build_return_ledger_case(payment, selected, role))
  }
  let orphan_entries : Array[ReturnLedgerLeg] = []
  for record in all_records {
    if !payment_ids.contains(record.end_to_end_id) {
      orphan_entries.push(
        ledger_leg_from_record(
          record, UnlinkedReversal, None, LedgerMissingLink,
        ),
      )
    }
  }
  { statement_count: statement_xmls.length(), cases, orphan_entries, diagnostics: [], }
}

///|
pub fn ReturnLedgerReport::is_valid(self : ReturnLedgerReport) -> Bool {
  if self.orphan_entries.length() > 0 {
    return false
  }
  for case in self.cases {
    if case.state is LedgerConflict || case.state is LedgerEvidenceIncomplete {
      return false
    }
  }
  true
}

///|
fn ledger_issue_json(issue : LedgerIssue) -> Json {
  { "code": issue.code, "severity": issue.severity, "message": issue.message, }
}

///|
fn ledger_leg_json(leg : ReturnLedgerLeg) -> Json {
  let statement_id : Json = match leg.statement_id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let booking_date : Json = match leg.booking_date {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let entry_reference : Json = match leg.entry_reference {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let transaction_id : Json = match leg.transaction_id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let uetr : Json = match leg.uetr {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let original_entry_reference : Json = match leg.original_entry_reference {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let original_transaction_id : Json = match leg.original_transaction_id {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  let linked_to : Json = match leg.linked_to {
    Some(value) => Json::string(value)
    None => Json::null()
  }
  {
    "statementId": statement_id,
    "bookingDate": booking_date,
    "entryReference": entry_reference,
    "transactionId": transaction_id,
    "uetr": uetr,
    "originalEntryReference": original_entry_reference,
    "originalTransactionId": original_transaction_id,
    "amount": leg.amount.to_string(),
    "currency": leg.currency,
    "creditDebit": leg.credit_debit,
    "reversal": leg.reversal,
    "kind": leg.kind.name(),
    "linkedTo": linked_to,
    "linkQuality": leg.link_quality.name(),
  }
}

///|
pub fn ReturnLedgerReport::to_text(self : ReturnLedgerReport) -> String {
  let output = StringBuilder()
  output.write_string("Return and reversal ledger\n")
  output.write_string("Statements: ")
  output.write_string(self.statement_count.to_string())
  for case in self.cases {
    output.write_string("\n\n")
    output.write_string(case.end_to_end_id)
    output.write_string(" | ")
    output.write_string(case.declared_amount.to_string())
    output.write_string(" ")
    output.write_string(case.currency)
    output.write_string(" | account=")
    output.write_string(case.account_role)
    output.write_string(" | state=")
    output.write_string(case.state.name())
    output.write_string(" | crossPeriod=")
    output.write_string(if case.crossed_period { "true" } else { "false" })
    output.write_string("\nPosted payment: ")
    output.write_string(match case.posted_payment {
      Some(value) => value.to_string()
      None => "(not verifiable)"
    })
    output.write_string("\nEffective refund: ")
    output.write_string(match case.effective_refund {
      Some(value) => value.to_string()
      None => "(not verifiable)"
    })
    output.write_string("\nRemaining: ")
    output.write_string(match case.remaining {
      Some(value) => value.to_string()
      None => "(not verifiable)"
    })
    output.write_string("\nAction: ")
    output.write_string(case.action)
    for leg in case.legs {
      output.write_string("\n- ")
      output.write_string(ledger_option_text(leg.booking_date))
      output.write_string(" ")
      output.write_string(ledger_option_text(leg.entry_reference))
      output.write_string(" ")
      output.write_string(leg.credit_debit)
      output.write_string(" ")
      output.write_string(leg.amount.to_string())
      output.write_string(" ")
      output.write_string(leg.currency)
      output.write_string(" | kind=")
      output.write_string(leg.kind.name())
      output.write_string(" | link=")
      output.write_string(leg.link_quality.name())
      match leg.linked_to {
        Some(value) => {
          output.write_string(" -> ")
          output.write_string(value)
        }
        None => ()
      }
    }
    for issue in case.issues {
      output.write_string("\n  [")
      output.write_string(issue.severity)
      output.write_string("] ")
      output.write_string(issue.code)
      output.write_string(": ")
      output.write_string(issue.message)
    }
  }
  if self.orphan_entries.length() > 0 {
    output.write_string("\n\nStatement entries without payment:")
    for leg in self.orphan_entries {
      output.write_string("\n- ")
      output.write_string(ledger_option_text(leg.entry_reference))
      output.write_string(" ")
      output.write_string(leg.amount.to_string())
      output.write_string(" ")
      output.write_string(leg.currency)
    }
  }
  output.to_string()
}

///|
pub fn ReturnLedgerReport::to_json(self : ReturnLedgerReport) -> String {
  let cases : Array[Json] = []
  for case in self.cases {
    let legs : Array[Json] = []
    for leg in case.legs {
      legs.push(ledger_leg_json(leg))
    }
    let issues : Array[Json] = []
    for issue in case.issues {
      issues.push(ledger_issue_json(issue))
    }
    cases.push({
      "endToEndId": case.end_to_end_id,
      "declaredAmount": case.declared_amount.to_string(),
      "currency": case.currency,
      "accountRole": case.account_role,
      "state": case.state.name(),
      "observedPayment": case.observed_payment.to_string(),
      "observedRefund": case.observed_refund.to_string(),
      "postedPayment": ledger_optional_decimal(case.posted_payment),
      "effectiveRefund": ledger_optional_decimal(case.effective_refund),
      "remaining": ledger_optional_decimal(case.remaining),
      "crossedPeriod": case.crossed_period,
      "action": case.action,
      "legs": Json::array(legs),
      "issues": Json::array(issues),
    })
  }
  let orphans : Array[Json] = []
  for leg in self.orphan_entries {
    orphans.push(ledger_leg_json(leg))
  }
  let root = Map([])
  root.set("valid", Json::boolean(self.is_valid()))
  root.set("statementCount", Json::number(self.statement_count.to_double()))
  root.set("cases", Json::array(cases))
  root.set("orphanEntries", Json::array(orphans))
  Json::object(root).stringify(indent=2)
}

///|
pub fn ReturnLedgerReport::to_markdown(self : ReturnLedgerReport) -> String {
  let output = StringBuilder()
  output.write_string("# Return and reversal ledger\n\n")
  output.write_string("| EndToEndId | Declared | State | Posted | Refunded | Remaining | Cross period |\n")
  output.write_string("|---|---|---|---|---|---|---|\n")
  for case in self.cases {
    output.write_string("| `")
    output.write_string(case.end_to_end_id)
    output.write_string("` | ")
    output.write_string(case.declared_amount.to_string())
    output.write_string(" ")
    output.write_string(case.currency)
    output.write_string(" | `")
    output.write_string(case.state.name())
    output.write_string("` | ")
    output.write_string(match case.posted_payment {
      Some(value) => value.to_string()
      None => "(unknown)"
    })
    output.write_string(" | ")
    output.write_string(match case.effective_refund {
      Some(value) => value.to_string()
      None => "(unknown)"
    })
    output.write_string(" | ")
    output.write_string(match case.remaining {
      Some(value) => value.to_string()
      None => "(unknown)"
    })
    output.write_string(" | ")
    output.write_string(if case.crossed_period { "yes" } else { "no" })
    output.write_string(" |\n")
  }
  output.write_string("\n## Linked legs\n\n")
  for case in self.cases {
    output.write_string("### `")
    output.write_string(case.end_to_end_id)
    output.write_string("`\n\n")
    output.write_string(case.action)
    output.write_string("\n\n")
    output.write_string("| Date | Entry | Amount | Kind | Linked to | Link quality |\n")
    output.write_string("|---|---|---|---|---|---|\n")
    for leg in case.legs {
      output.write_string("| ")
      output.write_string(ledger_option_text(leg.booking_date))
      output.write_string(" | `")
      output.write_string(ledger_option_text(leg.entry_reference))
      output.write_string("` | ")
      output.write_string(leg.amount.to_string())
      output.write_string(" ")
      output.write_string(leg.currency)
      output.write_string(" | `")
      output.write_string(leg.kind.name())
      output.write_string("` | `")
      output.write_string(ledger_option_text(leg.linked_to))
      output.write_string("` | `")
      output.write_string(leg.link_quality.name())
      output.write_string("` |\n")
    }
    for issue in case.issues {
      output.write_string("\n- `")
      output.write_string(issue.code)
      output.write_string("`: ")
      output.write_string(issue.message)
    }
    output.write_string("\n")
  }
  output.write_string("\n## Orphan entries\n\n")
  if self.orphan_entries.length() == 0 {
    output.write_string("None.\n")
  } else {
    for leg in self.orphan_entries {
      output.write_string("- `")
      output.write_string(ledger_option_text(leg.entry_reference))
      output.write_string("`: ")
      output.write_string(leg.amount.to_string())
      output.write_string(" ")
      output.write_string(leg.currency)
      output.write_string("\n")
    }
  }
  output.to_string()
}
