# Modeling goal and stopping rule

## Objective

Build a small, executable TLA+ abstraction of Parsl that is useful for finding
high-probability protocol errors. The model is deliberately bounded: it is not
intended to reproduce every Python implementation detail or every scheduler
backend.

The primary focus is communication. The secondary focus is asynchronous
interleaving and terminal-state handling. Other Parsl behavior is modeled only
when it is needed to make those two areas meaningful.

## Priority order

### 1. Communication (primary)

The communication audit covers the source paths that carry task and result
state across process or thread boundaries:

- HTEX/ZeroMQ task, result, command, ACK, retry, duplicate, and late-message paths;
- `TasksOutgoing`, `ResultsIncoming`, and `CommandClient` send/receive and close races;
- manager/worker registration, heartbeat, loss, and reconnect behavior;
- malformed frame, frame-count, task-ID, serializer, and route validation;
- ownership of a result when a send fails (requeue, explicit failure, or loss);
- correlation among logical task, physical attempt, message, Future, and monitoring row.

Each high-confidence boundary should have a bounded Current/Fixed TLA+ model and,
when the behavior is concrete, a runtime probe using the installed Parsl code and
in-process ZMQ.

### 2. Asynchronous behavior (secondary)

The async audit covers only interleavings that can change observable correctness:

- callback execution while a live dictionary, list, or Future registry is mutated;
- cancellation and timeout racing with completion, retry, or late delivery;
- shutdown/close racing with queued work, callbacks, or monitoring finalization;
- executor/provider failure fan-out and preservation of independent Futures;
- ordering between Future terminal state, result publication, and monitoring state.

The model should separate logical tasks from physical attempts and should make
terminal-state stability and stale-result handling explicit.

### 3. Supporting abstractions

Serialization, Python object contents, staging/file bytes, heartbeat clocks,
providers, and `join_app` are included only to the extent that they affect the
communication or asynchronous contracts above. Existing models remain valid;
new work should prefer cross-layer refinements over duplicate single-component
models.

## Required evidence for a new finding

Do not add a model merely because an implementation looks unusual. A new finding
must have all of the following:

1. a precise source location and an identified state transition;
2. a small runtime reproduction when the boundary is executable;
3. a Current configuration with a meaningful invariant violation or counterexample;
4. a Fixed configuration that expresses the candidate safe protocol;
5. documentation and a bug-ledger entry when the behavior is a concrete risk.

Duplicate coverage and speculative findings are out of scope.

## Completion criteria

This project is considered complete when:

- the primary task/result/command/ACK/heartbeat communication paths have been
  source-audited at the protocol boundaries listed above;
- the important asynchronous races in those paths have bounded models;
- logical task, physical attempt, message correlation, Future state, and
  monitoring terminality are represented where relevant;
- every new model has a targeted runtime/TLC check, and the full smoke suites pass;
- the repository contains a final coverage matrix, bug ledger, and reproduction guide.

After these criteria are met, no additional model is added unless the project
scope is explicitly changed. The goal is a useful finite audit, not exhaustive
modeling of all Parsl source files.

## Concrete audit inventory

The source tree used for this audit is `/tmp/parsl-source/parsl`. The following
inventory is the planned review set. Paths are relative to that directory. The
counts are estimates for deep protocol review, not a claim that every listed
file needs a new model.

### A. Primary communication set: 31 files

```text
executors/high_throughput/executor.py
executors/high_throughput/interchange.py
executors/high_throughput/process_worker_pool.py
executors/high_throughput/zmq_pipes.py
executors/high_throughput/manager_record.py
executors/high_throughput/manager_selector.py
executors/high_throughput/monitoring_info.py
executors/high_throughput/probe.py
executors/high_throughput/mpi_executor.py
executors/high_throughput/mpi_resource_management.py
executors/high_throughput/mpi_prefix_composer.py
executors/base.py
executors/execute_task.py
executors/status_handling.py
executors/threads.py
executors/flux/executor.py
executors/workqueue/executor.py
executors/taskvine/executor.py
executors/radical/executor.py
executors/globus_compute.py
dataflow/dflow.py
dataflow/futures.py
dataflow/taskrecord.py
dataflow/states.py
dataflow/errors.py
serialize/facade.py
serialize/base.py
serialize/concretes.py
serialize/errors.py
app/futures.py
app/python.py
```

