# 多状态报告时间线与冲突检测

## 使用场景

支付系统通常不会只收到一份状态报告。一笔付款可能依次经历：

```text
RCVD -> PDNG -> ACSP -> ACSC
```

也可能在任一阶段进入：

```text
RJCT
```

MoonPay Flow 的 `timeline` 命令把多份 `pain.002` / `pacs.002` 按 `GrpHdr/CreDtTm` 合并，并按 `EndToEndId` 还原每笔付款的状态历史。

付款来源支持：

- `pain.001.001.03`
- `pacs.008.001.08`

状态来源支持：

- `pain.002.001.03`
- `pacs.002.001.10`

## 输入

案例文件：

```text
fixtures/timeline_pain001.xml
fixtures/timeline_status_1.xml
fixtures/timeline_status_2.xml
```

第一份状态报告：

```text
TL-TX-A  PDNG
TL-TX-B  ACSP
```

第二份状态报告：

```text
TL-TX-A  ACSC
TL-TX-B  RJCT  reason=AC01
```

运行：

```bash
moon run cmd/main -- timeline \
  fixtures/timeline_pain001.xml \
  fixtures/timeline_status_1.xml \
  fixtures/timeline_status_2.xml
```

## 输出

```text
TL-TX-A | 100.00 EUR | latest=ACSC | state=SETTLED
TL-TX-B | 50.00 EUR  | latest=RJCT | state=REJECTED
```

每个交易结果包含：

- 按时间排序的完整状态事件；
- 状态报告消息 ID、创建时间；
- 状态报告中的原始金额与币种；
- 最新状态；
- 最终分类；
- 处理动作；
- 相关异常代码。

## 异常规则

| 代码 | 含义 |
| --- | --- |
| `STATUS_REPORT_ID_MISSING` | 状态报告缺少 `MsgId` |
| `STATUS_REPORT_TIME_MISSING` | 状态报告缺少可用于排序的 `CreDtTm` |
| `STATUS_REPORT_EMPTY` | 状态报告没有完整交易状态 |
| `STATUS_MESSAGE_ID_DUPLICATE` | 多份输入使用相同状态报告消息 ID |
| `STATUS_EVENT_DUPLICATE` | 同一消息、时间、ID 和状态被重复记录 |
| `STATUS_TIMELINE_CONFLICT` | 同一时间出现两个不同的交易状态 |
| `TERMINAL_STATUS_REGRESSION` | `ACSC` 或 `RJCT` 后又出现不同状态 |
| `STATUS_AMOUNT_MISMATCH` | 状态报告 `OrgnlInstdAmt` / `OrgnlIntrBkSttlmAmt` 与付款金额不同 |
| `STATUS_CURRENCY_MISMATCH` | 状态报告原始币种与付款币种不同 |
| `STATUS_CODE_INVALID` | 状态码不受支持 |
| 孤立状态 | 状态报告中的 `EndToEndId` 没有对应付款 |

## 用户动作

- `AWAITING_STATUS`：请求状态报告；
- `IN_PROGRESS`：等待下一份状态或再次查询；
- `SETTLED`：归档为结算证据；
- `REJECTED`：查看原因，决定是否使用新的 `EndToEndId` 重发；
- `STATUS_CONFLICT`：暂停自动完成，人工核对冲突状态；
- `UNKNOWN_STATUS`：先修正未知状态码，不能按已结算处理。

## MoonBit API

```moonbit
let report = @moonpay_flow.status_timeline_report(
  payment_xml,
  [status_xml_1, status_xml_2],
)
println(report.to_json())
```

主要字段：

- `message_count`
- `event_count`
- `cases`
- `orphan_status_ids`
- `orphan_events`
- `diagnostics`
