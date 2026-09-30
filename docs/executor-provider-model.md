# Executor and provider model map

The executor abstraction is intentionally split into local execution and provider-backed
execution. The main bounded model is ParslExecutorKinds.tla; focused models refine its
contracts for HTEX, MPI, Work Queue, TaskVine, Flux, Globus Compute, and provider families.

## Source hierarchy

| Source class/path | Model role |
| --- | --- |
| parsl/executors/threads.py::ThreadPoolExecutor | provider-free executor; local worker slots are immediately available |
| parsl/executors/high_throughput/executor.py::HighThroughputExecutor | manager/worker registration, task/result transport, heartbeat, and provider-backed slots |
| parsl/executors/high_throughput/mpi_executor.py::MPIExecutor | HTEX transport plus node/rank allocation and resource release |
| parsl/executors/workqueue/executor.py::WorkQueueExecutor | provider-backed submission and collector result lifecycle |
| parsl/executors/taskvine/executor.py::TaskVineExecutor | provider-backed submission and collector result lifecycle |
| parsl/executors/flux/executor.py::FluxExecutor | provider status and cancellation around a Flux job |
| parsl/executors/globus_compute.py::GlobusComputeExecutor | callback/result propagation without a local worker pool |
| parsl/executors/status_handling.py::BlockProviderExecutor | scale-out, scale-in, job/block ownership, status polling, drain, and bad-state cleanup |

In ParslExecutorKinds.tla, ProviderRequired(e) distinguishes the local path from manager
and provider-backed paths. workerSlots is the bounded resource capacity, resourceRequest
models a provider submission, and managerReady separates a provisioned block from a registered
worker manager. Admission requires a live provider when one is required, a ready manager for
remote executors, and a positive slot count.

## Safety contracts

The unified model checks:

- tasks are rejected when provider/manager/slot admission is not satisfied;
- a provider failure removes worker capacity and drains queued/running work;
- scale-in cannot remove capacity still occupied by a running task;
- local executors do not acquire provider state;
- unsupported resource specifications do not become accepted submissions;
- executor drain leaves no queued or running work.

The focused models then refine implementation-specific boundaries, including HTEX registration
and result frames, MPI rank allocation, Work Queue/TaskVine duplicate reports, Flux cancellation,
callback-based Globus/Radical Pilot results, and provider status/cancel shape validation.
Their current/fixed configurations are included in the TLC sweep and corresponding runtime
probes are listed in the bug ledger.

`ParslProviderExecutorTimed.tla` is the smallest dynamic provider-backed composition. It models
one provider block, one registered manager, one worker slot, heartbeat expiry, provider failure,
logical retry, and a late report from the old physical attempt. The current branch accepts the
late report after `provider_lost` and TLC finds `TerminalCauseSafety` after 1,222 generated / 626
distinct states. The fixed branch records the report as stale and passes admission, capacity,
retry-bound, terminal-cause, and stale-result invariants with 2,162 generated / 720 distinct
states at depth 14. This complements `ParslExecutorKinds.tla`: the latter checks the static
contract matrix across executor families, while this model checks the dynamic provider/manager
loss boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProviderExecutorTimedCurrent.cfg models/executors/ParslProviderExecutorTimed.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProviderExecutorTimedFixed.cfg models/executors/ParslProviderExecutorTimed.tla
```

Globus Compute has a distinct concurrency boundary: GlobusComputeExecutor.submit temporarily
mutates one shared SDK Executor's resource specification and endpoint configuration before
calling submit, then restores defaults in a finally path. ParslGlobusComputeSubmitRace models
the override/submit/restore critical section and shows that overlapping submissions can observe
the other task's configuration. The fixed variant serializes the critical section; the runtime
probe is tests/test_globus_compute_submit_race_runtime.py.

`ParslGlobusComputeResourceSpecType.tla` covers the preceding admission boundary: the current
wrapper calls `.pop()` on a truthy per-submit specification before checking that it is a mapping,
so a scalar leaks `AttributeError`. The fixed branch rejects malformed input before SDK state is
changed, with a direct runtime probe against the wrapper.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeResourceSpecTypeCurrent.cfg models/executors/ParslGlobusComputeResourceSpecType.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeResourceSpecTypeFixed.cfg models/executors/ParslGlobusComputeResourceSpecType.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_compute_resource_spec_type_runtime.py -v
```

`ParslHtexHeartbeatVersion.tla` combines two HTEX admission boundaries that are often analyzed
separately. A version-mismatched registration and a manager whose heartbeat age reaches the
expiry threshold both close the interchange and queue a fatal result. The fixed submit action
blocks immediately on `failureSeen`, `fatalPending`, or a non-ready manager; the current action
can accept a task in that window. TLC finds the current admission counterexample and checks
100,001 fixed states.

`ParslProviderProvisioningLifecycle.tla` models a provider block across request, provisioning,
failure, retry, stale status polling, dispatch, completion, and scale-in. A poll from an older
generation can arrive after provider failure; the fixed branch ignores it and checks 100,001
states while preserving retry, admission, and scale-in safety.

`ParslProviderMultiBlockOwnership.tla` extends this to two independently owned blocks and two
tasks. It checks that scale-in removes only idle blocks, running tasks retain active ownership,
and stale polls cannot revive a failed generation; the fixed configuration checks 100,001 states.

`ParslProviderThreeBlockOwnership.tla` extends the same protocol to three blocks and three
logical tasks. It adds an explicit one-task-per-block capacity invariant while preserving failure,
retry, stale-poll, ownership, and idle-only scale-in checks.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProviderThreeBlockOwnershipCurrent.cfg models/executors/ParslProviderThreeBlockOwnership.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProviderThreeBlockOwnershipFixed.cfg models/executors/ParslProviderThreeBlockOwnership.tla
```

`ParslManagerLivenessPool.tla` provides the small three-manager pool refinement. Heartbeat expiry
marks M1 unavailable; a lost task can retry on M2 or M3, while admission must not select the
expired manager.
The current branch also accepts a late result from the expired manager, whereas the fixed branch
classifies it as stale. `LiveManagerAdmission` and `NoLateResultAcceptance` are checked in both
configurations.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslManagerLivenessPoolCurrent.cfg models/executors/ParslManagerLivenessPool.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslManagerLivenessPoolFixed.cfg models/executors/ParslManagerLivenessPool.tla
```