This pass covers task/result framing, serializer boundaries, attempt
correlation, ACK/retry, duplicate and stale frames, close behavior, and result
ownership after a failed send.

### B. Asynchronous and lifecycle set: 20 entries

```text
dataflow/dflow.py                 dataflow/futures.py
dataflow/memoization.py           dataflow/dependency_resolvers.py
dataflow/rundirs.py               app/app.py
app/bash.py                       app/errors.py
executors/base.py                 executors/status_handling.py
executors/high_throughput/process_worker_pool.py
executors/high_throughput/interchange.py
executors/flux/execute_parsl_task.py
executors/flux/flux_instance_manager.py
executors/taskvine/manager.py     executors/taskvine/factory.py
executors/workqueue/parsl_coprocess.py
monitoring/remote.py              monitoring/monitoring.py
```

These entries are reviewed for callback mutation, cancellation/timeout races,
shutdown ordering, failure fan-out, and Future/monitoring terminality. Shared
files are counted once; the mandatory communication plus async set is about 42
unique source files.

### C. Monitoring and persistence set: 14 files

```text
monitoring/db_manager.py          monitoring/message_type.py
monitoring/types.py               monitoring/monitoring.py
monitoring/remote.py              monitoring/radios/base.py
monitoring/radios/htex.py         monitoring/radios/multiprocessing.py
monitoring/radios/zmq.py          monitoring/radios/zmq_router.py
monitoring/radios/udp.py          monitoring/radios/udp_router.py
monitoring/radios/filesystem.py   monitoring/radios/filesystem_router.py
```

### D. Supporting data-transfer set: 10 files

```text
data_provider/data_manager.py     data_provider/staging.py
data_provider/files.py             data_provider/http.py
data_provider/ftp.py               data_provider/rsync.py
data_provider/globus.py            data_provider/zip.py
data_provider/file_noop.py         data_provider/__init__.py
```

Only transfers that gate task readiness or result delivery are in scope.

### E. Provider adapter sweep: 13 implementation files

```text
providers/base.py                 providers/cluster_provider.py
providers/local/local.py          providers/slurm/slurm.py
providers/pbspro/pbspro.py        providers/torque/torque.py
providers/lsf/lsf.py              providers/condor/condor.py
providers/grid_engine/grid_engine.py
providers/aws/aws.py              providers/azure/azure.py
providers/googlecloud/googlecloud.py
providers/kubernetes/kube.py      providers/errors.py
```

This sweep covers every currently shipped provider family. Provider templates
and package `__init__.py` files are reference-only unless they change a message
shape or lifecycle contract.

### Expected file changes

The planned source review is approximately 70–80 file entries, with roughly
42 unique files in the mandatory communication/async pass and the remaining
entries providing monitoring, staging, and provider context. The expected
repository delta is smaller:

- 6–10 new model families, normally one `.tla` plus 2–3 `.cfg` files each;
- 6–10 focused runtime probe files;
- 5–10 updates across documentation, bug ledger, coverage matrix, and smoke scripts.

If a reviewed source file has no communication or asynchronous risk, it is
recorded as reviewed and does not generate a model or speculative bug entry.

## Explicit non-goals

- exhaustive line-by-line modeling of all Parsl backends;
- unbounded Python heap, network scheduling, or OS thread behavior;
- claiming that a passing bounded TLC run proves the entire Parsl implementation;
- continuing to expand the model solely to increase file or case counts.
