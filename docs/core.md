# Core workflow models

The shared `ParslAbstract` model covers logical task/Future state, physical attempts, dependency
blocking, workers, executors, providers, retries, memoization, data readiness, and stale results.

Files live in [`models/core/`](../models/core/). Start with `ParslAbstract.tla` and its scenario
configurations such as `ParslNoFailures.cfg`, `ParslTime.cfg`, and `ParslProviderFailure.cfg`.

`ParslDataReadyExecution.tla` is the cross-layer data-readiness model: stage-in captures a source
version, transfers bounded chunks, publishes a ready DataFuture, and only then admits a dependent
task. The current branch can publish a stale captured version if the source changes during
transfer; the fixed branch marks the transfer stale and retries. The real byte-level dependency
bridge is `tests/test_datafuture_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataReadyExecutionCurrent.cfg models/core/ParslDataReadyExecution.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataReadyExecutionFixed.cfg models/core/ParslDataReadyExecution.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_runtime.py -v
```

`ParslDataTransferDependencyFailure.tla` closes the stage-out/dataflow loop.  A producer finishes,
the DataManager transfers a bounded output in chunks, and a DataFuture becomes ready only after
publication.  If the stage-out fails, the consumer remains blocked and is completed as a
dependency failure; it never executes against a partial file.  The Current configuration permits
consumer admission on a failed DataFuture and TLC finds the counterexample.  The Fixed
configuration checks no-partial-execution, failure propagation, publication atomicity, and terminal
result consistency.  The runtime bridge is `tests/test_datafuture_runtime.py`, including the
failed-output case where the consumer function is never called.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataTransferDependencyFailureCurrent.cfg models/core/ParslDataTransferDependencyFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataTransferDependencyFailureFixed.cfg models/core/ParslDataTransferDependencyFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_runtime.py -v
```

For a fast executable smoke check, `ParslAbstractSmoke.cfg` reduces the abstraction to one local
task, one worker, no dependencies, no retries, and no provider blocks. It is useful for validating
changes to the shared model before launching the much larger multi-task configuration.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslAbstractSmoke.cfg models/core/ParslAbstract.tla
```

`ParslAbstractJoinSmoke.cfg` is the corresponding join-focused smoke check. It keeps two inner
tasks and one outer join task while removing provider, file, monitoring, retry, and failure
branching. This gives a small regression target for the join state transitions before running the
full `ParslJoinSafety.cfg` composition.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslAbstractJoinSmoke.cfg models/core/ParslAbstract.tla
```

`ParslEndToEnd.tla` is the deliberately small integration model. It connects dependency release,
task serialization, wire delivery, worker execution, result delivery, retry/timeout, and late
results. `ParslEndToEnd.cfg` intentionally permits an old attempt to resolve the Future and TLC
finds a `StaleResultSafety` counterexample. `ParslEndToEndFixed.cfg` rejects that result as stale;
TLC checks 198 states with all invariants passing. The model also checks
`CurrentAttemptResultSafety`: a result arriving after the current physical attempt has timed out
or failed must not resolve the logical Future merely because its retry number still matches
`currentAttempt`. The current configuration reaches this counterexample in 23 states; the fixed
configuration classifies the result as stale. This complements the retry/timeout probes in
`tests/test_retry_timeout_runtime.py` while keeping logical tasks separate from physical attempts.

`ParslTaskStagingMonitoring.tla` combines producer task completion, chunked stage-out/DataFuture
publication, dependent-consumer admission, and asynchronous monitoring persistence. The current
configuration permits a success row (and a ready DataFuture) before all chunks are received;
the fixed configuration gates both observations on complete stage-out and checks 21 states.

`ParslPipeline.tla` composes the same boundaries with payload serialization, physical worker
attempts, retry/result correlation, output stage-out, DataFuture readiness, and monitoring
persistence. Its current configuration reaches the early-monitoring counterexample in 435
generated / 221 distinct states; the fixed configuration passes in 228 generated / 85 distinct
states at depth 22. `ParslPipelineSmoke.cfg` is the one-chunk/no-retry fixed check (32 generated /
16 distinct, depth 13). The action mapping follows `parsl/dataflow/dflow.py`,
`parsl/data_provider/data_manager.py`, `parsl/serialize/facade.py`, and the monitoring database
writer.

`ParslPipelineTimed.tla` is a deliberately smaller cross-layer composition for the timing and
monitoring boundary. It keeps a two-node logical DAG (`A -> B`), gives each physical attempt its
own deadline, models manager heartbeat expiry, retry admission, and late completion separately
from the logical task state, and sends terminal events through an explicit
`EmitStatus -> PersistStatus` queue. `ParslPipelineTimedCurrent.cfg` accepts a completion from an
attempt whose task was already marked `manager_lost`; TLC finds the `TerminalCauseSafety`
violation after 1,698 generated / 827 distinct states. `ParslPipelineTimedFixed.cfg` records that
completion as stale and passes dependency, retry, result, terminal-cause, stale-result, and
database-cause invariants with 225,836 generated / 51,703 distinct states at depth 24. This model
is intentionally complementary to the larger `ParslPipeline.tla`: it makes the logical-task
versus physical-attempt, clock, and monitoring boundaries easy to inspect before adding more
executor/provider detail.

The combined join configuration `models/core/ParslJoinSafety.cfg` has also been checked against
the shared `ParslAbstract` module. It explores 427,320 generated states (66,459 distinct states,
depth 61) with dependency, Future, retry, join-result, join-handle, and join-failure invariants
all passing. This is a bounded composition check; the focused `models/dataflow/` join models
remain preferable for larger duplicate, cancellation, memoization, and callback-race scenarios.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringCurrent.cfg models/core/ParslTaskStagingMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringFixed.cfg models/core/ParslTaskStagingMonitoring.tla
```

