///|
/// Portfolio-level audit result for all statements in one camt.053 file.
pub struct StatementPortfolioReport {
  message_id : String?
  statements : Array[StatementAuditReport]
  diagnostics : Array[Diagnostic]
}

///|
fn optional_value_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => ""
  }
}

///|
fn statement_group_key(statement_id : String?, account_iban : String?) -> String {
  optional_value_text(statement_id) + "|" + optional_value_text(account_iban)
}

///|
fn group_index(
  keys : Array[String],
  indexes : Map[String, Int],
  key : String,
) -> Int {
  match indexes.get(key) {
    Some(index) => index
    None => {
      let index = keys.length()
      keys.push(key)
      indexes.set(key, index)
      index
    }
  }
}

///|
/// Audit every Stmt in a camt.053 file separately.
pub fn statement_portfolio_audit(
  xml_text : String,
) -> StatementPortfolioReport raise XmlParseError {
  let fields = flatten_xml(xml_text)
  let records = statement_records(xml_text)
  let balance_diagnostics : Array[Diagnostic] = []
  let diagnostics : Array[Diagnostic] = []
  let owned_balances = parse_statement_balances_with_owner(
    xml_text, balance_diagnostics,
  )
  let keys : Array[String] = []
  let indexes : Map[String, Int] = Map([])
  let statement_ids : Array[String?] = []
  let accounts : Array[String?] = []
  let record_groups : Array[Array[StatementRecord]] = []
  let balance_groups : Array[Array[StatementBalance]] = []
  for record in records {
    let key = statement_group_key(record.statement_id, record.account_iban)
    let index = group_index(keys, indexes, key)
    if index >= statement_ids.length() {
      statement_ids.push(record.statement_id)
      accounts.push(record.account_iban)
      record_groups.push([])
      balance_groups.push([])
    }
    record_groups[index].push(record)
  }
  for owned in owned_balances {
    let key = statement_group_key(owned.statement_id, owned.account_iban)
    let index = group_index(keys, indexes, key)
    if index >= statement_ids.length() {
      statement_ids.push(owned.statement_id)
      accounts.push(owned.account_iban)
      record_groups.push([])
      balance_groups.push([])
    }
    balance_groups[index].push(owned.balance)
  }
  let statements : Array[StatementAuditReport] = []
  for i = 0; i < keys.length(); i = i + 1 {
    let account_count = if accounts[i] is Some(_) { 1 } else { 0 }
    statements.push(
      build_statement_audit_report(
        statement_ids[i],
        accounts[i],
        account_count,
        record_groups[i],
        balance_groups[i],
        [],
        record_groups[i].length(),
      ),
    )
  }
  if statements.length() == 0 {
    push_diagnostic(
      diagnostics,
      "STATEMENT_MISSING",
      "Stmt",
      "The camt.053 portfolio contains no statement.",
    )
  }
  for diagnostic in balance_diagnostics {
    diagnostics.push(diagnostic)
  }
  let statement_id_counts : Map[String, Int] = Map([])
  for field in fields {
    if field.path.has_suffix("/Stmt/Id") {
      match field.text {
        Some(value) =>
          if value != "" {
            let count = match statement_id_counts.get(value) {
              Some(number) => number
              None => 0
            }
            statement_id_counts.set(value, count + 1)
          }
        None => ()
      }
    }
  }
  for pair in statement_id_counts {
    if pair.1 > 1 {
      push_diagnostic(
        diagnostics,
        "STATEMENT_ID_DUPLICATE",
        "Stmt/Id",
        "Statement ID is repeated " + pair.1.to_string() + " times: " + pair.0 + ".",
      )
    }
  }
  {
    message_id: first_text_by_suffix(fields, "/GrpHdr/MsgId"),
    statements,
    diagnostics,
  }
}

///|
pub fn StatementPortfolioReport::is_valid(self : StatementPortfolioReport) -> Bool {
  if self.diagnostics.length() > 0 {
    return false
  }
  for statement in self.statements {
    if !statement.is_valid() {
      return false
    }
  }
  true
}

///|
pub fn StatementPortfolioReport::to_text(self : StatementPortfolioReport) -> String {
  let output = StringBuilder()
  output.write_string("Bank statement portfolio audit\nMessage ID: ")
  output.write_string(match self.message_id {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("\nStatements: ")
  output.write_string(self.statements.length().to_string())
  output.write_string("\nResult: ")
  if self.is_valid() {
    output.write_string("VALID")
  } else {
    output.write_string("ISSUES FOUND")
  }
  for diagnostic in self.diagnostics {
    output.write_string("\n- [")
    output.write_string(diagnostic.code)
    output.write_string("] ")
    output.write_string(diagnostic.path)
    output.write_string(": ")
    output.write_string(diagnostic.message)
  }
  for statement in self.statements {
    output.write_string("\n\n---\n")
    output.write_string(statement.to_text())
  }
  output.to_string()
}

///|
fn diagnostic_array_json(diagnostics : Array[Diagnostic]) -> Json {
  let items : Array[Json] = []
  for diagnostic in diagnostics {
    items.push({
      "code": diagnostic.code,
      "path": diagnostic.path,
      "message": diagnostic.message,
    })
  }
  Json::array(items)
}

///|
pub fn StatementPortfolioReport::to_json(self : StatementPortfolioReport) -> String {
  let output = StringBuilder()
  output.write_string("{\n  \"valid\": ")
  output.write_string(if self.is_valid() { "true" } else { "false" })
  output.write_string(",\n  \"messageId\": ")
  output.write_string(match self.message_id {
    Some(value) => Json::string(value).stringify()
    None => "null"
  })
  output.write_string(",\n  \"statementCount\": ")
  output.write_string(self.statements.length().to_string())
  output.write_string(",\n  \"statements\": [")
  for i = 0; i < self.statements.length(); i = i + 1 {
    if i > 0 {
      output.write_char(',')
    }
    output.write_char('\n')
    output.write_string(self.statements[i].to_json())
  }
  output.write_string("\n  ],\n  \"diagnostics\": ")
  output.write_string(diagnostic_array_json(self.diagnostics).stringify(indent=2))
  output.write_string("\n}")
  output.to_string()
}

///|
pub fn StatementPortfolioReport::to_markdown(
  self : StatementPortfolioReport,
) -> String {
  let output = StringBuilder()
  output.write_string("# Bank statement portfolio audit\n\n")
  output.write_string("- Message ID: `")
  output.write_string(match self.message_id {
    Some(value) => value
    None => "(missing)"
  })
  output.write_string("`\n- Statements: ")
  output.write_string(self.statements.length().to_string())
  output.write_string("\n- Result: ")
  if self.is_valid() {
    output.write_string("VALID\n")
  } else {
    output.write_string("ISSUES FOUND\n")
  }
  if self.diagnostics.length() > 0 {
    output.write_string("\n## Portfolio diagnostics\n\n")
    for diagnostic in self.diagnostics {
      output.write_string("- `")
      output.write_string(diagnostic.code)
      output.write_string("`: ")
      output.write_string(diagnostic.message)
      output.write_string("\n")
    }
  }
  for statement in self.statements {
    output.write_string("\n---\n\n")
    output.write_string(statement.to_markdown())
  }
  output.to_string()
}
