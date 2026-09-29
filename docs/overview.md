# A Small TLA+ Abstraction of Parsl

This is the detailed reference document. For a topic-oriented entry point, see the module guides
in [`docs/`](./).

This repository contains an executable, finite-state abstraction of Parsl. It is not a
line-by-line translation of the Python implementation. It preserves the control-flow
boundaries that affect observable workflow behavior: DataFlowKernel task/Future state,
executor submission, worker execution, provider capacity, retries, memoization, data
readiness, and late results.

The model was based on the Parsl paper and the current source tree, especially:

- `parsl/dataflow/states.py`: task states. The usual DFK success path is
  `pending -> launched -> exec_done`; `running`/`running_ended` are primarily monitoring-side states.
- `parsl/dataflow/dflow.py`: dependency resolution, dependency failure, memoization,
  executor submission, and completion callbacks.
- `parsl/executors/high_throughput/executor.py`: HTEX task submission, provider scaling,
  and manager capacity.
- `parsl/executors/high_throughput/interchange.py`: pending queue, manager registration,
  heartbeats, dispatch, result forwarding, and manager loss.
- `parsl/executors/high_throughput/process_worker_pool.py`: worker availability and task execution.
- `parsl/providers/base.py` and `parsl/jobs/strategy.py`: provider submit/status/cancel
  interfaces and scaling policy.
- `parsl/data_provider/data_manager.py`: the data-staging abstraction boundary.

## Repository layout

The root contains the focused models that are still being migrated. The shared workflow
abstraction and its first group of scenario configurations live under `models/core/`; each
configuration remains next to the TLA+ module it instantiates. Serialization and transport
models are under `models/serialization/`; monitoring models are under `models/monitoring/`; provider
and scheduler models are under `models/providers/`; staging and data-transfer models are under
`models/staging/`; executor, HTEX, worker, and command models are under `models/executors/`;
DFK dataflow, Future, Join, retry, and memoization models are under `models/dataflow/`; runtime
probes remain under `tests/`. Clock/timeout models are under `models/clock/`, the strategy model
is under `models/strategy/`, and small cross-cutting models remain in their closest topic
directory. More model families will move into topic directories only after their TLC commands are
updated and checked.

## Logical tasks and physical attempts

The most important modeling decision is to keep a logical workflow task separate from a
physical execution attempt. An attempt is identified by `(task, retryIndex)`, so `(A,0)`
and `(A,1)` are distinct executions.

Logical task/Future states:

```text
pending -> staging -> ready -> queued -> running -> succeeded
                                      \-> retry_wait -> queued
                                      \-> failed
ready --memoization hit--> memoized
```

Physical attempt states:

```text
absent -> submitted -> serialized -> sent -> received -> decoded -> dispatched -> running -> succeeded
                                             \-> result_serialized -> result_sent
                                                 -> result_received -> result_decoded -> succeeded
                                             \-> failed
                                             \-> timed_out
                                             \-> lost
failed/timed_out/lost --late result--> stale
```

Once an old attempt is replaced, a late result can only mark that physical attempt as
`stale`; it cannot overwrite the logical Future or final result. This allows TLC to explore
retry + late-result, timeout, worker-loss, and duplicate-completion scenarios.

The provider uses `none/requested/active/failed/cancelled`; workers use
`unregistered/idle/busy/failed`. Workers begin as `unregistered` and must pass through
`RegisterWorker` before becoming idle, matching the HTEX interchange manager-registration
boundary.
Executors additionally use `up/draining/down`; `ExecutorDrain` blocks new submissions while
existing attempts may continue, and `ExecutorRecover` reopens submission.
`RequestAllocation`, `AllocationSucceeds`, and `AllocationFails` abstract resource request,
resource availability, and allocation failure. Memoization completes a task without creating
an attempt or consuming a worker.
The reserved executor name `local` models a provider-free local executor: it still uses the
same serialized task/result and worker-binding protocol, but does not require a provider block.
Its workers start idle without HTEX manager registration. `ParslLocalExecutor.cfg` checks this
path separately from provider-backed executors.
Scale-in is block-granular: cancelling one of several active blocks keeps the provider active,
while cancelling the final block transitions it to `cancelled`. `ParslScaleIn.cfg` exercises this
multi-block case. Scale-out may also fail while an earlier block remains active; in that case the
failed request is rolled back to the existing active target instead of taking the whole provider
offline. `CancelRequestedAllocation` covers cancelling a pending block request before it becomes
active. The model now exposes a `MIN_BLOCKS` floor: active and pending scale-in cannot remove
capacity below that floor. `ParslMinBlocks.cfg` exercises a provider that must retain one block.

`ParslStrategy.tla` is a separate focused model of the core policy in Parsl's strategy layer:
active-task pressure is compared with slots (`blocks * SLOTS_PER_BLOCK`), scale-out is bounded by
`MAX_BLOCKS`, and idle scale-in stops at `MIN_BLOCKS` after `MAX_IDLE_TIME`. It is intentionally
kept separate from the DFK protocol state machine so strategy bugs can be isolated with a small
state space. The policy is based on `parsl/jobs/strategy.py` in the current Parsl source.

The runtime probe `tests/test_strategy_runtime.py` checks the same source boundary with a fake
provider-backed executor: initialization requests are issued once, overloaded slots request
bounded additional blocks, and idle scale-in waits for `max_idletime` while preserving
`min_blocks`.

`ParslProbeAddresses.tla` covers the concrete HTEX ZMQ address probe. Empty candidate sets are
rejected, a response selects one candidate, and a poll timeout without a response becomes a
connection failure. `tests/test_probe_addresses_runtime.py` checks the empty and unresponsive
paths with the real pyzmq helper.

`ParslCurveZMQCertificateMode.tla` adds the file-permission guard around CurveZMQ credentials:
only a private certificate directory with a secret key can enter the loaded state. The runtime
probe uses `create_certificates` and the real `_load_certificate` helper.

`ParslStrategyBlockCapacity.tla` refines strategy configuration admission. An overloaded poll
with `nodes_per_block=0` reaches the current division by zero in the excess-block calculation;
the fixed branch rejects zero capacity before polling. The runtime probe demonstrates the current
`ZeroDivisionError` using the real strategy method.

`ParslZMQ.tla` is the next focused transport model. It represents a multipart message as a
header/body encoding protocol, a bounded outbound/inbound queue pair, ROUTER/DEALER-style endpoint
identity and route checks, disconnect/drop, queue reordering, duplicate delivery, invalid payloads,
and receiver-side correlation by `(task, attempt, kind)`. It is deliberately independent of the
DFK model so transport counterexamples remain short and interpretable.

`ParslPython.tla` refines callable serialization into Python-like object categories: function
code, globals, defaults, closure cells, arguments, and nested references. Encoding traverses the
referenced graph before creating a symbolic pickle token; decoding traverses it again before a
payload is considered reconstructed. `ParslPythonFailure.cfg` marks a nested closure object as
unserializable and checks that the task fails before a token or decoded payload is exposed.

`ParslCallableSerializerCache.tla` isolates a smaller callable-object boundary. Parsl routes a
callable through the `DillCallableSerializer`, whose `lru_cache` wrapper hashes the callable before
calling `dill.dumps`; an otherwise serializable callable object with `__hash__ = None` therefore
fails at cache lookup. The current configuration produces this counterexample, while the fixed
configuration bypasses the cache for unhashable callable objects. The runtime probe compares the
real Parsl facade with direct Dill serialization.

`ParslCallableDeserializeCache.tla` checks the reverse cache. The current
`DillCallableSerializer.deserialize` cache can return the same mutable callable instance for an
identical payload, so a mutation by one task becomes visible to a later task. The current model
violates `FreshSecondDecode`; the fixed model uses a fresh decode. The runtime probe is
`tests/test_callable_deserialize_cache_runtime.py`.

`ParslCallableArgumentAlias.tla` models a cross-root identity boundary.  A closure and an
argument may reference the same mutable object before submission, but the current
`pack_apply_message` path serializes them independently and reconstructs two non-identical
objects.  The current configuration violates `AliasSafety`; the fixed configuration represents
a bundled object graph that preserves the alias.  The runtime probe confirms the current result
with a real closure and argument.

`ParslExecuteTask.tla` models the next worker-side boundary in `parsl.executors.execute_task`:
the packed apply message must decode before the callable is invoked, a user exception becomes a
failed execution result, and malformed input is rejected without invoking user code. The three
configurations cover successful execution, user failure, and malformed input.

`ParslAzureStatus.tla` models Azure VM status translation: a short `instanceView.statuses` list
is treated as provisioning (`PENDING`), known running and terminal VM states are translated, and
an unfamiliar display string remains explicit `UNKNOWN` rather than being mistaken for success.

`ParslAzureCancel.tla` models Azure VM cancellation, including `linger` rejection and cloud-delete
failure. Its current configuration exposes a bookkeeping race: if the cloud deletion succeeds
after the local `instances` list has already lost the VM id, `list.remove` raises and Parsl returns
`False`; the fixed configuration makes this idempotent cleanup a successful cancellation.

`ParslThreadExecutor.tla` refines the provider-free thread executor. It checks rejection of
unsupported resource specifications, preservation of accepted work across `shutdown(wait=False)`,
and the stronger wait-for-completion contract of `shutdown(wait=True)`.

`ParslThreadExecutorResourceSpec.tla` refines the input-validation path. The current
`ThreadPoolExecutor.submit` raises `AttributeError` for a truthy non-mapping resource value before
it can construct `InvalidResourceSpecification`; the fixed branch keeps this rejection controlled.
The runtime probe exercises a list and a mapping against the concrete executor.

`ParslZipStageIn.tla` refines `ZipFileStaging.stage_in`: archive validation happens before output
creation, but the current direct write can expose a partial output if the destination write fails.
The fixed configuration uses a temporary output and atomic publication.

`ParslZipStageOut.tla` models `ZipFileStaging.stage_out` writing an archive member before removing
the source. If source cleanup fails, a retry currently appends a duplicate member (and emits a
duplicate-name warning); the fixed configuration models idempotent replacement.

`ParslCommandClient.tla` models the HTEX command REQ/REP socket. A successful reply completes the
request; a response timeout marks the client permanently bad, matching `CommandClient.run`'s
protection against reusing a request socket whose state is unknown.

`ParslCommandClientSendTimeout.tla` models the complementary pre-send timeout branch. When the
socket is not writable before any request is sent, `CommandClient.run` raises a timeout but keeps
the client reusable; a later command may send and receive normally. The runtime probe is
[`tests/test_command_send_timeout_runtime.py`](../tests/test_command_send_timeout_runtime.py).

`ParslCommandClientMaxRetries.tla` audits the `max_retries` argument exposed by the same method.
The current model and runtime probe show that a `send_pyobj` exception is attempted exactly once
even when `max_retries=2`; TLC reaches the `RetryBudgetHonored` counterexample. The fixed model
shows the candidate retry contract, but the repository does not claim that this policy is required
by the Parsl paper.

`ParslHtexCancelledResult.tla` models cancellation racing with HTEX result delivery. The current
result thread removes a cancelled Future and then calls `set_result`, so `InvalidStateError` can
terminate the thread before later results in the same batch are handled. The fixed branch treats
the cancelled result as stale and continues processing the batch; the runtime probe reproduces
the current orphaned-pending-task behavior.

`ParslHtexUnknownTaskResult.tla` models a result whose task id has already been removed from the
executor task map. The current `tasks.pop(task_id)` raises `KeyError` and terminates the result
worker, leaving later valid results unprocessed. The fixed branch discards the stale result and
continues the batch; the runtime probe drives the concrete result worker with both messages.

`ParslHtexAmbiguousResult.tla` models a result message carrying both `result` and `exception`.
The current worker silently prefers `result`; the fixed branch rejects the malformed combination
instead of resolving a Future as successful. The runtime probe confirms the current precedence.

`ParslMPINonDivisibleRanks.tla` audits MPI resource derivation. The current helper accepts
`num_nodes=2, num_ranks=5`, derives the non-integral `ranks_per_node="2.5"`, and inserts it into
the `mpiexec -ppn` command. The fixed model rejects non-divisible allocations before launch;
the runtime probe confirms the current command construction.

`ParslMPINoResourceResult.tla` covers the MPI scheduler's unmapped-result path. A task without
`num_nodes` is not entered into `_map_tasks_to_nodes`, but the current `get_result` assertion
requires every result task to have an entry and aborts the scheduler (Issue #3427 in the source
comment). The fixed model returns such a result without a node-reclamation step.

`ParslMPIBacklogRetry.tla` models the MPI scheduler's resource-starved backlog. The current
`_schedule_backlog_tasks` requeues an oversized head task and recursively retries without a state
change, eventually overflowing the Python call stack. The fixed branch stops the pass and leaves
the task queued until resources are returned.

`ParslBashTimeoutCleanup.tla` models Bash app timeout cleanup. The current
`remote_side_bash_executor` reports `AppTimeout` after `Popen.wait` expires but leaves the shell
or process group alive; the fixed branch kills it before reporting the timeout.

