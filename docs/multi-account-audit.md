# 多账户 camt.053 审计

## 功能边界

旧版单账户审计会要求一个 `camt.053` 文件只包含一个账户。`audit-portfolio` 新增按 `Stmt` 分组的能力，可以在同一文件中分别审计：

- `Stmt/Id`
- `Stmt/Acct/Id/IBAN`
- 该 `Stmt` 下的 `Ntry`
- 该 `Stmt` 下的 `Bal`

每个账户独立计算，不会把一个账户的发生额或余额混入另一个账户。

## 输入

案例文件：`fixtures/multi_account_camt053.xml`

```text
STMT-DEBTOR    DE89370400440532013000
OPBD 1000.00 + CRDT 250.00 - DBIT 100.00 = CLBD 1150.00

STMT-CREDITOR  FR1420041010050500013M02606
OPBD 50.00 - DBIT 50.00 = CLBD 0.00
```

运行：

```bash
moon run cmd/main -- audit-portfolio fixtures/multi_account_camt053.xml
```

## 输出

```text
Statements: 2
Result: VALID

STMT-DEBTOR   BALANCED
STMT-CREDITOR BALANCED
```

面向机器处理的 JSON 会为每个 `Stmt` 输出独立对象：

```json
{
  "valid": true,
  "messageId": "CAMT-MULTI-001",
  "statementCount": 2,
  "statements": [
    {
      "statementId": "STMT-DEBTOR",
      "accountIban": "DE89370400440532013000",
      "balanceStatus": "BALANCED"
    },
    {
      "statementId": "STMT-CREDITOR",
      "accountIban": "FR1420041010050500013M02606",
      "balanceStatus": "BALANCED"
    }
  ]
}
```

每个账户对象包含：

- 期初、期末余额；
- 贷方发生额、借方发生额；
- 净变动；
- 期望期末和实际差额；
- 重复流水组；
- 账户级诊断。

## 规则

- 不同 `Stmt` 使用相同 `EndToEndId` 时，不视为重复流水；
- 同一个 `Stmt` 和账户中的完全重复流水仍会报告；
- 不同 `Stmt` 可以属于同一账户，并分别核对各自余额；
- `Stmt/Id` 在同一文件中重复时报告 `STATEMENT_ID_DUPLICATE`；
- 单个 `Stmt` 缺少账户 IBAN 时只影响该账户的诊断。

## MoonBit API

```moonbit
let report = @moonpay_flow.statement_portfolio_audit(xml_text)
for statement in report.statements {
  println(statement.statement_id.unwrap())
  println(statement.balance_status.name())
}
```

如果只需要单账户或旧的汇总行为，继续使用：

```moonbit
let report = @moonpay_flow.statement_audit(xml_text)
```