`FinishProducer` represents the DFK logical result, `PublishStageOut` the DataManager/DataFuture
readiness boundary, `StartConsumer` dependency admission, and the monitoring actions event and
database delivery. The focused chunk protocol remains in
`models/staging/ParslDataFutureTransfer.tla`.

`ParslProviderFailureRetry.tla` connects provider block failure to executor attempt loss and
retry. It permits an old worker result to arrive after a retry begins. The current configuration
violates `FutureSafety` at depth 6; the fixed configuration classifies that result as stale and
checks 79 distinct states. This corresponds to provider status/failure handling, executor
physical-attempt bookkeeping, and the retry path. The Python retry baseline is exercised by
`tests/test_retry_timeout_runtime.py` and `tests/test_retry_handler_runtime.py`.

`ParslResultDecodeRetry.tla` adds the ZMQ/result boundary: a completed worker result can be
corrupt at deserialization, causing the physical attempt to be retried while the old frame is
still deliverable. Current TLC finds the stale-resolution violation at depth 5; Fixed rejects
the old frame and checks 18 distinct states. The concrete corrupt-result behavior is covered by
`tests/test_htex_result_decode_failure_runtime.py` and
`tests/test_htex_result_queue_runtime.py`.

The detailed action-to-Parsl mapping and TLC results are in [the overview](overview.md).

## Foundational smoke suite

Before running the larger model inventory, `scripts/tlc_foundational_smoke.sh` checks the
small first-stage abstractions that establish the repository's main boundaries: a dependency
and retry path, callable/object snapshotting, chunked file bytes, heartbeat time, monitoring
database persistence, `join_app`, and an end-to-end ZMQ/serialization route. The suite uses
TLC simulation with bounded state and exits on the first failing model. Java and TLC can be
provided explicitly when they are not on `PATH`:

```bash
JAVA_BIN=/path/to/java TLA_JAR=/path/to/tla2tools.jar \
  TLC_SIMULATE=1000 scripts/tlc_foundational_smoke.sh
```

The suite can be split into reproducible case intervals when the full inventory is too large for
one interactive run. `TLC_CASE_START` is one-based and `TLC_CASE_LIMIT` is inclusive; for example,
`TLC_CASE_START=31 TLC_CASE_LIMIT=60` runs only cases 31 through 60.

This is a regression entry point, not a replacement for the exhaustive TLC configurations or
the concrete Python runtime probes documented by each module.

The current repository smoke runner enumerates 349 TLC cases and 220 Python runtime test files.
On 2026-09-30, all 313 TLC cases passed in segmented runs with `TLC_SIMULATE=10`, and the
complete runtime suite passed with 196 files; the subsequently added cases were also run
individually as they were introduced, including the PBS Pro status-batch isolation and
monitoring worker cross-table, malformed-HTEX-ingress continuation, Globus token-schema, and
Globus initialization-race
refinements.
These counts are evidence for the fast regression gate;
the individual model pages still document larger fixed/current counterexample runs.

The final three cases also pin down the first executor-specific refinement after the simple
abstractions: HTEX submit queue rollback, result-deserialization failure cleanup, and rejection
of a result frame that carries both a result and an exception. Their current configurations are
kept as counterexamples in the executor/serialization documentation; the smoke suite runs the
fixed configurations so the foundational path remains green.