`ParslHtexForceScaleIn.tla` models the concrete HTEX `scale_in` path. With
`max_idletime=None`, the current implementation can select a block whose manager still has
active tasks, hold it, and cancel its provider job; this is the intentionally forceful behavior
documented in `high_throughput/executor.py` (issue #530). The current model violates
`BusyScaleInSafety`, while the fixed idle-only policy passes. The runtime probe verifies the
busy-manager cancellation calls against the real method.

`ParslWorkQueueCancelledResult.tla` models cancellation racing with a Work Queue collector
report. The current collector removes a cancelled Future before `set_result`, so
`InvalidStateError` exits the collector and its cleanup marks an unrelated pending Future with
`WorkQueueFailure`. The fixed model treats the report as stale and continues with later results.

`ParslTaskVineCancelledResult.tla` models the corresponding TaskVine collector race. The current
collector removes a cancelled Future before `set_result`, so `InvalidStateError` exits the
collector and cleanup marks another outstanding Future with `TaskVineManagerFailure`. The fixed
model ignores the stale report and continues processing result files.

`ParslHtexManagerMessage.tla` models manager-to-interchange message decoding. Malformed multipart
or pickle input is ignored without changing the manager record; a valid heartbeat updates its
timestamp and produces the heartbeat reply.

`ParslGridEngineSubmit.tla` models Grid Engine `qsub` submission: script creation precedes the
command, failed/empty output creates no resource, and the first non-empty successful output line
registers a pending job.

`ParslSlurmStatus.tla` refines Slurm batch status handling. The current path indexes every
reported scheduler job ID into `resources`, so a foreign ID raises `KeyError`; the fixed path
ignores foreign lines and preserves local resource state.

`ParslMonitoringDBRetry.tla` refines `DatabaseManager._insert`: SQLAlchemy `OperationalError` is
rolled back and retried, while integrity errors are dropped after rollback. The runtime probe
drives one transient database-lock failure through the real retry loop.

`ParslMonitoringPersistentRetry.tla` isolates the persistent-lock case: the current retry loop
has no attempt bound and can keep the monitoring thread from finishing shutdown indefinitely. The
fixed branch aborts after a bounded number of failures. A watchdog-based runtime probe confirms
the current `_insert` remains in the retry loop until externally interrupted.

`ParslAWSProviderCancel.tla` models EC2 cancellation: `linger` rejection, remote termination
failure, successful local cleanup, and the current exception when a successful remote terminate
finds no local resource/instance record. The fixed configuration makes local cleanup idempotent.

`ParslGoogleCloudCancel.tla` models GCE cancellation. The current provider returns success after
remote deletion but leaves the local resource marked `RUNNING`; the fixed configuration marks it
`COMPLETED`.

`ParslMonitoringClose.tla` models monitoring shutdown/finalization. An abnormal close with a
workflow start message writes the final completion update once; a normal close does not duplicate
it. Both paths switch batching to drain mode and signal the manager to stop.

`ParslMonitoringHubClose.tla` models the outer `MonitoringHub.close()` resource lifecycle. It
signals the DB process, waits for termination, closes and joins the multiprocessing queue, and
keeps the operation idempotent when called again.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringHubClose.cfg models/monitoring/ParslMonitoringHubClose.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_hub_close_runtime.py -v
```

`ParslMonitoringCloseIdempotence.tla` refines the inner `DatabaseManager.close()` boundary. On
an abnormal workflow, the current method emits the workflow-finalization update again on every
close call because it does not record that finalization; the fixed branch makes repeated calls
no-ops. The runtime probe calls the real method twice.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringCloseIdempotenceCurrent.cfg models/monitoring/ParslMonitoringCloseIdempotence.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringCloseIdempotenceFixed.cfg models/monitoring/ParslMonitoringCloseIdempotence.tla
```

`ParslMonitoringZMQRouterFailure.tla` models a receive channel that remains broken. The current
router catches the exception and keeps retrying until an external exit event is set; the fixed
branch stops after the first unrecoverable channel failure.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQRouterFailureCurrent.cfg models/monitoring/ParslMonitoringZMQRouterFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQRouterFailureFixed.cfg models/monitoring/ParslMonitoringZMQRouterFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringZMQRouterFailureValid.cfg models/monitoring/ParslMonitoringZMQRouterFailure.tla
```

`ParslSlurmCancel.tla` models Slurm `scancel`: command failure preserves local state, while a
successful command marks known resources `CANCELLED`; the current path can raise on a foreign ID,
and the fixed path ignores that stale local entry.

`ParslMonitoringBatch.tla` models `DatabaseManager._get_messages_in_batch`. With
`batching_interval=0`, the current implementation checks the time boundary before reading the
queue, so it can return an empty batch while a message is waiting. The TLC current configuration
produces that counterexample; fixed and positive-interval configurations preserve message
collection. The runtime probe is `tests/test_monitoring_batch_runtime.py`.

`ParslMonitoringBatchAtomicity.tla` models a second monitoring batch boundary: one duplicate
STATUS key can make a SQLAlchemy bulk insert roll back the entire batch. The current manager then
drops a valid sibling event along with the duplicate; fixed bookkeeping preserves valid messages.
`tests/test_monitoring_batch_atomicity_runtime.py` reproduces this with a temporary SQLite DB.

`ParslMonitoringThreshold.tla` checks the configuration boundary where
`batching_threshold=0`. The current loop returns before reading an available event; the fixed
configuration guarantees one available event is consumed before applying the threshold. The
runtime probe exercises the real `_get_messages_in_batch` method.

`ParslRetryHandler.tla` models the retry-budget boundary in `DataFlowKernel.handle_exec_update`.
The current implementation adds the user handler's returned cost directly to `fail_cost`; a zero
cost therefore permits another physical attempt even when `retries=0`. The current TLC
configuration and `tests/test_retry_handler_runtime.py` reproduce that behavior, while the fixed
configuration charges a minimum cost of one.

`ParslMemoFunctionIdentity.tla` models the function identity used by `BasicMemoizer`. The current
`id_for_memo_function` implementation hashes only `__name__` and `__module__`, so a changed body
can reuse an old checkpoint. `tests/test_memo_function_identity_runtime.py` constructs two
same-identity functions with different results and confirms their keys collide; the fixed model
adds a symbolic source/version component.

`ParslExecuteWaitTimeout.tla` models scheduler command timeout cleanup in `utils.execute_wait`,
which is used by `ClusterProvider.execute_wait`. The current path propagates `TimeoutExpired`
without terminating the process; `tests/test_execute_wait_timeout_runtime.py` verifies this with a
controlled fake `Popen` process. The fixed configuration performs process cleanup before raising.

`ParslMemoExceptionCheckpoint.tla` models failure persistence across a memoizer restart. The
current `BasicMemoizer` updates its in-memory cache with a failed `AppFuture`, but the checkpoint
writer skips exception commands, leaving an empty `tasks.pkl`. TLC finds the four-state current
counterexample (`RunAndFail -> Checkpoint -> Restart`); the fixed branch persists the failure.
The real probe is [`tests/test_memo_exception_checkpoint_runtime.py`](../tests/test_memo_exception_checkpoint_runtime.py).
This records a semantic gap for review, not a claim that failure persistence is necessarily the
intended Parsl policy.

`ParslMemoCheckpointOrder.tla` models a duplicate-key recovery ordering issue. The helper
`get_all_checkpoints` sorts UUID-named run directories lexically, but `BasicMemoizer` overwrites
each repeated hash with the last checkpoint it loads. UUID lexical order does not encode run
chronology: TLC finds a three-state current counterexample where `new` is loaded before `old`, and
the old result wins. The chronological fixed configuration passes with 3 distinct states.
[`tests/test_memo_checkpoint_order_runtime.py`](../tests/test_memo_checkpoint_order_runtime.py)
reproduces the stale restoration using two UUID-like run directory names.

`ParslLastCheckpointUUID.tla` models `get_last_checkpoint` in `parsl/utils.py`. Current DFK run
directories are UUIDs, but the helper filters candidates with `str.isdigit()`, so a valid UUID
checkpoint is not selected. TLC finds the two-state current counterexample and the fixed branch
passes with 2 distinct states. [`tests/test_last_checkpoint_uuid_runtime.py`](../tests/test_last_checkpoint_uuid_runtime.py)
confirms the actual UUID-versus-numeric behavior.

`ParslMemoDictOrdering.tla` models dictionary-key normalization in `BasicMemoizer`. Python allows
heterogeneous dictionary keys, but the current `id_for_memo_dict` calls `sorted(dict)` directly,
so a mixed `int`/`str` key dictionary raises `TypeError` while computing a memo key. The runtime
probe and current TLC configuration reproduce this; the fixed branch uses a canonical ordering.

`ParslRsyncQuoting.tla` models shell argument construction in `RSyncStaging`. The current
in-task wrappers interpolate hostnames and paths directly into `os.system`, so a valid path with
spaces is split into multiple shell words. `tests/test_rsync_quoting_runtime.py` captures that
command; the fixed branch quotes each shell argument.

`ParslCommandDeadline.tla` refines the HTEX `CommandClient.run` timeout boundary. When a deadline
has already elapsed, the current path passes a negative timeout to ZMQ `poll`; the runtime probe
records that value with a fake socket. The fixed branch clamps the poll timeout to zero.

`ParslCommandClientLockTimeout.tla` adds the mutex boundary: the current command client starts
its timeout clock before acquiring `_lock`, so lock contention can consume the entire deadline and
still allow a late send. The fixed branch rejects the command at lock acquisition when the
deadline has expired. A threaded runtime probe holds the real client lock to force the interleaving.

`ParslGridEngineDuplicateStatus.tla` models duplicate records in Grid Engine `qstat` output. The
current `_status` implementation removes each job from `jobs_missing` without checking whether it
was already removed, so duplicate lines raise `ValueError`. The runtime probe reproduces this and
the fixed branch makes removal idempotent.

`ParslLSFDuplicateStatus.tla` models the analogous LSF `bjobs` behavior. LSF stores missing jobs
in a set, so a duplicate record raises `KeyError` on the second removal. The runtime probe and
fixed branch document idempotent handling.

`ParslLSFMissingJob.tla` models the LSF provider's missing-job fallback. The current `_status`
path marks an active job absent from `bjobs` output as `COMPLETED`, which can hide a scheduler
failure; the fixed branch keeps it `UNKNOWN`. The runtime probe confirms the current
`COMPLETED` transition using the real provider method.

`ParslSlurmDuplicateStatus.tla` models the corresponding Slurm status path. Duplicate rows also
raise `KeyError` when the same job is removed twice from the missing-job set; the runtime probe
and fixed branch make this behavior explicit.

`ParslTorqueDuplicateStatus.tla` models duplicate Torque qstat rows. Torque uses a list for
missing jobs, so duplicate rows raise `ValueError` on the second removal; the runtime probe and
fixed branch make the operation idempotent.

`ParslPBSProJobIdAlias.tla` models PBS Pro's short-to-qualified job-id normalization. Distinct
JSON keys such as `42` and `42.server` can both normalize to the same local `42.server` resource;
the current parser then removes that resource from `jobs_missing` twice and raises `ValueError`.
The runtime probe drives the real JSON parser and provider method, while the fixed branch makes
normalized-record bookkeeping idempotent.

`ParslJoinListMutation.tla` models mutable aliasing in `join_app` list results. The current DFK
stores the returned Future list directly in the task record; if that list is cleared before the
callback, the outer join can complete with an empty result. The runtime probe calls the real
`handle_join_update` path, while the fixed branch snapshots the list.

`ParslFTPConnectionCleanup.tla` models FTP in-task stage-in connection lifetime. If
`retrbinary` fails, the current wrapper propagates the exception without calling `ftp.quit()`,
leaving the connection open. The runtime probe uses a fake FTP connection; the fixed branch closes
it on failure.

`ParslHTTPPartialCleanup.tla` models HTTP streaming publication. If a later response chunk fails,
the current wrapper leaves earlier bytes at the destination path. `tests/test_http_partial_cleanup_runtime.py`
reproduces the partial file, while the fixed branch removes incomplete output before propagating the
failure.

`ParslHTTPStatusValidation.tla` models HTTP response validation. The current
`HTTPInTaskStaging` wrapper accepts a non-2xx response, publishes its body, and starts the user
task; the fixed branch rejects the response before publication. The runtime probe confirms this
behavior with a fake 404 response.

`ParslDataFutureFalseyException.tla` models parent exception propagation in `DataFuture`. The
current `parent_callback` uses `if e`, so an exception whose `__bool__` returns `False` is treated
as a successful file result. `tests/test_datafuture_falsey_exception_runtime.py` reproduces this
with real `Future` and `DataFuture` objects; the fixed branch checks `e is not None`.

`ParslCondorStatusFailure.tla` refines the Condor status boundary with the `execute_wait` return
code. The current `_status()` ignores a failed `condor_q` command, so failed stdout can overwrite a
running resource or crash while being parsed. Fixed configurations return before parsing failed
output.

`ParslSerializationSnapshot.tla` isolates the object-content boundary: serialization captures a
versioned snapshot of the callable/argument graph, later mutation of the original Python object
does not alter the captured payload, and decoding exposes the captured version. The runtime
counterpart is the closure snapshot test in `tests/test_serialization_runtime.py`.

`ParslFileBytes.tla` models file contents as bounded symbolic byte chunks rather than a single
content flag. Each chunk carries a checksum through a temporary transfer buffer; corruption forces
repair/retransfer, and an input whose source version changes during stage-in becomes `stale`.
Stage-in and stage-out publish atomically only after every chunk is complete and validated.

`ParslDataFutureCopy.tla` models the smaller but important `DataManager.optionally_stage_in`
boundary: a staging operation receives a clean `File` copy with no inherited site-local path,
while the original user object remains unchanged. A dependent task is admitted only after the
parent `DataFuture` is ready. The runtime counterpart is
`test_stage_in_uses_clean_file_copy_and_preserves_parent` in `tests/test_datafuture_runtime.py`.

`ParslDataManagerStageInOrdering.tla` checks a failure ordering in the concrete
`DataManager.optionally_stage_in` implementation. A provider's separate stage-in transfer is
started before `replace_task` is called; if wrapper construction raises, the transfer can remain
pending after the task has failed. The current configuration violates `NoOrphanTransfer`, while
the fixed configuration prepares the wrapper first. The direct probe is
`tests/test_data_manager_stage_in_ordering_runtime.py`.

`ParslDataManagerStageOutOrdering.tla` checks the analogous output path in
`DataFlowKernel._add_output_deps`: a separate `stage_out` Future is started before
`replace_task_stage_out` constructs the application wrapper. If wrapper construction raises,
the transfer can remain pending after task setup fails. The current configuration violates
`NoOrphanTransfer`; the fixed ordering model prepares the wrapper first. The direct probe is
`tests/test_data_manager_stage_out_ordering_runtime.py`.

`ParslRsyncStage.tla` models the in-task `RSyncStaging` wrappers. Stage-in transfers before the
user function and blocks the function on a nonzero `rsync` result; stage-out runs the function
first but propagates a later transfer failure. The model has separate in-failure, out-failure,
and successful configurations, backed by fake-`os.system` runtime probes.

`ParslHTTPStage.tla` checks the analogous HTTP in-task boundary. The current wrapper streams any
response body without checking its status code, so a non-success response can be written as an
input file and still reach the user function. The current configuration preserves that depth-3
counterexample; fixed and successful-response configurations require status validation. The same
unchecked response handling is present in the separate-task `_http_stage_in` path.

`ParslFTPStage.tla` models partial-file cleanup for `FTPInTaskStaging`: a failed `retrbinary`
transfer must not run the user function, and a corrected wrapper should remove bytes already
written before the connection failure. The current configuration records the residual partial
file; fixed and successful-transfer configurations pass the cleanup invariant.
The separate-task `_ftp_stage_in` path exhibits the same residual partial-file behavior.

`ParslGlobusStageDependency.tla` models the Future wiring in `GlobusStaging`: stage-in preserves
the parent `DataFuture` as an input dependency, while stage-out passes the application Future to
the transfer app. Neither transfer can begin before its corresponding producer is ready.

`ParslGlobusTransferFailure.tla` models the terminal Globus transfer failure path. The current
`Globus.transfer_file` assumes a failed transfer always has at least one diagnostic event and
indexes `events.data[0]`; an empty event list therefore crashes with `IndexError` instead of
reporting the transfer failure. The runtime probe uses a fake SDK and the fixed branch reports a
failure without requiring diagnostic details.

`ParslGlobusTokenFileAtomicity.tla` models the OAuth token cache write. The current helper opens
the old token file before JSON encoding, so an encoder failure destroys the last valid contents;
the fixed branch publishes a temporary file only after a complete encode.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityCurrent.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityFixed.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityValid.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_token_file_atomicity_runtime.py -v
```

`ParslGlobusEndpointPath.tla` models `GlobusStaging._get_globus_endpoint`. A missing executor
working directory and an unrelated local path are rejected, while a local path below the working
directory should be accepted. The current implementation rejects that valid descendant because
it compares `local_path` directly with `os.path.commonpath`; the current TLC configuration and
runtime probe expose this counterexample, while the fixed configuration accepts it.

`ParslFileCleanCopy.tla` models `File.cleancopy()` at the DataFuture staging boundary. The URL is
immutable global metadata, while `local_path` is site-local mutable metadata and must be cleared
in a copy. The unsafe branch aliases the old path and violates `LocalPathIsClean`; the fixed
branch and `tests/test_file_clean_copy_runtime.py` confirm the isolation contract.

`ParslSerializationBinaryPayload.tla` follows a bounded payload containing newline, NUL, and
non-ASCII bytes through `pack_buffers` and `unpack_buffers`. Its length and byte sequence remain
unchanged at the decode boundary, matching the serializer's real byte-oriented framing.

`ParslMonitoringBatchClock.tla` models the monitoring batch deadline with a wall-clock rollback.
The current `DatabaseManager._get_messages_in_batch` uses `time.time()`, so a backwards clock
jump can admit another message after the configured interval; the fixed branch uses monotonic
elapsed time. The runtime probe drives the real helper with a deterministic rollback sequence.

`ParslJoinReturnShape.tla` isolates the `join_app` return contract: only one Future, a
Future-only list, or an empty list may enter the joining state. Tuple, scalar, and mixed-list
returns fail before callbacks are registered, matching the validation in `DataFlowKernel`.

`ParslTimerIntervalValidation.tla` models the `Timer` constructor's interval guard. The current
`max(0, interval)` normalization turns a negative interval into a zero-delay periodic loop; the
fixed branch rejects that configuration before starting the timer thread. The runtime probe
observes the current normalized value directly.

`ParslFluxCancelUnderlyingState.tla` refines Flux cancellation when the underlying future is
already cancelled. The current wrapper returns success without cancelling the Parsl-facing Future,
so it remains pending; the fixed branch enforces terminal cancellation. The runtime probe uses the
real `FluxFutureWrapper` with a fake already-cancelled future.

`ParslLocalProviderSubmitCleanup.tla` models script ownership across a failed LocalProvider
launch. The provider writes the worker script before invoking the launcher; the current failure
path leaves that file behind, while the fixed path removes it before raising. The runtime probe
uses a temporary script directory and a fake failed launch command.

`ParslLocalProviderCancelUnknown.tla` models a cancellation arriving after polling has removed a
local job from `resources`. The current `cancel()` path raises `KeyError`; the fixed branch treats
the stale request as a non-throwing unsuccessful cancellation. The runtime probe uses the real
provider with an empty resource map.

`ParslWalltimeParsing.tla` models the provider utility `wtime_to_minutes`. A positive
sub-minute walltime is currently truncated to zero minutes; the fixed branch rounds it up to one
minute. This is a small provider-input boundary rather than a scheduler-specific model.

`ParslTimeLimitedOpenTimeout.tla` models the missing-file branch of `time_limited_open`. The
current wait context yields after its horizon and then lets `open()` raise `FileNotFoundError`;
the fixed branch reports a timeout before opening. The runtime probe uses a missing temporary path.

`ParslStageOutFuture.tla` refines the DataManager/DataFlowKernel output boundary. It distinguishes
separate stage-out (the output `DataFuture` follows a returned staging Future), in-task stage-out
(the wrapper makes publication part of application completion), and the no-staging `None` path.
The separate path includes failure, retry, and the rule that dependent work cannot start until the
published output is ready. This follows
[`data_manager.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/data_provider/data_manager.py)
and the output handling in
[`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslMultiOutputStageOut.tla` extends that boundary to two output files. Each output has an
independent staging Future and readiness state, but both stage-out operations receive the same
application Future as their dependency. A failed output cannot publish itself or make its own
dependent task run early. `tests/test_multi_output_stageout_runtime.py` drives the real
`DataManager.stage_out()` wiring with two fake staging transfers.

`ParslClock.tla` separates wall-clock progression from heartbeat delivery and attempt deadlines.
It models heartbeat send/drop/delivery, manager expiry and recovery, per-attempt timeout, retry
selection after both task timeout and manager loss, and a late result that is marked stale when its
physical attempt is no longer current. A manager-lost attempt can now retry after reconnection;
its late result is explicitly allowed to arrive but cannot resolve the Future.
`ParslClockTerminal.cfg` fixes the retry budget at zero to exercise terminal timeout rejection.

`ParslFutureWaitTimeout.tla` separates the caller's `Future.result(timeout=...)` wait deadline from
the app's Parsl `walltime`: a caller timeout only returns control to the caller while the physical
task continues, whereas an app walltime timeout rejects the Future. The distinction is exercised
against a real thread executor in `test_client_wait_timeout_does_not_cancel_app`.

`ParslHeartbeatBoundary.tla` makes the HTEX heartbeat boundary explicit: expiration occurs only
when `now - last_heartbeat > heartbeat_threshold`, a heartbeat received before the expiry check
resets the timestamp, and expiration converts all manager in-flight tasks into failure reports.
The finite model mirrors the main-loop ordering in
[`interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py).

`ParslHeartbeatClockJump.tla` refines the clock source itself. The current interchange compares
`time.time()` values, so a forward wall-clock adjustment can expire a manager whose monotonic age
is still below the threshold. The fixed configuration uses monotonic elapsed time for the safety
decision while retaining wall time only for diagnostics.

`ParslMonitoringDB.tla` models a versioned monitoring radio queue and asynchronous database writer.
The queue can reorder events, writes can fail and be retried, stale versions are ignored, and a
terminal database record is not overwritten by an older event. `MAX_FAILURES` and queue bounds
keep the monitoring model finite for TLC.

`ParslMonitoringDeferred.tla` adds the concrete database-manager race for worker task messages.
When a worker's first status/resource message arrives before the DFK inserts the corresponding
task/try rows, the message is deferred and replayed after the try row exists. A second first
message replaces the single deferred entry, while status rows are never written before their try
foreign key exists. This follows the deferred-message sets and replay logic in
[`monitoring/db_manager.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/monitoring/db_manager.py).

`ParslFilesystemRadioAtomicity.tla` models the monitoring filesystem radio. A writer must keep
partial pickle bytes in `tmp/` and atomically rename the complete file into `new/`; publishing
directly in `new/` allows a reader to consume a partial message. The runtime probe exercises the
real `FilesystemRadioSender` and its write-failure behavior.

`ParslExecutorProvider.tla` is a focused model of the HTEX/BlockProviderExecutor boundary. It
separates provider block requests and failures from executor admission, manager registration,
worker readiness, queued/running tasks, drain/recovery, and block-granular scale-in. Provider
failure and scale-in explicitly clean up queued tasks for resubmission and mark running tasks
lost; an active provider block alone never implies that `submit` is accepted.

`ParslJoinApp.tla` models the bounded `join_app` result protocol. The outer app may return one
Future, a list of Futures, an empty list, or an invalid value. A join handle remains live until
all selected inner Futures are terminal; successful list results preserve input order, and any
inner failure becomes an outer join failure. Inner retries are intentionally owned by the inner
tasks, matching Parsl's callback behavior.

`ParslJoinDuplicates.tla` refines list joins beyond set-based dependency tracking. It models a
joinable list shaped like `[I1, I1, I2]`, registers callbacks by list position, preserves the
duplicate result in the aggregate, and counts a failed repeated Future once per list occurrence.
Callbacks delivered again after a position has already been observed are harmless. This follows
the list registration, all-done gate, ordered `future.result()` aggregation, and exception scan in
[`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslJoinImmediateCallback.tla` covers the registration race where a join body returns an
already-completed Future. The callback may run immediately during `add_done_callback`, so the
outer task must initialize its joining state and lock first; the runtime counterpart is
`join_precompleted` in `tests/test_join_runtime.py`.

`ParslJoinMixedList.tla` isolates the list-shape validation boundary. A list containing only
Futures is observed and aggregated in order, an empty list completes immediately, and a mixed
list such as `[Future, 7]` fails with a TypeError-like result before any inner callback is
registered. `ParslJoinValueList.cfg` adds a non-empty list containing only ordinary values, which
is rejected by the same source branch rather than being treated like the valid empty-list case.
This follows the join branch in
[`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslJoinRetry.tla` refines that protocol with separate logical inner Futures and physical inner
attempts. A retryable inner failure leaves the Future unresolved, so the outer join waits; only a
final-attempt failure is propagated as `JoinError`, while a later successful retry contributes its
final result to the ordered aggregate.

`ParslJoinCancellation.tla` covers a cancelled inner Future. In the current callback,
`future.exception()` raises `CancelledError` before `_complete_task_exception` runs, leaving the
outer task in `joining`. The current configuration produces that counterexample; the fixed
configuration converts cancellation into terminal join failure.

`ParslJoinListCancellation.tla` applies the same check to a list-valued join. A cancelled member
still raises from the list's `future.exception()` scan, so the current outer join remains in
`joining`; the fixed branch converts the cancellation into terminal failure. The runtime probe
uses the real `DataFlowKernel.handle_join_update` list path.

`ParslJoinSingleCancellation.tla` checks the single-Future join path separately. A cancelled
inner Future makes `future.exception()` raise `CancelledError`; in the current callback this
escapes before terminalization and leaves the outer join in `joining`. The fixed branch maps it
to terminal join failure. TLC reports the expected current counterexample and verifies the fixed
model with 4 generated/2 distinct states. The direct runtime probe is
`tests/test_join_single_cancellation_runtime.py`.

`ParslNestedJoin.tla` adds a nested join: the outer join observes a direct Future and a Future
produced by another join. The nested handle remains live until both leaf Futures are observed;
nested success/failure then becomes the only state visible to the outer join.

`ParslTaskTransport.tla` connects object-graph serialization to the task/result wire protocol.
It checks multipart encode order, envelope corruption, decode rejection, dispatch admission,
worker loss, retry correlation, result serialization failure, and stale results from an old
physical attempt. `ParslTaskTransportFailure.cfg` uses a non-serializable object graph to exercise
the pre-dispatch failure path.

`ParslDependencyTraversal.tla` models the dependency resolver used by `DataFlowKernel`. The
default shallow resolver only recognizes a Future passed directly; the deep resolver recursively
gathers and unwraps Futures in lists, tuples, sets, and dictionaries. The bounded model uses a
single nested list to show why a shallow configuration can send a Future object to the callable,
while the deep configuration waits for and substitutes its result. The runtime probe is
`tests/test_dependency_traversal_runtime.py`.

The repository also contains [`tools/cloudpickle_fixture.py`](../tools/cloudpickle_fixture.py) and
an observed fixture at [`fixtures/cloudpickle_fixture.json`](../fixtures/cloudpickle_fixture.json).
The script serializes a closure with globals, defaults, arguments, and nested objects, checks the
round trip, and verifies that a `threading.Lock` captured by a closure is rejected. Pickle length
and SHA-256 are recorded as versioned observations, not universal constants:

```bash
python3 tools/cloudpickle_fixture.py --output fixtures/cloudpickle_fixture.json
```

The checked observation used cloudpickle 2.0.0, 776 bytes, and round-trip result `42`; a lock
closure raised `TypeError`.

`ParslProviderPolling.tla` refines the provider side of the executor model into explicit
`submit`, `status`, and `cancel` API calls. It distinguishes pending/running/unknown status,
transient API errors, submit rejection, cancel failure rollback, and desired block-target updates;
bounded poll/failure counters keep the state space finite.

`ParslExecutorKinds.tla` adds a small executor contract matrix. It distinguishes provider-free
thread execution from provider-backed HTEX/MPI/workqueue-style paths, makes manager registration
explicit where required, rejects unsupported resource specifications, and checks submit,
drain/recovery, provider failure, and executor failure behavior. The model is based on the
abstract executor lifecycle in [`base.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/base.py),
the provider-free [`threads.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/threads.py),
and the manager/provider boundary in
[`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py).
It is a contract-level comparison, not a full implementation of every executor.

`ParslMPISpec.tla` is the first MPI-specific refinement. It models the current MPI resource
specification keys (`ranks_per_node`, `num_nodes`, `num_ranks`, and `launcher_options`), the
derived-rank step, and the requirement that a provider use `SimpleLauncher`. The actual
configuration preserves the current validation shape and finds a zero-node derivation path when
`num_nodes=0` and `num_ranks` is supplied without `ranks_per_node`; the fixed configuration adds
the candidate positive-node admission guard. This follows
[`mpi_executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/mpi_executor.py)
and [`mpi_prefix_composer.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/mpi_prefix_composer.py).

The corresponding validation path is exercised against the real MPI prefix composer:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_spec_runtime.py -v
```

The runtime probe confirms empty specifications are rejected, positive node counts derive the
missing rank count, and `num_nodes=0` with `num_ranks` reproduces the current division-by-zero
failure.

MPI launch-prefix selection is exercised directly against the composer:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_mpi_prefix_runtime.py -v
```

`ParslMPIPrefix.tla` checks that `mpiexec`, `srun`, and `aprun` select their matching generated
prefixes and that an unsupported launcher is rejected rather than silently remapped.

`ParslExecutorShutdown.tla` makes the shutdown distinction executable. ThreadPool shutdown keeps
accepted work eligible to complete before the executor reaches `stopped`; WorkQueue shutdown has
an explicit collector-cleanup action that fails work left behind when its submit process exits;
HTEX closes the interchange first and models in-flight cleanup as a separate loss event, matching
the fact that worker termination is handled by scaling or heartbeat expiry. All three paths reject
new submissions after shutdown begins. The mapping follows the concrete shutdown methods in
[`threads.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/threads.py),
[`workqueue/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/workqueue/executor.py),
and [`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py).

`ParslWorkQueueResults.tla` models the WorkQueue collector's result-file boundary. A valid
deserialized value resolves the executor Future, a corrupt result file or an app-produced
exception becomes a failed Future, and a report without a result file also fails. If the submit
process/collector exits, the final cleanup action fails every remaining outstanding task. This
follows `_collect_work_queue_results` in
[`workqueue/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/workqueue/executor.py).

`ParslWorkQueueDuplicateReport.tla` models a stale or duplicate collector report. The current
collector removes the Future before decoding the report, so a second report for the same executor
ID raises `KeyError`, exits the collector, and causes its `finally` block to fail unrelated
outstanding Futures. The fixed configuration ignores the stale report instead. The runtime probe
drives the real `_collect_work_queue_results` method through this duplicate-report path.

`ParslWorkQueueSubmit.tla` models the submit-side ordering around serialization and the Work Queue
process. The current implementation registers the Future in `_tasks` before serialization and
before checking process liveness; either a serialization exception or a dead process can leave that
map entry orphaned. The fixed configurations remove the mapping on either failure. The runtime
probe reproduces both orderings with a real `WorkQueueExecutor.submit` and fake filesystem/queue
objects.

`ParslFluxResult.tla` models the Flux executor's wrapped Future boundary. A Flux job must finish
before the callback reads the result file; zero exit status still requires a valid serialized
result, while missing/malformed files and task exceptions fail the Parsl Future. The actual
configuration also probes cancellation: the current callback returns immediately for a cancelled
underlying Flux future, which can leave the wrapper Future running. The fixed configuration
propagates cancellation to the wrapper. This follows
[`flux/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/flux/executor.py).

`ParslTaskVineResults.tla` models the TaskVine executor's ready-task queue, manager report, and
collector thread. It maps valid result files to success, missing/corrupt files and application
exceptions to failed Futures, and models collector finalization failing every outstanding task
when the TaskVine submit process dies. The model follows
[`taskvine/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/taskvine/executor.py)
and the report construction in
[`taskvine/manager.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/taskvine/manager.py).

`ParslTaskVineFactory.tla` models the optional factory process around that executor. It checks
factory construction, application of worker/factory timeout and capacity settings, context entry,
and stop-signal-driven context exit. The runtime probe patches the optional SDK and invokes the
real `_taskvine_factory` function.

`ParslTaskVineSubmit.tla` refines TaskVine submission ordering. The current path registers a
Future before callable/argument serialization and before checking manager-process liveness, so
both failures can leave an orphaned task-map entry. The fixed branch rolls back the entry. The
runtime probe drives both failures through the concrete `TaskVineExecutor.submit` method.

`ParslTaskVineDuplicateReport.tla` refines the TaskVine collector with a duplicate or late manager
report. The current `tasks.pop(task_report.executor_id)` path raises `KeyError`, exits the
collector, and lets final cleanup fail unrelated Futures. The fixed configuration ignores an
executor ID that has already been removed. `tests/test_taskvine_duplicate_report_runtime.py`
drives the real collector method through this interleaving.

`ParslRadicalPilotResults.tla` models RadicalPilot task callbacks for Bash, Python, and MPI-like
tasks: DONE maps to an exit code, deserialized value, or raw MPI return; CANCELED cancels the
Future; FAILED sets an exception; and a master failure fails all outstanding tasks. The actual
configuration probes shutdown with a pending RP task, because the current `shutdown()` closes the
session without an explicit sweep of `future_tasks`; the fixed configuration adds that sweep.
This follows [`radical/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/radical/executor.py).

`ParslRadicalPilotLateCallback.tla` isolates a terminal-state race in the same callback path:
after a task is canceled, a late `DONE` callback currently calls `Future.set_result` and raises
`InvalidStateError`. The fixed branch treats the callback as stale. The runtime probe reproduces
the two callbacks against the real `task_state_cb` implementation.

`ParslRadicalPilotBulkShutdown.tla` covers the bulk collector shutdown path. The current
`shutdown()` sets `_terminate` before joining the collector, which makes the collector exit before
submitting queued tasks; their Futures remain pending. The fixed branch flushes the bulk queue
before collector exit. The runtime probe calls the real `_bulk_collector` with an already-set stop
event and verifies that its queued item is left behind.

`ParslGlobusComputeConfig.tla` models the thin Globus Compute wrapper's temporary resource and
endpoint configuration. Each submit copies task-specific values into the shared SDK executor,
calls the underlying submit, and restores both defaults in `finally`. The unsynchronized
configuration finds cross-task specification or endpoint use under interleaving submits; the
serialized configuration captures the caller-side lock required to make the wrapper safe. This follows
[`globus_compute.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/globus_compute.py).

`ParslGlobusComputeResult.tla` models the complementary result boundary: the wrapper returns the
SDK Future directly, so success, exception, and cancellation propagate without a second Future.
The TLC model checks identity and terminal-result consistency, and
[`tests/test_globus_compute_result_runtime.py`](../tests/test_globus_compute_result_runtime.py)
verifies the behavior with a fake SDK executor.

`ParslGlobusComputeSubmitRace.tla` models concurrent calls to the same Globus Compute wrapper.
Because `GlobusComputeExecutor.submit` temporarily mutates shared SDK executor configuration,
the current branch permits one task to observe another task's resource specification or the
restored default. The fixed branch serializes the critical section. The runtime probe forces the
interleaving with two threads and a blocking fake SDK executor.

`ParslBlockProviderBadStateOrdering.tla` refines `BlockProviderExecutor.set_bad_state_and_fail_all`.
The current loop calls `set_exception` without checking whether a Future is already terminal; a
completed Future can raise `InvalidStateError` and leave later pending tasks unresolved. TLC finds
the two-state counterexample and the fixed branch skips terminal Futures. The runtime probe is
[`tests/test_block_provider_bad_state_order_runtime.py`](../tests/test_block_provider_bad_state_order_runtime.py).

`ParslJobStatusOutputReadError.tla` models the read-error mismatch in `JobStatus`: `stdout`
swallows all file-read exceptions, while `stdout_summary` and `stderr_summary` currently swallow
only `FileNotFoundError`. TLC finds the three-state current counterexample for a permission error;
the fixed branch returns no output consistently. The runtime probe is
[`tests/test_job_status_output_read_error_runtime.py`](../tests/test_job_status_output_read_error_runtime.py).

`ParslBlockProviderBadStateMutation.tla` models callback mutation during
`BlockProviderExecutor.set_bad_state_and_fail_all`. Because `Future.set_exception()` executes
callbacks synchronously, a callback can modify the live `_tasks` dictionary and raise
`RuntimeError`, leaving another original task pending. TLC finds the two-state current
counterexample; the fixed branch iterates a snapshot. The runtime probe is
[`tests/test_block_provider_bad_state_mutation_runtime.py`](../tests/test_block_provider_bad_state_mutation_runtime.py).

`ParslFluxCancelSubmitRace.tla` models the cancellation interleaving in
`FluxFutureWrapper.cancel`: cancellation can happen before `_flux_future` is bound, after which
a late successful callback currently attempts to publish into the cancelled wrapper. The current
configuration violates `NoLateCallbackError`/`NoLatePublication`; the fixed configuration carries
the cancellation request into binding. The direct probe is
`tests/test_flux_cancel_submit_race_runtime.py`.

`ParslFluxErrorCleanupCancellation.tla` models `_error_out_jobs` after a Flux submission-thread
failure. The current helper can raise on a canceled first Future while setting its exception,
leaving later queued Futures pending; the fixed branch treats canceled Futures as stale and drains
the remainder. The runtime probe drives the real helper with a canceled and a pending Future.

`ParslProviderKinds.tla` refines the provider side with concrete backend semantics. It models
the common `ExecutionProvider` API (`submit`, `status`, and `cancel`), Slurm-like cluster status
translation, Kubernetes pod status translation, scheduler command failure, missing-job behavior,
timeout as distinct from failure, cancellation success/failure, executor-driven `SCALED_IN`,
and CPU-per-task admission. It also covers Slurm `SUSPENDED` to `HELD` and `REQUEUED` to
`PENDING` translations while preserving terminal-state stability.
The missing-job rule intentionally preserves the current Slurm provider behavior (a job absent
from `squeue` is treated as completed) while Kubernetes reports an unknown pod as `UNKNOWN`.

`ParslProviderPollClockRollback.tla` models the polling guard in
`BlockProviderExecutor.poll_facade`. A wall-clock rollback makes
`now >= _last_poll_time + status_polling_interval` false and suppresses provider status updates
until the old timestamp is reached. TLC finds the two-state current counterexample; the fixed
branch resets the polling baseline on rollback. The runtime probe is
[`tests/test_provider_poll_clock_runtime.py`](../tests/test_provider_poll_clock_runtime.py).

`ParslAWSProviderStatus.tla` adds a cloud-provider-specific status boundary. It models EC2
`pending`/`running`/`terminated` translation and the case where a requested instance ID is absent
from the `describe_instances` response. The actual configuration preserves the current behavior
and exposes an incomplete status result; the fixed configuration supplies a terminal completion
mapping for the missing instance. This follows
[`aws.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/aws/aws.py).
This is a bounded status-mapping model, not a shell or Kubernetes API emulator. It is based on
[`providers/base.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/base.py),
[`providers/cluster_provider.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/cluster_provider.py),
[`providers/slurm/slurm.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/slurm/slurm.py),
[`providers/kubernetes/kube.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/kubernetes/kube.py),
and [`jobs/states.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/states.py).

`ParslKubernetesPolling.tla` is a source-level bug probe for Kubernetes pod reads. The actual
configuration (`USE_FIXED = FALSE`) reproduces the current exception branch: a failed pod read
records an API error but leaves a running job in `RUNNING`, because the source uses an identity
comparison against a newly constructed `JobStatus` object. TLC produces a two-state counterexample.
The companion fixed configuration (`USE_FIXED = TRUE`) represents the intended value-based check
and proves that every read error exposes `UNKNOWN` while terminal states remain stable. A likely
source fix is to test `status.state == JobState.RUNNING` rather than `status is JobStatus(...)`.
This is a model-derived candidate for a Parsl regression test, not a claim that the external source
has already been patched.

`ParslProviderStatusBatch.tla` models the scheduler polling boundary more closely. Active jobs
are queried in bounded batches; a failed or timed-out scheduler command leaves the previous
provider status map unchanged, while a successful poll applies all reported states atomically
and maps jobs absent from the scheduler output to `COMPLETED` (the current Slurm fallback rule).
The finite configuration bounds the number of successful polls while retaining all status
translation branches. This follows the batching and `execute_wait` behavior in
[`cluster_provider.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/cluster_provider.py)
and [`slurm.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/providers/slurm/slurm.py).

`ParslClusterProviderUnknownJob.tla` checks the common `ClusterProvider.status` lookup contract.
The current method raises `KeyError` when a requested scheduler job is absent from local
`resources`, even after a successful poll. The fixed configuration returns an explicit `MISSING`
state instead. The runtime probe uses a minimal concrete `ClusterProvider` subclass and invokes
the real common method.

`ParslProviderExecutorBridge.tla` connects those provider observations to executor admission.
It models a pilot block moving from `pending` to `running`, manager registration, task submission,
unknown status without immediate teardown, and terminal provider observations from either the
pre-manager `pending` phase or the post-registration phase. Terminal observations revoke manager
and worker capacity and account for queued/running work as lost. This cross-component model is
intentionally small so a provider/executor inconsistency produces a short TLC trace.

`ParslHeartbeatProvider.tla` adds the time boundary between provider status and HTEX manager
health. A transient provider `unknown` state does not revoke an otherwise healthy manager;
heartbeat age is advanced separately, and crossing the threshold removes the manager and marks
its in-flight tasks lost. Provider terminal states still revoke the block independently. This
matches the interchange's `last_heartbeat` update and expiry path in
[`high_throughput/interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py).

`ParslResultRace.tla` focuses on DFK callback ordering. It separates a physical attempt's
failure/success message from delivery of that message, permits a late success after a failure
callback has already selected a retry, and requires that only the current attempt can resolve the
logical Future. Older or duplicate callbacks are consumed as stale. This mirrors the retry and
Future-completion branches in [`dflow.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/dflow.py).

`ParslJoinCallbackRace.tla` refines `join_app` at callback level. An inner completion callback
may run while another inner Future is still unresolved; that callback returns without finalizing.
The callback for the final done Future performs the all-done check under a modeled join lock.
Failures therefore propagate as `JoinError` only after every selected Future is done, and duplicate
callbacks after outer termination are harmless. Ordered list results remain tied to input order.

`ParslJoinDuplicateFailureAggregation.tla` extends failure aggregation to duplicate list
positions. The same failed Future appearing twice must contribute two entries to
`JoinError.dependent_exceptions_tids`, because the concrete callback scans the list rather than a
set of Future identities. The current configuration loses one entry; the fixed configuration and
runtime probe preserve both.

`ParslJoinMemoData.tla` connects that callback protocol to two real DFK boundaries: a memoization
hit returns an already-completed Future without launching an executor attempt, while a file-valued
`DataFuture` remains unresolved through staging until data readiness is published. The outer join
cannot finalize before the staged file is ready, and its aggregate still preserves input order.
This follows the `BasicMemoizer.check_memo` and `DataFuture.parent_callback` contracts in
[`memoization.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/dataflow/memoization.py)
and [`futures.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/app/futures.py).

`ParslJoinMonitoring.tla` connects the resulting outer join status to the asynchronous monitoring
radio/database model. It emits versioned `joining`, `succeeded`, and `failed` events, permits radio
reordering and write failure/retry, and prevents an older/non-terminal event from overwriting a
terminal database row. The join/data invariants remain active while monitoring delivery is delayed.
The event categories correspond to the task-information channel in
[`monitoring/message_type.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/monitoring/message_type.py)
and the sender/receiver boundary in [`monitoring/radios/base.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/monitoring/radios/base.py).

`ParslResourceAdmission.tla` models concrete WorkQueue-style resource admission. It checks the
accepted resource-specification fields (`cores`, `memory`, `disk`, `gpus`, priority, and runtime),
the rule that cores/memory/disk are supplied together when `autolabel=False`, and worker-level
capacity accounting while tasks wait, dispatch, and complete. The companion autolabel
configuration checks that a partial specification is admitted only when autolabeling is enabled.
This follows the validation and task tuple construction in
[`workqueue/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/workqueue/executor.py).

`ParslResourceScaling.tla` connects resource demand to provider block scaling. A task whose core
demand exceeds current block capacity causes a pending block request; allocation success adds
capacity, allocation failure rolls back only the pending request, and a later strategy step may
retry. Dispatch remains guarded by aggregate core capacity, and scale-in cannot remove the
minimum block floor. This combines the resource-aware admission abstraction with the slot-pressure
rules in [`jobs/strategy.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/strategy.py)
and block request handling in [`executors/status_handling.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/status_handling.py).

`ParslPollerBadState.tla` models the ordering in `JobStatusPoller.poll`: provider status is
refreshed first, the error handler counts `FAILED`/`MISSING` blocks, and strategy scaling is
available only while the executor is healthy. Reaching the initial-block failure threshold puts
the executor in bad state, fails outstanding tasks, and prevents later task admission or scale-out.
The abstraction follows [`jobs/job_status_poller.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/job_status_poller.py),
[`jobs/error_handlers.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/jobs/error_handlers.py),
and [`executors/status_handling.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/status_handling.py).

`ParslPollerCloseScaleInRace.tla` refines the shutdown side of that poller. `Timer.close(timeout)`
can return while a status callback is still running, but the current `JobStatusPoller.close` then
scales in providers immediately. TLC finds `ScaleInAfterPollQuiescence`; the fixed branch waits
for callback quiescence before scale-in. The runtime probe drives the concrete close method with a
controlled live-thread double.

`ParslSerializationWire.tla` models the concrete `pack_apply_message` wire shape: callable,
args, and kwargs are serialized separately; callable/data serializer identifiers are placed before
each body; decimal length prefixes frame the buffers in order; and unpack/decode cannot dispatch
until all three buffers are valid. It also models serializer failure and corrupt-frame rejection.
The configurations use the current identifiers (`C2` for callable dill and `02` for data dill)
from [`serialize/facade.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/serialize/facade.py)
and [`serialize/concretes.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/serialize/concretes.py).

`ParslSerializationLength.tla` checks the declared-length framing boundary directly. The current
`unpack_buffers` behavior accepts a truncated frame (`5\nabc`) as a three-byte buffer, violating
`LengthSafety`; the fixed configuration models strict rejection. This is retained as an
executable counterexample for a future parser-hardening change.

`ParslSerializationNegativeLength.tla` checks the signed-length boundary. A negative header
currently performs a Python negative slice and then reaches a second parse failure on the
leftover byte; the fixed configuration rejects the malformed declaration before slicing. The
runtime probe records the real `ValueError` behavior.

`ParslSerializationFrameCount.tla` checks the complementary extra-frame boundary. The current
`unpack_and_deserialize` decodes every framed buffer before asserting that an apply message has
exactly three buffers, so a fourth frame can trigger deserializer work before rejection. The fixed
configuration validates the frame count before decoding.

`ParslApplyMessageArity.tla` applies the exact-three-buffer contract to the public
`unpack_apply_message` function. The current unpacker returns an extra decoded frame and leaves
the failure to `execute_task` tuple assignment; the fixed configuration rejects non-three-frame
messages at the unpack boundary. `tests/test_apply_message_arity_runtime.py` drives the real
facade.

`ParslSerializationZMQBridge.tla` connects those framed buffers to a bounded ZMQ-like route.
Task and result messages carry an attempt id and serializer token; send/receive can drop, duplicate,
or misroute a message; decode is required before task dispatch; and only a result for the current
attempt can resolve the Future. A result from an old attempt is explicitly stale even after a
valid decode. This combines the concrete serialization facade with the ROUTER/DEALER-style
correlation already abstracted in `ParslZMQ.tla`.

`ParslSerializationPluginError.tla` models unknown serializer headers that dynamically import a
class. The current facade wraps import/construction failures but lets an imported class without a
`deserialize()` method leak `AttributeError`; the fixed branch wraps that interface failure as a
`DeserializerPluginError`. `tests/test_serialization_plugin_error_runtime.py` contrasts both
paths with a real `builtins.str` plugin header.

`ParslHtexResultQueue.tla` probes the concrete HTEX result thread. It models successful result
decoding, exception decoding, malformed result messages, duplicate task IDs, and the special
interchange-failure message. The actual configuration reproduces an orphaned Future when a
malformed message is popped from `tasks` before validation; the fixed configuration keeps the
Future terminal and ignores duplicates. This follows
[`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py)
around `_result_queue_worker` and `submit_payload`.

`ParslHtexResultDecodeFailure.tla` refines the result path when the payload itself is corrupt. The
current worker pops the Future before `deserialize(result)`, so a decode exception exits with a
pending Future no longer present in `tasks`; the fixed branch delivers a deserialization failure
and keeps the worker alive.

`ParslHtexSubmitFailure.tla` covers the submit-side half of that lifecycle. If
`outgoing_q.put` fails after `submit_payload` inserts its Future into `tasks`, the current path
leaves a pending orphan; fixed behavior rolls back the map entry and fails the Future.

The registration mismatch branch is exercised directly with a fake ROUTER socket:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_version_mismatch_runtime.py -v
```

The probe confirms that incompatible manager versions set the kill event, emit a fatal
`task_id=-1` `VersionMismatch` result, and never enter `_ready_managers`.

`ParslHtexVersionMismatch.tla` models registration rejection when manager Python/Parsl versions
do not match. The actual configuration exposes a race: the interchange has already set its kill
event and queued the `task_id=-1` fatal result, but the executor result thread has not yet set
`bad_state_is_set`; `submit_payload` can therefore accept another task in that window. The fixed
configuration adds an admission guard for the closed interchange/pending-fatal state. This follows
the registration branch and fatal result construction in
[`interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py)
and the admission check in
[`high_throughput/executor.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/executor.py).

`ParslHtexDispatchPriority.tla` models the HTEX pending-task queue and manager dispatch boundary.
It uses the current `SortedList` ordering (`-priority`, then `-task_id`), dispatches only while a
manager has capacity and is not draining, releases capacity on completion, and clears in-flight
work when the manager fails. This follows the queue insertion, `get_tasks`, and
`process_tasks_to_send` paths in
[`interchange.py`](https://raw.githubusercontent.com/Parsl/Parsl/master/parsl/executors/high_throughput/interchange.py).

Each logical task also has two abstract serialization capabilities: membership in
`CALLABLE_SERIALIZABLE` represents whether the Python function can be encoded, while
membership in `PAYLOAD_SERIALIZABLE` represents whether its arguments or closure object graph
can be encoded. `SerializeAttempt` requires both. If either capability is absent,
`SerializationFailure` rejects the attempt before a worker is assigned and applies the normal
retry bound.

The finite object-graph refinement adds `OBJECTS`, `TASK_OBJECTS`, `SERIALIZABLE_OBJECTS`, and
`OBJECT_EDGES`. A task's object set stands for its function object, arguments, and closure
contents; two bounded levels of referenced children are checked. Thus a task can have a
serializable callable and top-level arguments but still fail because a nested closure object is
not serializable. `ParslNestedSerialization.cfg` exercises that grandchild failure path. This is
still symbolic rather than an execution of Python `pickle`, but it makes the failure cause
explicit and gives TLC a concrete counterexample vocabulary.

Result encoding is checked separately through the optional symbolic object `task:result`. If
that object (or its bounded descendants) is not serializable, `SerializeResult` is disabled and
`ResultSerializationFailure` releases the worker, drops the result envelope, and follows the
normal retry/rejection path. `ParslResultSerializationFailure.cfg` exercises this post-execution
failure.

File-oriented data readiness is represented by `dataState`:

```text
unavailable -> staging -> available -> stageout_chunk1 -> stageout_chunk2 -> transferred
              \-> staging_corrupt -> staging
                                      \-> stageout_chunk1_corrupt
                                      \-> stageout_chunk2_corrupt
```

`BeginStaging`/`FinishStaging` model input stage-in before dependency release. `CorruptStaging`
and `RepairStaging` model an input transfer that is damaged before it becomes available. For tasks in
`FILE_OUTPUTS`, `BeginStageOut` starts output transfer, `TransferOutputChunk` advances the first
chunk, and `FinishStageOut` commits the second chunk as `transferred`. This prevents a model
execution from claiming that a file is ready before all transfer stages complete. The token stands
for file contents and transfer completion without enumerating bytes, paths, or a particular staging provider. The checked
configurations use task `C` as one representative output file to keep the finite state space
small while still exercising both directions of the data path.

The corruption refinement records which chunk was damaged: corruption of the first or second
chunk enters a chunk-specific state, and repair resumes from that chunk rather than silently
marking the whole file transferred. This is a symbolic content/checksum abstraction, not a byte-
for-byte file-system simulation.

The file-content refinement defines a deterministic symbolic token `task:content` for each
logical output task. `FinishStageOut` therefore represents transfer of that task's content token,
not just a boolean readiness flag. `FileContentSafety` checks that a transferred output has the
correct logical token and that stage-out is only associated with a completed result. The token
stands for bytes or a checksum at this level; the two chunk states provide a bounded transfer
protocol, while later refinements can replace them with checksums and richer corruption transitions.

## What is and is not modeled

The current model covers the major control-flow effects represented in the paper's DFK,
executor, interchange/manager, provider, and dataflow architecture. It does **not** simulate
every implementation detail or every component in full fidelity.

Deliberately abstracted away are ZMQ byte messages, serialized Python objects, callable
contents, real filenames, wall-clock time, heartbeat timing, database schema, monitoring
transport, and the exact behavior of every alternative executor/provider. Data staging is
represented only by `unavailable/staging/available`. The model therefore checks protocol
properties of a bounded abstraction; it is not a proof that the complete Parsl implementation
is correct.

The submission path now exposes an abstract message lifecycle: `SerializeAttempt` represents
encoding the task payload, `SendAttempt` and `ReceiveAttempt` represent transport across the
interchange boundary, and `DecodeAttempt` represents reconstructing the work item. Dispatch to
a worker is enabled only after decoding succeeds. Payload bytes and Python object contents remain
abstract; this stage checks ordering and failure-safe handoff rather than ZMQ or pickle behavior.

The wire lifecycle is represented explicitly by `taskWireState` and `resultWireState` for every
physical attempt. Each side has the finite states `none`, `queued`, `sent`, `received`,
`acknowledged`, and `consumed`, while `taskEnvelope` and `resultEnvelope` record whether the serialized envelope is
`valid` or `invalid`. `MessageSafety` checks that a queued/sent/received envelope agrees with the
corresponding attempt state. This is a protocol-level ZMQ abstraction: it models the two message
directions and their ordering without enumerating sockets, byte buffers, or multipart frames.
The result direction additionally uses `acknowledged` between `received` and `consumed`, modeling
a receiver-side consume acknowledgement before decode without claiming a particular ZMQ wire
ack implementation.
`ProtocolProgress` gives ACK transitions their own strong-fairness obligation; duplicate/discard
traffic alone is not treated as useful progress, preventing a livelock from starving decode.
The next refinement can add bounded drops, duplicate deliveries, and symbolic object graphs
without changing the logical-task/physical-attempt boundary.

`DropTaskMessage` and `DropResultMessage` add a bounded network-loss hypothesis. A dropped task
envelope never reaches a worker; a dropped result envelope releases the worker and turns the
current attempt into `lost`, after which the ordinary retry or rejection path applies. The
message-loss configuration checks that a dropped or invalid envelope cannot resolve a Future,
leak a worker binding, or bypass the retry bound.

`DuplicateTaskMessage` and `DuplicateResultMessage` model a receiver observing a second copy
of an already received envelope. The duplicate must pass through an explicit discard action
before the normal decode action can continue; it cannot create a second logical completion.

`MisrouteAttempt` models decoded work offered to a manager belonging to the wrong executor.
The message is rejected and the attempt follows the lost/retry path instead of executing on the
wrong manager.

`MisrouteResult` applies the same check on the return path: a result envelope claiming a
different executor source is rejected before `AttemptSuccess` can resolve the Future.

The result path has the same shape after worker execution: `SerializeResult`, `SendResult`,
`ReceiveResult`, and `DecodeResult` must occur before `AttemptSuccess` resolves the Future. A
worker or executor failure can still replace an in-flight result with a retry, so a result from
the old attempt remains eligible only for the explicit stale-result transition.

## Join applications

Tasks in `JOIN_TASKS` model Parsl `join_app` tasks. Their first successful physical attempt
returns a join handle rather than resolving the outer Future: the logical task enters
`joining`, and `JoinObserve` records completion of each inner Future listed in `JOIN_DEPS`.
`JoinComplete` resolves the outer Future only after every inner Future succeeds; with failures
enabled, `JoinFailure` propagates a rejected inner Future to the outer task. This keeps the
outer logical task separate from the physical attempt that produced the list of inner Futures,
matching `DataFlowKernel.handle_exec_update` and `handle_join_update`.
Successful joins carry a distinct symbolic `join-result` output marker, recording that the outer
value is an aggregation rather than an ordinary task result while remaining independent of the
concrete Python list/dict shape.
`JoinHandleSafety` also keeps the intermediate `join-handle` distinct from the final aggregate.
`JoinFailureSafety` requires a failed outer join to have a rejected inner Future; an arbitrary
outer rejection cannot masquerade as inner-Future propagation.

`JOIN_INVALID` models a join app whose callable returns neither a Future nor a list of Futures.
The physical attempt may finish successfully, but join unwrapping fails deterministically and
the outer Future becomes rejected. `ParslJoinInvalid.cfg` checks this TypeError-like branch
without allowing it to masquerade as a successful join.

## Logical time and heartbeat failures

The model uses a bounded logical clock rather than wall-clock timestamps. `Tick` advances the
clock, `Heartbeat` records the latest manager heartbeat for a worker, and `StartAttemptTimed`
records an attempt start time. `WorkerFailure` can therefore be enabled by a heartbeat age beyond
`HEARTBEAT_TIMEOUT`, while `AttemptTimeout` can be enabled by an attempt age beyond
`TASK_TIMEOUT`. A timeout on the final retry now rejects the Future and terminates the task rather
than leaving it indefinitely running. The full workflow configurations set `MAX_TIME = 0` to avoid combining every
workflow interleaving with clock values; `ParslTime.cfg` is a deliberately tiny one-task model
that explores the time and timeout transitions with `MAX_TIME = 1`.
`ParslTimeoutTerminal.cfg` uses `MAX_RETRIES = 0` to check the terminal-timeout path directly.
For an executor with multiple manager workers, `IdleManagerTimeout` removes only the expired
manager's block; remaining managers and capacity stay active until the final expiry.

Monitoring is modeled as `monitoringState`, a per-task database record containing the last
persisted status and a monotonic write `version`. `PublishMonitor` may lag behind the logical
task state, matching asynchronous monitoring delivery, but `MonitoringConsistency` forbids a
persisted terminal success, memoized state, or failure from appearing before the corresponding
logical outcome. `MonitoringDatabaseSafety` ensures the initial `none` record has version zero
and every published update advances its version. As with time, the full workflow configurations
disable event expansion and `ParslMonitoring.cfg` is the focused one-task exploration. A bounded
`write_failed` state represents a transient database write error; recovery must publish the
current logical view again rather than inventing a terminal status.

Executor/provider submission is separated into two hypotheses. `SubmitAttempt` is allowed only
for an executor in `SUBMITTABLE_EXECUTORS`, representing an executor whose bad-state check and
submit path accept work. `SubmitFailure` represents a provider block that exists while the
executor rejects new submissions; it creates a failed physical attempt before any worker is
bound and follows the normal retry/rejection path. `ParslSubmitFailure.cfg` explores this race
with a one-task executor whose submit set is empty.

Provider block failure is modeled separately from allocation failure. `ProviderFailure` represents
an already-active block terminating while idle; it marks the provider and executor unavailable and
clears the desired and active block counts. `ProviderExecutorConsistency` checks that an active
provider implies an up executor with a positive block count, and that a failed provider has no
remaining target or active blocks. Recovery requests increment the target again before a new
allocation can become active.

## TLC verification

The compact integration check is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslEndToEnd.cfg models/core/ParslEndToEnd.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslEndToEndFixed.cfg models/core/ParslEndToEnd.tla
```

The first command is an intentional counterexample configuration: an old attempt can resolve the
Future, including a late result from an attempt that has already timed out. The fixed configuration
rejects both forms of stale result and passes all seven invariants (`CurrentAttemptResultSafety`
included).

The task/stage-out/monitoring boundary is checked separately:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringCurrent.cfg models/core/ParslTaskStagingMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTaskStagingMonitoringFixed.cfg models/core/ParslTaskStagingMonitoring.tla
```

`ParslTaskStagingMonitoring.tla` combines logical producer completion, chunked
`DataManager`/`DataFuture` publication, dependent-consumer admission, and monitoring database
delivery. The current branch permits a success observation before all chunks arrive; the fixed
branch gates monitoring success and consumer admission on complete publication (21 distinct
states checked).

The provider-failure/retry boundary is also modeled:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslProviderFailureRetryCurrent.cfg models/core/ParslProviderFailureRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslProviderFailureRetryFixed.cfg models/core/ParslProviderFailureRetry.tla
```

`ParslProviderFailureRetry.tla` models a provider block disappearing during a physical attempt,
executor loss, provider recovery, retry admission, and a late result from the lost worker. The
current branch resolves the logical Future with that late result; the fixed branch rejects it as
stale and checks 79 distinct states.

The result-deserialization/retry boundary is modeled by:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslResultDecodeRetryCurrent.cfg models/core/ParslResultDecodeRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslResultDecodeRetryFixed.cfg models/core/ParslResultDecodeRetry.tla
```

`ParslResultDecodeRetry.tla` represents a corrupt result payload, retry admission, and an old
frame arriving after the new attempt starts. The fixed branch rejects the old frame and checks 18
distinct states. Runtime probes are `test_htex_result_decode_failure_runtime.py` and
`test_htex_result_queue_runtime.py`.

The combined clock/heartbeat check is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimedHeartbeat.cfg models/clock/ParslTimedHeartbeat.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimedHeartbeatFixed.cfg models/clock/ParslTimedHeartbeat.tla
```

The current branch produces a `ResultSafety` counterexample after timeout or manager expiry; the
fixed branch rejects the late result and checks 3,061 states.

The monitoring delivery check is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDelivery.cfg models/monitoring/ParslMonitoringDelivery.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDeliveryFixed.cfg models/monitoring/ParslMonitoringDelivery.tla
```

The current branch exposes an older monitoring event overwriting a newer database record; the
fixed branch preserves the version high-water mark and checks 1,978 states.

The provider/executor lifecycle check is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslExecutorProviderLifecycle.cfg models/executors/ParslExecutorProviderLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslExecutorProviderLifecycleFixed.cfg models/executors/ParslExecutorProviderLifecycle.tla
```

The current branch exposes scale-in below `MIN_BLOCKS`; the fixed branch preserves the provider
floor and checks 161 states.

The serializer registry check is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializerRegistry.cfg models/serialization/ParslSerializerRegistry.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializerRegistryFixed.cfg models/serialization/ParslSerializerRegistry.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializerRegistryNormal.cfg models/serialization/ParslSerializerRegistry.tla
```

The collision configuration finds the code-first dispatch counterexample in 4 states; the fixed
and normal configurations pass in 6 states each.

The combined ZMQ/serialization check is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQSerializationEndToEnd.cfg models/serialization/ParslZMQSerializationEndToEnd.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQSerializationEndToEndFixed.cfg models/serialization/ParslZMQSerializationEndToEnd.tla
```

The current branch allows a decoded result from the wrong attempt to resolve the Future; the
fixed branch preserves correlation and checks 562,641 states.

The combined `join_app` check is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinComplete.cfg models/dataflow/ParslJoinComplete.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinCompleteFixed.cfg models/dataflow/ParslJoinComplete.tla
```

The current branch loses duplicate Future positions; the fixed branch preserves list order and
checks 5,694 states.

The checked configurations use three logical tasks (`A`, `B`, `C`), two executors, two
workers, one retry, and one block per executor. Java and `tla2tools.jar` are required.

```bash
java -cp tla2tools.jar tlc2.TLC -deadlock -config parsl.cfg parsl.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslMemo.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslSerializationFailure.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslNoFailures.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslTime.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslMonitoring.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslSubmitFailure.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslProviderFailure.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslJoin.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslJoinSafety.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslJoinInvalid.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslRegistration.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslRegistrationFailure.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslIdleManagerTimeout.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslExecutorDrain.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslMisroute.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslResultMisroute.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslMessaging.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslMessageLoss.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslMessageDuplicate.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslFileContent.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslFileCorruptionSmall.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -config models/core/ParslNestedSerialization.cfg models/core/ParslAbstract.tla
java -cp tla2tools.jar tlc2.TLC -config models/strategy/ParslStrategy.cfg models/strategy/ParslStrategy.tla
java -cp tla2tools.jar tlc2.TLC -config models/strategy/ParslStrategyBlockCapacityCurrent.cfg models/strategy/ParslStrategyBlockCapacity.tla
java -cp tla2tools.jar tlc2.TLC -config models/strategy/ParslStrategyBlockCapacityFixed.cfg models/strategy/ParslStrategyBlockCapacity.tla
java -cp tla2tools.jar tlc2.TLC -config models/strategy/ParslStrategyBlockCapacitySuccess.cfg models/strategy/ParslStrategyBlockCapacity.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProbeAddresses.cfg models/executors/ParslProbeAddresses.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProbeAddressesEmpty.cfg models/executors/ParslProbeAddresses.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProbeAddressesSuccess.cfg models/executors/ParslProbeAddresses.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCurveZMQCertificateModeValid.cfg models/serialization/ParslCurveZMQCertificateMode.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCurveZMQCertificateModeInvalid.cfg models/serialization/ParslCurveZMQCertificateMode.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQ.cfg models/serialization/ParslZMQ.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPython.cfg models/serialization/ParslPython.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPythonFailure.cfg models/serialization/ParslPython.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableArgumentAliasCurrent.cfg models/serialization/ParslCallableArgumentAlias.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableArgumentAliasFixed.cfg models/serialization/ParslCallableArgumentAlias.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableSerializerCache.cfg models/serialization/ParslCallableSerializerCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableSerializerCacheFixed.cfg models/serialization/ParslCallableSerializerCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableDeserializeCacheCurrent.cfg models/serialization/ParslCallableDeserializeCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableDeserializeCacheFixed.cfg models/serialization/ParslCallableDeserializeCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationSnapshot.cfg models/serialization/ParslSerializationSnapshot.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFileBytes.cfg models/staging/ParslFileBytes.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDataFutureCopy.cfg models/dataflow/ParslDataFutureCopy.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncStageInFail.cfg models/staging/ParslRsyncStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncStageOutFail.cfg models/staging/ParslRsyncStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncStageSuccess.cfg models/staging/ParslRsyncStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStageCurrent.cfg models/staging/ParslHTTPStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStageFixed.cfg models/staging/ParslHTTPStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStageSuccess.cfg models/staging/ParslHTTPStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPStageCurrent.cfg models/staging/ParslFTPStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPStageFixed.cfg models/staging/ParslFTPStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPStageSuccess.cfg models/staging/ParslFTPStage.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusStageDependency.cfg models/staging/ParslGlobusStageDependency.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusStageOutDependency.cfg models/staging/ParslGlobusStageDependency.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTransferFailureCurrentEmpty.cfg models/staging/ParslGlobusTransferFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTransferFailureCurrentEvent.cfg models/staging/ParslGlobusTransferFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTransferFailureFixedEmpty.cfg models/staging/ParslGlobusTransferFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTransferFailureSuccess.cfg models/staging/ParslGlobusTransferFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusEndpointPathCurrent.cfg models/staging/ParslGlobusEndpointPath.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusEndpointPathFixed.cfg models/staging/ParslGlobusEndpointPath.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusEndpointPathValid.cfg models/staging/ParslGlobusEndpointPath.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFileCleanCopyCurrent.cfg models/staging/ParslFileCleanCopy.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFileCleanCopyFixed.cfg models/staging/ParslFileCleanCopy.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslStageOutFuture.cfg models/staging/ParslStageOutFuture.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslStageOutInTask.cfg models/staging/ParslStageOutFuture.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslStageOutNone.cfg models/staging/ParslStageOutFuture.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslMultiOutputStageOutCurrent.cfg models/staging/ParslMultiOutputStageOut.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslMultiOutputStageOutEarly.cfg models/staging/ParslMultiOutputStageOut.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslClock.cfg models/clock/ParslClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslClockTerminal.cfg models/clock/ParslClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslFutureWaitTimeout.cfg models/dataflow/ParslFutureWaitTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatBoundary.cfg models/executors/ParslHeartbeatBoundary.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatClockJumpCurrent.cfg models/executors/ParslHeartbeatClockJump.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatClockJumpFixed.cfg models/executors/ParslHeartbeatClockJump.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatClockJumpNormal.cfg models/executors/ParslHeartbeatClockJump.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDB.cfg models/monitoring/ParslMonitoringDB.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBReorder.cfg models/monitoring/ParslMonitoringDB.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDeferred.cfg models/monitoring/ParslMonitoringDeferred.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsert.cfg models/monitoring/ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsertFixed.cfg models/monitoring/ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDBInsertPresent.cfg models/monitoring/ParslMonitoringDBInsert.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchCurrent.cfg models/monitoring/ParslMonitoringBatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchFixed.cfg models/monitoring/ParslMonitoringBatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchPositive.cfg models/monitoring/ParslMonitoringBatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchClockCurrent.cfg models/monitoring/ParslMonitoringBatchClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchClockFixed.cfg models/monitoring/ParslMonitoringBatchClock.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchAtomicityCurrent.cfg models/monitoring/ParslMonitoringBatchAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchAtomicityFixed.cfg models/monitoring/ParslMonitoringBatchAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringBatchAtomicitySuccess.cfg models/monitoring/ParslMonitoringBatchAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringThreshold.cfg models/monitoring/ParslMonitoringThreshold.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringThresholdFixed.cfg models/monitoring/ParslMonitoringThreshold.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslRetryHandlerCurrent.cfg models/dataflow/ParslRetryHandler.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslRetryHandlerFixed.cfg models/dataflow/ParslRetryHandler.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslRetryHandlerPositive.cfg models/dataflow/ParslRetryHandler.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoFunctionIdentityCurrent.cfg models/dataflow/ParslMemoFunctionIdentity.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoFunctionIdentityFixed.cfg models/dataflow/ParslMemoFunctionIdentity.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoFunctionIdentityStable.cfg models/dataflow/ParslMemoFunctionIdentity.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoExceptionCheckpointCurrent.cfg models/dataflow/ParslMemoExceptionCheckpoint.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoExceptionCheckpointFixed.cfg models/dataflow/ParslMemoExceptionCheckpoint.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoCheckpointOrderCurrent.cfg models/dataflow/ParslMemoCheckpointOrder.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoCheckpointOrderFixed.cfg models/dataflow/ParslMemoCheckpointOrder.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslLastCheckpointUUIDCurrent.cfg models/dataflow/ParslLastCheckpointUUID.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslLastCheckpointUUIDFixed.cfg models/dataflow/ParslLastCheckpointUUID.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslExecuteWaitTimeoutCurrent.cfg models/executors/ParslExecuteWaitTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslExecuteWaitTimeoutFixed.cfg models/executors/ParslExecuteWaitTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslExecuteWaitTimeoutSuccess.cfg models/executors/ParslExecuteWaitTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoDictOrderingCurrent.cfg models/dataflow/ParslMemoDictOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoDictOrderingFixed.cfg models/dataflow/ParslMemoDictOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslMemoDictOrderingHomogeneous.cfg models/dataflow/ParslMemoDictOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncQuotingCurrent.cfg models/staging/ParslRsyncQuoting.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncQuotingFixed.cfg models/staging/ParslRsyncQuoting.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncQuotingNormal.cfg models/staging/ParslRsyncQuoting.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandDeadlineCurrent.cfg models/executors/ParslCommandDeadline.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandDeadlineFixed.cfg models/executors/ParslCommandDeadline.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandDeadlineNormal.cfg models/executors/ParslCommandDeadline.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslCommandClientSendTimeout.cfg models/executors/ParslCommandClientSendTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineDuplicateStatusCurrent.cfg models/providers/ParslGridEngineDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineDuplicateStatusFixed.cfg models/providers/ParslGridEngineDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineDuplicateStatusUnique.cfg models/providers/ParslGridEngineDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFDuplicateStatusCurrent.cfg models/providers/ParslLSFDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFDuplicateStatusFixed.cfg models/providers/ParslLSFDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFDuplicateStatusUnique.cfg models/providers/ParslLSFDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmDuplicateStatusCurrent.cfg models/providers/ParslSlurmDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmDuplicateStatusFixed.cfg models/providers/ParslSlurmDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmDuplicateStatusUnique.cfg models/providers/ParslSlurmDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueDuplicateStatusCurrent.cfg models/providers/ParslTorqueDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueDuplicateStatusFixed.cfg models/providers/ParslTorqueDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueDuplicateStatusUnique.cfg models/providers/ParslTorqueDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProJobIdAliasCurrent.cfg models/providers/ParslPBSProJobIdAlias.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProJobIdAliasFixed.cfg models/providers/ParslPBSProJobIdAlias.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProJobIdAliasUnique.cfg models/providers/ParslPBSProJobIdAlias.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListMutationCurrent.cfg models/dataflow/ParslJoinListMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListMutationFixed.cfg models/dataflow/ParslJoinListMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListMutationStable.cfg models/dataflow/ParslJoinListMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPConnectionCleanupCurrent.cfg models/staging/ParslFTPConnectionCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPConnectionCleanupFixed.cfg models/staging/ParslFTPConnectionCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPConnectionCleanupSuccess.cfg models/staging/ParslFTPConnectionCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPPartialCleanupCurrent.cfg models/staging/ParslHTTPPartialCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPPartialCleanupFixed.cfg models/staging/ParslHTTPPartialCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPPartialCleanupSuccess.cfg models/staging/ParslHTTPPartialCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStatusValidationCurrent.cfg models/staging/ParslHTTPStatusValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStatusValidationFixed.cfg models/staging/ParslHTTPStatusValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStatusValidationSuccess.cfg models/staging/ParslHTTPStatusValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDataFutureFalseyExceptionCurrent.cfg models/dataflow/ParslDataFutureFalseyException.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDataFutureFalseyExceptionFixed.cfg models/dataflow/ParslDataFutureFalseyException.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslDataFutureFalseyExceptionNormal.cfg models/dataflow/ParslDataFutureFalseyException.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProSubmit.cfg models/providers/ParslPBSProSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProSubmitFixed.cfg models/providers/ParslPBSProSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProSubmitPresent.cfg models/providers/ParslPBSProSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueStatus.cfg models/providers/ParslTorqueStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueStatusFixed.cfg models/providers/ParslTorqueStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueStatusPresent.cfg models/providers/ParslTorqueStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatus.cfg models/providers/ParslCondorStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusFixed.cfg models/providers/ParslCondorStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusPresent.cfg models/providers/ParslCondorStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusFailureCurrentValid.cfg models/providers/ParslCondorStatusFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusFailureCurrentMalformed.cfg models/providers/ParslCondorStatusFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusFailureFixedValid.cfg models/providers/ParslCondorStatusFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusFailureFixedMalformed.cfg models/providers/ParslCondorStatusFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusFailureSuccess.cfg models/providers/ParslCondorStatusFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslExecutorProvider.cfg models/executors/ParslExecutorProvider.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinApp.cfg models/dataflow/ParslJoinApp.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinRetry.cfg models/dataflow/ParslJoinRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListCancellationCurrent.cfg models/dataflow/ParslJoinListCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListCancellationFixed.cfg models/dataflow/ParslJoinListCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinListCancellationSuccess.cfg models/dataflow/ParslJoinListCancellation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslNestedJoin.cfg models/dataflow/ParslNestedJoin.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinDuplicates.cfg models/dataflow/ParslJoinDuplicates.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinImmediateCallback.cfg models/dataflow/ParslJoinImmediateCallback.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinMixedList.cfg models/dataflow/ParslJoinMixedList.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinMixedListValid.cfg models/dataflow/ParslJoinMixedList.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeFuture.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeList.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeEmpty.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeTuple.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinReturnShapeMixed.cfg models/dataflow/ParslJoinReturnShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinNoneResultSingle.cfg models/dataflow/ParslJoinNoneResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinNoneResultList.cfg models/dataflow/ParslJoinNoneResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslTaskTransport.cfg models/serialization/ParslTaskTransport.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslTaskTransportFailure.cfg models/serialization/ParslTaskTransport.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPolling.cfg models/providers/ParslProviderPolling.tla
java -cp tla2tools.jar tlc2.TLC -depth 10 -config models/executors/ParslExecutorKinds.cfg models/executors/ParslExecutorKinds.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslExecutorShutdown.cfg models/executors/ParslExecutorShutdown.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueResults.cfg models/executors/ParslWorkQueueResults.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueDuplicateReport.cfg models/executors/ParslWorkQueueDuplicateReport.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslWorkQueueDuplicateReportFixed.cfg models/executors/ParslWorkQueueDuplicateReport.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxResultFixed.cfg models/executors/ParslFluxResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelUnderlyingStateCurrent.cfg models/executors/ParslFluxCancelUnderlyingState.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslFluxCancelUnderlyingStateFixed.cfg models/executors/ParslFluxCancelUnderlyingState.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineResults.cfg models/executors/ParslTaskVineResults.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineDuplicateReport.cfg models/executors/ParslTaskVineDuplicateReport.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslTaskVineDuplicateReportFixed.cfg models/executors/ParslTaskVineDuplicateReport.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslRadicalPilotResultsFixed.cfg models/executors/ParslRadicalPilotResults.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusComputeConfigFixed.cfg models/staging/ParslGlobusComputeConfig.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslGlobusComputeResult.cfg models/executors/ParslGlobusComputeResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateOrderingCurrent.cfg models/executors/ParslBlockProviderBadStateOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateOrderingFixed.cfg models/executors/ParslBlockProviderBadStateOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputReadErrorCurrent.cfg models/executors/ParslJobStatusOutputReadError.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslJobStatusOutputReadErrorFixed.cfg models/executors/ParslJobStatusOutputReadError.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateMutationCurrent.cfg models/executors/ParslBlockProviderBadStateMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslBlockProviderBadStateMutationFixed.cfg models/executors/ParslBlockProviderBadStateMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderKinds.cfg models/providers/ParslProviderKinds.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPollClockRollbackCurrent.cfg models/providers/ParslProviderPollClockRollback.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPollClockRollbackFixed.cfg models/providers/ParslProviderPollClockRollback.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAWSProviderStatus.cfg models/providers/ParslAWSProviderStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAWSProviderStatusFixed.cfg models/providers/ParslAWSProviderStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAWSProviderStatusPresent.cfg models/providers/ParslAWSProviderStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderStatusBatch.cfg models/providers/ParslProviderStatusBatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterProviderUnknownJob.cfg models/providers/ParslClusterProviderUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterProviderUnknownJobFixed.cfg models/providers/ParslClusterProviderUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesPollingFixed.cfg models/providers/ParslKubernetesPolling.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslProviderExecutorBridge.cfg models/executors/ParslProviderExecutorBridge.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHeartbeatProvider.cfg models/executors/ParslHeartbeatProvider.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslResultRace.cfg models/dataflow/ParslResultRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinCallbackRace.cfg models/dataflow/ParslJoinCallbackRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinMemoData.cfg models/dataflow/ParslJoinMemoData.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinMonitoring.cfg models/dataflow/ParslJoinMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslResourceAdmission.cfg models/dataflow/ParslResourceAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslResourceAdmissionAutolabel.cfg models/dataflow/ParslResourceAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslResourceScaling.cfg models/dataflow/ParslResourceScaling.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPollerBadState.cfg models/providers/ParslPollerBadState.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationWire.cfg models/serialization/ParslSerializationWire.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationWireFailure.cfg models/serialization/ParslSerializationWire.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationBinaryPayload.cfg models/serialization/ParslSerializationBinaryPayload.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationPluginError.cfg models/serialization/ParslSerializationPluginError.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationPluginErrorFixed.cfg models/serialization/ParslSerializationPluginError.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationLength.cfg models/serialization/ParslSerializationLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationLengthFixed.cfg models/serialization/ParslSerializationLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationNegativeLengthCurrent.cfg models/serialization/ParslSerializationNegativeLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationNegativeLengthFixed.cfg models/serialization/ParslSerializationNegativeLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationNegativeLengthValid.cfg models/serialization/ParslSerializationNegativeLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFrameCountCurrent.cfg models/serialization/ParslSerializationFrameCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFrameCountFixed.cfg models/serialization/ParslSerializationFrameCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFrameCountNormal.cfg models/serialization/ParslSerializationFrameCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslApplyMessageArity.cfg models/serialization/ParslApplyMessageArity.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslApplyMessageArityFixed.cfg models/serialization/ParslApplyMessageArity.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationZMQBridge.cfg models/serialization/ParslSerializationZMQBridge.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultQueueFixed.cfg models/executors/ParslHtexResultQueue.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultDecodeFailureCurrent.cfg models/executors/ParslHtexResultDecodeFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultDecodeFailureFixed.cfg models/executors/ParslHtexResultDecodeFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexResultDecodeFailureNormal.cfg models/executors/ParslHtexResultDecodeFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitFailure.cfg models/executors/ParslHtexSubmitFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitFailureFixed.cfg models/executors/ParslHtexSubmitFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexSubmitSuccess.cfg models/executors/ParslHtexSubmitFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexVersionMismatchFixed.cfg models/executors/ParslHtexVersionMismatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexDispatchPriority.cfg models/executors/ParslHtexDispatchPriority.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslMPISpecFixed.cfg models/executors/ParslMPISpec.tla
```

The first configuration checks `TypeOK`, dependency safety, terminal-state stability,
retry bounds, worker capacity/binding, valid assignments, executor availability for running
attempts, attempt identity, Future result consistency, stale-result safety, serialization
safety, data readiness, file-transfer safety, symbolic file-content identity, and time consistency.

The purpose of these checks is bug finding, not only documentation. A model action is a small
executable hypothesis about a Parsl transition; if an implementation change would permit a task
to run before its data is ready, accept an old result, exceed its retry bound, or run after a
heartbeat/timeout failure, the corresponding invariant should produce a finite TLC counterexample
trace. Each trace can then be mapped back to the source locations in the table below and used as
a focused test or as evidence that the abstraction is missing a guard.

Measured with TLC 2.19 and Java 17 on 2026-09-28:

- `ParslAbstract.cfg`: 6,074,516 states generated, 911,791 distinct states, depth 87;
  all invariants passed.
- `ParslMemo.cfg`: 557,440 states generated, 81,233 distinct states, depth 65; all invariants passed.
- `ParslSerializationFailure.cfg`: 3,901,406 states generated, 569,651 distinct states, depth 69;
  all safety invariants passed, including the pre-dispatch serialization-failure path.
- `ParslResultSerializationFailure.cfg`: 2,776 states generated, 600 distinct states, depth 28;
  an unencodable worker return failed after execution without resolving the Future.
- `ParslNestedSerialization.cfg`: 559 states generated, 118 distinct states, depth 16;
  a non-serializable grandchild object failed before dispatch while object-graph safety held.
- `ParslCallableArgumentAliasCurrent.cfg`: expected counterexample at depth 2; independently
  serialized closure and argument roots lose Python object identity.
- `ParslCallableArgumentAliasFixed.cfg`: 6 states generated, 3 distinct states, depth 3; a
  bundled graph preserves the shared alias.
- `ParslSerializationSnapshot.cfg`: 18 states generated, 8 distinct states, depth 5; object
  mutation after serialization could not change the captured payload or decoded value.
- `ParslSerializationLength.cfg`: expected counterexample at depth 2; the current unpacker accepts
  a declared-length mismatch (`5` declared, `3` bytes received), violating `LengthSafety`.
- `ParslSerializationLengthFixed.cfg`: 4 states generated, 2 distinct states, depth 2; strict
  length validation rejects the truncated frame.
- `ParslSerializationNegativeLengthCurrent.cfg`: expected counterexample at depth 2; a negative
  length reaches the malformed leftover-byte parse and violates `NegativeLengthSafety`.
- `ParslSerializationNegativeLengthFixed.cfg` and `ParslSerializationNegativeLengthValid.cfg`:
  4 states generated, 2 distinct states, depth 2; negative declarations are rejected while a
  zero-length frame remains valid.
- `ParslSerializationFrameCountCurrent.cfg`: expected counterexample, 4 states generated; an
  extra frame is deserialized before the three-buffer assertion rejects the message.
- `ParslSerializationFrameCountFixed.cfg` and `ParslSerializationFrameCountNormal.cfg`: 4 states
  generated, 2 distinct states, depth 2; extra frames are rejected before decode and normal
  three-buffer messages decode successfully.
- `ParslApplyMessageArity.cfg`: expected counterexample at depth 2 (2 states generated,
  2 distinct); the public unpacker returns a fourth decoded frame. `ParslApplyMessageArityFixed.cfg`:
  4 states generated, 2 distinct states, depth 2; non-three-frame messages are rejected early.
- `ParslDataFutureCopy.cfg`: 61 states generated, 26 distinct states, depth 7; clean staging
  copies preserved the original local-path annotation and dependency admission waited for the
  parent Future.
- `ParslDataManagerStageInOrderingCurrent.cfg`: expected counterexample at depth 3; a wrapper
  construction failure left a separate stage-in transfer running after task failure.
- `ParslDataManagerStageInOrderingFixed.cfg`: 4 states generated, 2 distinct states, depth 2;
  wrapper preparation before transfer prevents the orphaned stage-in state.
- `ParslDataManagerStageOutOrderingCurrent.cfg`: expected counterexample at depth 3; a wrapper
  construction failure left a separate stage-out transfer running after task setup failure.
- `ParslDataManagerStageOutOrderingFixed.cfg`: 4 states generated, 2 distinct states, depth 2;
  wrapper preparation before transfer prevents the orphaned stage-out state.
- `ParslRsyncStageInFail.cfg`: 6 states generated, 3 distinct states, depth 3; stage-in failure
  prevented user-function execution.
- `ParslRsyncStageOutFail.cfg`: 8 states generated, 4 distinct states, depth 4; stage-out
  failure was propagated after the user function ran.
- `ParslRsyncStageSuccess.cfg`: 8 states generated, 4 distinct states, depth 4; successful
  stage-in reached the user function and completed safely.
- `ParslHTTPStageCurrent.cfg`: expected counterexample at depth 3; a non-success response was
  written and the app still ran.
- `ParslHTTPStageFixed.cfg`: 4 states generated, 2 distinct states, depth 2; non-success HTTP
  responses failed before app execution.
- `ParslHTTPStageSuccess.cfg`: 6 states generated, 3 distinct states, depth 3; successful HTTP
  staging reached the app safely.
- `ParslFTPStageCurrent.cfg`: expected counterexample at depth 2; a failed transfer left a
  partial local file even though the app did not run.
- `ParslFTPStageFixed.cfg`: 4 states generated, 2 distinct states, depth 2; failed FTP staging
  removed the partial artifact.
- `ParslFTPStageSuccess.cfg`: 4 states generated, 2 distinct states, depth 2; successful FTP
  transfer produced the input artifact and ran the app.
- `ParslGlobusStageDependency.cfg`: 19 states generated, 8 distinct states, depth 5; stage-in
  could start only after the parent Future became ready.
- `ParslGlobusStageOutDependency.cfg`: 19 states generated, 8 distinct states, depth 5; stage-out
  could start only after the application Future completed.
- `ParslGlobusTransferFailureCurrentEmpty.cfg`: expected counterexample, 4 states generated; a
  failed transfer with no diagnostic event reaches `events.data[0]` and crashes.
- `ParslGlobusTransferFailureCurrentEvent.cfg`, `ParslGlobusTransferFailureFixedEmpty.cfg`, and
  `ParslGlobusTransferFailureSuccess.cfg`: 6 states generated, 3 distinct states, depth 3;
  event-bearing failures and event-free fixed failures are reported without a parser crash.
- `ParslNoFailures.cfg`: 21,760 states generated, 3,969 distinct states, depth 60;
  `EventuallySettled` passed under `WF_vars(NextCore)`.
- `ParslTime.cfg`: 690 states generated, 198 distinct states, depth 36;
  `EventuallySettled` passed with logical ticking and timeout transitions enabled.
- `ParslTimeoutTerminal.cfg`: 859 states generated, 240 distinct states, depth 23;
  a final-attempt timeout rejected the Future and still satisfied `EventuallySettled`.
- `ParslMonitoring.cfg`: 167,482 states generated, 25,066 distinct states, depth 43;
  all monitoring consistency invariants passed.
- `ParslSubmitFailure.cfg`: 185 states generated, 45 distinct states, depth 12;
  submit rejection remained pre-dispatch and all retry/result invariants passed.
- `ParslProviderFailure.cfg`: 6,868 states generated, 1,280 distinct states, depth 40;
  provider failure, recovery request, and block-count consistency all passed.
- `ParslScaleIn.cfg`: 54,755 states generated, 7,668 distinct states, depth 37;
  multi-block scale-out, partial scale-in, and failed secondary allocation preserved provider
  block/target consistency.
- `ParslMinBlocks.cfg`: 66,423 states generated, 9,612 distinct states, depth 37;
  scale-in could not remove the configured minimum one block.
- `ParslStrategy.cfg`: 327 states generated, 114 distinct states, depth 13;
  slot-pressure scale-out, idle-timer handling, minimum/maximum block bounds, and task-pressure
  safety all passed in the focused strategy model.
- `ParslStrategyBlockCapacityCurrent.cfg`: expected counterexample, 4 states generated; a
  zero-capacity provider reaches the strategy's division-by-zero path.
- `ParslStrategyBlockCapacityFixed.cfg`: 4 states generated, 2 distinct states, depth 2; invalid
  zero capacity is rejected before polling.
- `ParslStrategyBlockCapacitySuccess.cfg`: 6 states generated, 3 distinct states, depth 3; a
  valid capacity produces a safe scale request.
- `ParslProbeAddresses.cfg`: 6 states generated, 3 distinct states, depth 3; an unresponsive
  candidate reaches the timeout failure outcome.
- `ParslProbeAddressesEmpty.cfg`: 4 states generated, 2 distinct states, depth 2; an empty
  candidate set is rejected.
- `ParslProbeAddressesSuccess.cfg`: 6 states generated, 3 distinct states, depth 3; a probe
  response selects an address.
- `ParslCurveZMQCertificateModeValid.cfg`: 4 states generated, 2 distinct states, depth 2; a
  private directory and secret key load safely.
- `ParslCurveZMQCertificateModeInvalid.cfg`: 4 states generated, 2 distinct states, depth 2; a
  non-private directory is rejected.
- `ParslZMQ.cfg`: 33,321 states generated, 6,216 distinct states, depth 35;
  multipart encoding order, bounded queues, disconnect/drop, route validation, duplicate discard,
  correlation, and acknowledgement safety all passed in the focused transport model.
- `ParslPython.cfg`: 4,415 states generated, 1,035 distinct states, depth 17;
  callable roots, globals/defaults/closure traversal, symbolic pickle round-trip, and payload
  reconstruction safety passed.
- `ParslPythonFailure.cfg`: 4,415 states generated, 1,035 distinct states, depth 18;
  a non-serializable nested closure object failed before encoding completed or a payload token was
  published.
- `ParslCallableSerializerCache.cfg`: expected counterexample at depth 2 (2 states generated,
  2 distinct); an unhashable callable fails in the `lru_cache` wrapper before `dill.dumps`.
  `ParslCallableSerializerCacheFixed.cfg`: 4 states generated, 2 distinct states, depth 2;
  the unhashable callable reaches serialization and completes.
- `ParslCallableDeserializeCacheCurrent.cfg`: expected counterexample at depth 4; a second decode
  returns the first task's mutated callable object.
- `ParslCallableDeserializeCacheFixed.cfg`: 8 states generated, 4 distinct states, depth 4;
  repeated payloads receive fresh callable objects.
- `ParslHtexCoresPerWorkerCurrent.cfg`: expected counterexample at depth 1; zero
  `cores_per_worker` reaches the provider CPU-slot division.
- `ParslHtexCoresPerWorkerFixed.cfg`: 4 states generated, 2 distinct states, depth 2; invalid
  zero capacity is rejected before the division.
- `ParslHtexCoresPerWorkerValid.cfg`: 4 states generated, 2 distinct states, depth 2; one core
  per worker produces a safe capacity.
- `ParslHtexAddressProbeTimeoutCurrent.cfg`: expected counterexample at depth 1; an explicit
  zero timeout is omitted from the worker command.
- `ParslHtexAddressProbeTimeoutFixed.cfg`: 4 states generated, 2 distinct states, depth 2;
  explicit zero is preserved.
- `ParslHtexAddressProbeTimeoutValid.cfg`: 4 states generated, 2 distinct states, depth 2;
  positive timeout is preserved.
- `ParslPoolExecutorMap.cfg`: 146 states generated, 53 distinct states, depth 6; map consumes
  results in input order, times out at its deadline, and never cancels submitted Futures.
- `ParslFileBytes.cfg`: 630 states generated, 201 distinct states, depth 14;
  chunk checksums, corruption repair, stale source-version detection, and atomic stage-in/stage-out
  publication all passed.
- `ParslStageOutFuture.cfg`: 47 states generated, 23 distinct states, depth 10; separate
  stage-out completion, failure/retry, output publication, and dependent-task gating passed.
- `ParslStageOutInTask.cfg`: 14 states generated, 7 distinct states, depth 5; in-task transfer
  publication is tied to application completion.
- `ParslStageOutNone.cfg`: 14 states generated, 7 distinct states, depth 5; the no-staging path
  correctly makes the application Future the output dependency.
- `ParslMultiOutputStageOutCurrent.cfg`: 43 states generated, 17 distinct states, depth 6; two
  outputs have independent publication and dependency gates while sharing the application gate.
- `ParslMultiOutputStageOutEarly.cfg`: expected counterexample, 3 states generated; allowing an
  output to publish before application completion violates `NoEarlyPublication`.
- `ParslClock.cfg`: 179,383 states generated, 37,788 distinct states, depth 21;
  wall-clock bounds, heartbeat delivery/drop/expiry, attempt deadlines, timeout-or-manager-loss
  retry selection, and stale late-result handling all passed.
- `ParslClockTerminal.cfg`: 6,440 states generated, 1,574 distinct states, depth 13;
  terminal timeout rejection with no remaining retry passed the same time and result invariants.
- `ParslHeartbeatBoundary.cfg`: 316 states generated, 93 distinct states, depth 10;
  strict heartbeat threshold, heartbeat reset at the boundary, manager expiry, and in-flight
  failure accounting all passed.
- `ParslHeartbeatClockJumpCurrent.cfg`: expected counterexample, 4 states generated; a wall-clock
  jump expires a manager after only one monotonic tick.
- `ParslHeartbeatClockJumpFixed.cfg` and `ParslHeartbeatClockJumpNormal.cfg`: 6 states generated,
  3 distinct states, depth 3; monotonic expiry avoids the premature loss and normal clock passage
  retains the existing threshold behavior.
- `ParslFutureWaitTimeout.cfg`: 20 states generated, 10 distinct states, depth 5; a caller-side
  wait timeout left the running task and Future unresolved, while app walltime failure rejected
  the Future.
- `ParslMonitoringDB.cfg`: 757 states generated, 291 distinct states, depth 11;
  asynchronous write failure/retry, version monotonicity, database consistency, and terminal
  record safety passed.
- `ParslMonitoringDBReorder.cfg`: 527 states generated, 206 distinct states, depth 9;
  radio queue reordering and stale-event suppression passed with the same invariants.
- `ParslMonitoringDeferred.cfg`: 36 states generated, 16 distinct states, depth 6;
  deferred first-message replay, duplicate-first replacement/discard, try-before-status foreign
  key ordering, and bounded monitoring cleanup all passed.
- `ParslMonitoringCloseIdempotenceCurrent.cfg`: expected counterexample at depth 2; repeated
  abnormal closes emit duplicate workflow-finalization updates.
- `ParslMonitoringCloseIdempotenceFixed.cfg`: 4 states generated, 2 distinct states, depth 2;
  a second close is a no-op after finalization.
- `ParslMonitoringDBInsert.cfg`: expected counterexample, 4 states generated and 3 distinct
  states at depth 3; a duplicate STATUS key reaches the current generic-exception return path,
  so the event is dropped while the pre-existing row remains.
- `ParslMonitoringDBInsertFixed.cfg`: 6 states generated, 3 distinct states, depth 3; an
  idempotent duplicate handler preserves the row and satisfies `DuplicatePersistence`.
- `ParslMonitoringDBInsertPresent.cfg`: 6 states generated, 3 distinct states, depth 3; a
  non-duplicate STATUS insert passes the same invariants.
- `ParslMonitoringPersistentRetryCurrent.cfg`: expected counterexample at depth 5; a persistent
  `OperationalError` keeps the retrying write at the attempt bound.
- `ParslMonitoringPersistentRetryFixed.cfg`: 10 states generated, 7 distinct states, depth 5;
  bounded failure transitions to `aborted` instead of spinning indefinitely.
- `ParslFilesystemRadioAtomicityCurrent.cfg`: expected counterexample at depth 3; direct
  publication lets the reader consume a partial monitoring message.
- `ParslFilesystemRadioAtomicityFixed.cfg`: 13 states generated, 6 distinct states, depth 6;
  tmp-file writes and atomic rename preserve complete-message visibility.
- `ParslMonitoringBatchCurrent.cfg`: expected counterexample, 2 states generated; with a queued
  message and zero interval, the batch action returns empty and leaves the message unread.
- `ParslMonitoringBatchFixed.cfg` and `ParslMonitoringBatchPositive.cfg`: 4 states generated,
  2 distinct states, depth 2; queued-message collection satisfies `AvailableBatchSafety`.
- `ParslMonitoringBatchAtomicityCurrent.cfg`: expected counterexample, 2 states generated; a
  duplicate STATUS row rolls back a valid sibling in the same bulk insert.
- `ParslMonitoringBatchAtomicityFixed.cfg` and `ParslMonitoringBatchAtomicitySuccess.cfg`: 4
  states generated, 2 distinct states, depth 2; valid events are preserved with and without a
  duplicate.
- `ParslMonitoringThreshold.cfg`: expected counterexample at depth 2 (2 states generated,
  2 distinct); a zero threshold leaves an available event queued. `ParslMonitoringThresholdFixed.cfg`:
  4 states generated, 2 distinct states, depth 2; the first available event is consumed.
- `ParslRetryHandlerCurrent.cfg`: expected counterexample, 3 distinct states; a zero-cost handler
  advances `tryId` to 1 despite `RETRIES=0`.
- `ParslRetryHandlerFixed.cfg`: 3 distinct states, depth 3; minimum-cost charging preserves
  `RetryLimitSafety`. `ParslRetryHandlerPositive.cfg` also passes with a one-unit budget.
- `ParslMemoFunctionIdentityCurrent.cfg`: expected counterexample, 2 states generated; changing
  the symbolic function source leaves the memo key unchanged.
- `ParslMemoFunctionIdentityFixed.cfg` and `ParslMemoFunctionIdentityStable.cfg`: 4 states
  generated, 2 distinct states, depth 2; source-aware and unchanged-function cases satisfy
  `MemoKeySafety`.
- `ParslMemoExceptionCheckpointCurrent.cfg`: expected counterexample at depth 4; a failed
  in-memory memo entry is absent after checkpoint and restart.
- `ParslMemoExceptionCheckpointFixed.cfg`: 6 states generated, 5 distinct states, depth 5;
  persisted failures satisfy `FailureCheckpointRecovery`.
- `ParslMemoCheckpointOrderCurrent.cfg`: expected counterexample at depth 3; lexical UUID order
  loads `new` before `old`, then restores the old duplicate value.
- `ParslMemoCheckpointOrderFixed.cfg`: 4 states generated, 3 distinct states, depth 3;
  chronological loading satisfies `LatestCheckpointWins`.
- `ParslLastCheckpointUUIDCurrent.cfg`: expected counterexample at depth 2; `isdigit()` filtering
  leaves a UUID checkpoint unselected.
- `ParslLastCheckpointUUIDFixed.cfg`: 3 states generated, 2 distinct states, depth 2; UUID
  checkpoint selection satisfies `UUIDCheckpointRecovery`.
- `ParslExecuteWaitTimeoutCurrent.cfg`: expected counterexample, 2 states generated; a command
  timeout raises while the scheduler process remains alive.
- `ParslExecuteWaitTimeoutFixed.cfg` and `ParslExecuteWaitTimeoutSuccess.cfg`: 4 states generated,
  2 distinct states, depth 2; timeout cleanup and normal completion satisfy
  `TimeoutCleanupSafety`.
- `ParslMemoDictOrderingCurrent.cfg`: expected counterexample, 2 states generated; a mixed-key
  dictionary reaches the memo-hash error state.
- `ParslMemoDictOrderingFixed.cfg` and `ParslMemoDictOrderingHomogeneous.cfg`: 4 states generated,
  2 distinct states, depth 2; canonical and homogeneous key ordering satisfy
  `MixedDictHashSafety`.
- `ParslRsyncQuotingCurrent.cfg`: expected counterexample, 2 states generated; a path with spaces
  builds an ambiguous shell command.
- `ParslRsyncQuotingFixed.cfg` and `ParslRsyncQuotingNormal.cfg`: 4 states generated, 2 distinct
  states, depth 2; quoted and whitespace-free paths satisfy `PathQuotingSafety`.
- `ParslCommandDeadlineCurrent.cfg`: expected counterexample, 2 states generated; an expired
  command deadline forwards `pollTimeout = -1`.
- `ParslCommandDeadlineFixed.cfg` and `ParslCommandDeadlineNormal.cfg`: 4 states generated,
  2 distinct states, depth 2; clamped and non-expired deadlines satisfy `PollTimeoutSafety`.
- `ParslCommandClientSendTimeout.cfg`: 8 states generated, 5 distinct states, depth 3; a
  pre-send timeout leaves the command client reusable and the later reply path consistent.
- `ParslCommandClientLockTimeoutCurrent.cfg`: expected counterexample at depth 4; a caller sends
  after its deadline because it waited on the Python lock.
- `ParslCommandClientLockTimeoutFixed.cfg`: 12 states generated, 8 distinct states, depth 4;
  deadline-aware lock acquisition prevents the late send.
- `ParslGridEngineDuplicateStatusCurrent.cfg`: expected counterexample, 4 states generated; a
  duplicate qstat line crashes while removing the same job twice.
- `ParslGridEngineDuplicateStatusFixed.cfg` and `ParslGridEngineDuplicateStatusUnique.cfg`: 6
  states generated, 3 distinct states, depth 3; idempotent and unique status handling satisfy
  `DuplicateSafety`.
- `ParslLSFDuplicateStatusCurrent.cfg`: expected counterexample, 4 states generated; a duplicate
  bjobs line raises `KeyError` while removing the same set member twice.
- `ParslLSFDuplicateStatusFixed.cfg` and `ParslLSFDuplicateStatusUnique.cfg`: 6 states generated,
  3 distinct states, depth 3; idempotent and unique status handling satisfy `DuplicateSafety`.
- `ParslLSFMissingJobCurrent.cfg`: expected counterexample at depth 2; an absent `bjobs` record
  is reported as `COMPLETED`.
- `ParslLSFMissingJobFixed.cfg`: 7 states generated, 4 distinct states, depth 2; missing jobs
  remain `UNKNOWN` while explicit failure and running states are preserved.
- `ParslSlurmDuplicateStatusCurrent.cfg`: expected counterexample, 4 states generated; a duplicate
  status row raises `KeyError` while removing the same set member twice.
- `ParslSlurmDuplicateStatusFixed.cfg` and `ParslSlurmDuplicateStatusUnique.cfg`: 6 states
  generated, 3 distinct states, depth 3; idempotent and unique status handling satisfy
  `DuplicateSafety`.
- `ParslTorqueDuplicateStatusCurrent.cfg`: expected counterexample, 4 states generated; a
  duplicate qstat row raises `ValueError` while removing the same list member twice.
- `ParslTorqueDuplicateStatusFixed.cfg` and `ParslTorqueDuplicateStatusUnique.cfg`: 6 states
  generated, 3 distinct states, depth 3; idempotent and unique status handling satisfy
  `DuplicateSafety`.
- `ParslPBSProJobIdAliasCurrent.cfg`: expected counterexample, 4 states generated and 3 distinct
  states at depth 3; short and fully qualified JSON keys normalize to one local resource and the
  second missing-list removal crashes.
- `ParslPBSProJobIdAliasFixed.cfg` and `ParslPBSProJobIdAliasUnique.cfg`: 6 states generated,
  3 distinct states, depth 3; idempotent alias handling and a single short-id record satisfy
  `AliasSafety` and `MissingBookkeepingSafety`.
- `ParslJoinListMutationCurrent.cfg`: expected counterexample, 4 states generated; mutating the
  aliased join list lets the outer join finish with `resultCount = 0` instead of 2.
- `ParslJoinListMutationFixed.cfg`: 6 states generated, 3 distinct states, depth 3; snapshotting
  the join membership satisfies `JoinSnapshotSafety`. The stable-list configuration also passes.
- `ParslJoinListCancellationCurrent.cfg`: expected counterexample, 2 states generated; a cancelled
  list member raises `CancelledError` and leaves the outer join in `joining`.
- `ParslJoinListCancellationFixed.cfg` and `ParslJoinListCancellationSuccess.cfg`: 4 states
  generated, 2 distinct states, depth 2; cancellation becomes terminal failure and normal list
  completion remains successful.
- `ParslFTPConnectionCleanupCurrent.cfg`: expected counterexample, 2 states generated; a failed
  transfer leaves the FTP connection open.
- `ParslFTPConnectionCleanupFixed.cfg` and `ParslFTPConnectionCleanupSuccess.cfg`: 4 states
  generated, 2 distinct states, depth 2; failure cleanup and successful transfer satisfy
  `FailureCleanupSafety`.
- `ParslHTTPPartialCleanupCurrent.cfg`: expected counterexample, 4 states generated; a failed
  second chunk leaves `bytesPublished = 1`.
- `ParslHTTPPartialCleanupFixed.cfg` and `ParslHTTPPartialCleanupSuccess.cfg`: 6 states generated,
  3 distinct states, depth 3; failed-stream cleanup and successful transfer satisfy
  `FailurePublicationSafety`.
- `ParslHTTPStatusValidationCurrent.cfg`: expected counterexample; a 404 response reaches the
  task with a published error body.
- `ParslHTTPStatusValidationFixed.cfg`: 6 states generated, 3 distinct states, depth 3;
  non-2xx response rejection preserves `StatusSafety`.
- `ParslHTTPStatusValidationSuccess.cfg`: 10 states generated, 5 distinct states, depth 5; a
  200 response satisfies status and publication safety.
- `ParslDataFutureFalseyExceptionCurrent.cfg`: expected counterexample, 2 states generated; a
  failed parent with a falsey exception resolves the DataFuture as success.
- `ParslDataFutureFalseyExceptionFixed.cfg` and `ParslDataFutureFalseyExceptionNormal.cfg`: 4
  states generated, 2 distinct states, depth 2; explicit exception-presence handling satisfies
  `FailurePropagationSafety`.
- `ParslPBSProSubmit.cfg`: expected counterexample, 2 states generated and 2 distinct states at
  depth 2; successful empty `qsub` output returns `None` without registering a resource.
- `ParslPBSProSubmitFixed.cfg`: 4 states generated, 2 distinct states, depth 2; empty output is
  rejected instead of being reported as a successful submission.
- `ParslPBSProSubmitPresent.cfg`: 4 states generated, 2 distinct states, depth 2; a normal job
  identifier satisfies the submission contract.
- `ParslTorqueStatus.cfg`: expected counterexample, 4 states generated and 3 distinct states at
  depth 3; a foreign qstat line reaches the direct resource-map lookup crash.
- `ParslTorqueStatusFixed.cfg`: 6 states generated, 3 distinct states, depth 3; foreign lines
  are ignored and known-job status remains safe.
- `ParslTorqueStatusPresent.cfg`: 6 states generated, 3 distinct states, depth 3; a known qstat
  line updates the tracked job to completed.
- `ParslCondorStatus.cfg`: expected counterexample, 4 states generated and 3 distinct states at
  depth 3; a malformed `condor_q` line reaches the unchecked two-field indexing path.
- `ParslCondorStatusFixed.cfg`: 6 states generated, 3 distinct states, depth 3; short lines are
  ignored without changing the known resource status.
- `ParslCondorStatusPresent.cfg`: 6 states generated, 3 distinct states, depth 3; a valid
  two-field status line updates the tracked job.
- `ParslCondorStatusFailureCurrentValid.cfg`: expected counterexample, 4 states generated; a
  failed `condor_q` command still applies stale valid stdout and changes `RUNNING` to `COMPLETED`.
- `ParslCondorStatusFailureCurrentMalformed.cfg`: expected counterexample, 4 states generated;
  failed command output with one field reaches the unchecked `parts[1]` access.
- `ParslCondorStatusFailureFixedValid.cfg`, `ParslCondorStatusFailureFixedMalformed.cfg`, and
  `ParslCondorStatusFailureSuccess.cfg`: 6 states generated, 3 distinct states, depth 3; failed
  commands preserve local state and successful commands still apply valid status output.
- `ParslCondorSubmit.cfg`: expected counterexample at depth 3 (9 states generated, 7 distinct);
  empty successful submit output reaches an uncaught job-id indexing error.
- `ParslCondorSubmitFixed.cfg`: 18 states generated, 9 distinct states, depth 3; malformed
  successful output is rejected without registering a resource.

The Condor status counterexample is also checked against the current Python source with a
deterministic scheduler stub (no Condor installation is required):

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_status_malformed.py -v
```

The runtime probe confirms that a one-field `condor_q` line raises `IndexError`, while a valid
two-field line updates the tracked resource. A separate failure probe confirms that the current
provider ignores a nonzero command return code in both cases:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_status_failure_runtime.py -v
```

Condor submission parsing is also exercised without a Condor installation:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_submit_runtime.py -v
```

The probe covers valid cluster registration, nonzero command failure, and the current uncaught
`IndexError` paths for empty or malformed successful `condor_submit` output.

Condor cancellation is exercised with a fake scheduler and a one-job chunk size:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_cancel_runtime.py -v
```

`ParslCondorCancel.tla` checks that each chunk returns an independent Boolean result and that a
successful cancellation of an unknown id is ignored locally rather than crashing, unlike the
current LSF and Grid Engine cancellation paths.

`ParslCondorChunkSize.tla` models the `cmd_chunk_size` input to Condor scheduler commands. The
current `_chunker` silently turns a zero size into one unbounded chunk; the fixed branch rejects
non-positive sizes before status or cancellation batching.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorChunkSizeCurrent.cfg models/providers/ParslCondorChunkSize.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorChunkSizeFixed.cfg models/providers/ParslCondorChunkSize.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorChunkSizeValid.cfg models/providers/ParslCondorChunkSize.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_chunk_size_runtime.py -v
```

The Torque foreign-job counterexample has the same kind of source-level runtime probe:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_status_foreign.py -v
```

It confirms that an unregistered qstat job raises `KeyError`, while a known job line updates the
tracked resource.

The monitoring STATUS insert path is checked against a real temporary SQLite database:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_db_runtime.py -v
```

The test confirms both the duplicate primary-key `IntegrityError` and the current
`DatabaseManager._insert` behavior that catches, rolls back, and silently returns from that
error, leaving only the original STATUS row.

The deferred worker-message race is also exercised through the real database-manager loop:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_monitoring_deferred_runtime.py -v
```

These probes use a temporary SQLite database and verify that an early first worker message is
replayed after its TASK_INFO/TRY row arrives, while a duplicate deferred message replaces the
older observation. This is the runtime counterpart of `ParslMonitoringDeferred.tla`.

The real serialization facade is also exercised with the same callable/object boundary used by
the wire models:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_runtime.py -v
```

The tests verify closure round-trip behavior, the `C2` callable and `02` data headers, three-part
apply-message ordering, and rejection of an unserializable argument before a message is packed.
They also verify closure snapshot semantics and nested argument-object graph round trips.
The truncated-frame probe records the current `unpack_buffers` behavior: a short slice is returned
instead of being rejected, matching the TLA+ counterexample above.

Extra apply-message framing is exercised separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_frame_count_runtime.py -v
```

The probe confirms that all four payloads are passed to `deserialize` before the current
three-buffer assertion rejects the message.

The HTEX result-thread boundary is exercised without launching an interchange:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_result_queue_runtime.py -v
```

The probe sends a malformed result message to the real `_result_queue_worker` and confirms the
current pop-before-validation behavior: the pending Future is removed from the task map but stays
unfinished when the worker raises `BadMessage`. It also sends the same valid result twice and
confirms the current second `tasks.pop` raises `KeyError`; both paths are represented by
`ParslHtexResultQueue.cfg`.

Corrupt result payload handling is exercised separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_result_decode_failure_runtime.py -v
```

The probe confirms that the current `deserialize(result)` exception leaves the Future pending
after its task-map entry has already been removed.

The heartbeat-to-Future failure path is also exercised end-to-end with local fake transport:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_manager_loss_runtime.py -v
```

An expired manager produces the real serialized `RemoteExceptionWrapper` report, and the real HTEX
result worker turns it into a `ManagerLost` exception on the corresponding Future.

The local zip staging implementation is exercised against actual bytes as well:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_zip_file_transfer_runtime.py -v
```

This verifies stage-out archive creation and source cleanup, stage-in byte preservation, failure
on a corrupt archive before output publication, and the local-file scheme gate in
`NoOpFileStaging`.

The multi-output DataManager dependency wiring is exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_multi_output_stageout_runtime.py -v
```

The probe confirms that both output staging Futures receive the same application Future while
remaining independently completable.

The ZMQ transport and serialization boundary is exercised with real in-process ROUTER/DEALER
sockets:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_zmq_serialization_runtime.py -v
```

The probe checks multipart frame count, route identity preservation, Parsl apply-message
deserialization, task execution, and an ACK sent back over the routed socket.

All runtime probes can be run together as an integration baseline:

```bash
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_*runtime.py' -v
```

The current baseline runs 408 tests covering serialization, ZMQ, files/DataFutures, retry and
timeouts, heartbeat expiry, monitoring SQLite writes, join semantics, memoization, executor
shutdown, and provider status/submit paths.

`ParslJoinNoneResult.tla` adds the falsey-result case to the join abstraction. A completed inner
Future whose value is Python `None` is still successful; both single-Future and list-valued joins
must preserve `None` and list positions. The two TLC configurations cover those shapes, and
`tests/test_join_none_result_runtime.py` checks them with the real thread executor.

The concrete `join_app` protocol is exercised with a real local thread executor:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_join_runtime.py -v
```

This verifies single-Future propagation, ordered list results with duplicate Future references,
empty-list completion without callbacks, and `JoinError` propagation from a failed inner app.
It also checks nested join propagation and rejection of scalar, mixed-list, and non-empty
all-value-list join returns.

The callback-level join gate is exercised directly against the real `DataFlowKernel` method:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_join_callback_runtime.py -v
```

The list-cancellation boundary is also exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_join_list_cancellation_runtime.py -v
```

The probe confirms that the current callback raises `CancelledError` and leaves a list-valued
outer join in `joining`.

The same cancellation boundary for a single inner Future is exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_join_single_cancellation_runtime.py -v
```

This confirms that the current callback raises `CancelledError` and leaves the single-Future
outer join in `joining`.

The probe checks that early callbacks do not finalize an outer task, final callbacks preserve list
order and duplicate references, duplicate callbacks after terminal state are harmless, and inner
failures become `JoinError` with dependent exception metadata. It also reproduces the current
cancelled-inner `CancelledError` escape that leaves the outer task in `joining`.

Physical retry and Python app timeout behavior are checked against a local thread executor:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_retry_timeout_runtime.py -v
```

The tests confirm a first-attempt failure is followed by a second physical attempt, and that a
task exceeding its `walltime` completes with `AppTimeout` when no retries remain.

The Python timeout injection boundary is also exercised with a function that catches
`AppTimeout`. The current implementation allows that function to return normally after the
walltime signal, which is modeled by `ParslPythonTimeoutCatch.tla`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPythonTimeoutCatch.cfg models/serialization/ParslPythonTimeoutCatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPythonTimeoutCatchFixed.cfg models/serialization/ParslPythonTimeoutCatch.tla
```

The underlying timeout timer lifecycle is exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_timeout_timer_runtime.py -v
```

`ParslTimeoutTimer.tla` checks that `AutoCancelTimer` is cancelled after a fast return or an
ordinary function exception, while a slow function can still receive `AppTimeout` before it
finishes.

`ParslPythonTimeoutParameter.tla` checks timeout-delay admission separately. A negative delay is
accepted by the current decorator and fires `AppTimeout` immediately; the fixed branch rejects
non-positive delays before starting the timer.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslPythonTimeoutParameterCurrent.cfg models/clock/ParslPythonTimeoutParameter.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslPythonTimeoutParameterFixed.cfg models/clock/ParslPythonTimeoutParameter.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslPythonTimeoutParameterValid.cfg models/clock/ParslPythonTimeoutParameter.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_python_timeout_parameter_runtime.py -v
```

The shared periodic timer used by `JobStatusPoller` and checkpointing is modeled separately by
`ParslPeriodicTimer.tla`. TLC checks that the first callback is immediate, callback exceptions do
not terminate the timer, and `close()` leaves the timer quiescent. The runtime counterpart is:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslPeriodicTimer.cfg models/clock/ParslPeriodicTimer.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_periodic_timer_runtime.py -v
```

`ParslTimerIntervalValidation.tla` checks negative interval admission and the current zero-delay
normalization:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerIntervalValidationCurrent.cfg models/clock/ParslTimerIntervalValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerIntervalValidationFixed.cfg models/clock/ParslTimerIntervalValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimerIntervalValidationValid.cfg models/clock/ParslTimerIntervalValidation.tla
```

`ParslTimeLimitedOpenTimeout.tla` checks the missing-file timeout boundary:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeLimitedOpenTimeoutCurrent.cfg models/clock/ParslTimeLimitedOpenTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeLimitedOpenTimeoutFixed.cfg models/clock/ParslTimeLimitedOpenTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslTimeLimitedOpenTimeoutSuccess.cfg models/clock/ParslTimeLimitedOpenTimeout.tla
```

The worker-side apply-message helper is exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_execute_task_runtime.py -v
```

This confirms callable/argument decoding, propagation of a user exception, and rejection of a
malformed packed message before invocation.

The Azure status parser is exercised without Azure SDK credentials:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_status_runtime.py -v
```

The probe covers running VMs, short provisioning responses, and unknown Azure display states.

Azure cancellation is also exercised against a fake compute API:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_cancel_runtime.py -v
```

The runtime probe reproduces the current false result when cloud deletion succeeds but local
bookkeeping no longer contains the VM id.

The concrete thread executor shutdown modes are exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_thread_executor_runtime.py -v
```

The non-blocking case confirms that new submissions are rejected while already accepted work is
still allowed to finish.

Zip stage-in is exercised with real temporary archives and an injected destination write failure:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_zip_file_transfer_runtime.py -v
```

The probe confirms byte preservation, corrupt-archive rejection, and the current partial-output
behavior on a failed direct write.

The stage-out retry boundary is covered by the same zip probe. It changes the source between a
failed cleanup and retry, then checks that the archive contains two entries for the same member;
Python reads the latest entry, but the duplicate archive state remains observable.

The HTEX command client lifecycle is exercised without starting an interchange:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_command_client_runtime.py -v
```

The fake socket covers a normal reply and the timeout path that poisons the client and rejects a
second request.

The manager-message boundary is exercised without a live worker:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_manager_message_runtime.py -v
```

The probe checks malformed-message isolation and heartbeat timestamp/reply handling.

Memoization and cached-result dependency propagation are exercised with a real local executor:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_memoization_runtime.py -v
```

The probe confirms duplicate calls execute once, calls with different arguments execute normally,
and a dependent app can consume the memoized Future result.

The LSF provider status parser is exercised with deterministic `bjobs` output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_lsf_status_runtime.py -v
```

The probe checks foreign-job filtering, unknown-state exposure, and the current missing-job
fallback to `COMPLETED`.

The LSF submit path is exercised independently with fake `bsub` command results:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_lsf_submit_runtime.py -v
```

`ParslLSFSubmit.tla` models script creation, command execution, marker-based job-id parsing,
resource registration, scheduler failure, and successful output without a submission marker.
The runtime probe also checks the `bsub < script` redirection option.

`ParslLSFCancel.tla` models the `bkill` path for known and unknown resource ids. Its unknown-id
configuration intentionally produces a depth-2 counterexample: the current implementation
returns from the scheduler successfully and then indexes `resources[jid]`, which raises
`KeyError` when the local resource map has no such id. The runtime probe reproduces that boundary.

`ParslLSFResourceValidation.tla` models core-based LSF resource derivation. The current
constructor rejects zero `cores_per_node` but accepts a negative value and computes a negative
`nodes_per_block`; the fixed branch rejects every non-positive value.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFResourceValidationCurrent.cfg models/providers/ParslLSFResourceValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFResourceValidationFixed.cfg models/providers/ParslLSFResourceValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFResourceValidationValid.cfg models/providers/ParslLSFResourceValidation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_lsf_resource_validation_runtime.py -v
```

Slurm batched status handling is exercised with deterministic scheduler command results:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_status_batch_runtime.py -v
```

The tests check that a non-zero scheduler command preserves every previous status and that a
successful batch updates reported jobs while applying the current missing-job `COMPLETED` fallback.

`ParslSlurmBatchStrict.tla` checks the Python-version fallback used by Slurm status batching.
The current pre-3.12 helper ignores `strict=True` and accepts an incomplete final tuple; the
fixed branch rejects that input before scheduler records are consumed.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmBatchStrictCurrent.cfg models/providers/ParslSlurmBatchStrict.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmBatchStrictFixed.cfg models/providers/ParslSlurmBatchStrict.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmBatchStrictValid.cfg models/providers/ParslSlurmBatchStrict.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_batch_strict_runtime.py -v
```

Slurm `sbatch` submission parsing is exercised with deterministic output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_submit_runtime.py -v
```

The probe covers normal `Submitted batch job <id>` registration, empty-output rejection, and the
current `IndexError` when a custom matching regex has no named `id` group.

Grid Engine qstat parsing is exercised with deterministic output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_status_runtime.py -v
```

The probe reproduces the short-line `IndexError` boundary, checks `r` to `RUNNING` translation,
and verifies foreign-job filtering with the missing-job `COMPLETED` fallback.

Grid Engine submission parsing is exercised with deterministic `qsub` output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_submit_runtime.py -v
```

The tests cover successful empty output returning `None` without a resource and normal job-id
registration as `PENDING`.

Grid Engine cancellation is exercised with deterministic `qdel` outcomes:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_cancel_runtime.py -v
```

`ParslGridEngineCancel.tla` models the provider's successful-cancel-to-`COMPLETED` convention,
failed cancellation, and the current `KeyError` when a successful `qdel` names an id absent from
the local resource map.

Azure VM status handling is exercised with a fake compute client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_status_runtime.py -v
```

The tests check running-state translation, the current `IndexError`-to-`PENDING` path for missing
instance-view status, and propagation of non-index cloud API errors.

Azure VM cancellation is exercised with a fake asynchronous delete client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_cancel_runtime.py -v
```

The probe checks linger-mode refusal, delete-error rollback, and successful deletion/removal from
the provider's instance list.

Azure VM submission is exercised with fake resource, network, and compute clients:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_submit_runtime.py -v
```

The probe checks successful pending-resource registration and reproduces the current partial-state
path where a disk-attach failure leaves the instance list and resource map populated.

The corresponding bounded model can be checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureProviderSubmit.cfg models/providers/ParslAzureProviderSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureProviderSubmitFixed.cfg models/providers/ParslAzureProviderSubmit.tla
```

The current configuration finds the post-registration setup-failure counterexample; the fixed
configuration rolls back both resource registration and instance tracking.

The provider-free LocalProvider exit-file state machine is exercised with temporary `.ec` files:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_local_provider_runtime.py -v
```

The tests cover running-marker/liveness, zero exit completion, malformed exit failure, and
cancelled dead-process handling.
They also launch a real local provider process and collect its exit code and stdout.
An additional real process exits with code 3 and is recorded as `FAILED` rather than a submission
failure.
The suite also starts a real `sleep` process, cancels its process group, and observes terminal
`CANCELLED` status.

The corresponding LocalProvider model can be checked with TLC:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProvider.cfg models/providers/ParslLocalProvider.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderFixed.cfg models/providers/ParslLocalProvider.tla
```

The model represents the `.ec` marker, process liveness, cancellation, malformed exit codes, and
a delayed zero exit marker. The current implementation configuration exposes a counterexample:
a late numeric marker can make a cancelled process appear `COMPLETED`; the fixed configuration
prioritizes cancellation during polling.

`ParslLocalProviderSubmitCleanup.tla` checks failed launch cleanup:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderSubmitCleanupCurrent.cfg models/providers/ParslLocalProviderSubmitCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderSubmitCleanupFixed.cfg models/providers/ParslLocalProviderSubmitCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderSubmitCleanupSuccess.cfg models/providers/ParslLocalProviderSubmitCleanup.tla
```

The stale LocalProvider cancellation refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderCancelUnknownCurrent.cfg models/providers/ParslLocalProviderCancelUnknown.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderCancelUnknownFixed.cfg models/providers/ParslLocalProviderCancelUnknown.tla
```

`ParslLocalProviderStatusScope.tla` checks a separate query-scope boundary. The implementation
loops over every resource in `self.resources` even when `status(job_ids)` requests one job, so a
stale unrelated resource with a missing `.ec` file can abort the requested status query. The
current configuration produces this counterexample; the fixed configuration updates only the
requested resource. `tests/test_local_provider_status_scope_runtime.py` reproduces the behavior
with the real provider method.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderStatusScope.cfg models/providers/ParslLocalProviderStatusScope.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderStatusScopeFixed.cfg models/providers/ParslLocalProviderStatusScope.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_provider_status_scope_runtime.py -v
```

Google Compute Engine status handling is exercised with a fake discovery client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_googlecloud_status_runtime.py -v
```

The probe checks normal `RUNNING` translation, propagation of API errors, and the current
`KeyError` path for an unrecognized provider status.

The corresponding Grid Engine qstat TLA+ model can be checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineStatus.cfg models/providers/ParslGridEngineStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineStatusFixed.cfg models/providers/ParslGridEngineStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineStatusPresent.cfg models/providers/ParslGridEngineStatus.tla
```

The current configuration finds an expected depth-3 counterexample (4 generated/3 distinct
states); fixed and valid configurations each generate 6 states/3 distinct states at depth 3.

The corresponding Google Cloud status TLA+ model can be checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudStatus.cfg models/providers/ParslGoogleCloudStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudStatusFixed.cfg models/providers/ParslGoogleCloudStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudStatusPresent.cfg models/providers/ParslGoogleCloudStatus.tla
```

The current unknown-status configuration finds a depth-2 counterexample (2 generated/2 distinct
states); fixed and known-status configurations each generate 4 states/2 distinct states at depth 2.

The Google Cloud instance-creation bookkeeping boundary is checked separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_googlecloud_submit_runtime.py -v
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudSubmit.cfg models/providers/ParslGoogleCloudSubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudSubmitFixed.cfg models/providers/ParslGoogleCloudSubmit.tla
```

The current probe reproduces a failed image/API request consuming `num_instances` before any VM
exists; the current TLA configuration finds the depth-2 bookkeeping counterexample, while the
fixed configuration keeps the allocation counter unchanged on failure.

Torque cancellation outcomes are exercised with deterministic `qdel` results:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_cancel_runtime.py -v
```

The probe records the current distinction between a successful cancellation return and the
provider's `COMPLETED`/exiting resource status, while failed cancellation preserves `RUNNING`.

The corresponding bounded TLA+ cancellation probe can be run with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueCancel.cfg models/providers/ParslTorqueCancel.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueCancelFixed.cfg models/providers/ParslTorqueCancel.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueCancelFailure.cfg models/providers/ParslTorqueCancel.tla
```

`ParslTorqueCancel.cfg` intentionally finds a depth-2 counterexample (2 states generated): a
successful cancel returns `success` while the current provider records `completed`. The fixed
configuration generates 4 states/2 distinct states at depth 2; the failure configuration generates
5 states/2 distinct states at depth 2, and both satisfy the invariants.

Torque submission parsing is exercised with deterministic `qsub` output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_submit_runtime.py -v
```

`ParslTorqueSubmit.tla` checks pending-resource registration for a job id, the empty-output and
nonzero-command paths, and the current behavior of returning/registering the last non-empty line
when a command prints multiple ids.

`ParslTorqueTasksPerNode.tla` checks the documented `tasks_per_node` admission rule. The current
submit path forwards a zero or negative value to the launcher; the fixed branch rejects
non-positive values before generating a Torque script.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueTasksPerNodeCurrent.cfg models/providers/ParslTorqueTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueTasksPerNodeFixed.cfg models/providers/ParslTorqueTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueTasksPerNodeValid.cfg models/providers/ParslTorqueTasksPerNode.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_tasks_per_node_runtime.py -v
```

The Kubernetes polling regression is also exercised with a mocked Kubernetes API client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_polling_runtime.py -v
```

The test reproduces the current read-error path that leaves a running job as `RUNNING`, and
checks the normal `Succeeded` pod translation to `COMPLETED`.

Kubernetes pod submission is exercised with a fake CoreV1 API client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_submit_runtime.py -v
```

The probe checks successful pod creation and API failure propagation. The current source records
newly created pods as `RUNNING` immediately; the corresponding TLA+ fixed configuration records
the resource as `PENDING` until Kubernetes reports a phase.

Kubernetes pod cancellation is exercised with a fake delete API:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_cancel_runtime.py -v
```

An API exception propagates before the resource is changed, but a returned error object is ignored
by the current `_delete_pod` wrapper and the resource is marked `CANCELLED`. The TLA+ fixed
configuration treats a returned error as a failed cancellation that leaves the job `RUNNING`.

Globus Compute configuration isolation is exercised with a fake SDK executor:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_compute_runtime.py -v
```

The probe checks per-submit resource and endpoint overrides, restoration after SDK exceptions, and
the current cross-submit race in which concurrent calls can observe another task's specification.

The EC2 status boundary is exercised with a fake `describe_instances` client:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_status_runtime.py -v
```

The probe checks the current missing-instance behavior (empty status list and unchanged resource)
and normal `running` state translation.

The EC2 submission boundary is exercised with a fake instance launcher:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_submit_runtime.py -v
```

The probe covers successful instance registration, failed launch returning `None`, unknown-state
fallback to `PENDING`, and the current unpacking error for an empty launch response.

The PBS Pro submission parser is exercised with a temporary script directory and fake `qsub`
output:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_submit_runtime.py -v
```

The tests reproduce the successful-empty-output path returning `None` without a resource and the
normal path registering a pending job id.

The PBS Pro JSON status path is exercised with deterministic `qstat` responses:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_status_runtime.py -v
```

`ParslPBSProStatus.tla` models known-job translation, scheduler failure preservation, and the
current `KeyError` when JSON contains a foreign job id not present in `resources`. The fixed
configuration ignores that foreign record.

The PBS Pro short/qualified job-id alias boundary is exercised separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_job_id_alias_runtime.py -v
```

The probe reproduces the current `ValueError` when `42` and `42.server` both normalize to the
same local resource.

The concrete thread executor shutdown and admission contract is exercised directly:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_thread_executor_runtime.py -v
```

The probe checks that accepted work completes before blocking shutdown returns, new submissions
are rejected afterwards, and unsupported resource specifications are rejected at admission.

Future cancellation contracts are exercised separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_future_cancellation_runtime.py -v
```

`ParslFutureCancellation.tla` keeps public AppFuture/DataFuture cancellation distinct from the
underlying `concurrent.futures.Future`: the former two explicitly raise `NotImplementedError`,
while a queued thread Future can be cancelled before execution.

Deferred Future projections are exercised separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_future_projection_runtime.py -v
```

`ParslFutureProjection.tla` models `AppFuture.__getitem__` and `__getattr__` as new internal
tasks. Projection creation does not synchronously wait; the projection waits for source success,
propagates source failure, and reports invalid keys as a projection exception.

`ParslTaskStatusFutureOrdering.tla` separates the logical DFK task state from the public
`AppFuture`. The completion path publishes `exec_done` before calling `set_result`, so a short
status lag is allowed while Future callbacks are still pending. The runtime probe invokes the
real `_complete_task_result` ordering with a recording Future.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTaskStatusFutureOrderingCurrent.cfg models/dataflow/ParslTaskStatusFutureOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTaskStatusFutureOrderingFixed.cfg models/dataflow/ParslTaskStatusFutureOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslTaskStatusFutureOrderingValid.cfg models/dataflow/ParslTaskStatusFutureOrdering.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_task_status_future_ordering_runtime.py -v
```

The strict Current configuration reports the two-state status-lag counterexample; Fixed and Valid
complete in 6 generated / 3 distinct states and preserve `FutureCompletionSafety`.

The WorkQueue collector result boundary is exercised directly without requiring a Work Queue
installation:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_workqueue_results_runtime.py -v
```

The probe uses the real collector method and serialization facade to cover valid result values,
serialized app exceptions, corrupt result files, and collector failure cleanup of outstanding
Futures.

The Flux result callback is exercised without a Flux installation:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_flux_result_runtime.py -v
```

The probe calls the real `_complete_future` callback with serialized `TaskResult` files and fake
Flux futures. It covers valid values, task exceptions, missing files, nonzero exit codes, and the
current cancellation behavior where a cancelled underlying future leaves the wrapper pending.

The TaskVine collector is exercised without a TaskVine installation:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_taskvine_results_runtime.py -v
```

The probe calls the real collector with manager reports and serialized result files, covering
valid values, task exceptions, corrupt files, no-result/resource failures, and manager-exit cleanup
of outstanding Futures.

Radical Pilot callback mapping is exercised without a Radical Pilot installation:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_radical_results_runtime.py -v
```

The probe supplies fake RP task objects and constants to the real callback, covering Bash exit
codes, Python deserialization, cancellation, Bash failures, master failure propagation, and the
current invalid non-exception failure path.

File/DataFuture readiness is exercised through a real two-task local dataflow:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_runtime.py -v
```

The producer writes binary output through a Parsl `File`, and the dependent consumer reads the
same bytes only after the producer has completed.
The same probe also checks that a consumer wired to the producer's output `DataFuture` receives a
`DependencyError` and is never executed when the producer fails.

Ordinary Future dependency propagation is checked separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_dependency_runtime.py -v
```

This verifies successful value propagation and failure blocking for non-file task dependencies.

DataFuture cancellation propagation is checked separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_datafuture_cancellation_runtime.py -v
```

`ParslDataFutureCancellation.tla` exposes the current callback boundary: a failed parent makes
the DataFuture fail, but a cancelled parent currently makes it appear available because
`parent_callback` checks `_exception` without checking `cancelled()`. The fixed configuration
adds that cancellation guard.

The HTEX heartbeat expiry path is also exercised without opening a real ZMQ socket:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_heartbeat_runtime.py -v
```

The runtime probe checks the strict `elapsed > heartbeat_threshold` boundary and verifies that an
expired manager is deactivated, removed from the scheduling set, and converted into a serialized
failure result for each in-flight task.

The adjustable-clock boundary is exercised separately:

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_heartbeat_clock_jump_runtime.py -v
```

This probe patches the real interchange clock forward and confirms that the current
`time.time()`-based implementation expires the manager.
- `ParslExecutorProvider.cfg`: 47,002 states generated, 8,221 distinct states, depth 25;
  provider request/success/failure, manager registration, worker slots, submit rejection, executor
  drain/recovery, provider failure, and block-granular scale-in all passed.
- `ParslJoinApp.cfg`: 1,210 states generated, 331 distinct states, depth 10;
  single/list/empty join returns, invalid-return rejection, inner completion/failure observation,
  ordered aggregation, join-handle lifetime, and JoinError propagation all passed.
- `ParslJoinRetry.cfg`: 840 states generated, 258 distinct states, depth 16;
  logical-inner versus physical-attempt separation, retryable inner failure isolation, final failure
  propagation, and ordered final-result aggregation all passed.
- `ParslNestedJoin.cfg`: 414 states generated, 126 distinct states, depth 11;
  nested leaf observation, nested handle lifetime, nested success/failure propagation, and outer
  completion gating all passed.
- `ParslJoinDuplicates.cfg`: 210 states generated, 49 distinct states, depth 7;
  duplicate Future references, callback-position observation, ordered duplicate results, repeated
  failure multiplicity, duplicate callback tolerance, and join-handle cleanup all passed.
- `ParslJoinImmediateCallback.cfg`: 25 states generated, 12 distinct states, depth 7; an
  already-completed inner Future could invoke its callback immediately without violating join
  registration or completion safety.
- `ParslJoinMixedList.cfg`: 4 states generated, 2 distinct states, depth 2; a mixed Future/non-
  Future list fails immediately without registering callbacks.
- `ParslJoinMixedListValid.cfg`: 76 states generated, 30 distinct states, depth 7; all-Future
  list observation, ordered aggregation, and inner-failure propagation passed.
- `ParslJoinValueList.cfg`: 4 states generated, 2 distinct states, depth 2; a non-empty list of
  ordinary values fails immediately without registering callbacks.
- `ParslJoinNoneResultSingle.cfg`: 10 states generated, 5 distinct states, depth 5; a
  successful single join preserves an inner `None` result.
- `ParslJoinNoneResultList.cfg`: 26 states generated, 11 distinct states, depth 7; a
  successful list join preserves both `None` values and their positions.
- `ParslTaskTransport.cfg`: 859 states generated, 288 distinct states, depth 28;
  serialization-before-send, envelope/decode ordering, dispatch admission, worker-loss retry,
  result serialization, correlation, and stale-result safety all passed.
- `ParslTaskTransportFailure.cfg`: 56 states generated, 25 distinct states, depth 13;
  a non-serializable Python object graph was rejected before dispatch on each bounded attempt.
- `ParslProviderPolling.cfg`: 2,861 states generated, 854 distinct states, depth 19;
  provider submit/status/cancel outcomes, unknown-status failure, transient API errors, cancel
  rollback, and block-target consistency all passed.
- `ParslExecutorKinds.cfg`: 50,149,761 states generated, 3,533,824 distinct states, depth 52;
  the bounded depth-10 executor contract run passed provider-free/provider-backed admission,
  manager registration, resource-specification rejection, drain/recovery, and failure cleanup.
- `ParslExecutorShutdown.cfg`: 394,010 states generated, 74,431 distinct states, depth 28;
  shutdown admission rejection, ThreadPool completion-before-stop, WorkQueue collector failure
  cleanup, HTEX interchange closure, and in-flight cleanup all passed.
- `ParslHtexUnknownTaskResultCurrent.cfg`: expected `KeyError` counterexample when a stale task id
  is popped from the result map; `ParslHtexUnknownTaskResultFixed.cfg`: 7 states generated, 4
  distinct states, depth 3; unknown results are discarded and later live results complete.
- `ParslThreadExecutorResourceSpecCurrent.cfg`: expected `AttributeError` counterexample for a
  truthy non-mapping resource value; `ParslThreadExecutorResourceSpecFixed.cfg`: 29 states
  generated, 8 distinct states, depth 4; invalid values are rejected without creating a Future.
- `ParslWorkQueueResults.cfg`: 606 states generated, 225 distinct states, depth 9;
  valid-result completion, corrupt/exception/no-result failure mapping, collector shutdown
  cleanup, and terminal-result consistency all passed.
- `ParslWorkQueueDuplicateReport.cfg`: expected counterexample at depth 3 (5 states
  generated, 4 distinct); a duplicate report kills the collector and exposes unrelated task
  failure. `ParslWorkQueueDuplicateReportFixed.cfg`: 22 states generated, 7 distinct states,
  depth 4; stale reports are ignored while every still-active unrelated task remains pending.
- `ParslFluxResult.cfg`: expected counterexample at depth 2 (54 states generated, 24 distinct);
  cancellation of the underlying Flux future can leave the wrapper Future non-terminal.
- `ParslFluxResultFixed.cfg`: 63 states generated, 26 distinct states, depth 6; valid, missing,
  malformed, and task-exception result mapping plus cancellation propagation all passed.
- `ParslTaskVineResults.cfg`: 56 states generated, 26 distinct states, depth 5; valid-result
  completion, missing/corrupt/exception/no-result failure mapping, and submit-process cleanup of
  outstanding Futures all passed.
- `ParslTaskVineDuplicateReport.cfg`: expected counterexample at depth 3 (5 states generated,
  4 distinct); a duplicate report kills the collector and exposes unrelated task failure.
  `ParslTaskVineDuplicateReportFixed.cfg`: 22 states generated, 7 distinct states, depth 4;
  stale reports are ignored while active unrelated tasks remain pending.
- `ParslTaskVineSubmitCurrent.cfg`: expected counterexample at depth 4; a dead submit process
  leaves the registered Future mapped after failure.
- `ParslTaskVineSubmitFixed.cfg`: 5 states generated, 4 distinct states, depth 4; failed
  serialization or process liveness checks roll back the task map.
- `ParslRadicalPilotResults.cfg`: expected counterexample at depth 2 (73 states generated, 38
  distinct); shutdown can leave a submitted RP task's Parsl Future pending.
- `ParslRadicalPilotResultsFixed.cfg`: 79 states generated, 38 distinct states, depth 4; Bash,
  Python, MPI, cancellation, task failure, master failure, and shutdown cleanup all passed.
- `ParslRadicalPilotBulkShutdownCurrent.cfg`: expected counterexample at depth 4; shutdown exits
  the bulk collector with one queued task and a pending Future.
- `ParslRadicalPilotBulkShutdownFixed.cfg`: 5 states generated, 4 distinct states, depth 4;
  queued work is flushed before shutdown completes.
- `ParslGlobusComputeConfig.cfg`: expected counterexample at depth 3 (38 states generated, 25
  distinct); interleaved submits can observe another task's temporary resource specification.
- `ParslGlobusComputeConfigFixed.cfg`: 37 states generated, 16 distinct states, depth 8;
  serialized submit sections preserve per-task resource specifications and default restoration.
- `ParslGlobusComputeResult.cfg`: 8 states generated, 5 distinct states, depth 3; direct SDK
  Future identity and success/exception/cancellation propagation satisfy the result invariants.
- `ParslBlockProviderBadStateOrderingCurrent.cfg`: expected counterexample at depth 2; a
  completed Future aborts the failure sweep and leaves a pending task unresolved.
- `ParslBlockProviderBadStateOrderingFixed.cfg`: 3 states generated, 2 distinct states, depth 2;
  terminal Futures are skipped while outstanding tasks are failed.
- `ParslJobStatusOutputReadErrorCurrent.cfg`: expected counterexample at depth 2; a permission
  error escapes from `stdout_summary` even though `stdout` returns `None`.
- `ParslJobStatusOutputReadErrorFixed.cfg`: 6 states generated, 4 distinct states, depth 3;
  summary reads normalize the error to no output.
- `ParslBlockProviderBadStateMutationCurrent.cfg`: expected counterexample at depth 2; a Future
  callback mutates `_tasks` and aborts the live-dictionary failure sweep.
- `ParslBlockProviderBadStateMutationFixed.cfg`: 3 states generated, 2 distinct states, depth 2;
  snapshot iteration preserves failure of the original tasks.
- `ParslFluxCancelSubmitRaceCurrent.cfg`: expected counterexample at depth 5; a late result
  callback attempts to complete a cancelled wrapper.
- `ParslFluxCancelSubmitRaceFixed.cfg`: 15 states generated, 7 distinct states, depth 4;
  cancellation is propagated at binding and late callback publication is suppressed.
- `ParslFluxErrorCleanupCancellationCurrent.cfg`: expected counterexample at depth 2; an
  `InvalidStateError` on a canceled first Future strands the next queued Future.
- `ParslFluxErrorCleanupCancellationFixed.cfg`: 4 states generated, 3 distinct states, depth 3;
  terminal Futures are skipped and the cleanup queue drains.
- `ParslProviderKinds.cfg`: 424,001 states generated, 40,000 distinct states, depth 15;
  provider submit/status/cancel lifecycle, Slurm/Kubernetes status translation, missing-job
  handling, timeout-versus-failure distinction, cancellation outcomes, scale-in terminal
  handling, and resource admission all passed.
- `ParslProviderPollClockRollbackCurrent.cfg`: expected counterexample at depth 2; a wall-clock
  rollback suppresses provider polling.
- `ParslProviderPollClockRollbackFixed.cfg`: 3 states generated, 2 distinct states, depth 2;
  rollback-aware polling preserves the safety invariant.
- `ParslAWSProviderStatus.cfg`: expected counterexample at depth 2 (4 states generated, 3
  distinct); an absent EC2 instance response produces no returned provider status.
- `ParslAWSProviderStatusFixed.cfg`: 11 states generated, 5 distinct states, depth 5; missing
  instance completion mapping and status translation passed.
- `ParslAWSProviderStatusPresent.cfg`: 11 states generated, 5 distinct states, depth 5; normal
  EC2 running-instance status translation passed.
- `ParslAWSProviderSubmit.cfg`: expected counterexample at depth 3 (10 states generated, 6
  distinct); an empty instance-launch response reaches an uncaught destructuring error.
- `ParslAWSProviderSubmitFixed.cfg`: 12 states generated, 5 distinct states, depth 3; empty
  responses are handled without registering a resource.
- `ParslGoogleCloudSubmit.cfg`: expected counterexample at depth 2; a failed GCE image/API
  request increments the instance-name counter even though no instance was created.
- `ParslGoogleCloudSubmitFixed.cfg`: 4 states generated, 2 distinct states, depth 2; failed
  creation leaves the allocation counter unchanged.
- `ParslProviderStatusBatch.cfg`: 140,628 states generated, 17,672 distinct states, depth 6;
  bounded batch size, atomic status updates, scheduler-command failure preservation, missing-job
  completion mapping, and terminal-state stability all passed.
- `ParslClusterProviderUnknownJob.cfg`: expected counterexample at depth 2 (2 states
  generated, 2 distinct); an unknown requested job raises instead of returning a status.
  `ParslClusterProviderUnknownJobFixed.cfg`: 4 states generated, 2 distinct states, depth 2;
  unknown IDs map to explicit `MISSING`.
- `ParslKubernetesPolling.cfg`: expected counterexample at depth 1 (62 states generated, 22
  distinct); the actual exception branch fails `ErrorVisibility` because `RUNNING` is retained.
- `ParslKubernetesPollingFixed.cfg`: 85 states generated, 23 distinct states, depth 5;
  value-based error visibility, cancellation cleanup, phase translation, and terminal stability
  all passed.
- `ParslKubernetesSubmit.cfg`: expected counterexample at depth 3 (5 states generated, 4
  distinct); a successful pod create is recorded as `RUNNING` before Kubernetes phase polling.
- `ParslKubernetesSubmitFixed.cfg`: 10 states generated, 5 distinct states, depth 3; successful
  creation is represented as `PENDING`, while API failure registers no resource.
- `ParslKubernetesCancel.cfg`: expected counterexample at depth 3 (8 states generated, 6
  distinct); a returned delete-error object is treated as successful cancellation.
- `ParslKubernetesCancelFixed.cfg`: 13 states generated, 6 distinct states, depth 3; returned
  delete errors preserve `RUNNING`, while exceptions leave the resource unchanged.
- `ParslProviderExecutorBridge.cfg`: 3,511 states generated, 432 distinct states, depth 15;
  provider-to-executor admission, pre-manager and post-manager terminal failure, unknown-status
  tolerance, and terminal provider cleanup of manager capacity and in-flight work all passed.
- `ParslJoinCallbackRace.cfg`: 4,778 states generated, 956 distinct states, depth 11;
  early callback return, all-inner-done gating, join-lock serialization, ordered aggregation,
  duplicate callback tolerance, and delayed JoinError propagation all passed.
- `ParslJoinMemoData.cfg`: 1,697 states generated, 496 distinct states, depth 13;
  memo-hit completion without an attempt, staging/readiness gating for a DataFuture, ordered join
  aggregation, callback locking, and inner-failure propagation all passed.
- `ParslJoinMonitoring.cfg`: 7,545 states generated, 1,816 distinct states, depth 18;
  join status emission, memoized/staged inner readiness, radio reordering, database write failure
  and retry, version monotonicity, and terminal monitoring protection all passed.
- `ParslResourceAdmission.cfg`: 861 states generated, 288 distinct states, depth 9;
  WorkQueue-style resource field validation, complete resource-triplet enforcement, worker
  capacity accounting, queueing, dispatch, and release all passed with autolabel disabled.
- `ParslResourceAdmissionAutolabel.cfg`: 1,640 states generated, 489 distinct states, depth 9;
  partial resource specifications were admitted only under the autolabel-enabled contract, with
  the same capacity invariants passing.
- `ParslResourceScaling.cfg`: 987 states generated, 292 distinct states, depth 21;
  resource-driven scale-out, pending allocation success/failure rollback, capacity-guarded
  dispatch, retryable scaling pressure, and minimum-block scale-in safety all passed.
- `ParslPollerBadState.cfg`: 6,699 states generated, 936 distinct states, depth 12;
  status-poll ordering, `FAILED`/`MISSING` threshold handling, bad-state task failure, and
  suppression of later admission/scale-out all passed.
- `ParslPollerCloseScaleInRaceCurrent.cfg`: expected counterexample for scale-in during a live
  callback; `ParslPollerCloseScaleInRaceFixed.cfg`: 23 states generated, 8 distinct states, depth
  6; provider scale-in waits for poller quiescence.
- `ParslSerializationWire.cfg`: 208 states generated, 73 distinct states, depth 14;
  three-buffer serialization, serializer headers, decimal length framing, ordered unpack/decode,
  dispatch gating, and corrupt-frame rejection all passed.
- `ParslSerializationWireFailure.cfg`: 21 states generated, 8 distinct states, depth 4;
  an unserializable callable was rejected before framing or dispatch.
- `ParslSerializationPluginError.cfg`: expected counterexample at depth 3 (4 states generated,
  3 distinct); an importable non-plugin class leaks `AttributeError`.
  `ParslSerializationPluginErrorFixed.cfg`: 6 states generated, 3 distinct states, depth 3;
  plugin interface failures are wrapped.
- `ParslSerializationZMQBridge.cfg`: 104,657 states generated, 20,320 distinct states, depth 39;
  serializer-token correlation, route validation, drop/duplicate handling, decode-before-dispatch,
  worker-loss retry, and stale result suppression all passed.
- `ParslHtexResultQueue.cfg`: expected counterexample at depth 1 (10 states generated, 6 distinct);
  a malformed result causes the actual pop-before-validation path to leave a pending Future after
  the result thread exits.
- `ParslHtexResultQueueFixed.cfg`: 17 states generated, 7 distinct states, depth 3; malformed
  message failure, duplicate-result handling, valid/exception result mapping, and interchange
  failure cleanup all passed.
- `ParslHtexResultDecodeFailureCurrent.cfg`: expected counterexample, 2 states generated; a
  corrupt result is removed from `tasks`, the worker exits, and its Future remains pending.
- `ParslHtexResultDecodeFailureFixed.cfg` and `ParslHtexResultDecodeFailureNormal.cfg`: 4 states
  generated, 2 distinct states, depth 2; decode failure becomes a terminal Future error without
  orphaning the task.
- `ParslHtexSubmitFailure.cfg`: expected counterexample at depth 2; a failed outgoing queue put
  leaves a pending Future in the task map.
- `ParslHtexSubmitFailureFixed.cfg`: 4 states generated, 2 distinct states, depth 2; failed
  submission rolls back the task map and fails the Future.
- `ParslHtexSubmitSuccess.cfg`: 4 states generated, 2 distinct states, depth 2; successful
  submission preserves the pending task mapping.
- `ParslHtexVersionMismatch.cfg`: expected counterexample at depth 2 (27 states generated, 12
  distinct); a task is accepted after mismatch but before the fatal result is consumed.
- `ParslHtexVersionMismatchFixed.cfg`: 30 states generated, 10 distinct states, depth 4; version
  mismatch rejection, fatal-result cleanup, and closed-interchange admission safety all passed.
- `ParslHtexDispatchPriority.cfg`: 78 states generated, 26 distinct states, depth 8; priority
  ordering, manager capacity, draining admission, completion release, and manager-failure
  cleanup all passed.
- `ParslMPISpec.cfg`: expected counterexample at depth 3 (21 states generated, 11 distinct);
  zero `num_nodes` is accepted and reaches the rank-derivation error path.
- `ParslMPISpecFixed.cfg`: 21 states generated, 10 distinct states, depth 6; empty-spec rejection,
  positive-node validation, rank derivation, and valid MPI launch admission all passed.
- `ParslHeartbeatProvider.cfg`: 588 states generated, 100 distinct states, depth 16;
  provider-unknown tolerance, heartbeat ticking/reset, manager expiry, reconnect, and terminal
  provider cleanup all passed.
- `ParslResultRace.cfg`: 143 states generated, 46 distinct states, depth 13;
  delayed failure/success callbacks, retry selection, late-success races, stale callback
  suppression, Future consistency, and retry bounds all passed.
- `ParslLocalExecutor.cfg`: 59 states generated, 19 distinct states, depth 17;
  a provider-free local executor completed through the common task/result protocol.
- `ParslLocalProvider.cfg`: expected counterexample at depth 5 (23 states generated, 13 distinct);
  a delayed zero `.ec` marker can turn a cancelled local job into `COMPLETED`.
- `ParslLocalProviderFixed.cfg`: 31 states generated, 14 distinct states, depth 5; cancellation
  takes precedence over a late numeric exit marker.
- `ParslLocalProviderStatusScope.cfg`: expected counterexample at depth 2 (2 states generated,
  2 distinct); an unrequested resource can abort a requested status query. The fixed
  configuration has 4 states generated, 2 distinct states, depth 2 and limits polling to the
  requested resource.
- `ParslLocalProviderCancelUnknownCurrent.cfg`: expected counterexample at depth 1; cancelling
  an already-removed local job raises `KeyError`.
- `ParslLocalProviderCancelUnknownFixed.cfg`: 4 states generated, 2 distinct states, depth 2;
  stale cancellation returns a non-throwing unsuccessful result.
- `ParslSlurmSubmit.cfg`: expected counterexample at depth 3 (13 states generated, 9 distinct);
  a matching custom regex without a named `id` group reaches the provider's uncaught error path.
- `ParslSlurmSubmitFixed.cfg`: 18 states generated, 9 distinct states, depth 3; malformed or
  incompatible submission output is rejected without registering a resource.
- `ParslFileContent.cfg`: 17,812 states generated, 3,247 distinct states, depth 54;
  dependency readiness, stage-out ordering, and symbolic output-content identity passed.
- `ParslInputCorruption.cfg`: 37,556 states generated, 7,024 distinct states, depth 66;
  a corrupted stage-in could not release the dependent task until repaired.
- `ParslFileCorruptionSmall.cfg`: 60,824 states generated, 10,424 distinct states, depth 64;
  corruption, repair/retransfer, and output-content safety passed for a minimal dependent DAG.
- `ParslRegistration.cfg`: 94 states generated, 29 distinct states, depth 18;
  unregistered workers could not receive work or heartbeat until manager registration.
- `ParslRegistrationFailure.cfg`: 7,067 states generated, 1,384 distinct states, depth 36;
  failed manager registration left the worker unavailable without violating bindings or Future consistency.
- `ParslRegistrationRecovery.cfg`: 7,067 states generated, 1,384 distinct states, depth 36;
  a failed manager could retry registration without becoming dispatchable before re-registration.
- `ParslIdleManagerTimeout.cfg`: 27,639 states generated, 5,359 distinct states, depth 38;
  an idle manager exceeding the heartbeat age was removed with provider/executor capacity cleared.
- `ParslMultiManagerTimeout.cfg`: 442,239 states generated, 59,892 distinct states, depth 40;
  one manager expiry preserved another active block before the final expiry took the executor down.
- `ParslExecutorDrain.cfg`: 3,696 states generated, 760 distinct states, depth 33;
  draining stopped new submissions while preserving safety for already submitted attempts.
- `ParslMisroute.cfg`: 370,669 states generated, 46,560 distinct states, depth 40;
  wrong-executor dispatches were rejected without worker binding or false Future completion.
- `ParslResultMisroute.cfg`: 371,765 states generated, 46,560 distinct states, depth 40;
  wrong-executor result envelopes were rejected before Future resolution.
- `ParslJoin.cfg`: 427,320 states generated, 66,459 distinct states, depth 61;
  `EventuallySettled` passed for an outer join task waiting on two inner Futures.
- `ParslJoinSafety.cfg`: 427,320 states generated, 66,459 distinct states, depth 61;
  join dependency and outer-Future safety invariants passed.
- `ParslJoinInvalid.cfg`: 1,114 states generated, 276 distinct states, depth 32;
  invalid join return values rejected the outer Future without a false success.
- `ParslMessaging.cfg`: 5,941,081 states generated, 679,392 distinct states, depth 49;
  task/result wire ordering, envelope validity, symbolic object-graph serialization, and
  stale-result invariants passed.
- `ParslMessageLoss.cfg`: 3,696 states generated, 760 distinct states, depth 33;
  task/result message loss, worker cleanup, retry bounds, and Future consistency passed.
- `ParslMessageDuplicate.cfg`: 100 states generated, 31 distinct states, depth 20;
  duplicate task/result envelopes were explicitly discarded without duplicate completion.

## Source-to-model mapping

| TLA+ action | Parsl concept | Current source location |
| --- | --- | --- |
| `BeginStaging` / `FinishStaging` | data readiness/staging | `parsl/data_provider/data_manager.py` |
| `StartTransferCurrent` / `PrepareWrapperCurrent` | stage-in transfer started before wrapper failure | `DataManager.optionally_stage_in` |
| `PrepareWrapperFixed` / `StartTransferFixed` | failure-safe wrapper-before-transfer ordering | proposed ordering around `DataManager.optionally_stage_in` |
| `StartTransferCurrent` / `PrepareWrapperCurrent` | stage-out transfer started before wrapper failure | `DataFlowKernel._add_output_deps` and `DataManager.replace_task_stage_out` |
| `PrepareWrapperFixed` / `StartTransferFixed` | failure-safe output wrapper-before-transfer ordering | proposed ordering around `_add_output_deps` |
| `ParentCancels` / `ParentCallback` | DataFuture parent success/failure/cancellation propagation | `DataFuture.parent_callback` |
| `PublishTaskStatus` / `PublishFutureResult` / `FutureCompletionSafety` | publish logical `exec_done` before resolving the public Future | `DataFlowKernel._complete_task_result` |
| `CorruptStaging` / `RepairStaging` / `FileStagingSafety` | damaged input transfer and repair before dependency release | `DataManager.stage_in` and transfer error paths |
| `BeginStageOut` / `TransferOutputChunk` / `FinishStageOut` | staged output-file transfer after task completion | `DataFlowKernel` stage-out hooks and `DataManager.stage_out` |
| `FileChunkSafety` / `CorruptStageOut` / `RepairStageOut` | bounded transfer integrity and retransfer after corruption | `DataManager.stage_out` and provider/file-transfer error paths |
| `WaitReturnsTerminalFailure` / `ReadFailureEvent` / `NoDiagnosticCrash` | Globus terminal transfer failure reporting with optional diagnostics | `Globus.transfer_file` |
| `SerializeFailure` / `FailurePreservesLastValidTokens` | atomic Globus OAuth token-file publication | `Globus._save_tokens_to_file` |
| `ResolveEndpoint` / `AllowedPathSafety` | Globus executor working-directory and endpoint-path validation | `GlobusStaging._get_globus_endpoint` |
| `CreateCleanCopy` / `LocalPathIsClean` | Preserve global File URL while clearing site-local staging metadata | `File.cleancopy` and `DataManager.optionally_stage_in` |
| `DependencyCheck` | wait for dependencies and unwrap Futures | `DataFlowKernel._launch_if_ready_async` |
| `GatherDependencies` / `RunWorker` | shallow versus recursive Future collection and unwrapping | `parsl/dataflow/dependency_resolvers.py` and `DataFlowKernel._unwrap_futures` |
| `MemoizationHit` | complete a Future from cache | `DataFlowKernel.launch_task` |
| `ValidateReturn` / `InvalidShapeSafety` | admit valid `join_app` return shapes and reject tuple/scalar/mixed values before callbacks | `DataFlowKernel.handle_exec_update` |
| `SubmitAttempt` | select an executor and call `submit` | `DataFlowKernel.launch_task` |
| `SerializationFailure` | callable/argument serialization failure before dispatch | `DataFlowKernel.launch_task` and executor serialization boundary |
| `ResultSerializationFailure` / `ResultSerializationSafety` | worker return-value serialization failure before transport | worker result encoding and executor/interchange result boundary |
| `ObjectGraphSerializable` / `ObjectGraphSafety` | callable, argument, closure, and nested-object serializability | Python callable/payload serialization boundary in `DataFlowKernel` and executor |
| `SerializeAttempt` / `SendAttempt` / `ReceiveAttempt` / `DecodeAttempt` | encode, transport, and decode a task message | `DataFlowKernel` submit path, interchange task transport, manager message handling |
| `Pack` / `Unpack` / `BinaryContentSafety` | length-prefixed raw-byte payload framing | `parsl.serialize.facade.pack_buffers` / `unpack_buffers` |
| `ParseFrame` / `NegativeLengthSafety` | reject signed negative frame lengths before slicing | `parsl.serialize.facade.unpack_buffers` |
| `ReadMessage` / `StopAtDeadline` / `NoOverdueBatch` | monitoring batch collection and clock-based deadline | `DatabaseManager._get_messages_in_batch` |
| `Decode` / `Invoke` / `ReturnValue` / `RaiseException` | worker-side apply-message decode and callable execution | `parsl.executors.execute_task.execute_task` |
| `Query` / `TranslateRunning` / `TranslateCompleted` / `TranslateShortView` / `TranslateUnknown` | Azure VM status polling and state translation | `AzureProvider.status` |
| `Parse` / `PositiveDurationSafety` | provider walltime conversion and sub-minute rounding | `parsl.utils.wtime_to_minutes` |
| `IgnoreLinger` / `DeleteFails` / `DeleteSucceedsWithLocalId` / `DeleteSucceedsWithoutLocalId` | Azure VM cancellation and local instance bookkeeping | `AzureProvider.cancel` |
| `Submit` / `RejectResource` / `BeginShutdown` / `CompleteTask` / `FinishShutdown` | provider-free thread executor admission and shutdown | `ThreadPoolExecutor.submit` and `ThreadPoolExecutor.shutdown` |
| `OpenArchive` / `WriteOutput` | zip archive stage-in validation and atomic output publication | `ZipFileStaging._zip_stage_in` |
| `WriteArchive` / `RemoveSource` / `ModifySourceBeforeRetry` | zip stage-out append, source cleanup, and retry duplication | `ZipFileStaging._zip_stage_out` |
| `SendCommand` / `ReceiveReply` / `ResponseTimeout` | HTEX command REQ/REP lifecycle and timeout poisoning | `high_throughput.zmq_pipes.CommandClient.run` |
| `DecodeMalformed` / `DecodeHeartbeat` / `UpdateHeartbeat` / `ReplyHeartbeat` | manager message decoding and heartbeat reply | `Interchange.process_manager_socket_message` |
| `WriteScript` / `SubmitCommand` / `CommandFails` / `EmptySuccess` / `RegisterJob` | Grid Engine qsub submission and resource registration | `GridEngineProvider.submit` |
| `BeginPoll` / `HandleReportedJob` | Slurm batch status translation, foreign-job handling, and missing-job completion | `SlurmProvider._status` |
| `Batch` / `StrictBatchSafety` | Slurm Python-version batching and incomplete-final-batch validation | `parsl.providers.slurm.slurm.batched` |
| `BeginInsert` / `OperationalFailure` / `RetryInsert` / `InsertSuccess` / `IntegrityFailure` | monitoring database retry and duplicate/error handling | `DatabaseManager._insert` |
| `FirstDecode` / `MutateFirst` / `SecondDecode` | callable deserialization cache aliasing and fresh-object safety | `DillCallableSerializer.deserialize` |
| `IgnoreLinger` / `RemoteFailure` / `RemoteSuccessWithLocalState` / `RemoteSuccessWithoutLocalState` | AWS EC2 cancellation and local bookkeeping | `AWSProvider.cancel` |
| `DeleteFails` / `DeleteSucceeds` | GCE cancellation result and local resource status | `GoogleCloudProvider.cancel` |
| `Close` / `FinalizationSafety` | monitoring workflow finalization and shutdown drain | `DatabaseManager.close` |
| `Close` / `RepeatedClose` / `IdempotentClose` | MonitoringHub process and queue cleanup with repeat-call safety | `MonitoringHub.close` |
| `ReceiveFailure` / `FailureTerminationSafety` | persistent monitoring ZMQ receive failure and retry/termination policy | `MonitoringRouter.start` |
| `Batch` / `AvailableBatchSafety` | zero-interval queue-read boundary and message collection | `DatabaseManager._get_messages_in_batch` |
| `InsertBatch` / `ValidMessagePreserved` | bulk STATUS rollback and valid-sibling preservation | `Database.insert` and `DatabaseManager._insert` |
| `AttemptFails` / `HandleFailure` / `RetryLimitSafety` | retry-handler failure-cost accounting and physical-attempt admission | `DataFlowKernel.handle_exec_update` |
| `ChangeSource` / `MemoKeySafety` | function-body identity and memo-key invalidation | `BasicMemoizer.id_for_memo_function` |
| `Complete` / `Timeout` / `TimeoutCleanupSafety` | scheduler command timeout and subprocess cleanup | `utils.execute_wait`, `ClusterProvider.execute_wait` |
| `HashDict` / `MixedDictHashSafety` | heterogeneous dictionary-key normalization for memoization | `BasicMemoizer.id_for_memo_dict` |
| `BuildCommand` / `PathQuotingSafety` | shell-safe rsync command construction | `RSyncStaging.in_task_stage_in_wrapper` and `in_task_stage_out_wrapper` |
| `ComputePollTimeout` / `PollTimeoutSafety` | nonnegative ZMQ poll deadline calculation | `high_throughput.zmq_pipes.CommandClient.run` |
| `HandleFirstLine` / `HandleSecondLine` / `DuplicateSafety` | duplicate scheduler-record handling | `GridEngineProvider._status` |
| `HandleFirstLine` / `HandleSecondLine` / `DuplicateSafety` | duplicate scheduler-record handling with set removal | `LSFProvider._status` |
| `MissingJob` / `MissingJobSafety` | missing LSF scheduler record versus explicit terminal status | `LSFProvider._status` |
| `Validate` / `ResourceSafety` | LSF core-based resource validation before node-count derivation | `LSFProvider.__init__` |
| `HandleFirstLine` / `HandleSecondLine` / `DuplicateSafety` | duplicate scheduler-record handling with set removal | `SlurmProvider._status` |
| `HandleFirstLine` / `HandleSecondLine` / `DuplicateSafety` | duplicate scheduler-record handling with list removal | `TorqueProvider._status` |
| `HandleShortId` / `HandleSecondRecord` / `AliasSafety` | PBS Pro short/qualified job-id normalization and idempotent missing-job bookkeeping | `PBSProProvider._status` |
| `MutateBeforeCallback` / `Callback` / `JoinSnapshotSafety` | join Future-list snapshot and callback result stability | `DataFlowKernel.handle_join_update` |
| `Transfer` / `TransferSuccess` / `FailureCleanupSafety` | FTP connection cleanup after stage-in failure | `FTPInTaskStaging.in_task_transfer_wrapper` |
| `FirstChunk` / `LaterChunk` / `FailurePublicationSafety` | atomic HTTP destination publication after stream failure | `HTTPInTaskStaging.in_task_transfer_wrapper` |
| `Propagate` / `FailurePropagationSafety` | parent exception presence and DataFuture result propagation | `DataFuture.parent_callback` |
| `CancelFailure` / `CancelSuccess` | Slurm scancel result and local resource cancellation | `SlurmProvider.cancel` |
| `DispatchAttempt` | interchange sends work to a manager | `Interchange.process_tasks_to_send` |
| `StartAttempt` | worker starts a decoded task | `process_worker_pool.py` |
| `SerializeResult` / `SendResult` / `ReceiveResult` / `DecodeResult` | encode, transport, and decode a worker result | `process_worker_pool.py`, `Interchange.process_manager_socket_message` |
| `taskWireState` / `resultWireState` and `MessageSafety` | bounded ZMQ-like queues and envelope/attempt ordering | interchange task/result queues and manager socket message handling |
| `AcknowledgeResult` | receiver-side result consume acknowledgement before decode | manager result receive/dispatch boundary |
| `DropTaskMessage` / `DropResultMessage` | transport loss before dispatch or Future resolution | interchange/socket failure boundary and retry handling |
| `DuplicateTaskMessage` / `DuplicateResultMessage` | duplicate delivery and receiver-side discard | interchange receive loop and result deduplication boundary |
| `MessageCorrelationSafety` | bind task/result envelopes to `(task, retryAttempt)` | interchange message identity and DFK current-attempt checks |
| `AttemptSuccess` | accept the current decoded result and resolve the Future | `DataFlowKernel.handle_exec_update` |
| `JoinObserve` / `JoinComplete` / `JoinFailure` | wait for inner Futures and propagate join result/failure | `DataFlowKernel.handle_exec_update`, `handle_join_update`, and `join_app` |
| `JOIN_INVALID` / `JoinSafety` / `JoinHandleSafety` / `JoinFailureSafety` | invalid return, handle lifetime, aggregate completion, and inner-failure propagation | `DataFlowKernel.handle_exec_update` and `handle_join_update` |
| `AttemptFailure` / `RetryTask` | retryable failure and resubmission | `DataFlowKernel.handle_exec_update` |
| `WorkerFailure` / `LateResult` | worker/manager loss and old-attempt results | `Interchange.expire_bad_managers`; stale-result behavior is explicit in the abstraction |
| `Tick` / `Heartbeat` / `AttemptTimeout` | logical time, manager heartbeat, and task timeout | `Interchange` heartbeat expiration and executor/worker timeout paths |
| `Start` / `FunctionReturns` / `FunctionRaises` / `TimerFires` | Python app timeout timer lifecycle and cleanup | `parsl.app.python.timeout` and `AutoCancelTimer` |
| `Start` / `InjectImmediateTimeout` / `TimeoutParameterSafety` | reject non-positive Python-app timeout delays | `parsl.app.python.timeout` |
| `Validate` / `Callback` / `NegativeIntervalSafety` | periodic Timer interval admission and zero-delay behavior | `parsl.utils.Timer.__init__` / `_wake_up_timer` |
| `WaitCompletes` / `MissingFileSafety` / `NoOpenAfterTimeout` | bounded file wait and open timeout boundary | `parsl.utils.wait_for_file` / `time_limited_open` |
| `ExpireManager` / `Heartbeat` / `ExpirationAccounting` | strict heartbeat threshold and in-flight manager-loss cleanup | `Interchange.expire_bad_managers` and main polling loop |
| `AdvanceClock` / `CheckExpiry` / `NoPrematureExpiry` | wall-clock jump versus monotonic heartbeat expiry | `Interchange.expire_bad_managers` |
| `PublishMonitor` | persist an asynchronous task status update | `DataFlowKernel._update_task_state`, `MonitoringHub`, and monitoring radios |
| `BeginWrite` / `FinishWrite` / `PublishFixed` / `ReadComplete` | filesystem monitoring message write, atomic rename, and reader visibility | `FilesystemRadioSender.send` and `filesystem_router_starter` |
| `monitoringState.version` / `MonitoringDatabaseSafety` | ordered monitoring database writes | `MonitoringHub`/radio persistence boundary |
| `RegisterWorker` / `RegistrationSafety` | manager registration before dispatch | `Interchange` manager registration and worker availability |
| `RegistrationFailure` / `RetryRegistration` | manager startup failure and reconnect/re-registration | `Interchange` manager registration failure boundary |
| `IdleManagerTimeout` | idle manager heartbeat expiry and block cleanup | `Interchange` heartbeat expiration and executor/provider error handling |
| `ExecutorDrain` / `ExecutorRecover` | executor drain and reopening of task submission | executor scaling strategy and `HighThroughputExecutor.submit` |
| `MisrouteAttempt` | reject decoded work sent to the wrong manager/executor | `Interchange` dispatch routing and manager registration |
| `MisrouteResult` | reject result envelopes claiming the wrong executor | interchange result routing and DFK completion boundary |
| `SubmitFailure` | executor bad-state/submit rejection before worker dispatch | `BlockProviderExecutor.bad_state_is_set`, `HighThroughputExecutor.submit` |
| `Construct` / `Reject` / `CapacitySafety` | HTEX CPU-slot capacity derived from provider cores and `cores_per_worker` | `HighThroughputExecutor.__init__` |
| `ProviderFailure` | active provider block failure and executor/provider recovery | `JobStatusPoller`, `BlockProviderExecutor.handle_errors`, provider status/cancel paths |
| `Cancel` / `NoStaleCancellationCrash` | stale LocalProvider cancellation after resource removal | `LocalProvider.cancel` |
| `ExecutorFailure` | executor/provider loss while an attempt is running | executor bad-state/error handling plus provider block failure |
| `RequestAllocation` / `AllocationSucceeds` / `AllocationFails` | provider submit/status and block lifecycle | `ExecutionProvider`, `BlockProviderExecutor.scale_out_facade` |
| `SubmitSuccess` / `SubmitEmptyCurrent` / `SubmitEmptyFixed` | PBS Pro `qsub` output parsing and job/resource registration | `PBSProProvider.submit` |
| `BeginStatus` / `HandleForeignJob` | PBS Pro JSON status translation and foreign-job handling | `PBSProProvider._status` |
| `WriteScript` / `ExecuteBsub` / `ParseBsub` | LSF `bsub` submission and resource registration | `LSFProvider.submit` |
| `Validate` / `ChunkSizeSafety` | Condor scheduler command chunk-size validation | `CondorProvider._chunker` / `CondorProvider.__init__` |
| `Cancel` | LSF `bkill` cancellation and local resource-state update | `LSFProvider.cancel` |
| `ForeignLineCrashes` / `ForeignLineIgnored` / `KnownLineUpdates` | Torque qstat foreign-job handling and status update | `TorqueProvider._status` |
| `CancelSuccess` / `CancelFailure` | Torque qdel outcome and resource-state convention | `TorqueProvider.cancel` |
| `WriteScript` / `ExecuteQsub` / `ParseQsub` | Torque qsub submission and last non-empty job-id registration | `TorqueProvider.submit` |
| `Submit` / `TaskAdmissionSafety` | Torque `tasks_per_node` validation before launcher invocation | `TorqueProvider.submit` |
| `MalformedLineCrashes` / `MalformedLineIgnored` / `ValidLineUpdates` | Condor status line length validation and update | `CondorProvider._status` |
| `FailedCommandCrashes` / `FailedCommandUpdatesStale` / `FailedCommandIgnored` | Condor command return-code handling before status parsing | `CondorProvider._status` |
| `CancelChunk` | Condor chunked `condor_rm` cancellation and unknown-job guard | `CondorProvider.cancel` |
| `MalformedLineCrashes` / `MalformedLineIgnored` / `ValidLineUpdates` | Grid Engine qstat line length validation and update | `GridEngineProvider._status` |
| `Cancel` | Grid Engine `qdel` cancellation and local resource-state update | `GridEngineProvider.cancel` |
| `CancelAllocation` | scale-in of an idle block | `HighThroughputExecutor.scale_in`, `jobs/strategy.py` |
| `CancelRequestedAllocation` | cancel a pending provider block request | provider strategy cancellation boundary |
| `ScaleOut` / `StartIdleTimer` / `ScaleIn` in `ParslStrategy.tla` | slot-pressure scaling and idle-timeout policy | `parsl/jobs/strategy.py` |
| `AcceptConfiguration` / `RejectConfiguration` / `ComputeScaleRequest` | reject zero block capacity before strategy overload calculation | `parsl/jobs/strategy.py` |
| `RejectEmpty` / `ReceiveProbeReply` / `ProbeTimeout` | HTEX candidate-address probing and timeout outcomes | `parsl/executors/high_throughput/probe.py` |
| `EncodeHeader` / `EncodeBody` / `FinishEncode` | multipart task/result serialization before transport | DFK/interchange task path and worker result encoding |
| `Send` / `Deliver` / `DuplicateInbound` / `DropOutbound` | bounded ZMQ-like transport, reconnect loss, reordering, duplicate delivery | HTEX interchange and manager socket queues |
| `ReceiveValid` / `RejectInvalid` / `Ack` | receiver validation, correlation, and consume acknowledgement | interchange manager message handling and DFK result path |
| `StartEncode` / `EncodeObject` / `FinishEncode` | callable, globals, defaults, closure, and argument object serialization | DFK task serialization and executor submission boundary |
| `Serialize` / `Decode` / `AliasSafety` | identity shared between a closure object and an argument object | `serialize.facade.pack_apply_message` callable/argument boundary |
| `StartDecode` / `DecodeObject` / `FinishDecode` | reconstructing a callable/payload only after a complete encoded graph | worker-side task deserialization |
| `ValidateFrameCount` / `DecodeExtraFrames` / `ExtraDecodeSafety` | apply-message frame-count validation before deserialization | `serialize.facade.unpack_and_deserialize` |
| `MutateObject` / `RepairObject` | object content becoming unencodable before submission | Python object/payload serialization failure path |
| `SendChunk` / `ReceiveChunk` / `RejectCorruptChunk` / `RepairChunk` | chunked content transfer, checksum validation, and retransmission | `DataManager.stage_in` / `stage_out` transfer paths |
| `PublishStageIn` / `RejectStaleStageIn` / `PublishStageOut` | readiness and atomic file visibility after complete transfer | DataManager staging completion and file publication boundary |
| `CompleteApp` / `StartStageOut` / `CompleteStageOut` / `RetryStageOut` | output `DataFuture` dependency on application or separate stage-out Future | `DataFlowKernel._add_output_deps` and `DataManager.stage_out` |
| `PublishOutput1` / `PublishOutput2` / `NoEarlyPublication` | independent multi-output readiness with a shared application dependency | `DataManager.stage_out` and output `DataFuture` construction |
| `Tick` / `SendHeartbeat` / `DeliverHeartbeat` / `ExpireManager` | wall-clock and manager heartbeat expiry | HTEX interchange heartbeat and manager health handling |
| `StartAttempt` / `TimeoutAttempt` / `RetryAttempt` / `RetryLostAttempt` / `DeliverResult` | attempt deadline, manager-loss retry choice, and stale late result | DFK timeout/retry callbacks, HTEX manager-loss handling, and result completion path |
| `AdvanceStatus` / `EmitEvent` | logical task status event generation | DFK task-state update and monitoring radio send |
| `DeliverHead` / `ReorderRadio` / `WriteSuccess` / `WriteFailure` | asynchronous monitoring queue and database persistence | MonitoringHub/radio/database boundary |
| `BeginInsert` / `InsertRow` / `DuplicateRejected` / `DuplicateIgnored` | STATUS-table primary-key collision, generic exception loss, and idempotent repair | `parsl/monitoring/db_manager.py` `STATUS` schema and `DatabaseManager._insert` |
| `ReceiveFirstBeforeTry` / `InsertTaskAndTry` / `ReceiveFirstAfterTry` | deferred worker-task monitoring message replay and try-row ordering | `DatabaseManager.start` deferred-resource logic |
| `RequestBlock` / `AllocationSucceeds` / `AllocationFails` | provider request and block lifecycle | `ExecutionProvider` and `BlockProviderExecutor.scale_out_facade` |
| `StatusBatchSuccess` / `StatusBatchFailure` | bounded scheduler polling, atomic status update, and timeout/error preservation | `ClusterProvider.status`, `SlurmProvider._status`, and `execute_wait` |
| `BeginPoll` / `ReceiveEC2Response` / `Reset` | EC2 instance status translation and missing-instance handling | `AWSProvider.status` |
| `TranslateKnown` / `UnknownStatusCurrent` / `UnknownStatusFixed` | Google Compute Engine status-table translation | `GoogleCloudProvider.status` |
| `PollError` / `ErrorVisibility` | Kubernetes pod-read exception and UNKNOWN-state exposure, including the identity-check regression probe | `KubernetesProvider._status` |
| `RegisterManager` / `ReadyWorker` / `DispatchTask` | manager registration and worker-slot readiness | HTEX interchange/manager registration and worker pool |
| `SubmitTask` / `RejectSubmit` / `DrainExecutor` | executor submit admission and drain behavior | `HighThroughputExecutor.submit` and executor bad-state handling |
| `BeginShutdown` / `Complete` / `WorkQueueCollectorFails` / `HtexInterchangeLoss` | concrete executor shutdown and outstanding-task cleanup | `threads.py`, `workqueue/executor.py`, and `high_throughput/executor.py` |
| `Report` / `DecodeReport` / `CollectorFinallyFailsOutstanding` | WorkQueue result-file decoding and collector-exit Future cleanup | `WorkQueueExecutor._collect_work_queue_results` |
| `Validate` / `Register` / `CheckSubmitProcess` | WorkQueue resource validation and submit-process liveness ordering | `WorkQueueExecutor.submit` |
| `FluxSucceeds` / `PrepareResult` / `CompleteCallback` / `FluxCancels` | Flux job completion, result-file decoding, and wrapped-Future cancellation | `FluxExecutor._complete_future` and `FluxFutureWrapper.cancel` |
| `CancelWrapper` / `CancellationConsistency` | propagate an already-terminal underlying Flux cancellation to the wrapper Future | `FluxFutureWrapper.cancel` |
| `WriteScript` / `Launch` / `FailedCleanupSafety` | LocalProvider worker-script ownership across launch failure | `LocalProvider.submit` |
| `CancelBeforeBind` / `BindUnderlying` / `PublishCallback` | Flux cancellation versus late underlying-future binding | `FluxFutureWrapper.cancel` and `_complete_future` |
| `Submit` / `Report` / `Collect` / `ManagerFails` / `CollectorCleanup` | TaskVine task submission, result report mapping, and manager-loss Future cleanup | `TaskVineExecutor.submit`, `_collect_taskvine_results`, and TaskVine manager report generation |
| `CreateFactory` / `ConfigureFactory` / `EnterContext` / `RequestStop` / `ExitContext` | TaskVine factory process configuration and stop lifecycle | `taskvine.factory._taskvine_factory` |
| `Register` / `Serialize` / `CheckProcess` | TaskVine Future registration and submit failure rollback | `TaskVineExecutor.submit` |
| `TaskDone` / `TaskCanceled` / `TaskFailed` / `MasterFailed` / `Shutdown` | Radical Pilot callback mapping and pending-Future cleanup | `RadicalPilotExecutor.task_state_cb`, `_fail_all_tasks`, and `shutdown` |
| `Cancel` / `LateDone` | Radical Pilot cancellation versus late result callback | `RadicalPilotExecutor.task_state_cb` terminal Future updates |
| `RequestShutdown` / `FlushBulk` / `DropBulk` / `FinishShutdown` | Radical Pilot bulk-queue flush before shutdown | `RadicalPilotExecutor._bulk_collector` and `shutdown` |
| `BeginSubmit` / `UnderlyingSubmit` / `FinishSubmit` | Globus Compute temporary resource-specification override and restoration | `GlobusComputeExecutor.submit` |
| `BeginA` / `BeginB` / `SubmitA` / `SubmitB` | concurrent Globus Compute configuration isolation and serialized fixed path | `GlobusComputeExecutor.submit` shared SDK executor mutation |
| `DeliverMalformed` / `DeliverDuplicate` / `InterchangeFailure` | HTEX result-thread message validation, duplicate handling, and fatal interchange cleanup | `HighThroughputExecutor._result_queue_worker` |
| `DeliverCorruptResult` / `DecodeFailureSafety` / `NoOrphanedPendingFuture` | corrupt result deserialization after task-map removal | `HighThroughputExecutor._result_queue_worker` |
| `RegisterMismatch` / `HandleFatalResult` | manager version rejection and pending-fatal admission race | `Interchange.process_manager_socket_message` and `HighThroughputExecutor.submit_payload` |
| `Dispatch` / `Complete` / `Drain` / `Recover` | HTEX pending-task priority, manager capacity, and draining admission | `Interchange.process_task_incoming`, `get_tasks`, and `process_tasks_to_send` |
| `Configure` / `Validate` / `DeriveRanks` / `Launch` | MPI resource-specification validation and derived rank counts | `MPIExecutor.validate_resource_spec` and `mpi_prefix_composer.validate_resource_spec` |
| `Compose` | MPI launcher-prefix construction and backend selection | `mpi_prefix_composer.compose_all` |
| `FailProvider` / `CancelAllocation` | provider failure and block-granular scale-in cleanup | `BlockProviderExecutor.handle_errors` and provider cancel/strategy paths |
| `ReturnSingle` / `ReturnList` / `ReturnEmptyList` / `ReturnInvalid` | `join_app` return-shape validation | `DataFlowKernel.handle_exec_update` join branch |
| `ObserveInner` / `FinalizeJoin` | inner Future callbacks, aggregate completion, and JoinError | `DataFlowKernel.handle_join_update` |
| `ObservePosition` / `DuplicateCallback` | ordered list-position callbacks and duplicate Future references | `DataFlowKernel.handle_join_update` list branch |
| `ReturnJoinable` / `ReturnMixedList` / `RegisterEmptyCompletion` | list element validation, immediate empty-list completion, and mixed-list rejection | `DataFlowKernel.handle_exec_update` join branch |
| `StartAttempt` / `FailAttempt` / `RetryAttempt` / `CompleteAttempt` in `ParslJoinRetry.tla` | inner Future retry lifecycle before join observation | DFK retry handling and inner Future callbacks |
| `CompleteInner` / `HandleCallback` in `ParslJoinCancellation.tla` | cancelled inner Future handling and outer join termination | `DataFlowKernel.handle_join_update` |
| `ObserveCancelled` / `CancellationTerminal` in `ParslJoinListCancellation.tla` | cancelled Future handling for list-valued joins | `DataFlowKernel.handle_join_update` list branch |
| `ObserveCancelled` / `CancellationTerminal` in `ParslJoinSingleCancellation.tla` | cancelled single inner Future handling and terminal join failure | `DataFlowKernel.handle_join_update` single-Future branch |
| `StartNestedJoin` / `FinalizeNested` / `ObserveNestedResult` | nested join handle and result propagation | nested `join_app` callback composition |
| `BeginEncode` / `FinishEncodeSuccess` / `DecodeTaskSuccess` | serialized callable/payload gating task transport | DFK serialization boundary, interchange task queue, worker decode |
| `CorruptTaskEnvelope` / `DecodeTaskFailure` / `LoseAttempt` / `AcceptResult` | protocol corruption, worker loss, retry and stale result handling | HTEX message/result paths and DFK attempt correlation |
| `SubmitBlock` / `SubmitAccepted` / `SubmitRejected` | provider submit API and target rollback | `ExecutionProvider.submit` and block scaling facade |
| `BeginStatus` / `StatusPending` / `StatusRunning` / `StatusUnknown` | provider status polling and unknown-job failure | `ExecutionProvider.status` and `JobStatusPoller` |
| `BeginCancel` / `CancelAccepted` / `CancelFailed` | provider cancellation and rollback | `ExecutionProvider.cancel` and scale-in handling |
| `LocalExecutors` / `LocalExecutorSafety` | local executor path without provider provisioning or manager registration | `ThreadPoolExecutor` submission boundary |
| `PublicCancel` / `Run` / `Finish` | AppFuture/DataFuture versus underlying Future cancellation behavior | `AppFuture.cancel`, `DataFuture.cancel`, and `ThreadPoolExecutor.submit` |
| `CreateProjection` / `RunProjection` / `PropagateSourceFailure` | deferred item/attribute access over a Future | `AppFuture.__getitem__`, `AppFuture.__getattr__`, and `_parsl_internal` apps |

## Representative traces

Normal execution:

```text
DependencyCheck(A), Enqueue(A), RequestAllocation(E1), AllocationSucceeds(E1,W1),
SubmitAttempt(A,E1), DispatchAttempt(A,0,W1), StartAttempt(A,0,W1),
AttemptSuccess(A,0,W1),
DependencyCheck(B), Enqueue(B), SubmitAttempt(B,E1), DispatchAttempt(B,0,W1),
StartAttempt(B,0,W1), AttemptSuccess(B,0,W1),
BeginStaging(C), FinishStaging(C), DependencyCheck(C), Enqueue(C), ...,
AttemptSuccess(C,0,W1)
```

Retry plus a late result:

```text
AttemptFailure(A,0,W1), RetryTask(A), SubmitAttempt(A,E1),
DispatchAttempt(A,1,W2), StartAttempt(A,1,W2),
LateResult(A,0),                 # (A,0) becomes stale; Future(A) is unchanged
AttemptSuccess(A,1,W2)           # Future(A) accepts only attempt 1
```

Two noteworthy source/model differences are intentional: Parsl's `States.running` is mainly
observed by monitoring while the DFK success path is `pending -> launched -> exec_done`; and
the real HTEX heartbeat, batching, and ZMQ message protocol are compressed into discrete
`DispatchAttempt` and `WorkerFailure` events. The model also prevents scale-in from silently
removing a provider block with an in-flight attempt.

The monitoring dispatch-envelope refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDispatchEnvelopeCurrent.cfg models/monitoring/ParslMonitoringDispatchEnvelope.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDispatchEnvelopeFixed.cfg models/monitoring/ParslMonitoringDispatchEnvelope.tla
java -cp tla2tools.jar tlc2.TLC -config models/monitoring/ParslMonitoringDispatchEnvelopeValid.cfg models/monitoring/ParslMonitoringDispatchEnvelope.tla
```

The current configuration reaches the malformed-tuple assertion; fixed and valid configurations
complete in 4 generated / 2 distinct states and preserve `MalformedIsolation`.

The Kubernetes unknown-job refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesUnknownJobCurrent.cfg models/providers/ParslKubernetesUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesUnknownJobFixed.cfg models/providers/ParslKubernetesUnknownJob.tla
```

The current configuration reaches the `KeyError` crash outcome; the fixed configuration returns
UNKNOWN and completes in 4 generated / 2 distinct states.

The analogous Condor lookup refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorUnknownJobCurrent.cfg models/providers/ParslCondorUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorUnknownJobFixed.cfg models/providers/ParslCondorUnknownJob.tla
```

The current configuration reaches the stale-id `KeyError`; the fixed configuration returns
UNKNOWN and completes in 4 generated / 2 distinct states.

The heartbeat-parameter refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslHeartbeatParameterValidationCurrent.cfg models/clock/ParslHeartbeatParameterValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslHeartbeatParameterValidationFixed.cfg models/clock/ParslHeartbeatParameterValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/clock/ParslHeartbeatParameterValidationValid.cfg models/clock/ParslHeartbeatParameterValidation.tla
```

The current configuration accepts invalid non-positive values and violates `ParameterSafety`;
the fixed configuration rejects them (5 generated / 2 distinct states).

The ThreadPoolExecutor thread-count refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorThreadCountCurrent.cfg models/executors/ParslThreadExecutorThreadCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorThreadCountFixed.cfg models/executors/ParslThreadExecutorThreadCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorThreadCountValid.cfg models/executors/ParslThreadExecutorThreadCount.tla
```

The current configuration reaches the delayed start error; fixed and valid configurations
preserve `ThreadCountSafety`.

The ThreadPoolExecutor resource-specification refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorResourceSpecCurrent.cfg models/executors/ParslThreadExecutorResourceSpec.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslThreadExecutorResourceSpecFixed.cfg models/executors/ParslThreadExecutorResourceSpec.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_thread_executor_resource_spec_runtime.py -v
```

The HTEX `cores_per_worker` refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCoresPerWorkerCurrent.cfg models/executors/ParslHtexCoresPerWorker.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCoresPerWorkerFixed.cfg models/executors/ParslHtexCoresPerWorker.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexCoresPerWorkerValid.cfg models/executors/ParslHtexCoresPerWorker.tla
```

The current configuration reaches the division error for zero cores per worker; fixed and valid
configurations preserve `NoDivisionError`.

The `ParslPoolExecutor.map` timeout and no-cancellation contract is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslPoolExecutorMap.cfg models/executors/ParslPoolExecutorMap.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pool_executor_map_runtime.py -v
```

The bounded model checks input-order result consumption, deadline timeout, and preservation of
already-submitted Futures after timeout. The runtime probe also checks the advisory
`cancel_futures` shutdown behavior.

The HTEX address-probe-timeout propagation refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAddressProbeTimeoutCurrent.cfg models/executors/ParslHtexAddressProbeTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAddressProbeTimeoutFixed.cfg models/executors/ParslHtexAddressProbeTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/executors/ParslHtexAddressProbeTimeoutValid.cfg models/executors/ParslHtexAddressProbeTimeout.tla
```

The current configuration drops an explicit zero from the worker command; fixed and valid
configurations preserve the configured timeout.

The LocalProvider `tasks_per_node` refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalTasksPerNodeCurrent.cfg models/providers/ParslLocalTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalTasksPerNodeFixed.cfg models/providers/ParslLocalTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalTasksPerNodeValid.cfg models/providers/ParslLocalTasksPerNode.tla
```

The current configuration reaches the failed-launch outcome; fixed and valid configurations
preserve `NoInvalidProcess`.

The provider walltime refinement is checked with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslWalltimeParsingCurrent.cfg models/providers/ParslWalltimeParsing.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslWalltimeParsingFixed.cfg models/providers/ParslWalltimeParsing.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslWalltimeParsingValid.cfg models/providers/ParslWalltimeParsing.tla
```

The current configuration reaches the zero-minute sub-minute outcome and violates
`PositiveDurationSafety`; fixed and valid configurations complete in 4 generated / 2 distinct
states. The runtime probe is `tests/test_walltime_parsing_runtime.py`.

## Concrete Parsl example

`parsl_demo.py` runs the same three-node dataflow shape with real Parsl. It demonstrates the
mapping, but it is not itself the TLC proof object: the TLA+ `result` token only means that
the result was accepted by the abstract DFK.

```bash
python3 -m pip install parsl
python3 parsl_demo.py
```
