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
worker loss, executor loss, stale results, final-result acceptance, and an abstract
serialize/send/receive/decode path for task messages before worker dispatch.
Worker result messages use the same abstract lifecycle before a Future is resolved, including
the possibility that a failed attempt's late result is rejected as stale.
Task payloads now distinguish callable serializability from argument/closure serializability;
an unencodable payload fails before worker dispatch and follows the bounded retry path.
The data path now distinguishes input stage-in from output stage-out and records a transferred
content token for declared output files.
The bounded `ParslTime.cfg` model adds logical ticking, heartbeat age, attempt start time, and
timeout guards so TLC can explore timing-dependent worker loss and retry behavior.
`ParslMonitoring.cfg` adds a focused asynchronous monitoring/database status model with a
monotonic per-task write version, and checks that persisted terminal statuses never precede the
corresponding Future outcome.
`ParslSubmitFailure.cfg` adds a focused executor/provider boundary model in which an active
provider block does not imply that the executor accepts a new task submission.
`ParslProviderFailure.cfg` covers an active block becoming failed, clearing capacity, and
requesting a replacement block without producing a negative target count.
`ParslMessaging.cfg` adds explicit bounded task/result wire queues and serialized-envelope
states, with `MessageSafety` checking that transport progress cannot bypass encoding or decode.
Its object-graph constants model callable, argument, closure, and nested referenced objects;
`ObjectGraphSafety` checks that a valid envelope cannot contain an unencodable object.
`ParslMessageLoss.cfg` adds bounded task/result transport loss and checks cleanup plus retry
behavior after a message is dropped.
`ParslMessageDuplicate.cfg` adds receiver-side duplicate delivery and explicit discard before
decode, preventing a duplicate envelope from resolving a Future twice.
`ParslFileContent.cfg` adds a deterministic symbolic content token for output files and checks
that stage-out transfers the token only after successful task completion.
`ParslFileCorruptionSmall.cfg` adds a minimal corrupted-output and repair/retransfer path;
the larger three-task corruption configuration is retained for future state-space reduction.
`ParslJoinInvalid.cfg` covers the `join_app` type-error branch. `SpecFair` now uses strong
fairness for logical/attempt progress so duplicate-message discard loops cannot starve work.
`ParslRegistration.cfg` adds explicit HTEX manager registration before a worker can receive
dispatches or emit heartbeats.
`ParslRegistrationFailure.cfg` explores manager startup failure before registration and checks
that no worker binding is created from the failed manager.
`ParslIdleManagerTimeout.cfg` covers heartbeat expiry for an idle registered manager and clears
the associated provider/executor capacity.
`ParslExecutorDrain.cfg` models an executor entering `draining`, rejecting new submissions while
allowing existing attempts to finish, followed by explicit recovery.
`MessageCorrelationSafety` now checks that queued, received, duplicate, and consumed envelopes
remain associated with their logical task and retry attempt.

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
9. Wire/envelope safety: task and result messages cannot skip serialization, transport, or
   decode states, and failed attempts cannot leave a deliverable result envelope behind.

The no-failure configuration adds `EventuallySettled` under `WF_vars(NextCore)` fairness.

## Planned extensions

After the MVP is stable, possible extensions are:

- richer DataManager/staging behavior, including stage-in/stage-out failure and checksums;
- bounded message reordering and message correlation IDs;
- richer `join_app` behavior beyond the bounded inner-Future set and invalid-return branch now modeled;
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
