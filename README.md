# Parsl 的小型 TLA+ 抽象

这是一个可供 TLC 穷举的 Parsl 抽象模型。模型的核心不是逐行翻译 Python，而是
保留会影响可观察行为的边界：DFK 的逻辑任务和 Future、executor 提交、worker
执行、provider 资源、重试、memoization、数据就绪和迟到结果。

依据包括 Parsl 论文和当前源码：

- `parsl/dataflow/states.py`：任务状态；DFK 的典型成功路径是
  `pending -> launched -> exec_done`，`running`/`running_ended`主要是监控侧状态。
- `parsl/dataflow/dflow.py`：依赖解包、依赖失败、memoizer、executor 提交和完成回调。
- `parsl/executors/high_throughput/executor.py`：HTEX executor、任务提交、provider
  scaling 和 manager capacity。
- `parsl/executors/high_throughput/interchange.py`：pending queue、manager 注册、
  heartbeat、任务派发、结果转发和 manager 丢失。
- `parsl/executors/high_throughput/process_worker_pool.py`：worker idle/busy、任务
  执行和结果消息。
- `parsl/providers/base.py` 与 `parsl/jobs/strategy.py`：provider 的 submit/status/
  cancel 接口和扩缩容策略。
- `parsl/data_provider/data_manager.py`：数据 staging 的抽象边界。

## 两层状态机

逻辑任务是 workflow 节点/Future，状态为：

```text
pending -> staging -> ready -> queued -> running -> succeeded
                                      \\-> retry_wait -> queued
                                      \\-> failed
ready --memoization hit--> memoized
```

物理尝试由二元组 `(task, retryIndex)` 标识，例如 `(A,0)` 和 `(A,1)` 是不同的
执行尝试。尝试状态为：

```text
absent -> submitted -> dispatched -> running -> succeeded
                                             \\-> failed
                                             \\-> timed_out
                                             \\-> lost
failed/timed_out/lost --late result--> stale
```

旧尝试进入 `stale` 后不再修改逻辑任务的 Future、结果或终态。这使得 retry + late
result、worker loss、timeout 和 duplicate completion 可以同时出现在同一个状态空间。

provider 使用 `none/requested/active/failed/cancelled`，worker 使用
`idle/busy/failed`。`RequestAllocation`、`AllocationSucceeds` 和 `AllocationFails`
分别抽象 provider 的资源申请、资源出现和申请失败；只有 active provider 的 idle
worker 才能接收 attempt。memoization 命中不创建 attempt，也不占用 worker。

## TLC

需要 Java 和 `tla2tools.jar`。在本目录运行：

```bash
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslAbstract.cfg ParslAbstract.tla
```

配置文件使用 `A -> {C}`、`B -> {C}` 的三任务 DAG，两个 executor、两个 worker、
一次重试。改变 `MEMOIZED` 可以检查缓存命中；将 `AllocationSucceeds`/`AllocationFails`
保留为非确定动作可以探索 provider failure；`AttemptTimeout` 后的 `LateResult`
可以探索迟到结果。

模型检查的 invariant 是：`TypeOK`、依赖安全、终态稳定、重试上限、worker 单任务
容量、running attempt 的 executor/worker 合法性、attempt identity、Future 结果一致性
、worker/attempt 双向绑定和 stale-result 安全性。

实际检查结果（TLC 2.19，Java 17，2026-09-28）：

- `ParslAbstract.cfg`：1,247,270 states generated，243,593 distinct states，深度 49，
  全部 invariant 通过。
- `ParslMemo.cfg`：78,656 states generated，16,799 distinct states，memoization 路径
  全部 invariant 通过。
- `ParslNoFailures.cfg`：1,306 states generated，409 distinct states；在
  `WF_vars(NextCore)` 公平性下 `EventuallySettled` 通过。

命令分别是：

```bash
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslAbstract.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config ParslMemo.cfg ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config ParslNoFailures.cfg ParslAbstract.tla
# 等价的最小入口：
java -cp tla2tools.jar tlc2.TLC -deadlock -config parsl.cfg parsl.tla
```

## 源码到模型的动作映射

