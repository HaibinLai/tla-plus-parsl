# Parsl TLA+ 抽象实现计划

## 依据和边界

第一版以 Babuji 等人的 Parsl 论文（论文中的 DataFlowKernel 架构图和 HTEX
执行路径）为基线，并以当前上游源码为行为依据。论文只提供高层组件关系，不能
直接当作逐行实现规范；源码中实际的任务状态定义和消息处理优先级更高。

本计划先固定一个执行配置：`DataFlowKernel -> HighThroughputExecutor ->
Interchange -> Manager/worker pool -> ExecutionProvider`。其他 executor 复用同一
`ParslExecutor.submit()` 抽象，不在第一版同时建模。

## 分阶段工作

### 1. 建立行为基线

整理源码到一张状态/消息表，作为 TLA+ 注释和测试依据：

- 状态枚举包含 `pending`, `launched`, `running`, `running_ended`, `exec_done`,
  `failed`, `dep_fail`, `fail_retryable`, `memo_done`, `joining`；需要特别保留源码的
  语义区别：`running`/`running_ended`主要是监控侧观察到的状态，DFK 的典型成功路径
  是 `pending -> launched -> exec_done`。
- DFK 的关键路径：依赖计数与 future 解包、依赖失败传播、memoizer 查询、向
  executor 提交、executor future 回调、成功/异常完成。
- HTEX：executor 把任务放入 client-to-interchange 队列；interchange 按优先级放入
  pending queue，按 manager capacity 分发；manager 用 heartbeat 注册、接收任务、
  返回结果；丢失 manager 时为其未完成任务生成失败结果。
- Provider/Strategy：`submit/status/cancel` 资源接口，以及
  `min_blocks/init_blocks/max_blocks/parallelism` 驱动的 scale-out；HTEX 对空闲块
  的 scale-in 只在 manager 无任务且达到 idle 条件时发生。

### 2. TLA+ MVP（先验证安全性）

用有限集合替代 Python 对象、Future、序列化 payload 和真实时间：

- 常量：任务集合、`DEPS` DAG、executor、manager、每个 manager 的容量、重试上限、
  provider block 上限。
- 任务记录：状态、依赖、选择的 executor、分配的 manager、尝试次数、结果/异常。
- 组件状态：DFK task table、ready/pending 队列、interchange queue、manager 空闲
  容量和 in-flight 任务、provider target/actual blocks。
- 动作：`DependencyCheck`、`MemoizationLookup/Complete`、`Enqueue`、
  `ExecutorSubmit`、`InterchangeDispatch`、`ManagerAccept`、`TaskSuccess`、
  `TaskRetry`、`DependencyFailure`、`TaskPermanentFailure`、provider
  `ScaleOut/BlockRunning/ScaleIn`。

第一版只使用离散事件，不模拟网络字节、Python 调度线程和墙钟时间；这能让 TLC
穷举所有组件交错顺序。

### 3. 必须通过的性质

先检查 invariant，再在明确加入公平性后检查 liveness：

1. `TypeOK`：所有状态、队列、映射和计数都落在有限域内。
2. 依赖安全：任务进入 `launched/running` 前，所有依赖必须为成功或 memo 完成；
   失败依赖只能导致 `dep_fail`，不能执行用户函数。
3. 单次完成：一个 task id 不能同时出现在成功和失败终态；终态不再重新提交。
4. 容量安全：一个 manager 的 in-flight 数不超过 capacity；interchange 只向
   active、非-draining、仍有 heartbeat 的 manager 分发。
5. 重试边界：尝试次数不超过 `MAX_RETRIES + 1`，最终失败不会再次进入队列。
6. memoization：命中只产生 `memo_done`/结果，不占用 manager 或 provider slot。
7. scaling 安全：actual blocks 不超过 max，不低于 min；scale-in 不杀掉仍有任务的
   block（HTEX 的强制 scale-in 作为单独配置测试）。
8. 在 DAG 无环、manager 最终可用且公平调度的假设下，所有可成功任务最终达到
   `exec_done` 或 `memo_done`。

### 4. 与 Python Parsl 示例对照

保留一个很小的 `A -> {B,C} -> D` Python workflow：它只验证任务图和结果依赖，
不把 Python 执行结果直接当作 TLA+ 证明。另写一个 trace adapter（先用手工事件，
再可选接 Parsl logging/monitoring）把 `task_id/status/executor` 投影成 TLA+ 事件，
用于检查“实现轨迹满足抽象状态机”，而不是声称 TLC 已证明 Python 实现正确。

### 5. 第二版扩展（MVP 稳定后）

- DataManager/staging：把文件传输建模为带依赖的内部 app，覆盖 stage-in/stage-out
  失败和重试。
- `join_app`：加入 `joining` 状态和 inner futures 全部完成/失败传播。
- manager 心跳与版本不匹配、drain、executor bad state。
- Monitoring：只建模“状态事件最终写入监控流”，不建模数据库和 UDP/ZMQ 细节。
- 动态任务图：允许运行中的 app 产生新任务；单独设置状态空间上限。

## 验收方式

每个阶段都提供独立 `.cfg`：正常成功、memo 命中、一次重试后成功、永久失败、
manager 丢失、scale-out/in。CI 中运行 TLC invariant；对每个安全性质保留一个故意
违反该性质的变体，确认 TLC 能生成反例。最终 README 给出“源码组件 -> TLA+变量/动作
-> Python 示例”的映射表和复现实验命令。

## 主要源码入口

- `parsl/dataflow/states.py`, `parsl/dataflow/dflow.py`
- `parsl/executors/high_throughput/executor.py`
- `parsl/executors/high_throughput/interchange.py`
- `parsl/executors/high_throughput/process_worker_pool.py`
- `parsl/providers/base.py`, `parsl/jobs/strategy.py`
- `parsl/data_provider/data_manager.py`
