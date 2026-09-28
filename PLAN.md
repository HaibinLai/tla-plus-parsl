# Plan for the Parsl TLA+ Abstraction

## Basis and scope

The first version uses the Parsl paper's DataFlowKernel architecture and HTEX execution path
as the conceptual baseline, and the current upstream source as the behavioral reference. The
paper describes component relationships at a high level; source behavior takes precedence when
the two differ.

The primary configuration is:

```text
DataFlowKernel -> HighThroughputExecutor -> Interchange -> Manager/worker pool
               -> ExecutionProvider
```

Other executors can reuse the same abstract submission boundary, but are not modeled in full
in the first version.

## Completed phases

### 1. Behavioral baseline

The source audit covered:

- DFK task states, dependency counting, Future unwrapping, dependency-failure propagation,
  memoization, executor submission, retries, and completion callbacks.
- HTEX client-to-interchange queues, manager capacity, registration, heartbeats, result return,
  and manager loss.
- Provider `submit/status/cancel`, block lifecycle, and scaling parameters.
- DataManager as the boundary for data readiness/staging.

### 2. Executable safety model

The model uses finite sets for tasks, executors, workers, dependencies, retry count, and block
capacity. Python callables, Futures, serialized payloads, and wall-clock time are abstracted.

The central design choice is to keep logical tasks and physical attempts separate:

```text
Task A
 ├── Attempt(A, 0)
 ├── Attempt(A, 1)
 └── Attempt(A, 2)
```

The model includes task/Future state, dependency gating, executor assignment, worker binding,
provider allocation and failure, scale-in, memoization, data readiness, retries, timeout,
worker loss, executor loss, stale results, and final-result acceptance.

### 3. Checked properties

The safety configurations check:

1. `TypeOK` for all finite domains and state mappings.
2. Dependency safety: a task cannot run before all dependency Futures resolve.
3. Terminal-state stability: a completed logical task remains resolved.
4. Retry bounds.
5. One-at-a-time worker capacity and bidirectional worker/attempt binding.
6. Valid executor/worker assignment for running attempts.
7. Attempt identity and Future result consistency.
8. Stale-result safety: an old attempt cannot overwrite a newer logical result.

The no-failure configuration adds `EventuallySettled` under `WF_vars(NextCore)` fairness.

## Planned extensions

After the MVP is stable, possible extensions are:

- richer DataManager/staging behavior, including stage-in/stage-out failure;
- `join_app` and the `joining` state;
- manager heartbeat timeout, version mismatch, drain, and executor bad state;
- monitoring as an abstract eventual event stream;
- dynamic task creation while a workflow is running;
- additional executor/provider-specific models.

## Validation workflow

Each meaningful stage should have its own commit and TLC configuration. The repository should
retain normal-success, memoization-hit, retry-success, permanent-failure, provider-failure,
worker-loss, scale-in/out, and late-result scenarios. For each safety property, a deliberately
broken variant can be added later to ensure TLC produces a counterexample.

The model is intentionally a bounded protocol abstraction. A passing TLC run means that the
specified finite abstraction satisfies the listed properties; it does not prove that every
implementation detail of Parsl is correct.
