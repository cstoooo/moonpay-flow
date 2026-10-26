# 跨账期退回与冲正关联规则

## 为什么不能只看净额

同一 `EndToEndId` 下的流水可能包含：

- 原始付款；
- 部分退回；
- 后续补退；
- 退回被银行冲正；
- 原始付款被整体冲正；
- 历史中缺少原始付款。

只看“借记减贷记”的净额无法判断某一笔冲正到底作用在原始付款还是某笔退款上，也无法区分“最终全额退回”和“全额退回后又被冲正”。因此项目新增 `return-ledger`，以流水关联账本作为退回和冲正的权威判断入口。

## 支持的流水字段

当前从 `camt.053.001.08` 解析：

- `Ntry/NtryRef`
- `Ntry/AcctSvcrRef`
- `Ntry/BookgDt/Dt`、`Ntry/BookgDt/DtTm`
- `Ntry/CdtDbtInd`
- `Ntry/RvslInd`
- `Ntry/Amt` 和 `@Ccy`
- `Ntry/OrgnlNtryRef`
- `Ntry/OrgnlTxId`
- `Ntry/NtryDtls/TxDtls/Refs/EndToEndId`
- `Ntry/NtryDtls/TxDtls/Refs/TxId`
- `Ntry/NtryDtls/TxDtls/Refs/UETR`
- `Ntry/NtryDtls/TxDtls/Refs/OrgnlNtryRef`
- `Ntry/NtryDtls/TxDtls/Refs/OrgnlTxId`

## 关联优先级

冲正流水按以下顺序寻找被冲正流水：

1. `OrgnlNtryRef` 精确匹配 `NtryRef`；
2. `OrgnlTxId` 精确匹配 `TxId`；
3. 唯一 `UETR` 匹配；
4. 同 `EndToEndId`、同金额、同币种、相反借贷方向，并且候选唯一时进行推断。

如果存在多个候选，结果为 `REVERSAL_TARGET_AMBIGUOUS`，不会任选其中一条。命名了原始参考但历史中找不到时，结果为 `REVERSAL_REFERENCE_NOT_FOUND`。

## 历史完整性边界

系统只有在提供的流水中观察到与付款金额一致的原始付款流水时，才输出 `PAID`、`PARTIALLY_RETURNED`、`FULLY_RETURNED`、`PAYMENT_REVERSED` 等确定状态。

出现以下情况时输出 `EVIDENCE_INCOMPLETE`：

- 只提供退款或冲正流水，缺少原始付款流水；
- 原始付款流水合计小于付款金额；
- 冲正对象无法唯一确定。

此时 `postedPayment`、`effectiveRefund`、`remaining` 输出 `null`，不会根据净额猜测“部分退回”或“全额退回”。

## 案例一：跨日部分退回

输入：

```text
2026-10-01  原始付款  DBIT 100.00 EUR  NtryRef=PAY-100
2026-10-02  部分退回  CRDT  20.00 EUR  NtryRef=RET-20
```

运行：

```bash
moon run cmd/main -- return-ledger \
  fixtures/returns_pain001.xml \
  fixtures/returns_day1.xml \
  fixtures/returns_day2_partial.xml
```

输出：

```text
state=PARTIALLY_RETURNED
Posted payment: 100.00
Effective refund: 20.00
Remaining: 80.00
crossPeriod=true
```

## 案例二：跨日补足全额退回

继续增加第三天：

```text
2026-10-03  剩余退款  CRDT 80.00 EUR  NtryRef=RET-80
```

输出：

```text
state=FULLY_RETURNED
Effective refund: 100.00
Remaining: 0.00
```

## 案例三：退款被冲正

在案例二基础上增加：

```text
2026-10-04  RvslInd=true
            DBIT 80.00 EUR
            NtryRef=REV-RET-80
            OrgnlNtryRef=RET-80
```

关联结果：

```text
RET-80 -> REVERSAL_OF_REFUND -> REV-RET-80
linkQuality=EXPLICIT
```

最终账本：

```text
原始付款            100.00
有效退款             20.00
冲正后的剩余待退      80.00
state=PARTIALLY_RETURNED
```

这条链不能被错误地解释为 `FULLY_RETURNED`。

## 案例四：历史不完整

只提供 2026-10-02 的 20.00 退回流水，不提供原始付款：

```text
state=EVIDENCE_INCOMPLETE
postedPayment=null
effectiveRefund=null
remaining=null
[RETURN_HISTORY_INCOMPLETE]
```

用户动作：加载原始付款所在账期，不能根据单笔退回直接判断部分退回或全额退回。

## 状态定义

| 状态 | 含义 |
| --- | --- |
| `NOT_POSTED` | 没有找到对应流水 |
| `PAID` | 原始付款已观察，当前没有有效退款 |
| `PARTIALLY_RETURNED` | 有效退款大于 0，且剩余金额大于 0 |
| `FULLY_RETURNED` | 有效退款等于有效付款 |
| `PAYMENT_REVERSED` | 原始付款被完整冲正，且不存在有效退款 |
| `EVIDENCE_INCOMPLETE` | 原始付款或冲正关联证据不足 |
| `CONFLICT` | 金额超额、目标歧义或借贷关系冲突 |

## CLI

```bash
moon run cmd/main -- return-ledger \
  fixtures/returns_pain001.xml \
  fixtures/returns_day1.xml \
  fixtures/returns_day2_partial.xml \
  fixtures/returns_day3_final.xml \
  fixtures/returns_day4_refund_reversal.xml \
  --format json
```