| TLA+ action | Parsl 概念 | 当前源码位置 |
| --- | --- | --- |
| `BeginStaging` / `FinishStaging` | data readiness/staging | `parsl/data_provider/data_manager.py` |
| `DependencyCheck` | 等待依赖并解包 Future | `DataFlowKernel._launch_if_ready_async` in `parsl/dataflow/dflow.py` |
| `MemoizationHit` | cache hit 直接完成 Future | `DataFlowKernel.launch_task` in `parsl/dataflow/dflow.py` |
| `SubmitAttempt` | 选择 executor 并调用 `submit` | `DataFlowKernel.launch_task` |
| `DispatchAttempt` | interchange 把任务送给可用 manager | `Interchange.process_tasks_to_send` |
| `StartAttempt` / `AttemptSuccess` | worker 执行并返回结果 | `process_worker_pool.py`、`Interchange.process_manager_socket_message` |
| `AttemptFailure` / `RetryTask` | retryable failure 和重新提交 | `DataFlowKernel.handle_exec_update` |
| `WorkerFailure` / `LateResult` | manager/worker 丢失及旧 attempt 结果 | `Interchange.expire_bad_managers`；抽象中显式建模 stale result |
| `RequestAllocation` / `AllocationSucceeds` / `AllocationFails` | provider submit/status 及 block 出现/失败 | `ExecutionProvider`、`BlockProviderExecutor.scale_out_facade` |
| `CancelAllocation` | 空闲 block 的 scale-in | `HighThroughputExecutor.scale_in`、`jobs/strategy.py` |

TLA+ 对 `LateResult` 的处理是一个明确的抽象决定：当前 attempt 已经替代旧 attempt
后，旧结果只能把物理 attempt 标成 `stale`，不能覆盖逻辑 Future。这是为了专门探索
retry + late result，而不是断言所有 Parsl executor 都以完全相同的消息顺序实现。

## 代表性事件轨迹

正常路径（省略不影响任务的 provider 事件）：

```text
DependencyCheck(A), Enqueue(A), RequestAllocation(E1), AllocationSucceeds(E1,W1),
SubmitAttempt(A,E1), DispatchAttempt(A,0,W1), StartAttempt(A,0,W1),
AttemptSuccess(A,0,W1),
DependencyCheck(B), Enqueue(B), SubmitAttempt(B,E1), DispatchAttempt(B,0,W1),
StartAttempt(B,0,W1), AttemptSuccess(B,0,W1),
BeginStaging(C), FinishStaging(C), DependencyCheck(C), Enqueue(C), ...,
AttemptSuccess(C,0,W1)
```

retry + late result 路径：

```text
AttemptFailure(A,0,W1), RetryTask(A), SubmitAttempt(A,E1),
DispatchAttempt(A,1,W2), StartAttempt(A,1,W2),
LateResult(A,0),                 [0m# (A,0) -> stale，不改变 Future(A)
AttemptSuccess(A,1,W2)           # Future(A) 只接受 attempt 1 的结果
```

源码和抽象之间有两个值得注意的差别：当前 Parsl 的 `States.running` 主要由监控侧
观察，DFK 的常见成功状态是 `pending -> launched -> exec_done`；另外，真实 HTEX
interchange 的 manager 心跳、批量 capacity 和消息队列在模型中压缩成离散的
`DispatchAttempt`/`WorkerFailure` 事件。模型还专门禁止带有 in-flight attempt 的
provider scale-in，以避免把一个仍在提交或运行的资源块无声删除。

## 对应的 Parsl 示例

`parsl_demo.py` 以真实 Parsl 产生同一 DAG。它用于说明抽象映射，不是 TLC 的证明
对象：TLA+ 中的 `result` 只代表结果已被 DFK 接受，不模拟 Python 对象、序列化或网络。

```bash
python3 -m pip install parsl
python3 parsl_demo.py
```

## 已知抽象

没有建模真实 ZMQ 字节流、Future 对象内容、Python 函数、文件名、墙钟超时、manager
心跳时间和数据库监控格式。它们可在第二版增加；当前模型只保留这些机制对任务状态、
资源容量和结果接受规则的影响。