The provider cases then sample concrete admission and response boundaries across Kubernetes,
Torque, LocalProvider, AWS, and Google Cloud. They are deliberately small schema/state checks;
the provider-specific documents and runtime probes remain the authoritative deeper models.

The last case, `ParslProviderExecutorTimedMonitoringFixed`, is the first combined dynamic path in
this smoke suite: provisioning, manager heartbeat expiry, task timeout/retry, stale old-attempt
results, monitoring persistence, and scale-in/scale-out admission are checked together. Its
exhaustive configuration remains documented in `docs/executor-provider-model.md` because the
full state space is intentionally larger than the smoke bound.

`ParslJoinFull.cfg` is the corresponding fixed join composition. It adds join-body execution,
serialized callable admission, duplicate-preserving input positions, inner retry attempts,
outer cancellation, stale-result rejection, failure aggregation, and terminal monitoring to the
small `ParslJoinApp` protocol. Focused models remain the place for individual callback races and
backend-specific details.

The monitoring cases cover the next database refinement: all-or-nothing batch publication,
persistent retry of transient writes, and explicit terminal handling for permanent insert/update
errors. They complement the smaller `ParslMonitoringDBSmoke` path without making the smoke suite
depend on an unbounded database or queue.

The file-transfer cases extend the byte-level model with DataManager wrapper ordering, HTTP
content-length validation, and safe rsync path construction. They keep publication atomic and
make provider-transfer failures visible before dependent task admission.

The time cases cover adjustable-clock rollback, result-traffic starvation of HTEX contact expiry,
worker contact deadlines, initial probe timeout, and command deadline handling. These fixed
models use logical time while the corresponding runtime probes exercise deterministic clock and
socket doubles against the actual Parsl loops.

The object-content cases then refine the callable boundary: aliases shared between a callable and
its argument, nested mutable aliases, closure values used in memoization keys, and per-attempt
object snapshots. The fixed paths preserve submission-time identity/content rather than allowing
post-submit mutation to alter execution or cache behavior.

The serialization cases refine the wire protocol itself: logical-task/attempt correlation,
duplicate ACK retransmission, serializer-header identity, primary/secondary serializer fallback,
failed dynamic-plugin cache eviction, and registry collision handling. They sit below the larger
ZMQ end-to-end model and keep serializer-specific invariants directly executable.

The scheduler cases sample parser and admission boundaries for Slurm, Condor, PBS Pro, Grid
Engine, and LSF: foreign or malformed status lines, empty submissions, job-ID aliases, malformed
JSON, missing jobs, and invalid resource derivation. Each fixed model rejects malformed scheduler
output without corrupting local resource bookkeeping.

The executor-family cases cover ThreadPool resource validation, Work Queue and TaskVine submit
rollback/serialization/cancelled-result handling, Flux cleanup after submission failure, and
Globus Compute resource-spec validation, concurrent-submit isolation, and shutdown cleanup. These
models preserve the shared Future terminality contract while keeping backend-specific state
bounded.

The cloud-provider cases cover AWS, Azure, and Google Cloud submit, cancel, status-bookkeeping,
empty-response, duplicate-ID, reservation-shape, and remote-failure paths. They model remote API
responses separately from local resource maps so a partial or stale cloud response cannot silently
publish inconsistent capacity.

The provider-lifecycle cases add generic provisioning generations, multi-block ownership,
worker-per-block capacity, three-block ownership, retry-aware scale-in monitoring, and rejection
of negative scale-in requests. Together they make the resource-scaling contract explicit before
backend-specific scheduler details are layered on top.

The MPI and Radical Pilot cases complete another executor-family slice: MPI resource derivation,
non-divisible rank handling, no-resource result delivery, and Radical Pilot failure payloads,
failure fanout, late/unknown callbacks, and bulk shutdown cleanup.

The DFK cases now include bounded dynamic task creation, chain and fanout dependency release,
memoization function identity/dict ordering/ignore-key handling, and task-status versus Future
publication ordering. These preserve logical dependency safety as the graph grows after runtime
submission.

The generic provider cases cover bad-state ordering and mutation, unknown cluster jobs, LocalProvider
submit/cancel cleanup and PID-shape admission, plus poller close/duplicate-executor races. They
model lifecycle ownership independently of scheduler-specific response parsing.

The shared executor-contract cases add executor-kind admission, provider/executor bridging,
provider lifecycle, empty-selection rejection, shutdown ordering, and timed provider-backed
execution. These are the common contracts that concrete backend models refine.

The join-specific cases now exercise cancellation of single and list joins, immediate callback
cancellation, cleanup quiescence, duplicate failure aggregation, callback multiplicity, return
shape validation, and outer cancellation. The runtime runner includes the corresponding decorated
`join_app` probes, so the fixed TLA+ terminal-state properties are checked against real Futures.

The HTEX result cases cover cancelled and duplicate result delivery, corrupt outer result frames,
malformed manager result payloads, and worker task batch/frame continuation. They assert that one
bad or stale message cannot terminate processing for unrelated tasks.

The HTEX schema cases cover manager registration shape/type, version mismatch, task admission,
task ID/context/priority/resource-spec types, and malformed task messages. Fixed paths reject
invalid decoded metadata before scheduler state or manager ownership is mutated.

The monitoring lifecycle cases cover hub close before start, startup failure cleanup, repeated
start protection, idempotent close, shutdown draining, and close/worker races. They make resource
ownership and queue/process cleanup explicit in addition to database write semantics.

The monitoring stream cases cover event ordering/status history, malformed worker messages,
dispatch-envelope validation, ZMQ tuple shape, worker-status atomicity, and lifecycle bookkeeping.
These models separate transport admission from database transaction state.

The staging-provider cases now cover FTP connection/partial cleanup, Globus endpoint/token/
timeout/failure events, HTTP connection/status cleanup, rsync partial cleanup, and Zip member/path/
traversal/stage-in publication. They keep temporary files and published outputs distinct so failed
transfers cannot appear ready to dependent tasks.

The additional scheduler cases cover Kubernetes polling/cancel response shapes, empty pod phases,
Condor chunk-size and command-failure handling, and Slurm strict batch/cancel/duplicate-status/
empty-ID behavior. These fixed models isolate scheduler response parsing from provider ownership.

The data-readiness cases connect staging to the DFK: DataFuture transfer and cancellation,
DataManager cache reuse, stage-out return ownership, stale captured data, and dependency failure
propagation. They enforce that consumers execute only after a published, non-failed DataFuture.

The serializer framing cases make the concrete `pack_buffers`/`unpack_buffers` contract explicit:
exactly three apply buffers, declared lengths, short/truncated/negative frames, and binary-safe
payloads. These checks sit below route/correlation and expose malformed framing before worker
dispatch.

The core failure-path cases cover serialized result-file publication, result decode retry,
provider failure retry, invalid retry-handler costs, DFK cleanup, wait-snapshot shutdown, and
dependency-failure propagation. They preserve the distinction between logical Future terminality
and physical retry/result-file state.

The smoke suite also runs the integrated `ParslAbstract` configuration in both its base and
join-focused forms. Those two configurations connect logical tasks, physical attempts, workers,
provider capacity, wire envelopes, serialization, data readiness, heartbeat/deadline state,
monitoring records, and join result invariants in one bounded model.

The pipeline smoke cases add a compact composition check for ordered pipeline dependencies,
timed progression, content-file publication, and timeout/retry stale-result rejection.

`scripts/runtime_foundational_smoke.sh` is the matching runtime entry point. It runs representative
Python probes for each foundational area and supports the same one-based `TEST_CASE_START` and
inclusive `TEST_CASE_LIMIT` interval controls as the TLC runner. Set `PYTHON_BIN` and
`PARSL_SOURCE` when the development environment uses different paths.

`ParslDataFlowCleanup.tla` captures the DFK shutdown sequence: mark cleanup, close memoization
and usage tracking, stop the status poller, shut down executors, close monitoring, and terminate
the task-launch pool. A repeated cleanup call is rejected without re-closing components. The
runtime probe invokes the real `DataFlowKernel.cleanup` with recording components.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowCleanup.cfg models/core/ParslDataFlowCleanup.tla
```

`ParslDataFlowWaitSnapshot.tla` models the documented race in
`DataFlowKernel.wait_for_current_tasks`: the method snapshots task records before waiting, so a
task inserted afterward can remain pending when the call returns and cleanup proceeds. The current
configuration exposes both `NoPendingTaskAtReturn` and `NoPendingTaskAtCleanup`; the fixed
configuration adds a late-task drain/check. The runtime probe uses a dictionary that inserts a task
immediately after the real snapshot operation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowWaitSnapshotCurrent.cfg models/core/ParslDataFlowWaitSnapshot.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataFlowWaitSnapshotFixed.cfg models/core/ParslDataFlowWaitSnapshot.tla
```
