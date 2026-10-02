# Project Progress Log

This file is the durable project record for the TLA+ Parsl abstraction effort. Chat retention is
external to this repository, so important decisions, coverage counts, and the next audit target
are recorded here in English and committed with the model changes.

## 2026-10-02 — Full 726-case regression after transfer and transport refinements

- Ran `scripts/runtime_foundational_smoke.sh` with the installed Parsl source: all 465 named
  runtime entries passed.
- Ran `scripts/tlc_foundational_smoke.sh` with TLC 2.19 and Java 17: all 726 foundational
  configurations passed, including the HTTP in-task cleanup gate, FTP transfer gate, HTEX ferry
  send-failure model, and Slurm scale-in composition. The recent-model runner continues to keep
intentional Current counterexamples separate from the Fixed foundational gate.

## 2026-10-02 — Full 729-case regression after projection monitoring and ZMQ refinements

- Ran `scripts/tlc_foundational_smoke.sh` with TLC 2.19 and Java 17: all 729 foundational
  configurations passed, including the projection/retry monitoring and serialized-ZMQ cases.
- Ran `scripts/runtime_foundational_smoke.sh` against `/tmp/parsl-source`: all 468 runtime
  entries passed. Existing `join_app`, provider, executor, staging, clock, and database cases
  remain green after the new cross-layer additions.

## 2026-10-02 — Source-aligned `join_app` audit

- Reviewed the installed `DataFlowKernel.handle_exec_update` and `handle_join_update` branches
  and mapped single-Future, empty-list, list, invalid-shape, cancellation, retry, stale-result,
  nested-join, callback-race, stage-out, and monitoring behavior to existing models and runtime
  probes in `docs/audits/join-source-audit.md`.
- Confirmed that the known cancellation escapes are already tracked as BUG-011, BUG-012, and
  BUG-178; no duplicate model or ledger entry was added. The next distinct join composition is
  list-valued join callback plus stage-out/DataFuture publication and monitoring finalization.

## 2026-10-02 — Full 727-case regression after Future projection retry model

- Ran `scripts/tlc_foundational_smoke.sh` with TLC 2.19 and Java 17: all 727 foundational
  configurations passed, including `ParslFutureProjectionRetry`.
- Ran `scripts/runtime_foundational_smoke.sh` against `/tmp/parsl-source`: all 466 runtime
  entries passed. The complete regression covers the new projection/retry bridge together with
  the existing ZMQ, callable, staging, clock, monitoring, executor, provider, and `join_app`
  abstractions.

## 2026-10-02 — Flux cancellation ledger reconciliation

- Promoted the already-verified `ParslFluxCancelUnderlyingState` finding to BUG-328. When the
  underlying Flux Future is already cancelled, the installed wrapper returns success but remains
  pending; the existing Current/Fixed TLC pair and runtime probe provide the evidence. No new
  model was needed; the executor ledger now records this previously omitted finding.

## 2026-10-02 — TaskVine failure fan-out mutation

- Added `ParslTaskVineFailureFanout`, a small executor model for manager-failure fan-out. The
  Current branch reproduces `RuntimeError: dictionary changed size during iteration` when a
  Future callback removes its task entry; the Fixed branch snapshots entries and fails all
  pending Futures. The concrete runtime probe reproduces the installed collector behavior.
- Added BUG-324 to the executor ledger and promoted the Fixed case into the foundational gate.
  The inventory is now 721 TLC configurations, 460 runtime entries, and 731 unittest methods.

## 2026-10-02 — Work Queue failure fan-out mutation

- Added `ParslWorkQueueFailureFanout`, independently modeling the Work Queue collector's
  manager-failure fan-out. The Current branch reproduces a callback-driven dictionary mutation
  that strands a later Future; Fixed snapshots entries before callbacks. The concrete runtime
  probe passes against the installed executor.
- Added BUG-325 and promoted the Fixed case into the foundational gate. The inventory is now
  722 TLC configurations, 461 runtime entries, and 732 unittest methods.

## 2026-10-02 — Slurm cancellation to scale-in monitoring composition

- Added `ParslSlurmCancelScaleInMonitoring`, connecting Slurm's stale local cancellation failure
  to `BlockProviderExecutor.scale_in_facade`. Current reproduces remote cancellation followed by
  a `KeyError`, leaving executor state RUNNING without monitoring publication; Fixed passes the
  terminal propagation invariant. The runtime bridge passes against installed Parsl.
- Added BUG-326 and promoted the Fixed case into the foundational gate. Inventory: 723 TLC
  configurations, 462 runtime entries, and 733 unittest methods.

## 2026-10-02 — HTEX ferry result send-failure ownership

- Added `ParslHtexFerryResultSendFailure`, connecting the real worker-pool result scheduler to
  its ZMQ send boundary. Current reproduces a consumed-but-unsent result after `notify_sock.send`
  fails; Fixed preserves ownership for retry. The deterministic runtime bridge passes.
- Added BUG-327 and promoted the Fixed case into the foundational gate. Inventory: 724 TLC
  configurations, 463 runtime entries, and 734 unittest methods.

## 2026-10-02 — FTP in-task transfer gate composition

- Added `ParslFTPInTaskTransferGate`, composing existing FTP partial-publication and connection
  cleanup boundaries with wrapped user-function admission. Current reproduces partial bytes and
  an open FTP connection after transfer failure while user code remains blocked; Fixed passes the
  combined cleanup/admission invariants. The real wrapper probe passes.
- The composition reuses BUG-076/105 rather than creating duplicate ledger entries. Inventory is
  now 725 TLC configurations, 464 runtime entries, and 735 unittest methods.

## 2026-10-02 — HTTP in-task cleanup and admission composition

- Added `ParslHTTPInTaskCleanupGate`, composing HTTP response cleanup and partial-byte
  publication with wrapped-task admission. Current reproduces an open response and visible
  partial bytes after stream failure; Fixed passes the combined cleanup invariant. The real
  wrapper probe passes.
- This refines BUG-085/288 without adding duplicate ledger entries. Inventory is now 726 TLC
  configurations, 465 runtime entries, and 736 unittest methods.

## 2026-10-02 — Full foundational TLC regression

- Ran `scripts/tlc_foundational_smoke.sh` with TLC 2.19 and Java 17. Every foundational Fixed or
  normal case passed, including the recent Flux serializer, staging-provider fallback, composed
  file pipeline, join stale-result, and serialized ZMQ attempt-correlation coverage. The suite
  completed without a TLC failure; intentional Current counterexamples remain exercised by the
  recent-model runner.

## 2026-10-02 — Real ZMQ serialized-result attempt bridge

- Extended `test_zmq_serialization_runtime.py` with a real in-process ZMQ result path. Multipart
  result frames carry serialized payload bytes and attempt IDs; the probe rejects the late old
  attempt and resolves the Future only from the current attempt. Inventory is now 720 TLC cases
  and 459 runtime entries (730 unittest methods).

## 2026-10-02 — Composed callable snapshot and file-content pipeline bridge

- Added `test_content_file_pipeline_runtime.py`, combining the real Parsl callable serializer with
  Zip stage-in bytes in one worker-style path. The existing `ParslContentFilePipeline` model now
  has a concrete runtime bridge for callable snapshot isolation and file publication readiness.
  Inventory is now 720 TLC cases and 468 runtime entries (728 unittest methods).

## 2026-10-02 — Staging transfer failure and ordered provider fallback

- Added `ParslStagingProviderTransferFailure.tla` and a real `DataManager` runtime probe. A
  provider whose capability predicate succeeds but whose transfer raises currently aborts before
  a later capable provider is considered; the Fixed branch isolates the failure and continues
  fallback. Inventory is now 720 TLC cases and 467 runtime entries (727 unittest methods).

## 2026-10-02 — Flux non-TypeError serializer-failure abstraction

- Added `ParslFluxSerializationFailure.tla` and a concrete runtime probe. The installed
  `FluxExecutor.submit` catches only `TypeError` from `pack_apply_message`; a `ValueError` escapes
  raw. Current TLC produces the intentional `FailureNormalization` counterexample, while Fixed
  passes. Inventory is now 719 TLC cases and 466 runtime entries (726 unittest methods).

## 2026-10-02 — Radical-Pilot decode failure and collector-progress runtime bridge

- Added `test_radical_decode_monitoring_runtime.py`, which drives the real
  `RadicalPilotExecutor.task_state_cb` with a malformed `DONE` payload followed by a valid
  payload. The current callback raises before the later event is consumed and leaves both
  Futures unresolved; the accompanying Fixed TLA branch records a terminal decode failure and
  keeps collection alive. Inventory is now 718 TLC cases and 465 runtime entries (725 unittest
  methods).

## 2026-10-02 — PBS Pro malformed-status Future monitoring bridge

- Added `test_pbspro_malformed_future_monitoring_runtime.py`, connecting the real PBS Pro JSON
  parser to logical Future/monitoring terminality. A malformed qstat response currently raises
  `ValueError` before a task failure can be published, leaving the Future pending, matching
  `ParslPBSProMalformedFutureMonitoring`. Inventory is now 718 TLC cases and 464 runtime entries
  (725 unittest methods).

## 2026-10-02 — Condor empty-submit Future monitoring bridge

- Added `test_condor_empty_submit_future_monitoring_runtime.py`, connecting the real Condor
  parser to a logical Future and monitoring observation. An empty successful submit currently
  leaks `IndexError`, leaving the Future pending and emitting no terminal event, matching
  `ParslCondorEmptySubmitFutureMonitoring`. Inventory is now 718 TLC cases and 463 runtime
  entries (724 unittest methods).

## 2026-10-02 — AWS unknown-instance Future monitoring bridge

- Added `test_aws_unknown_future_monitoring_runtime.py`, connecting the real AWS provider status
  loop to an independent Future/monitoring observation. An untracked EC2 instance currently
  raises `KeyError` before the healthy peer can resolve its Future or publish a terminal event,
  matching `ParslAwsUnknownFutureMonitoring`. Inventory is now 718 TLC cases and 462 runtime
  entries (723 unittest methods).

## 2026-10-02 — Zip duplicate readiness runtime bridge

- Added `test_zip_duplicate_readiness_runtime.py`, connecting real Zip byte extraction to a real
  `DataFuture`. The current Parsl path publishes the last duplicate archive member and marks the
  represented file ready even though the archive contains two entries; this is the runtime
  witness for `ParslZipDuplicateReadiness`/BUG-190. Inventory is now 718 TLC cases and 461
  runtime entries (722 unittest methods).

## 2026-10-02 — timed inner Future through join_app

- Added `test_join_timed_monitoring_runtime.py`, a real DFK bridge for the timed join boundary.
  An inner `python_app(walltime=...)` timeout is aggregated by `join_app` into one terminal
  `JoinError`; the outer Future does not remain in `joining`. Inventory is now 718 TLC cases and
  460 runtime entries (721 unittest methods).

## 2026-10-02 — heartbeat expiry and timeout Future bridge

- Added a concrete runtime bridge for `ParslHeartbeatTimeoutFutureMonitoring`. The real HTEX
  `Interchange.expire_bad_managers` emits a manager-loss result frame, while a logical Future
  already terminal due to its timeout remains a timeout and ignores that stale frame. The Fixed
  TLC branch preserves timeout terminality and passes its bounded run. Inventory is now 718 TLC
  cases and 459 runtime entries (720 unittest methods).

## 2026-10-02 — serialized ACK retry with Future monitoring bridge

- Added a concrete runtime bridge for `ParslZMQSerializedAckFutureMonitoring`. Two duplicate
  in-process ZMQ envelopes are decoded with Parsl's real `pack_apply_message` facade; receiver
  correlation resolves one Future and emits one terminal monitoring event. The existing Current
  TLC branch still exposes duplicate dispatch, while Fixed passes its bounded model. Inventory is
  now 718 TLC cases and 458 runtime entries (719 unittest methods).

## 2026-10-02 — provider poll isolation with Future terminality

- Added `ParslPollerExecutorFutureIsolation`, refining the provider status-poller model so a
  failing executor cannot strand an independent healthy executor Future. Current TLC violates
  `IndependentFutureTerminality`; Fixed TLC passes the bounded model. The real `JobStatusPoller`
  runtime bridge reproduces the current skipped healthy poll and pending Future. Inventory is now
  718 TLC cases and 457 runtime entries (718 unittest methods).

## 2026-10-02 — full Python foundational regression

- Ran `scripts/runtime_foundational_smoke.sh` against the inspected Parsl source and virtual
  environment. All 446 listed runtime test files completed successfully, including the newest
  memoized-join and monitoring-DB retry bridges. The run emitted only pre-existing resource/SQL
  warnings and no test failures; the repository inventory remains 717 TLC cases and 456 named
  runtime entries (717 unittest methods).

## 2026-10-02 — monitoring DB retry runtime bridge

- Added a direct runtime bridge for `ParslMonitoringDBRetryFuture`. A real
  `DatabaseManager._insert` call retries one transient SQLAlchemy `OperationalError` while an
  application Future is already terminal; the Future remains unchanged and the insert succeeds
  on the second call. The foundational inventory is now 717 TLC cases and 456 runtime entries
  (717 unittest methods).

## 2026-10-02 — memoized failure propagation through join_app

- Added `ParslJoinMemoFailure`, composing an already-terminal failed memo Future with a staged
  successful inner Future and the outer `join_app` callback barrier. Current TLC violates
  `MemoFailurePropagation`; Fixed TLC passes 10,000 simulation steps. The real runtime bridge
  confirms that `BasicMemoizer` reuses the failed Future without a new attempt and that
  `handle_join_update` produces one terminal `JoinError`. The foundational inventory is now
  717 TLC cases and 455 runtime entries (716 unittest methods).

## 2026-10-02 — callable decode failure with Future monitoring

- Added `ParslFunctionDecodeFailureFutureMonitoring`, composing Python callable/argument snapshot
  bytes with worker decode failure and task/Future/monitoring terminality. Current TLC violates
  `DecodeFailureTerminality`; Fixed TLC passes 10,000 simulation steps. The real serializer
  facade rejects malformed apply-message bytes in the new runtime probe. The foundational
  inventory is now 716 TLC cases and 454 runtime entries (714 unittest methods).

## 2026-10-02 — Globus readiness timeout with monitoring

- Added `ParslGlobusTransferReadinessMonitoring`, composing ACTIVE-transfer poll budgets with
  DataFuture readiness, consumer admission, and monitoring terminality. Current TLC violates
  `TimeoutTerminality` when the transfer remains ACTIVE at the budget; Fixed TLC publishes a
  coordinated timeout failure and passes 10,000 simulation steps. The real Globus readiness and
  timeout runtime probes pass. The foundational inventory is now 715 TLC cases and 453 runtime
  entries.

## 2026-10-02 — RSync partial cleanup with DataFuture monitoring

- Added `ParslRsyncPartialCleanupFutureMonitoring`, composing a failed RSync stage-in with
  partial destination bytes, DataFuture readiness, dependent-task blocking, and monitoring
  failure propagation. Current TLC violates `FailureCleanupSafety`; Fixed TLC removes the partial
  publication and passes 10,000 simulation steps. The real RSync partial-cleanup runtime probe
  passes. The foundational inventory is now 714 TLC cases and 453 runtime entries.

## 2026-10-02 — HTTP partial cleanup with DataFuture monitoring

- Added `ParslHTTPPartialCleanupFutureMonitoring`, composing partial HTTP bytes with DataFuture
  readiness, dependent-task blocking, and monitoring failure propagation. Current TLC violates
  `FailurePublicationSafety` after a later stream failure; Fixed TLC removes the partial
  publication and passes 10,000 simulation steps. The real HTTP partial-cleanup runtime probe
  passes. The foundational inventory is now 713 TLC cases and 453 runtime entries.

## 2026-10-02 — FTP partial cleanup with DataFuture monitoring

- Added `ParslFTPPartialCleanupFutureMonitoring`, composing partial FTP bytes with DataFuture
  readiness, dependent-task blocking, and monitoring failure propagation. Current TLC violates
  `FailurePublicationSafety` after a stream failure; Fixed TLC removes the partial publication and
  passes 10,000 simulation steps. The real FTP partial-cleanup runtime probe passes. The
  foundational inventory is now 712 TLC cases and 453 runtime entries.

## 2026-10-02 — monitoring DB retry with Future terminality

- Added `ParslMonitoringDBRetryFuture`, composing persistent SQLite write retries with task/Future
  completion and monitoring publication. Current TLC violates `NoPersistentRetryAtBound`; Fixed
  TLC records an aborted write at the bounded retry limit and passes 10,000 simulation steps. The
  real persistent-retry DatabaseManager probes pass. The foundational inventory is now 711 TLC
  cases and 453 runtime entries.

## 2026-10-02 — HTEX contact starvation with Future monitoring

- Added `ParslHtexContactTimeoutStarvationFutureMonitoring`, composing continuous result traffic,
  heartbeat/contact expiry, task Future state, and monitoring publication. Current TLC violates
  `ContactTimeoutSafety` while the result socket stays readable; Fixed TLC expires the manager and
  passes 10,000 simulation steps. The real HTEX communicator starvation probe passes. The
  foundational inventory is now 710 TLC cases and 453 runtime entries.

## 2026-10-02 — Condor empty submit with Future monitoring

- Added `ParslCondorEmptySubmitFutureMonitoring`, composing an empty `condor_submit` response
  with provider admission, task failure, Future failure, and monitoring publication. Current TLC
  violates `NoRawEmptyResponse` because the provider leaks `IndexError`; Fixed TLC passes 10,000
  simulation steps. Both concrete Condor empty-submit runtime probes pass. The foundational
  inventory is now 709 TLC cases and 453 runtime entries.

## 2026-10-02 — ZMQ serialized ACK with Future monitoring

- Added `ParslZMQSerializedAckFutureMonitoring`, composing a real callable snapshot and ACK-loss
  retransmission with at-most-once dispatch, Future resolution, and monitoring publication.
  Current TLC violates `SingleDispatch`/`NoDuplicatePublication` after duplicate delivery; Fixed
  TLC passes 10,000 simulation steps. The real `parsl.serialize` duplicate-envelope runtime probe
  passes. The foundational inventory is now 708 TLC cases and 453 runtime entries.

## 2026-10-02 — join body retry with Future monitoring

- Added `ParslJoinBodyRetryMonitoring`, composing join-body physical retries with delayed inner
  Future admission and terminal monitoring. Current TLC violates `RetryDoesNotTerminate` by
  publishing failure during a retry window; Fixed TLC passes 10,000 simulation steps. The real
  `join_app` body-retry runtime probe passes. The foundational inventory is now 707 TLC cases and
  453 runtime entries.

## 2026-10-02 — Grid Engine empty submit with Future monitoring

- Added `ParslGridEngineEmptySubmitFutureMonitoring`, composing a successful-but-empty `qsub`
  response with provider admission, task failure, Future failure, and monitoring publication.
  Current TLC violates `NoUnusableSubmit` because `None` is returned to the scaling layer; Fixed
  TLC passes 10,000 simulation steps. The real Grid Engine empty-submit runtime probe passes.
  The foundational inventory is now 706 TLC cases and 453 runtime entries.

## 2026-10-02 — AWS empty submit with Future monitoring

- Added `ParslAwsEmptySubmitFutureMonitoring`, composing an empty EC2 launch response with task,
  Future, and monitoring failure propagation. Current TLC violates `NoCrashOnSubmit` because the
  provider crashes before publishing failure; Fixed TLC passes 10,000 simulation steps. The real
  `AWSProvider.submit()` runtime probe reproduces the empty-response `ValueError` and verifies the
  normal failed-submit path. The foundational inventory is now 705 TLC cases and 453 runtime
  entries.

## 2026-10-02 — AWS unknown instance with Future monitoring

- Added `ParslAwsUnknownFutureMonitoring`, composing AWS status-poll isolation with logical task
  completion, Future propagation, and monitoring publication. Current TLC violates
  `UnknownIsolation` after an untracked instance crashes the poller; Fixed TLC passes 10,000
  simulation steps. The existing AWS runtime probe still reproduces the concrete `KeyError`.
  The foundational inventory is now 704 TLC cases and 453 runtime entries.

## 2026-10-02 — complete 703-case foundational regression

- Ran the full foundational TLC smoke suite after the callable global/default retry and
  LocalProvider exit-file compositions were added. All 703 bounded configurations passed at
  `TLC_SIMULATE=1000`; the runtime inventory remains 453 entries. README, overview, and coverage
  matrix now report the verified 703-case baseline.

## 2026-10-02 — LocalProvider exit-file status with Future monitoring

- Added `ParslLocalExitFileFutureMonitoring`, composing a transient missing exit-code file with
  poller progress, Future failure, and monitoring publication. The Current branch violates
  `PollerProgress` by aborting before the later process failure; the Fixed branch records an
  unknown observation and passes 10,000 TLC simulation steps. The existing concrete LocalProvider
  missing-exit-file runtime probe passes. The foundational inventory is now 703 TLC cases and 453
  runtime entries.

## 2026-10-02 — callable global/default snapshot with retry

- Added `ParslFunctionGlobalDefaultFutureRetry`, composing separate function/global and default
  snapshots with task envelope execution, Future/monitoring terminality, and one physical retry.
  The Current branch violates `SnapshotResultSafety` on a mixed-epoch callable; the Fixed branch
  rejects it, re-snapshots on retry, and passes 10,000 TLC simulation steps. Three corresponding
  serializer runtime tests pass. The foundational inventory is now 702 TLC cases and 453 runtime
  entries.

## 2026-10-02 — Azure status bookkeeping with Future monitoring

- Added `ParslAzureStatusBookkeepingFutureMonitoring`, composing Azure translated/local status,
  Future completion, and monitoring publication. The Current branch violates
  `BookkeepingConsistency` because RUNNING is not recorded locally; the Fixed branch preserves
  the local status and passes 10,000 TLC simulation steps. The existing concrete Azure
  bookkeeping runtime probe passes. The foundational inventory is now 701 TLC cases and 453
  runtime entries.

## 2026-10-02 — Google Cloud unknown status with Future monitoring

- Added `ParslGoogleCloudUnknownFutureMonitoring`, composing unknown GCE status translation with
  poller progress, Future completion, and monitoring publication. The Current branch violates
  `UnknownIsolation` by aborting before a healthy observation; the Fixed branch isolates the
  unknown state and passes 10,000 TLC simulation steps. The existing four-case Google Cloud
  status runtime probe passes. The foundational inventory is now 700 TLC cases and 453 runtime
  entries.

## 2026-10-02 — PBS Pro malformed JSON with Future monitoring

- Added `ParslPBSProMalformedFutureMonitoring`, composing malformed `qstat` JSON with poller
  progress, Future completion, and monitoring publication. The Current branch violates
  `PollerProgress` by crashing before a later valid poll; the Fixed branch isolates the decode
  error and passes 10,000 TLC simulation steps. The existing concrete PBS Pro malformed-JSON
  runtime probe passes. The foundational inventory is now 699 TLC cases and 453 runtime entries.

## 2026-10-02 — multipart decode and peer monitoring composition

- Added `ParslZMQMultipartDecodeMonitoring`, composing malformed multipart frames, serializer
  failure, two result Futures, and monitoring. The Current branch violates
  `MalformedFrameIsolation` by crashing the collector before the bad Future is completed; the
  Fixed branch rejects the bad frame and continues to the valid peer. Fixed passes 10,000 TLC
  simulation steps, and four existing ZMQ/HTEX decode runtime tests pass. The foundational
  inventory is now 698 TLC cases and 453 runtime entries.

## 2026-10-02 — monitoring timeout and late-event persistence

- Added `ParslMonitoringTimeoutLateEvent`, composing logical timeout, asynchronous status events,
  transient database-write retry, and late success handling. The Current branch writes a stale
  success after timeout and violates `TimeoutDatabaseSafety`; the Fixed branch keeps Future and
  database terminal states aligned and passes 10,000 TLC simulation steps. Existing insert/update
  persistent-retry runtime probes pass. The foundational inventory is now 697 TLC cases and 453
  runtime entries.

## 2026-10-02 — LSF missing job with Future monitoring

- Added `ParslLSFMissingJobFutureMonitoring`, composing LSF missing-job polling with Future
  completion and monitoring publication. The Current branch reports success from absence alone;
  the Fixed branch retains `UNKNOWN` until explicit failure and passes 10,000 TLC simulation
  steps. The existing concrete LSF missing-job runtime probe passes. The foundational inventory
  is now 696 TLC cases and 453 runtime entries.

## 2026-10-02 — Condor malformed status with Future monitoring

- Added `ParslCondorMalformedFutureMonitoring`, composing a failed/truncated Condor status poll
  with poller progress, Future completion, and monitoring publication. The Current branch
  violates `PollerProgress` by crashing before a later valid status; the Fixed branch preserves
  progress and passes 10,000 TLC simulation steps. The existing concrete Condor malformed-line
  runtime probe passes. The foundational inventory is now 695 TLC cases and 453 runtime entries.

## 2026-10-02 — three-level join retry and monitoring composition

- Added `ParslTripleNestedJoinRetryMonitoring`, connecting a retried inner join (J1), a second
  nested join (J2), the root Future, and monitoring. The Current branch accepts a late J1 attempt
  and lets it resolve the root join; the Fixed branch rejects it as stale and preserves attempt
  correlation. Current violates `CurrentAttemptSafety`, Fixed passes 10,000 TLC simulation steps,
  and the existing heartbeat/ZMQ join runtime probes pass. The foundational inventory is now 694
  TLC cases and 453 runtime entries.

## 2026-10-02 — Slurm malformed status with Future monitoring

- Added `ParslSlurmMalformedFutureMonitoring`, composing the truncated Slurm status-line parser
  with poller progress, Future completion, and monitoring publication. The Current branch
  violates `PollerProgress` by crashing before a later valid completion; the Fixed branch skips
  the malformed record and passes 10,000 TLC simulation steps. The existing concrete Slurm
  malformed-line runtime probe passes. The foundational inventory is now 693 TLC cases and 453
  runtime entries.

## 2026-10-02 — heartbeat timeout and monitoring composition

- Added `ParslHeartbeatTimeoutFutureMonitoring`, combining wall-clock rollback, monotonic
  heartbeat age, task timeout, Future terminality, late completion, and monitoring status. The
  Current branch violates `TimeoutTerminality` after accepting a late completion; the Fixed
  branch passes 10,000 TLC simulation steps and preserves the timed-out result. Existing HTEX
  heartbeat and timeout runtime probes remain the concrete source-level evidence. The
  foundational inventory is now 692 TLC cases and 453 runtime entries.

## 2026-10-02 — file-content retry with DataFuture and monitoring

- Added `ParslFileTransferRetryMonitoring`, composing source-versioned file publication,
  asynchronous retry, DataFuture readiness, consumer admission, and monitoring state. The
  Current branch exposes stale bytes as a successful publication; the Fixed branch records the
  stale transfer, retries from the current source version, and keeps the consumer blocked until
  publication is safe. Current produces the expected TLC counterexample, Fixed passes 10,000
  simulation steps, and the existing two-case byte/checksum archive runtime probe passes. The
  foundational inventory is now 691 TLC cases and 453 runtime entries.

## 2026-10-02 — Radical-Pilot decode/monitoring composition

- Added `ParslRadicalPilotDecodeMonitoring`, composing the malformed Radical-Pilot `DONE`
  callback with Future completion, monitoring publication, and collector liveness. The Current
  branch strands the Future, hides the failure, and stops collection; the Fixed branch publishes
  a terminal failure and preserves progress. Targeted TLC checks pass for the Fixed branch and
  produce the expected counterexample for Current. The concrete malformed-payload runtime probe
  remains passing. The foundational inventory is now 690 TLC cases and 453 runtime entries.

## 2026-10-02 — Full foundational TLC regression

- Hardened `scripts/tlc_foundational_smoke.sh` so automatic Java/TLC discovery tolerates
  permission-denied temporary directories under `/tmp` while `set -e` is enabled.
- Re-ran the complete foundational suite after the fix: all 686 TLC cases passed at the bounded
  simulation setting, including the latest provider, staging, monitoring, join, and serialization
  compositions. Runtime count remains 453 entries.

## 2026-10-02 — Kubernetes provider/Future admission composition

- Added `ParslKubernetesFutureAdmission`, composing the concrete Kubernetes submit state with
  executor Future admission and monitoring publication. The Current branch admits work while
  the pod is still Pending because `submit` stores RUNNING before the first API poll; Fixed
  requires an observed Running phase and passes bounded TLC. The runtime bridge reproduces the
  submit-then-Pending observation. This deepens existing BUG-126 without duplicating its ledger
  entry. The foundational gate is now 682 TLC configurations and 445 runtime entries.

## 2026-10-02 — Kubernetes cancellation/Future/monitoring composition

- Added `ParslKubernetesCancelFutureMonitoring`, refining BUG-189 across provider, executor
  Future, and monitoring layers. Current TLC and runtime reproduce cancellation publication after
  a failed Kubernetes delete response; Fixed requires remote success and passes bounded TLC. The
  foundational gate is now 684 TLC configurations and 449 runtime entries.

## 2026-10-02 — Globus transfer/DataFuture readiness composition

- Added `ParslGlobusTransferReadiness`, composing ACTIVE transfer polling with DataFuture
  readiness and dependent-task admission. Current TLC and the concrete runtime bridge reproduce
  the missing overall deadline; Fixed turns poll-budget exhaustion into explicit transfer and
  DataFuture failure. The foundational gate is now 685 TLC configurations and 451 runtime
  entries.

## 2026-10-02 — Deserializer plugin retry/monitoring composition

- Added `ParslPluginRetryMonitoring`, connecting dynamic deserializer cache poisoning to logical
  retry, Future terminal state, and monitoring. Current TLC and runtime reproduce retry reuse of
  the failed plugin; Fixed evicts it and passes bounded TLC. This deepens BUG-064/BUG-104. The
  foundational gate is now 686 TLC configurations and 453 runtime entries.

## 2026-10-02 — Work Queue stale-result/peer-monitoring composition

- Added `ParslWorkQueueCancelledMonitoring`, refining the existing cancelled-result race across
  peer Future progress and monitoring terminality. Current TLC reproduces stale-report collector
  failure cascading to an unrelated peer; Fixed discards the stale report and passes bounded TLC.
  The foundational gate is now 687 TLC configurations and 453 runtime entries.

## 2026-10-02 — MPI malformed-result/monitoring composition

- Added `ParslMPIMalformedResultMonitoring`, refining corrupt MPI result decoding across node
  allocation, Future terminality, and monitoring failure publication. Current TLC reproduces the
  held-allocation/no-terminal-state combination; Fixed releases resources and passes bounded TLC.
  The foundational gate is now 688 TLC configurations and 453 runtime entries.

## 2026-10-02 — TaskVine stale-result/peer-monitoring composition

- Added `ParslTaskVineCancelledMonitoring`, refining the cancelled-result collector race across
  peer Future progress and monitoring terminality. Current TLC reproduces stale-report failure
  cascading to an unrelated peer; Fixed discards the stale report and passes bounded TLC. The
  foundational gate is now 689 TLC configurations and 453 runtime entries.

## 2026-10-02 — DFK executor-shutdown/monitoring finalization

- Added `ParslDfkExecutorShutdownMonitoring`, composing the real DFK cleanup order with executor
  shutdown failure and final WORKFLOW monitoring delivery. Current TLC and the runtime bridge
  reproduce cleanup aborting before terminal monitoring; Fixed isolates the executor error and
  passes bounded TLC. This is recorded as BUG-321. The foundational gate is now 683 TLC
  configurations and 447 runtime entries.

## 2026-10-02 — Flux provider startup handshake boundary

- Added `ParslFluxProviderHandshake`, a compact provider/executor composition for the concrete
  Flux startup sequence: provider allocation, package-path and instance-URI ZMQ messages, status
  polling, and executor readiness. The Current TLC configuration accepts a readable handshake
  after provider termination and violates `NoReadyAfterProviderTermination`; Fixed checks
  liveness before publication and passes. The runtime probe reproduces the concrete
  `_check_provider_job` early return and records the guard as BUG-320. The foundational gate is
  now 681 TLC configurations and 444 runtime entries.

## 2026-10-02 — Heartbeat/provider attempt-generation boundary

- Added `ParslHeartbeatProviderBoundary`, a compact cross-layer refinement that combines the
  source-accurate strict HTEX heartbeat boundary, manager-slot release, manager reconnection,
  retry generation, and stale physical results. The Current TLC configuration reaches the
  intentional `StaleResultSafety` counterexample; the Fixed configuration passes 100,001
  simulated states. The foundational gate is now 676 TLC configurations and 443 runtime entries.
  This stage is model-only because the concrete interchange expiry and stale-result paths already
  have focused runtime probes; it adds their composition rather than duplicating another probe.

## 2026-10-02 — Multi-output stage-out and join readiness

- Added `ParslJoinMultiOutputReadiness`, composing per-output transfer state, captured file
  versions, DataFuture publication, and ordered `join_app` callback aggregation. The Current TLC
  configuration reaches a `JoinCompleteness` counterexample where one output finishes the join;
  the Fixed configuration requires both outputs and both callbacks and passes 100,132 simulated
  states. Existing multi-output stage-out and join runtime probes remain green. The foundational
  gate is now 677 TLC configurations and 443 runtime entries.

## 2026-10-02 — Combined apply-frame validation

- Added `ParslApplyFrameValidation`, composing exact apply-message arity with declared byte
  lengths. The Current TLC configuration reproduces a decode side effect before malformed-frame
  rejection; the Fixed configuration rejects both bad frame count and truncated payload before
  deserialization and passes 100,001 simulated states. Existing arity and truncated-length
  runtime probes remain the concrete source evidence. The foundational gate is now 678 TLC
  configurations and 443 runtime entries.

## 2026-10-02 — RSync/DataFuture remote-publication gate

- Added `ParslRsyncDataFutureGate`, composing the real RSync stage-out wrapper (application first,
  remote copy second) with DataManager's `None` return/DataFuture contract and byte publication.
  The Current TLC configuration allows readiness after application completion, before RSync has
  published bytes; the Fixed configuration gates readiness and consumer admission on successful
  RSync and converts copy failure into a terminal DataFuture failure. Fixed TLC passes 100,001
  simulated states; existing RSync/DataFuture runtime probes provide concrete source evidence.
  The foundational gate is now 679 TLC configurations and 443 runtime entries.

## 2026-10-02 — Monitoring failure/shutdown terminal outcome

- Added `ParslMonitoringFailureShutdown`, composing permanent WORKFLOW-end update failure with
  database-manager close and loop termination. The Current TLC configuration stops after marking
  finalization while losing the failed update; the Fixed configuration bounds retries and records
  either persistence or an explicit dropped outcome before shutdown, passing 100,001 simulated
  states. Existing workflow-end bookkeeping, persistent-retry, and close runtime probes remain
  the concrete source evidence. The foundational gate is now 680 TLC configurations and 443
  runtime entries.

## 2026-10-02 — Zip duplicate-member/DataFuture readiness bridge

- Added `ParslZipDuplicateReadiness`, composing archive retry history with stage-in/DataFuture
  publication. The Current branch allows readiness after a duplicate member exists; the Fixed
  branch rejects ambiguous archive contents before exposing data to a consumer.
- TLC Fixed passes and Current reproduces `ReadinessUniqueness`; the real Zip stage-out/stage-in
  probes already demonstrate that Python `ZipFile.read` returns the latest duplicate member while
  both entries remain in the archive.
- The current baseline is 675 TLC cases, 443 runtime entries, and 702 unittest methods.

## 2026-10-02 — ordered join completion bridge

- Added `ParslJoinFailureOrder`, a small executable model in which inner Futures complete in an
  arbitrary order but the outer join result is constructed by original list position.
- The real `DataFlowKernel.handle_join_update` probe completes the second inner Future's callback
  first and still publishes `[1, 2]`, preserving join-list order.
- TLC and focused join coverage pass; the current baseline is 674 TLC cases, 443 runtime entries,
  and 702 unittest methods.

## 2026-10-02 — Radical-Pilot serialization failure bridge

- Added `ParslRadicalSerializationFailure`, separating the Current path that leaks non-`TypeError`
  serializer exceptions from a Fixed path that normalizes them at the executor boundary.
- The installed Radical-Pilot executor probe patches `pack_apply_message` to raise `ValueError`;
  Current propagates the raw exception and the Fixed model passes `FailureNormalization`.
- Focused runtime coverage passes; the current baseline is 673 TLC cases, 443 runtime entries,
  and 701 unittest methods. Recorded as BUG-319 in the executor ledger.

## 2026-10-02 — Azure duplicate cancellation bridge

- Added `ParslAzureCancelDuplicates`, modeling remote deletion and local instance bookkeeping
  when the same VM ID appears twice in one cancellation request.
- The current branch returns a partial result after both remote deletions succeed because the
  second local removal raises; the fixed branch makes duplicate cleanup idempotent. TLC produces
  the intended `RemoteSuccessSafety` counterexample for Current and passes Fixed.
- The runtime Azure provider probe reproduces `[True, False]` for the duplicate request. The
  current baseline is 672 TLC cases, 443 runtime entries, and 700 unittest methods. Recorded as
  BUG-318 in the provider ledger.

## 2026-10-02 — strategy parallelism range admission bridge

- Added `ParslStrategyParallelismRangeAdmission` for the documented upper bound on the
  parallelism ratio. The current branch accepts `parallelism=2.0`; with one active slot and
  queued work it requests all remaining capacity, while the fixed branch rejects the value.
- TLC fixed configuration passes and the current configuration reproduces the
  `AdmissionRangeSafety` counterexample. The real strategy runtime probe confirms the
  `[0, 3]` scale-out sequence (initialization plus provider-maximum demand).
- Focused strategy coverage passes 8/8 tests; the current baseline is 671 TLC cases, 443 runtime
  entries, and 699 unittest methods. Recorded as BUG-317 in the executor ledger.

## 2026-10-02 — monitoring priority TASK/STATUS/TRY atomicity bridge

- Added `ParslMonitoringPriorityStatusAtomicity`, modeling the priority path's separate TASK,
  STATUS, and TRY commits when a STATUS write fails.
- The current configuration reproduces a cross-table consistency violation: TASK and TRY metadata
  remain committed without the corresponding STATUS row. The fixed configuration rolls back the
  logical batch and passes TLC.
- The runtime bridge reproduces the same ordering against the installed `DatabaseManager`; focused
  coverage passes. The current baseline is 670 TLC cases, 443 runtime entries, and 698 unittest
  methods. Recorded as BUG-316 in the monitoring ledger.

## 2026-10-02 — negative strategy parallelism admission bridge

- Added `ParslStrategyParallelismAdmission`, separating the current behavior that accepts a
  negative provider parallelism ratio from a fixed admission path that rejects it before polling.
- TLC fixed configuration passes; the current configuration reproduces the `AdmissionSafety`
  counterexample. The runtime probe confirms that one active block plus queued work performs only
  the initial zero-block call when `parallelism=-1.0`, silently skipping overload scale-out.
- Focused strategy coverage passes 7/7 tests; the current baseline is 669 TLC cases, 443 runtime
  entries, and 697 unittest methods. Recorded as BUG-315 in the executor ledger.

## 2026-10-02 — concurrent join failure aggregation bridge

- Extended `test_join_callback_runtime.py` with simultaneous success and
  failure callbacks for a list-valued join.
- The real `DataFlowKernel` callback lock emits exactly one terminal
  `JoinError`, containing only the failed dependency, and never publishes an
  incorrect success result.
- Focused runtime coverage passes 7/7 tests; the current baseline is 668 TLC
  cases, 443 runtime entries, and 696 unittest methods.

## 2026-10-02 — no-slot strategy admission bridge

- Extended `test_strategy_runtime.py` with the strategy's explicit no-slot
  path: queued tasks with zero active blocks request one block.
- This exercises the concrete `Case 4a` branch and confirms it remains within
  the configured capacity boundary.
- Focused runtime coverage passes 6/6 tests; the current baseline is 668 TLC
  cases, 443 runtime entries, and 695 unittest methods.

## 2026-10-02 — strategy scale-out capacity bridge

- Extended `test_strategy_runtime.py` with a large-backlog case against the
  real `Strategy._general_strategy` path.
- The strategy requests only the remaining capacity up to `max_blocks`,
  preserving the `ParslStrategy` `CapacitySafety` invariant even when task
  pressure is much larger than available blocks.
- Focused runtime coverage passes 5/5 tests; the current baseline is 668 TLC
  cases, 443 runtime entries, and 694 unittest methods.

## 2026-10-02 — partial scale-out status isolation bridge

- Extended `test_scale_out_failure_monitoring_runtime.py` to poll after a
  mixed scale-out result using the real `BlockProviderExecutor.status()` path.
- The successful block remains provider-owned and PENDING, while the failed
  block remains a simulated FAILED status and is excluded from provider
  status requests and block/job maps.
- Focused runtime coverage passes 3/3 tests; the current baseline is 668 TLC
  cases, 443 runtime entries, and 693 unittest methods.

## 2026-10-02 — heartbeat expiry and late-message bridge

- Extended `test_heartbeat_result_attempt_runtime.py` to feed a real late
  heartbeat through `Interchange.process_manager_socket_message` after the
  manager was expired.
- The expired manager remains absent, no heartbeat acknowledgement is sent,
  and the persisted `lost` status remains the terminal observation while the
  old result is filtered from retry attempt 1.
- Focused runtime coverage passes 3/3 tests; the current baseline is 668 TLC
  cases, 443 runtime entries, and 692 unittest methods.

## 2026-10-02 — verified byte publication and DataFuture readiness

- Extended `test_file_bytes_transfer_runtime.py` with a real `DataFuture`
  readiness edge after archive bytes have been published and verified.
- The consumer callback remains blocked before the transfer Future resolves,
  then reads the exact binary payload after publication, matching the
  `ParslFileBytesAttemptGate` dependency/content safety boundary.
- Focused runtime coverage passes 3/3 tests; the current baseline is 668 TLC
  cases, 443 runtime entries, and 692 unittest methods.

## 2026-10-02 — ZMQ result-attempt transport bridge

- Extended `test_zmq_result_attempt_runtime.py` with a real in-process ZMQ
  multipart delivery of serialized `TaskResult` envelopes.
- The bridge filters a late attempt-0 result and a duplicate attempt-1 frame
  after transport, while decoding the current attempt exactly once.
- Focused runtime coverage passes 3/3 tests; the current baseline is 668 TLC
  cases, 443 runtime entries, and 691 unittest methods.

## 2026-10-02 — callback/monitoring terminal-publication model

- Added `ParslJoinCallbackMonitoring.tla` with Current/Fixed configurations.
- The model composes duplicate inner-Future callbacks, terminal outer state,
  Future resolution, and monitoring-row publication. Fixed TLC rejects a
  second terminal row while Current produces the intended counterexample.
- Extended the real callback runtime bridge to write SQLite `STATUS` rows;
  concurrent duplicate callbacks publish exactly one terminal row.
- Fixed TLC and focused runtime coverage pass; the current baseline is 668 TLC
  cases, 443 runtime entries, and 690 unittest methods.

## 2026-10-02 — concurrent `join_app` callback bridge

- Extended `test_join_callback_runtime.py` with two simultaneous duplicate
  callbacks against a real `DataFlowKernel.handle_join_update` record.
- The probe verifies that the `join_lock` serializes terminal completion:
  ordered results are published once and the second callback is harmless,
  matching `ParslJoinCallbackRace`'s lock and terminal-state invariants.
- Focused runtime coverage passes 5/5 tests.

## 2026-10-02 — provider scale-in to logical retry bridge

- Extended `test_htex_force_scale_in_runtime.py` to connect a real HTEX
  `scale_in` cancellation with heartbeat-driven `ManagerLost` resolution.
- The probe keeps the logical retry generation separate from the withdrawn
  physical attempt, matching `ParslProviderTaskScaleRetry`'s admission and
  retry invariants.
- The focused runtime file passes 3/3 tests; the Fixed provider scale/retry
  abstraction remains covered by the foundational TLC suite.

## 2026-10-02 — bounded monitoring queue-fairness abstraction

- Added `ParslMonitoringQueueFairness.tla` with Current/Fixed configurations.
- The model captures the per-queue `batching_threshold` bound in
  `DatabaseManager._get_messages_in_batch` and checks lower-priority admission
  under a continuously replenished priority stream.
- Added `test_monitoring_queue_fairness_runtime.py` to verify the helper's
  threshold behavior against the checked-out Parsl source.
- Added the probe to the foundational runtime runner; the current baseline is
  662 TLC cases, 435 runtime entries, and 676 unittest methods.

## 2026-10-02 — stage-out failure gate

- Added `ParslStageOutFailureGate.tla` with Current/Fixed configurations.
- The model separates a failed logical application Future from an independent
  physical stage-out transfer and forbids successful output publication after
  application failure in the Fixed branch.
- Added a Globus staging runtime bridge that verifies the provider receives the
  failed application Future as its stage-out dependency.
- Full regression after this addition: 663 TLC cases, 436 runtime entries, and
  677 unittest methods passed.

## 2026-10-02 — composed join immediate-callback/list-mutation model

- Added `ParslJoinImmediateMutation.tla` with Current/Fixed configurations.
- The model combines an already-completed inner Future's synchronous callback
  with mutation of the returned join list before the remaining callback.
- Added a runtime bridge for the same ordering through
  `DataFlowKernel.handle_join_update`.
- Full regression after this addition: 664 TLC cases, 437 runtime entries, and
  678 unittest methods passed.

## 2026-10-02 — staging predicate-failure isolation

- Added `ParslStagingPredicateFailure.tla` with Current/Fixed configurations.
- The model and runtime bridge cover ordered `DataManager` provider selection
  when an earlier `can_stage_*` predicate raises before a later provider can
  accept the file.
- Recorded the source-level risk as BUG-312 in the categorized and flat bug
  ledgers.
- Full regression after this addition: 665 TLC cases, 438 runtime entries, and
  679 unittest methods passed.
- The BUG-312 runtime bridge now covers both `stage_in` and `stage_out`; the
  repository-wide unittest count is 680.

## 2026-10-02 — composed DataFuture stage-out failure gate

- Added `ParslDataReadyStageOutFailure.tla` with Current/Fixed configurations.
- The model combines bounded file chunks, independent stage-out completion,
  DataFuture readiness, application failure, and downstream consumer admission.
- Added a real `DataManager`/`DataFuture` runtime bridge for the two-chunk path.
- Full regression after this addition: 666 TLC cases, 439 runtime entries, and
  681 unittest methods passed.

## 2026-10-02 — executor bad-state admission race

- Added `ParslBadStateSubmitRace.tla` with Current/Fixed configurations.
- The model isolates the interleaving between HTEX task admission and
  `set_bad_state_and_fail_all`; the runtime probe forces a submit after the
  failure sweep has already inspected the task registry.
- Recorded the source-level risk as BUG-313.
- Full regression after this addition: 667 TLC cases, 440 runtime entries, and
  682 unittest methods passed.

## 2026-10-02 — join/ZMQ/retry runtime bridge

- Added `test_join_zmq_retry_runtime.py` for submit-time object snapshots and
  `(logical task, physical attempt)` result correlation across retry.
- The bridge exercises the existing `ParslJoinZMQRetry` Fixed abstraction against
  the real Parsl serializer: a late old result and a duplicate current result do
  not resolve the join dependency twice.
- Full regression after this addition: 667 TLC cases, 441 runtime entries, and
  684 unittest methods passed.

## 2026-10-02 — versioned multi-output stage-out runtime bridge

- Extended `test_multi_output_stageout_runtime.py` with two real rsync-wrapper
  calls whose source files change between transfers.
- The probe reproduces the existing BUG-025 boundary: independent outputs can
  publish different source versions, while `ParslMultiOutputVersionedStageOut`
  Fixed requires one complete version-matched set.
- Full regression after this addition: 667 TLC cases, 441 runtime entries, and
  685 unittest methods passed.

## 2026-10-02 — monitoring status high-water runtime bridge

- Extended `test_result_monitoring_attempt_runtime.py` with a late older-attempt
  status arriving after a newer terminal row in the real SQLite `STATUS` table.
- The bridge confirms append-only history plus current `try_id` selection, matching
  the `ParslMonitoringVersionedBatch` high-water invariant.
- Full unittest regression after this addition: 687 tests passed.

## 2026-10-02 — callable and argument snapshot consistency

- Extended `test_function_object_contents_runtime.py` so one packed apply
  message carries a callable closure and a keyword object snapshot together.
- After mutating the submitter-side object, the decoded function and keyword
  argument still use the submit-time content required by the TLA+ abstraction.
- Full unittest regression after this addition: 687 tests passed.

## 2026-10-02 — multipart frame validation ordering

- Added BUG-314 for `unpack_and_deserialize` invoking an extra buffer
  deserializer before checking the required three-buffer count.
- Extended `test_zmq_multipart_ack_runtime.py` with a side-effect/exception
  probe for the malformed fourth frame; the Current behavior escapes before
  the framing error, while the existing Fixed TLA+ branch rejects it first.
- Full unittest regression after this addition: 688 tests passed.

## 2026-10-02 — provider/executor/monitoring timed composition

- Added `test_provider_executor_timed_monitoring_runtime.py` as a concrete
  bridge for provider loss, logical retry generation, Future result filtering,
  and SQLite `STATUS` persistence.
- The bridge backs the existing `ParslProviderExecutorTimedMonitoring` Fixed
  abstraction without adding a duplicate single-component model.
- Full regression after this addition: 667 TLC cases, 442 runtime entries, and
  689 unittest methods passed.

## 2026-10-02 — join heartbeat/retry runtime bridge

- Added `test_join_heartbeat_retry_runtime.py` for heartbeat-loss generation
  changes across two inner join dependencies.
- Real `Future` callbacks ignore late attempt-0 values and resolve the outer
  Future only after both current attempt-1 values arrive.
- Full regression after this addition: 667 TLC cases, 443 runtime entries, and
  690 unittest methods passed.

## 2026-10-02 — join monitoring high-water bridge

- Extended `test_join_monitoring_runtime.py` to select the current terminal
  status by highest inner `try_id` after a delayed old-generation row.
- This connects real `join_app` retry execution to the `ParslJoinMonitoringDB`
  high-water invariant without discarding append-only monitoring history.

## 2026-10-02 — heartbeat loss and monitoring persistence bridge

- Extended `test_heartbeat_result_attempt_runtime.py` to persist a real HTEX
  manager-loss status and reject a late result from the expired attempt.
- This ties `Interchange.expire_bad_managers`, retry attempt generation, and
  SQLite terminal status persistence to `ParslHeartbeatTimeoutPersistence`.
- Full unittest regression after this addition: 691 tests passed.

## 2026-10-02 — join cross-layer runtime bridge

The bounded `ParslJoinStageRetry` model remains in the foundational TLC gate and combines
per-dependency staging, physical-attempt retry, stale-result rejection, and outer-join gating.
The Fixed configuration is covered by the full 658-case TLC smoke run; the Current configuration
still produces the intended unsafe-publication and stale-result counterexamples.  With the
repository Parsl environment (`/tmp/parsl-venv`), the concrete join bridges
`test_nested_join_retry_runtime`, `test_join_stageout_cancellation_runtime`,
`test_join_retry_runtime`, `test_outer_join_cancellation_runtime`, and
`test_join_monitoring_runtime` all pass (5/5).  This confirms that the small model's combined
boundary is backed by executable Parsl behavior rather than TLC-only traces.

The complete foundational Python smoke command was then rerun with
`PYTHONPATH=/tmp/parsl-source:/home/cc/tla-parsl` and completed with all 434/434 entries passing.
This includes the serialization/ZMQ, callable-object, file-transfer, clock/heartbeat, monitoring,
executor/provider, and join runtime bridges in the current inventory.

The next cross-layer model is `ParslStageOutExecutorRetry`.  It separates executor result
delivery from asynchronous stage-out while a logical task retries.  The Current configuration
reproduces stale-result admission in 31 simulated states; the Fixed configuration passed one
million simulated states.  The Fixed case is now part of the foundational TLC gate.

The HTEX heartbeat/manager-loss audit was then rerun against the installed implementation.  The
runtime bridges for heartbeat/result attempt correlation, heartbeat expiry, manager loss, wall-clock
jumps, worker-pool heartbeat handling, and retry timeout all passed (15 unittest methods).  These
tests correspond to the existing `ParslHeartbeatResultAttempt`, `ParslHtexLivenessAttempt`, and
`ParslJoinTimedMonitoring` abstractions; no duplicate model was added.

The ThreadPoolExecutor audit added `ParslThreadExecutorShutdownMode`, separating executor-return
from worker termination for `shutdown(wait=False)`. Current TLC reaches `RunningWorkerSafety` in
293 states; Fixed passes 100,001 simulated states. The corresponding nonblocking-shutdown,
Future-lifecycle, and executor runtime probes pass 5/5, and the Fixed case is in the foundational
TLC gate. The resulting full foundational smoke run passed 659/659 TLC cases.

The `ParslPoolExecutor.map` audit then composed timeout with advisory shutdown.  Current TLC
reaches the cancellation invariant in 17 states; Fixed passes 100,001 simulated states.  The
combined timeout/shutdown runtime probe passes, and its Fixed configuration is now in the
foundational TLC gate. The updated full foundational smoke run passed 660/660 TLC cases.

The Kubernetes provider audit then re-read `submit`, `_status`, and `cancel`.  Its in-flight
cancel/poll race is already represented by `ParslKubernetesLifecycle` and BUG-282, so no duplicate
model was added.  The complete Kubernetes runtime subset (submit, polling, unknown jobs, cancel
response, stale cancellation, and cancel/poll race) passed 11/11 tests.

The Radical-Pilot executor audit then re-read task translation, callback dispatch, bulk collection,
failure fan-out, and shutdown.  Existing models cover the unknown-callback, late-callback,
failure-payload, decode-failure, master-admission, and bulk-shutdown boundaries; the complete
Radical-Pilot runtime subset passed 14/14 tests without requiring another model.

The `join_app` source audit then followed `handle_exec_update` and `handle_join_update` through
single-Future, empty-list, ordered-list, duplicate-Future, nested, retry, cancellation, and
failure-aggregation paths.  The existing model set covers these branches; the complete join-focused
runtime discovery passed 40/40 tests, so no duplicate join model was added in this pass.

The serialization/ZMQ audit then exercised the real facade registry, dynamic deserializer plugins,
fallback and header paths, frame length/arity validation, decode failures, ACK/result correlation,
and callable-object caches.  The serialization-focused subset passed 29/29 tests, the ZMQ subset
passed 10/10, and the callable-object subset passed 10/10; all corresponding boundaries already
have Current/Fixed models, so no duplicate model was added.

The file-content and staging audit then ran all 48 focused runtime probe files covering DataManager
ordering and DataFuture readiness, checksum/versioned bytes, FTP/HTTP/Rsync/Zip/Globus transfers,
partial cleanup, path validation, multi-output publication, and provider-backed staging.  Every
file passed; existing staging models remain the authoritative Current/Fixed abstractions.

The provider-focused audit then ran the complete scheduler/provider runtime selection (112 probe
files across AWS, Azure, Condor, Grid Engine, Kubernetes, Local, LSF, PBS Pro, Slurm, Torque,
Globus Compute, and shared provider logic).  All 112 files passed; no new provider behavior fell
outside the existing Current/Fixed model inventory.

The executor-focused audit then ran 112 runtime probe files across HTEX, MPI, ThreadPool,
PoolExecutor, Work Queue, TaskVine, Flux, Radical-Pilot, Globus Compute, poller lifecycle, and
shared executor paths.  All 112 files passed, including worker/result continuation, shutdown,
retry, cancellation, scaling, and resource-admission probes.

The time/heartbeat audit then ran all 34 focused runtime probe files covering wall-clock rollback,
monotonic deadlines, heartbeat/result generations, worker contact and drain, command/file/Future
timeouts, timer close/reentrancy/interval validation, provider polling clocks, and monitoring clock
paths.  All 34 files passed with no new nondeterministic failure.

The new `ParslProviderStageOutMonitoring` composition connects provider loss/reprovisioning to
stage-out publication and terminal monitoring.  Current TLC reaches `StaleSafety` in 181 states;
Fixed passes 100,001 simulated states.  The Fixed configuration is now in the foundational TLC
gate, extending the separate provider-retry, stage-out, and monitoring models across one boundary.
The updated foundational TLC smoke run passed 661/661 cases.

After this composition was added, the complete foundational Python runtime smoke was rerun from
the installed Parsl environment and passed 434/434 entries.  This confirms that the added provider,
stage-out, monitoring, and retry abstractions did not regress the concrete runtime bridges.

The callable/memoization audit then followed `id_for_memo`, memoized Future completion, checkpoint
loads, closure/function identity, ignored cache keys, and join-result memoization.  The focused
memoization plus base join probes passed 18/18 tests; `ParslJoinMemoData` and the integrated core
model already cover the memoized-inner/data-ready combination.

The complete repository test discovery initially found one order-dependent clock probe failure in
`test_htex_worker_drain_clock_runtime`: it patched the process-wide `time.time` object while other
tests were active.  The probe now injects a clock object only into `process_worker_pool`; the full
repository suite then passed 675/675 unittest methods.  The underlying wall-clock behavior remains
tracked as BUG-256 with its existing Current/Fixed model.

The monitoring runtime audit initially exposed an order-dependent probe failure: the ZMQ batch-clock
test patched the process-wide `time.time` object while other monitoring threads were still active.
The probe now injects a clock object only into `MonitoringRouter` and runs its bounded fake router
synchronously.  The complete monitoring subset then passed 55/55 tests, preserving BUG-247 as the
source-level wall-clock finding without treating test interference as a new Parsl defect.

## 2026-09-30

### Post-v0.1 extension: file bytes and logical-attempt gate

The first post-v0.1 model extension is `ParslFileBytesAttemptGate`. It combines concrete symbolic
file chunks and checksums with logical task retry identity. The Current branch allows a completed
physical transfer from an earlier attempt to publish the new DataFuture; the Fixed branch rejects
the stale attempt and source version, then restarts stage-in. TLC reproduced the Current
`PublicationSafety` counterexample with seed 1 and passed the Fixed branch with five million
simulated states. The fixed configuration is now part of the foundational smoke gate.

The foundational inventory after this extension is 638 TLC cases and 434 Python runtime probes;
the v0.1 acceptance baseline remains frozen at 637/434, while this model is tracked as the first
post-v0.1 refinement.

### Post-v0.1 extension: HTEX liveness, clock, and retry composition

`ParslHtexLivenessAttempt` composes continuous result traffic, heartbeat expiry, wall-clock
rollback, retry-attempt result filtering, and worker drain deadlines. The Current branch
reproduces a `DrainDeadlineSafety` counterexample; the Fixed branch uses monotonic elapsed time,
expires the manager on the communication path, and rejects old results. Targeted TLC passed the
Current/Fixed distinction, with the Fixed branch passing five million simulated states. The fixed
configuration is now part of the foundational smoke gate.

The post-v0.1 foundational inventory is now 639 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: monitoring result and shutdown composition

`ParslMonitoringResultShutdown` composes logical retry result filtering with the
`DatabaseManager` shutdown queue. The Current branch can stop with a queued result still present;
the Fixed branch requires the queue to drain before stopping and ignores results from an old
attempt. Targeted TLC reproduced the Current `ShutdownDrainSafety` counterexample and passed the
Fixed branch with five million simulated states. The fixed configuration is now part of the
foundational smoke gate.

The post-v0.1 foundational inventory is now 640 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Slurm provider lifecycle

`ParslSlurmLifecycle` composes valid submission, scheduler status parsing, and cancellation. It
keeps foreign/malformed/duplicate records separate from the local resource and models a stale
cancellation ID after a known job. The Current branch reaches `NoAbort`; the Fixed branch passes
five million simulated states. The fixed configuration is now part of the foundational smoke
gate.

The post-v0.1 foundational inventory is now 641 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Google Cloud provider lifecycle

`ParslGoogleCloudLifecycle` composes instance submission, per-VM status failure isolation, healthy
VM observation, and cancellation. The Current branch reaches `StatusBatchSafety` when one remote
lookup fails; the Fixed branch records an unknown observation and passes five million simulated
states. The fixed configuration is now part of the foundational smoke gate.

The post-v0.1 foundational inventory is now 642 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Azure provider lifecycle

`ParslAzureLifecycle` composes VM provisioning, status ordering, and post-delete bookkeeping. The
Current branch reaches `FailureCleanupSafety` on a partial setup failure; the Fixed branch rolls
back the VM/resource records and passes five million simulated states, including the swapped-status
and cancellation paths. The fixed configuration is now part of the foundational smoke gate.

The post-v0.1 foundational inventory is now 643 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Condor provider lifecycle

`ParslCondorLifecycle` composes submit admission, `condor_q` command failure and malformed/
foreign records, and cancellation. The Current branch reaches `NoAbort`; the Fixed branch keeps
the pending/running resource state and passes five million simulated states. The fixed
configuration is now part of the foundational smoke gate.

The post-v0.1 foundational inventory is now 644 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: AWS provider lifecycle composition

`ParslAwsLifecycle` composes AWS instance submission, incomplete status responses, stale local
records, and cancellation. The Current branch reaches `NoAbort` when a provider response is
missing or a remote termination arrives after local bookkeeping has been removed; the Fixed
branch records an `unknown` observation and makes termination idempotent, passing five million
simulated states. The fixed configuration is now part of the foundational smoke gate.

The post-v0.1 foundational inventory is now 645 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Local provider lifecycle composition

`ParslLocalLifecycle` composes local submission, process/exit-marker status, stale local
bookkeeping, and cancellation. The Current branch reaches `NoAbort` when cancellation sees a
missing local resource record; the Fixed branch makes the stale cancellation terminal and
idempotent. The model is now in the foundational smoke gate, with the existing concrete local
provider runtime suite covering process launch, output, exit markers, and cancellation.

The post-v0.1 foundational inventory is now 646 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: PBS Pro provider lifecycle composition

`ParslPBSProLifecycle` composes qsub admission, qstat status interpretation, local resource
ownership, and cancellation. The Current branch reaches `NoAbort` through empty successful
submission output, foreign/malformed status records, or stale cancellation; the Fixed branch
rejects the empty submission, preserves nonterminal state for missing observations, isolates bad
records, and passes five million simulated states. Existing PBS Pro runtime probes cover the
concrete parser behavior.

The post-v0.1 foundational inventory is now 647 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Torque provider lifecycle composition

`ParslTorqueLifecycle` composes qsub submission, qstat observations, local resource ownership,
and qdel cancellation. The Current branch reaches the safety counterexamples for missing status,
foreign/malformed rows, and cancellation-state misclassification; the Fixed branch requires
explicit terminal evidence, isolates invalid rows, and passes five million simulated states.
Existing Torque runtime probes cover the concrete parser and cancellation behavior.

The post-v0.1 foundational inventory is now 648 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: LSF provider lifecycle composition

`ParslLSFLifecycle` composes bsub admission, bjobs observations, local resource ownership, and
bkill cancellation. The Current branch reaches safety counterexamples for missing jobs,
duplicate/foreign/malformed records, and stale cancellation; the Fixed branch requires explicit
terminal evidence, isolates invalid rows, and passes five million simulated states. Existing LSF
runtime probes cover the concrete parser and cancellation behavior.

The post-v0.1 foundational inventory is now 649 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Grid Engine provider lifecycle composition

`ParslGridEngineLifecycle` composes qsub admission, qstat observations, local resource ownership,
and qdel cancellation. The Current branch reaches safety counterexamples for missing jobs,
malformed/duplicate/foreign rows, and stale cancellation; the Fixed branch requires explicit
terminal evidence, isolates invalid rows, and passes five million simulated states. Existing Grid
Engine runtime probes cover the concrete parser and cancellation behavior.

The post-v0.1 foundational inventory is now 650 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Work Queue executor lifecycle composition

`ParslWorkQueueLifecycle` composes task admission, result collection, duplicate/late reports,
and shutdown finalization. The Current branch reaches `StaleDoesNotKillPeer` when a duplicate
report exits the collector and later cleanup fails an unrelated pending Future; the Fixed branch
ignores stale reports and passes five million simulated states while requiring terminal shutdown.
Existing Work Queue runtime probes cover the concrete executor boundaries.

The post-v0.1 foundational inventory is now 651 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: TaskVine executor lifecycle composition

`ParslTaskVineLifecycle` composes manager admission, result collection, duplicate/late reports,
manager failure, and shutdown finalization. The Current branch reaches `StaleDoesNotKillPeer`
when a duplicate report stops collection and leaves an unrelated pending task; the Fixed branch
ignores stale reports and passes five million simulated states with terminal shutdown guarantees.
Existing TaskVine runtime probes cover the concrete executor boundaries.

The post-v0.1 foundational inventory is now 652 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Flux executor lifecycle composition

`ParslFluxLifecycle` composes Flux submission, underlying job failure/success, callback result
decoding, cancellation, late/duplicate callbacks, and shutdown draining. The Current branch
reaches `StaleDoesNotKillPeer` when a stale callback stops collection and leaves an unrelated task
pending; the Fixed branch ignores stale callbacks and passes five million simulated states with
terminal shutdown guarantees. Existing Flux runtime probes cover the concrete executor paths.

The post-v0.1 foundational inventory is now 653 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Radical Pilot executor lifecycle composition

`ParslRadicalPilotLifecycle` composes RP task submission, DONE/FAILED/CANCELED callback mapping,
late callbacks, master failure fan-out, and bulk shutdown. The Current branch reaches the stale
callback/peer-pending safety counterexample; the Fixed branch ignores stale callbacks, fails
outstanding tasks during shutdown, and passes five million simulated states. Existing Radical
Pilot runtime probes cover the concrete callback and shutdown paths.

The post-v0.1 foundational inventory is now 654 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: HTEX executor lifecycle composition

`ParslHtexLifecycle` composes HTEX task admission, worker execution, retry-attempt generation,
late-result filtering, manager/worker failure, and shutdown. It separates logical attempts from
physical result attempts; the Current branch reaches the stale-result safety counterexample,
while the Fixed branch drops stale traffic and passes five million simulated states. Existing
HTEX runtime probes cover the concrete transport, worker, retry, and shutdown boundaries.

The post-v0.1 foundational inventory is now 655 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: Globus Compute executor lifecycle composition

`ParslGlobusComputeLifecycle` composes SDK submission, result propagation, submit/restore error
ordering, and shutdown watcher cleanup. The Current branch reaches the primary-error masking and
watcher-leak counterexamples; the Fixed branch preserves the submit error, stops the watcher, and
passes five million simulated states. Existing Globus Compute runtime probes cover the concrete
submit, result, and shutdown paths.

The post-v0.1 foundational inventory is now 656 TLC cases and 434 Python runtime probes.

### Post-v0.1 extension: MPI executor lifecycle composition

`ParslMPILifecycle` composes MPI resource validation, node allocation, launch, result decoding,
optional task-to-node mapping, cancellation, and shutdown. The Current branch reaches the invalid
resource, decode-leak, and unmapped-result safety counterexamples; the Fixed branch rejects bad
resources, releases nodes on decode failure, and passes five million simulated states. Existing
MPI runtime probes cover the concrete scheduler boundaries.

The post-v0.1 foundational inventory is now 657 TLC cases and 434 Python runtime probes.

The post-v0.1 foundational inventory is now 641 TLC cases and 434 Python runtime probes.

### Current repository state

- Latest locally preserved commit: `f50a060` (`Model file bytes across logical retry attempts`).
- Foundational smoke inventory before the current liveness extension: 638 TLC cases and 434 Python runtime probes.
- The smoke inventory has been expanded across core dataflow, Futures, retries, stale results,
  ZMQ/serialization, callable snapshots, file bytes and staging, clocks/heartbeats/timeouts,
  monitoring persistence, executors, providers, schedulers, scaling, memoization, and `join_app`.
- The bug ledger records source/runtime findings separately from candidate fixed semantics. Current
  and fixed configurations are intentionally kept where a TLC counterexample documents the source
  behavior.
- Full Python runtime smoke was rerun after the HTEX worker poll-priority bridge: all 415/415 probes passed.

### Bounded v0.1 target (scope frozen; final acceptance gate)

The first deliverable is a bounded validation package, not a complete executable model of every
Parsl backend. It is complete when all of the following are true:

- the existing 637 TLC cases and 434 Python probes pass as a regression gate;
- the models cover the paper-level behaviors of logical tasks, physical attempts, dependency/Future
  propagation, executor/worker execution, retry and failure, timeout/stale results, provider
  provisioning and scale-in/out, memoization, staging/data readiness, monitoring, and `join_app`;
- each source-aligned risk in the bug ledger has a source location, a runtime reproduction when
  feasible, and a Current/Fixed TLA+ configuration or an explicit reason why modeling is not yet
  feasible;
- the final report documents the component mapping, counterexamples, limitations, and exact
  reproduction commands.

This acceptance gate is now met. The v0.1 scope is frozen at 637 TLC cases, 434 Python probes,
and 673 discovered unittest methods. Additional executors, providers, or implementation details
are a separately tracked backlog and must not extend the completion criteria for this deliverable.

### Close-out work only

The remaining work is documentation and handoff, not model expansion:

- keep the two regression commands reproducible;
- finish the v0.1 report and coverage/bug-ledger cross-links;
- record known limitations and the DNS-blocked GitHub push status;
- prepare a post-v0.1 backlog without adding items to the acceptance gate.

### Latest completed stages

- Current stage: audited Radical-Pilot master-count admission with
  `ParslRadicalMasterCountAdmission`. The Current branch permits `masters=0`, starts with an
  empty selector, and leaks `IndexError` on first selection; the Fixed branch rejects the
  configuration during startup. Full smoke verification passed: 637 TLC configurations and 434
  Python runtime probes; 673 unittest methods are present.

- Current stage: audited AWS teardown state-file cleanup with
  `ParslAwsTeardownStateCleanup`. The Current branch leaks `FileNotFoundError` when the state
  file is already absent after resource deletion; the Fixed branch treats that condition as
  idempotent cleanup. Full smoke verification passed: 636 TLC configurations and 433 Python
  runtime probes; 672 unittest methods are present.

- Current stage: audited Radical-Pilot master admission with
  `ParslRadicalMasterSubmitShape`. The Current branch reproduces raw `IndexError` when
  `submit_raptors` returns an empty collection; the Fixed branch turns the response into an
  explicit startup failure. Full smoke verification passed: 635 TLC configurations and 432
  Python runtime probes; 671 unittest methods are present.

- Current stage: composed deferred worker-first monitoring with TASK/TRY creation and STATUS/TRY
  persistence in `ParslMonitoringTaskTryWorkerLifecycle`. The Current branch reproduces a
  partial cross-table observation when STATUS writing fails during replay; the Fixed branch keeps
  the deferred event pending instead. Full smoke verification passed: 634 TLC configurations and
  431 Python runtime probes; 670 unittest methods are present.

- Current stage: composed logical task retry with physical stage-in transfer generations in
  `ParslStageInAttemptGeneration`. The Current branch allows a transfer from attempt 0 to publish
  readiness after the logical task has retried as attempt 1; the Fixed branch requires the
  transfer generation to match the current logical attempt. Targeted TLC checks produce the
  Current counterexample and pass the Fixed branch. Full TLC smoke verification passed: 633
  configurations; the Python runtime baseline remains 430 probes and 669 unittest methods.

- Current stage: modeled AWS provider state-file publication with
  `ParslAwsStateFileAtomicity`. The Current branch writes directly to the final JSON path, so an
  interrupted write can corrupt the only saved state and cause infrastructure recreation on
  restart. The Fixed branch publishes through a temporary file and preserves the last valid
  state. Targeted TLC and runtime checks pass; the full smoke checkpoint is pending.

- Current stage: modeled AWS provider state-file publication with
  `ParslAwsStateFileAtomicity`. The Current branch writes directly to the final JSON path, so an
  interrupted write can corrupt the only saved state and cause infrastructure recreation on
  restart. The Fixed branch publishes through a temporary file and preserves the last valid
  state. Full smoke verification passed: 632 TLC cases and 430 Python runtime probes; 669
  unittest methods are present.

- Previous stage: audited Globus Compute submit cleanup with
  `ParslGlobusComputeRestoreFailure`. The Current branch lets a restoration error mask the SDK
  submit exception; the Fixed branch preserves the primary error and terminalizes cleanup. Full
  smoke verification passed: 631 TLC cases and 429 Python runtime probes; 668 unittest methods
  are present.

- Current stage: refined Python callable contents with separate global/default roots in
  `ParslFunctionGlobalDefaultSnapshot`. The Current branch reproduces a live module-global read
  after serialization while retaining the default snapshot; the Fixed branch requires one epoch.
  Full smoke verification passed: 630 TLC cases and 428 Python runtime probes; 667 unittest
  methods are present.

- Current stage: composed retry-result filtering with monitoring persistence in
  `ParslResultMonitoringAttempt`. The Fixed branch records only the current attempt as terminal
  `succeeded`; a late old-attempt result becomes stale and does not resolve the Future or database
  record. Full smoke verification passed: 629 TLC cases and 427 Python runtime probes; 666
  unittest methods are present.

- Current stage: composed heartbeat expiry with retry-generation result delivery in
  `ParslHeartbeatResultAttempt`. The Fixed branch ignores late heartbeats from expired managers,
  rejects old-attempt results, and keeps malformed/current result handling terminal. Full smoke
  verification passed: 628 TLC cases and 426 Python runtime probes; 665 unittest methods are
  present.

- Current stage: composed result delivery with physical-attempt generations in
  `ParslZMQResultAttempt`. The Fixed branch rejects malformed result payloads, ignores old
  attempts, and consumes duplicate current results once. Full smoke verification passed: 627 TLC
  cases and 425 Python runtime probes; 663 unittest methods are present.

- Current stage: composed serialized callable/object snapshots with ZMQ-style ACK-loss
  retransmission in `ParslZMQSerializedAck`. The Current branch dispatches the duplicate envelope
  twice; the Fixed branch deduplicates by task/attempt identity. Full smoke verification passed:
  623 TLC cases and 423 Python runtime probes; 659 unittest methods are present.

- Current stage: composed Flux physical-future completion, serialized result-file publication,
  user-facing wrapper cancellation, and late callback delivery in
  `ParslFluxResultFileCancellation`. The fixed TLC branch discards the stale callback while the
  runtime bridge reproduces the current `InvalidStateError` behavior already tracked as BUG-185.
  Full regression: 622 TLC cases and 422 Python runtime probes passed; 658 unittest methods are
  present.

- Current stage: added the concrete `join_app`/stage-out cancellation runtime bridge. The probe
  uses the real `DataManager` and `DataFuture` contract to show that an independent transfer can
  publish after application cancellation, matching the Current branch of
  `ParslJoinStageOutCancellation`.

- Current stage: refined `ParslJoinStageOutCancellation` with an explicit `BOUND_TO_APP` provider
  parameter. The bound-provider TLC case now verifies cancellation safety for Globus/Zip-style
  dependency wiring, while the independent-provider Current counterexample remains visible.

- Current stage: added the Zip provider bridge. The real `ZipFileStaging.stage_out` implementation
  passes the application Future as `parent_fut`, corroborating the bound-provider branch with a
  focused runtime probe.

- Current stage: added `ParslHtexWorkerPollPriority`, exposing the task-first branch of the worker
  communicator when task and result sockets are simultaneously readable. The fixed branch gives a
  ready result bounded service priority, with a deterministic fake-ZMQ runtime reproduction. The
  Current simulation reaches its 27-state counterexample, while the Fixed case passes.

- Current stage: audited monitoring database queue ordering against `DatabaseManager.start`.
  Priority messages are batch-bounded and the loop proceeds to worker/resource queues, so no new
  unbounded starvation model was added; shutdown and stale-queue observations remain separately
  modeled risks.

- Current stage: completed the full foundational Python runtime regression after adding the
  duplicate-cancellation join probe. All 412/412 probes pass against the pinned Parsl source;
  the 614-case TLC gate remains green.

- Current stage: added fixed `ParslJoinDuplicateCancellation` to the foundational TLC gate. A
  duplicated logical input now maps to one physical cancellation callback, and cancellation
  terminalizes the outer join instead of escaping as a callback exception.

- Current stage: promoted fixed `ParslCallableAliasRetry` into the foundational TLC gate. A
  callable and its aliased argument preserve shared object identity across retry snapshotting,
  while each retry captures the current source epoch.

- Current stage: promoted fixed/success `ParslStrategyBlockCapacity` configurations into
  the foundational TLC gate. Non-positive nodes-per-block capacity now has an explicit rejected
  path, while valid capacity proceeds to scaling without division failure.

- Current stage: promoted the core `ParslStrategy` model into the foundational TLC gate. The
  strategy now has an executable bounded scale-out/idle-timer/scale-in lifecycle with block
  capacity and minimum/maximum bounds.

- Current stage: promoted fixed `ParslGlobusComputeConfig` into the foundational TLC gate. The
  shared SDK resource specification and endpoint overrides are now modeled as a serialized
  critical section with default restoration after each submit.

- Current stage: promoted fixed and successful `ParslHTTPStage` configurations into the
  foundational TLC gate. In-task HTTP staging now rejects non-success status before app execution
  while preserving the successful response path.

- Current stage: promoted the core `ParslZMQ` state machine into the foundational TLC gate.
  Bounded multipart task/result messages now cover route validation, duplicate suppression,
  corruption rejection, queue delivery, and acknowledgement correlation.

- Current stage: promoted fixed `ParslPythonTimeoutCatch` into the foundational TLC gate. An
  injected walltime timeout cannot be caught and converted into a successful Future result.

- Current stage: promoted CurveZMQ certificate valid/invalid configurations into the foundational
  TLC gate. Secret keys are loaded only from private certificate directories, while invalid
  directory modes are rejected before key publication.

- Current stage: promoted fixed `ParslScaleInCancelShape` into the foundational TLC gate. A
  partial provider cancellation response now preserves the successful cancellation prefix and
  reports partial progress instead of aborting with a raw assertion.

- Current stage: promoted MPI prefix, resource-spec, and task-context configurations into the
  foundational TLC gate. MPI launchers are selected only from supported prefixes, non-positive
  resource specs are rejected before derivation, and malformed task contexts are rejected before
  scheduler admission.

- Current stage: promoted `ParslJobStatusOutputSummary` threshold, large-file, and missing-file
  configurations into the foundational TLC gate. Summary output now distinguishes no output,
  full-at-threshold content, and head/tail truncation.

- Current stage: promoted fixed `ParslJobStatusOutputReadError` into the foundational TLC gate.
  JobStatus output and summary reads now share the same defensive read-error policy instead of
  allowing permission/I/O errors to escape only through summary properties.

- Current stage: promoted HTEX `probe_addresses` timeout, empty-input, and success configurations
  into the foundational TLC gate. Address probing now distinguishes rejected empty input,
  selected responsive endpoints, and timeout failure without falsely selecting an address.

- Current stage: promoted fixed `ParslHtexZeroScaleInIdle` into the foundational TLC gate. A
  zero-count idle-only scale-in request is now an immediate no-op before scanning idle blocks.

- Current stage: promoted HTEX manager-message heartbeat and malformed-message configurations
  into the foundational TLC gate. Valid heartbeats update liveness time and reply; malformed
  messages remain isolated without mutating manager state.

- Current stage: promoted fixed `ParslTimerReentrantClose` into the foundational TLC gate. A
  timer callback can now close its own timer without attempting to join the current thread.

- Current stage: promoted fixed `ParslRetryHandler` zero-cost handling into the foundational TLC
  gate. A failed attempt now consumes at least one retry-budget unit, preventing a zero-cost
  handler from launching another attempt when `retries=0`.

- Current stage: promoted fixed `ParslInputDependencyDuplicate` into the foundational TLC gate.
  The reserved `inputs` dependency is now collected once instead of receiving duplicate callback
  registration through the generic keyword pass and the dedicated inputs pass.

- Current stage: promoted fixed `ParslDataFutureFalseyException` into the foundational TLC gate.
  Exception presence is now modeled independently of exception truthiness, so a falsey user
  exception cannot make a failed DataFuture appear successful.

- Current stage: promoted fixed `ParslDataFutureCancellation` into the foundational TLC gate.
  A cancelled parent Future now propagates terminal failure to the dependent DataFuture instead
  of publishing the represented file as available.

- Current stage: promoted `ParslSerializationSnapshot` into the foundational TLC gate. The
  serializer boundary now explicitly preserves the captured callable/argument version across
  source mutation and decode, while keeping serialization failure terminal.

- Current stage: promoted `ParslTaskTransport` normal and serialization-failure configurations
  into the foundational TLC gate. The cross-layer model requires a valid serialized task before
  dispatch, correlates results to the current attempt, and bounds retry-driven stale results.

- Current stage: promoted fixed `ParslFileTransferMonitoring` into the foundational TLC gate.
  Stage-out now requires all chunks and a version-matching source snapshot before publishing a
  ready DataFuture or persisting terminal monitoring success.

- Current stage: promoted fixed `ParslMonitoringZMQBatchClock` into the foundational TLC gate.
  Monitoring ZMQ receive batches now use a monotonic deadline, so wall-clock rollback cannot
  extend the inner receive loop beyond its one-second budget.

- Current stage: promoted fixed `ParslMonitoringUDPPickleIsolation` into the foundational TLC
  gate. An authenticated malformed pickle is discarded without killing the UDP router, allowing
  the next valid datagram to reach the monitoring queue.

- Current stage: promoted fixed `ParslMonitoringBatchThree` into the foundational TLC gate. A
  three-event monitoring transaction restores its snapshot after a failure on the second write,
  preventing partial rows from becoming visible.

- Current stage: promoted fixed `ParslMonitoringStarterConstructionFailure` into the foundational
  TLC gate. A database-constructor exception now remains the original startup failure instead of
  being masked by an unconditional close on an unbound manager variable.

- Current stage: promoted fixed `ParslFilesystemRadioAtomicity` into the foundational TLC gate.
  Monitoring pickle data is written to a temporary file and atomically renamed into the reader
  directory; write failures leave only a partial temp file and never expose it as a message.

- Current stage: promoted `ParslHeartbeatProvider` into the foundational TLC gate. Provider
  UNKNOWN status is kept distinct from manager heartbeat expiry; provider terminal states revoke
  executor admission and clean up in-flight tasks.

- Current stage: promoted `ParslJoinThreeList` into the foundational TLC gate. Three distinct
  logical inner Futures may complete in any order, while the outer result reconstructs all four
  ordered list positions, including a duplicate reference.

- Current stage: promoted fixed and stable `ParslJoinListMutation` configurations into the
  foundational TLC gate. Join registration now snapshots mutable list membership before callbacks;
  the no-mutation path remains a separate positive baseline, while the Current aliasing case stays
  as a documented counterexample.

- Current stage: promoted `ParslResultRace` into the foundational TLC gate. Physical attempt
  failure, retry, late success, and result delivery are correlated by attempt id; stale results
  cannot resolve the logical Future after a newer attempt is current.

- Current stage: promoted fixed `ParslJoinThreeCancellation` into the foundational TLC gate. A
  cancelled member of a three-Future list now yields terminal outer failure while the callback
  handles `CancelledError` instead of escaping and leaving the join pending.

- Current stage: promoted fixed `ParslJoinRunningCancellation` into the foundational TLC gate.
  Cancellation of an already-running inner Future now resolves the outer join as terminal
  failure, and the callback cannot escape as an unhandled exception.

- Current stage: promoted fixed `ParslJoinRetryDuplicates` into the foundational TLC gate. The
  model preserves every duplicate input position after an inner physical retry while still
  observing one logical Future and one final value.

- Current stage: promoted `ParslJoinRetry` into the foundational TLC gate. Logical inner Futures
  now remain unresolved across non-final physical attempts; the outer join observes only the final
  result or final failure and preserves ordered aggregation.

- Current stage: promoted fixed `ParslProviderExecutorTimedMonitoring` into the foundational TLC
  gate. This cross-component model composes provider provisioning, manager heartbeat expiry,
  task timeout/retry, stale physical results, scale-in admission, and terminal DB persistence.

- Current stage: promoted fixed `ParslMonitoringVersionedBatch` into the foundational TLC gate.
  The model checks transaction rollback after a duplicate event and preserves a per-task version
  high-water mark so a late older status cannot overwrite a newer terminal row.

- Current stage: promoted fixed `ParslMonitoringThreshold` into the foundational TLC gate. The
  model requires a zero-threshold batch to consume an available monitoring event, while the
  Current configuration remains as the documented queued-message counterexample.

- Current stage: promoted the busy and idle `ParslHtexWorkerWatchdog` configurations into the
  foundational TLC gate. The model separates physical worker death from logical task state,
  emits one WorkerLost result for a busy worker, and restarts idle capacity without a task result.

- Current stage: promoted the fixed `ParslHtexHeartbeatVersion` configuration into the
  foundational TLC gate. The combined model rejects task admission after registration or
  heartbeat failure becomes observable, orders one fatal result, and drains outstanding work.

- Current stage: promoted `ParslHeartbeatBoundary` into the foundational TLC gate. The compact
  model checks strict heartbeat expiry, heartbeat reset at the exact threshold, in-flight task
  accounting when a manager expires, and suppression of post-loss heartbeats.

- Current stage: promoted `ParslStagingProviderDispatch` into the foundational TLC gate. The
  model checks first-capable provider selection, terminal `None` staging results, Future-backed
  dependency admission, and explicit failure when no provider can stage the file.

- Current stage: promoted the fixed-empty and successful `ParslGlobusTransferFailure`
  configurations. The staging model now requires a terminal Globus failure to become a reported
  transfer failure even when no diagnostic event is available, while preserving successful
  transfer handling.

- Current stage: promoted the fixed and normal `ParslSerializationFrameCount` configurations
  into the foundational TLC gate. The model now checks that an apply message with an extra frame
  is rejected before any payload decode, while a valid three-frame message decodes exactly once.

- Current stage: promoted the fixed and valid `ParslSerializationLength` configurations. The
  length model now distinguishes a truncated payload, which must be rejected, from a complete
  five-byte payload, which may be accepted without violating `LengthSafety`.

- Current stage: promoted `ParslNestedJoin` into the foundational TLC gate. The two-level
  composition now checks that an outer `join_app` waits for the inner join, preserves the inner
  list order, and propagates a nested leaf failure only after the inner handle is terminal.

- Current stage: added `ParslRadicalPilotDecodeFailure`, covering malformed serialized Python
  result payloads in the RP `DONE` callback. The Current branch lets decode failure escape and
  leaves the Future pending; the Fixed branch resolves a terminal failure. The focused TLC model
  and runtime probe pass.

- Current stage: added `ParslFluxShutdownLifecycle`, covering shutdown before FluxExecutor
  startup. The Current branch joins an unstarted submission thread and raises `RuntimeError`; the
  Fixed branch treats the unstarted executor as quiescent. TLC and the concrete FluxExecutor
  runtime probe pass without requiring a Flux service.

- Current stage: added `ParslThreadExecutorLifecycle`, covering failed thread-pool startup and
  cleanup. The Current branch exposes a second raw shutdown error when `start()` never created
  the underlying pool; the Fixed branch makes shutdown safe for the unstarted state. TLC and the
  installed ThreadPoolExecutor runtime probe pass.

- Current stage: added `ParslStrategyIdleClock`, which connects idle-resource scale-in to the
  wall-clock/monotonic-clock boundary. The Current branch reproduces suppression of scale-in
  after a wall-clock rollback; the Fixed branch evaluates the elapsed horizon monotonically.
  The focused TLC counterexample, Fixed run, and real `Strategy` runtime probe pass.

- Current stage: added `ParslJoinStageOutCancellation`, a compact composition of application
  completion, stage-out publication, outer cancellation, and a late stage-out callback. The
  Current branch reproduces publication after cancellation; the Fixed branch rejects that stale
  publication and passes the bounded TLC exploration. This is an abstract safety baseline rather
  than a claim that every Parsl staging provider currently exposes the same race.

- Current stage: promoted `ParslZipStageOut` as the archive publication boundary. Archive write,
  source cleanup, retry after cleanup failure, source-version change, and duplicate-member handling
  are explicit; the Fixed branch replaces an existing member rather than appending a duplicate.
  The fixed TLC configuration and six real ZIP staging probes pass.

- Current stage: promoted `ParslLSFSubmit` as the LSF `bsub` submission lifecycle. Script writing,
  scheduler failure, empty/malformed successful output, and valid marker/job-id registration are
  separate paths; only valid output publishes a resource. Three TLC configurations and five LSF
  submit runtime probes pass.

- Current stage: promoted `ParslGridEngineSubmit` as the basic qsub submission lifecycle.
  Script publication, command failure, empty successful output, and valid job-id registration
  are separate terminal paths; only the valid path publishes a pending resource. All three TLC
  configurations and the concrete Grid Engine submit probes pass.

- Current stage: promoted `ParslLocalProviderExitStatus` as the local `.ec` marker boundary.
  In-flight `-`, numeric exit codes, malformed contents, process liveness, and cancellation are
  distinct observations; numeric exit evidence wins over liveness/cancel and terminal status is
  not regressed by later marker changes. TLC and both LocalProvider runtime probes pass.

- Current stage: promoted `ParslCondorCancel` as the Condor cancellation boundary. Chunked
  scheduler cancellation updates only locally owned IDs, treats unknown IDs as absent rather
  than crashing, and returns per-request success/failure consistently. Both success/failure TLC
  configurations and the three concrete runtime probes pass.

- Current stage: promoted `ParslExecutorProvider` as the compact provisioning/admission model.
  Provider block allocation, manager registration, worker readiness, task submission, dispatch,
  provider failure, drain/recovery, and block-granular scale-in are separate transitions. The
  bounded model and provider-worker runtime bridges pass while preserving admission and ownership
  invariants.

- Current stage: promoted `ParslProviderStatusBatch` as the provider-neutral batched status
  projection boundary. It models bounded scheduler batches, atomic preservation on command failure,
  translation of reported states, and explicit completion of jobs absent from a successful batch.
  The full bounded TLC configuration and targeted Slurm status probes pass.

- Current stage: promoted `ParslClusterSubmitScript` as the common scheduler-script boundary.
  Valid template substitution publishes the script; missing template keys map to a scheduler
  argument error, and target I/O failures map to a path error without publishing a partial script.
  All three TLC configurations and the real `ClusterProvider` runtime probes pass.

- Current stage: promoted `ParslTasksOutgoing` as the HTEX task-channel sender boundary. A
  `put()` sends one Python object over the DEALER socket while the sender is open; close tears down
  the socket/context and later sends are outside the valid wrapper state. The normal TLC model and
  the real sender/close probes pass, with the close-race model retaining the source-level race.

- Current stage: promoted `ParslResultsIncoming` as the minimal HTEX result-channel boundary. A
  readable DEALER socket yields one multipart message, a poll timeout yields no message, and
  close terminates the receiver context. Both TLC configurations and the real wrapper probes pass;
  the separate close-race model continues to document post-close access behavior.

- Current stage: promoted `ParslJoinMonitoring` as the first compact join/monitoring composition.
  It combines memoized, staged-file, and compute inner Futures with outer join finalization,
  versioned monitoring events, queue reordering, bounded database-write failure, and terminal
  status persistence. The bounded TLC configuration passes all join, data-readiness, and
  monitoring invariants.

- Current stage: promoted `ParslMonitoringDelivery` as the compact logical-task to database
  event path. It models versioned status events, asynchronous queue delivery, reordering, and
  stale-write rejection at the database high-water mark. The Current configuration reproduces
  an older event overwriting a newer record; the Fixed configuration is smoke-gated, and the
  monitoring status-history/database runtime probes pass.

- Current stage: promoted `ParslJoinInternalExecutor` as the executor-admission boundary for
  `join_app`. The fixed branch routes the outer join through `_parsl_internal`, while the Current
  branch reproduces accidental dispatch through the user's `all` executor set. The focused TLC
  model and existing `join_app` runtime test both pass.

- Current stage: promoted `ParslGlobusStageDependency` as the explicit stage-in/stage-out Future
  dependency boundary. Stage-in cannot start until its parent DataFuture is ready, and stage-out
  cannot start until the application Future is done. The bounded TLC model and both real Globus
  staging dependency probes pass.

- Current stage: promoted `ParslMultiOutputStageOut` as the small multi-output DataFuture gate.
  Each output stage-out Future is independently represented but remains gated by the same
  application Future; a dependent consumer can run only after its own output is published. The
  early-publication configuration reproduces visibility before application completion, while the
  normal configuration passes the bounded TLC check and the real `DataManager.stage_out` probe.

- Current stage: promoted `ParslSerializationWire` as the concrete apply-message framing
  boundary. It requires callable, args, and kwargs buffers to serialize, receive the expected
  `C2`/`02` headers, preserve length validity, and decode in order before dispatch. The failure
  configuration also checks that an unserializable buffer rejects the complete message.

- Current stage: promoted `ParslThreeConcurrentTimeouts` as the multi-task timeout boundary.
  Three independent logical tasks have distinct deadlines and retry generations; a late result
  is accepted only when its task and generation are still current. The Current configuration
  reproduces acceptance of a stale result, while the Fixed configuration preserves independent
  task terminal state and passes the bounded TLC exploration.

- Current stage: promoted the compact integrated `ParslClock` smoke model. It combines logical
  wall-clock ticks, heartbeat send/deliver/drop, manager expiry/recovery, task deadlines,
  physical-attempt retry, and stale-result classification in one bounded state machine. The
  smoke configuration uses one worker, one retry, and a three-tick horizon while checking clock,
  heartbeat, timeout, result, and Future safety invariants.

- Current stage: promoted `ParslHtexMonitoringMessage` as the HTEX optional-monitoring-frame
  boundary. The Current configuration reproduces a crash when an optional monitoring payload is
  handled on a path where monitoring is disabled; the Fixed configuration ignores that payload
  while preserving task-result forwarding. The TLC counterexample, fixed run, and Python runtime
  probe all pass, and the fixed configuration is now part of the foundational smoke gate.

- Current stage: added the compact `ParslMonitoringDBRetry` insert primitive. The operational
  configuration models rollback/retry and single-row persistence; the integrity configuration
  models a non-retry drop. Both configurations are now part of the TLC smoke gate.

- Current stage: promoted `ParslProviderPolling` as the provider-neutral lifecycle baseline. It
  separates submit, status, transient API failure, unknown status, and cancellation rollback
  before scheduler-specific provider behavior is refined.

- Current stage: promoted the concrete `ParslLocalProvider` lifecycle baseline. The fixed branch
  preserves `.ec` exit-marker precedence and strict cancellation semantics; the runtime bridge
  exercises the corresponding LocalProvider status behavior.

- Current stage: added `ParslKubernetesLifecycle`, a cross-boundary provider model combining pod
  phase translation, read errors, cancellation, and late poll responses. The Current branch
  produces stale-terminal and hidden-error counterexamples; the Fixed branch is smoke-gated.

- Current stage: added a re-entrant Kubernetes runtime probe for a poll/cancel race. It reproduces
  BUG-282 against the installed provider: `_status()` can publish a late terminal pod phase after
  `cancel()` has already published `CANCELLED`.

- Current stage: promoted `ParslJoinCallableTransport` into the TLC gate. It composes callable
  snapshots, retry generations, stale result rejection, logical Future completion, and ordered
  duplicate join positions.

- Current stage: promoted `ParslJoinImmediateCallback` into the TLC gate. It models an already
  completed dependency invoking its callback during registration and verifies that outer join
  completion remains gated by the remaining dependency.

- Current stage: promoted `ParslFunctionObjectTransport` into the TLC gate. It models callable
  closure/object snapshot capture before queueing, source mutation while in flight, and execution
  from the decoded snapshot.

- Current stage: promoted `ParslHtexResultForwarding` into the TLC gate. It models manager task
  ownership across serialized result forwarding, send failure, and bounded retry; the Fixed branch
  prevents a failed ZMQ send from silently losing the task record.

- Current stage: promoted the full-horizon `ParslTimedHeartbeatFixed` configuration. The smoke gate
  now checks both the short and four-tick paths for heartbeat expiry, task timeout, and late-result
  classification.

- Current stage: promoted the normal-length `ParslHTTPSeparateContentLength` configuration. The
  staging gate now checks both short-response rejection and successful publication when received
  bytes exactly match the declared `Content-Length`.

- Current stage: promoted `ParslHtexResultQueue` into the executor gate. It models malformed,
  duplicate, and terminal Future result frames, requiring failed messages to resolve or preserve
  ownership without killing the result worker.

- Current stage: promoted the present-manager `ParslHtexManagerDrain` path. The smoke gate now
  checks the normal drained-manager acknowledgement/removal behavior alongside the stale-ID Fixed
  path and its existing runtime probe.

- Current stage: promoted the normal `ParslMonitoringDBInsertPresent` configuration. The monitoring
  gate now checks first-write persistence separately from duplicate-event idempotence/drop paths.

- Current stage: promoted the normal `ParslHTTPSeparateStatus` configuration. The staging gate now
  checks successful 2xx response publication separately from non-success response rejection.

- Current stage: promoted the one-block `ParslProviderThreeBlockOwnershipSmokeFixed` configuration.
  The provider gate now checks the bounded provisioning/assignment/scale-in ownership path in both
  the three-block and minimal smoke-sized state spaces.

- Current stage: promoted both invalid-admission and valid-start configurations for
  `ParslThreadExecutorThreadCount`. The executor gate now checks early rejection of zero workers
  and successful construction with one worker.

- Current stage: promoted `ParslGoogleCloudStatusPresent`. The provider gate now checks normal
  `RUNNING` translation separately from unknown-status tolerance and remote-failure handling.

- Current stage: promoted `ParslJoinImmediateCallback` into the TLC gate. It models an already
  completed dependency invoking its callback during registration and verifies that outer join
  completion remains gated by the remaining dependency.

- Current stage: promoted `ParslLocalProviderStatusScope`. The Fixed model passed TLC and the
  Current branch reproduced the stale unrelated-resource query failure; the targeted runtime
  probe passed against the installed LocalProvider implementation.

- Current stage: promoted `ParslLsfSubmitJobId`. The Fixed model passed TLC and the Current branch
  reproduced publication of a malformed scheduler token; the targeted LSF runtime probe passed.

- Current stage: promoted `ParslLSFCancel`. The Fixed model passed TLC and the Current branch
  reproduced the unknown-local-ID cancellation crash; three targeted runtime tests passed.

- Current stage: promoted the base `ParslKubernetesCancel` response model. The Fixed model passed
  TLC and the Current branch reproduced a returned-error response being marked cancelled; the
  existing Kubernetes cancellation runtime probes cover the concrete source boundary.

- Current stage: promoted the base `ParslCondorSubmit` output model. The Fixed model passed TLC
  and the Current branch reproduced empty/malformed successful output reaching raw parser failure;
  six targeted Condor submit runtime tests passed.

- Current stage: promoted `ParslGridEngineCancel`. The Fixed model passed TLC and the Current
  branch reproduced the unknown-local-ID `qdel` crash; three targeted runtime tests passed.

- Current stage: promoted `ParslPBSProSubmit`. The Fixed model passed TLC and the Current branch
  reproduced successful submission with no trackable resource; three targeted PBS Pro submit
  runtime tests passed.

- Current stage: added `ParslProviderCancelFuture`, the first focused cancellation composition
  model connecting provider state, one physical attempt, Future terminal state, late-result
  handling, and monitoring persistence. Fixed passed TLC; Current produced the expected
  cancellation/Future consistency counterexample.

- Current stage: added `ParslProviderCancelRetryMonitoring`, extending cancellation through
  provider loss, retry generation 2, stale generation-1 result delivery, and monitoring
  persistence. Fixed passed TLC; Current reproduced the expected cancellation consistency
  counterexample.

- Current stage: added `ParslJoinCancelRetryGeneration`, lifting cancellation, retry generation,
  stale results, and monitoring consistency to a two-dependency join. Fixed passed TLC; Current
  reproduced the cancelled-join mutation counterexample.

- Current stage: promoted the compact `ParslJoinComplete` Future-propagation model. Fixed passed
  TLC and the Current branch reproduced duplicate-list position loss; existing join runtime
  probes cover ordered values, failure propagation, and duplicate references.

- Current stage: promoted `ParslTripleNestedJoin`, extending dependency blocking and failure
  propagation to three nested join levels. Fixed passed TLC; Current reproduced premature J2
  evaluation with an unresolved input.

- Current stage: promoted `ParslMessageCorrelationThree`, extending ZMQ/serialization coverage
  to four logical tasks, two attempts, multipart delivery, retargeting, duplicates, and stale
  results. Fixed passed TLC; Current reproduced incorrect resolution of an obsolete/retargeted
  message.

- Current stage: promoted `ParslHeartbeatClockJump`. Fixed passed TLC and two targeted runtime
  probes passed; Current reproduced both forward-jump premature expiry and backward-jump delayed
  expiry behavior.

- Current stage: promoted `ParslMonitoringDBInsert`. Fixed passed TLC and three targeted runtime
  probes passed; Current reproduced duplicate STATUS event loss after an integrity rollback.

- Current stage: promoted `ParslHTTPPartialCleanup`. Fixed passed TLC and the targeted HTTP
  streaming runtime probe passed; Current reproduced partial destination publication after a
  later chunk failure.

- Current stage: promoted `ParslFileCleanCopy`. Fixed passed TLC and the targeted runtime probe
  passed; Current reproduced site-local path aliasing in a clean DataFuture copy.

- Current stage: promoted `ParslBadStateTerminalFuture`. Fixed passed TLC and two targeted runtime
  tests passed; Current reproduced a completed Future aborting bad-state failure fan-out.

- Current stage: promoted `ParslTorqueTasksPerNode`. Fixed passed TLC and the targeted runtime
  probe passed; Current reproduced non-positive `tasks_per_node` reaching launcher construction.

- Current stage: promoted `ParslLocalTasksPerNode`. Fixed passed TLC and the targeted runtime
  probe passed; Current reproduced zero `tasks_per_node` launching a failed local job.

- Current stage: promoted `ParslKubernetesUnknownJob`. Fixed passed TLC and the targeted runtime
  probe passed; Current reproduced stale status lookup raising a missing-resource error.

- Current stage: promoted `ParslPBSProStatus`. Fixed passed TLC and three targeted runtime tests
  passed; Current reproduced a foreign scheduler ID crashing the PBS Pro status poll.

- Current stage: promoted `ParslSlurmSubmit`. Fixed passed TLC and three targeted runtime tests
  passed; Current reproduced a successful regex match without a named job-id group crashing
  submission.

- Current stage: promoted `ParslKubernetesSubmit`. Fixed passed TLC and two targeted runtime tests
  passed; Current reproduced a newly created Pending pod being recorded as RUNNING.

- Current stage: promoted `ParslTorqueCancel`, making the provider's successful-cancel state
  convention explicit. Fixed passed TLC; three targeted Torque cancellation runtime tests passed.

- Current stage: promoted the positive `ParslAzureStatus` translation baseline, keeping the
  pending/running/terminal/unknown mapping in the foundational gate alongside Azure failure and
  ordering models.

- Current stage: added `ParslJoinStageRetry`, combining per-dependency file publication,
  physical-attempt retry, late-result correlation, and outer join completion. The Fixed
  configuration passed TLC; the Current configuration produced stale-result and unsafe staging
  counterexamples.

- Current stage: promoted the existing `ParslJoinTimedMonitoring` Fixed case into the
  foundational gate, covering heartbeat expiry, task timeout, cancellation, late completion,
  and monitoring persistence together with join data readiness.

- Current stage: promoted the HTEX unknown-result-type Fixed case, ensuring malformed result
  frames do not terminate the result worker before independent valid Futures are delivered.

- Current stage: promoted the HTEX watchdog-result race Fixed case, ensuring worker-loss
  synthesis cannot duplicate a result already published for the same task.

- Current stage: promoted the Flux inflight-submission Fixed case, ensuring a jobspec failure
  after queue dequeue completes the affected Future and leaves no orphaned inflight task.

- Current stage: promoted the Flux cancel-before-bind Fixed case, ensuring cancellation is
  propagated to the underlying Future and late callbacks cannot write a cancelled wrapper.

- Current stage: promoted the Flux late-success-on-cancelled-wrapper Fixed case, covering the
  complementary terminal callback race alongside the existing late-failure case.

- Current stage: promoted the TaskVine resource-spec-shape Fixed case, requiring malformed
  submit resource specifications to fail as controlled admission errors.

- Current stage: promoted the Work Queue category-schema Fixed case, ensuring a valid `category`
  resource reaches the executor mapping branch rather than being rejected by the schema.

- Current stage: promoted the Work Queue resource-spec-shape Fixed case, requiring validation
  before task-directory and Future-registration side effects.

- Current stage: promoted the HTEX address-probe-timeout Fixed case, preserving explicit zero
  timeout values instead of silently substituting the worker default.

- Current stage: promoted the provider polling clock-rollback Fixed case, ensuring a backward
  wall-clock step cannot suppress a due provider status poll.

- Current stage: promoted the AWS provider missing-instance Fixed case, requiring every requested
  instance to receive a deterministic status observation even when EC2 omits it.

- Current stage: promoted the Azure missing-local-cancellation Fixed case, treating successful
  remote deletion plus absent local bookkeeping as an idempotent cancellation.

- Current stage: promoted the Slurm foreign-status Fixed case, isolating unrelated scheduler rows
  instead of crashing the entire provider status poll.

- Current stage: promoted the Condor malformed-status-line Fixed case, preserving known resource
  state while skipping truncated scheduler records.

- Current stage: promoted the Grid Engine status-batch Fixed case, isolating malformed scheduler
  records so later valid jobs in the same poll still update.

- Current stage: promoted the Grid Engine single-record status Fixed case, retaining the direct
  malformed-line parser boundary alongside the batch composition model.

- Current stage: promoted the Torque foreign-status Fixed case, isolating unrelated scheduler
  lines instead of terminating the provider poll.

- Current stage: added `ParslJoinProviderResultMonitoringDB`, lifting provider failure/retry,
  stale inner results, two-dependency join completion, and monitoring persistence into one model.
  The Fixed configuration passed TLC; the Current configuration produced the expected provider
  and stale-inner-result counterexamples. The existing 406-entry runtime gate stays green.

- Current stage: added `ParslProviderResultMonitoringDB`, extending provider failure/retry and
  stale-result correlation with queued/persisted monitoring status and duplicate persistence.
  The Fixed configuration passed TLC; the Current configuration produced provider, stale-result,
  and terminal-row-loss counterexamples. The existing 406-entry runtime gate stays green.

- Current stage: added `ParslProviderResultRetryRace`, combining provider poll failure, executor
  collector loss, physical-attempt retry, late result delivery, and monitoring terminal state.
  The Fixed configuration passed TLC; the Current configuration produced the expected provider
  loss and stale-resolution counterexamples. The existing 406-entry runtime gate remains green.

- Current stage: promoted Bash app, cluster script, JobStatus, MPI, HTEX probe, Radical bulk
  shutdown, and Timer reentrant-close probes. Twenty-three targeted tests passed, and the
  affected runtime suffix (255–406) passed after insertion; the prior prefix (1–254) was already
  green.

- Current stage: promoted provider-status/cancellation probes for bad-state callback mutation,
  Grid Engine, LSF, PBS Pro, Slurm, Torque, and LocalProvider. Fourteen targeted tests passed,
  and the affected runtime suffix (246–394) passed after insertion; the prior prefix (1–245) was
  already green.

- Current stage: promoted core dataflow/dispatch probes for Future dependency blocking, duplicate
  dependency collection, apply-message arity, retry-handler accounting, and duplicate provider
  job-ID ownership. Seven targeted tests passed, and the affected runtime suffix (241–385)
  passed after insertion; the prior prefix (1–240) was already green.

- Current stage: promoted TaskVine shutdown/resource-shape, Work Queue resource-shape, and
  Radical-Pilot failure-fanout probes. Four targeted tests passed, and the affected runtime
  suffix (237–380) passed after insertion; the prior prefix (1–236) was already green.

- Current stage: promoted scheduler-submit runtime probes for Grid Engine, LSF, PBS Pro, Slurm,
  and Torque. Seventeen targeted tests passed, and the affected runtime suffix (230–376) passed
  after insertion; the prior prefix (1–229) was already green.

- Current stage: promoted HTEX transport ingress/egress probes for `TasksOutgoing`,
  `ResultsIncoming`, post-close sends, and executor-side `execute_task` decoding. Nine targeted
  tests passed, and the affected runtime suffix (226–369) passed after insertion; the prior
  prefix (1–225) was already green.

- Current stage: promoted CommandClient reply/timeout and expired-deadline probes, plus Timer
  interval and walltime conversion boundaries. Five targeted tests passed, and the affected
  runtime suffix (222–365) passed after insertion; the prior prefix (1–221) was already green.

- Current stage: promoted TaskVine and Work Queue result-file/Future propagation probes plus
  `File.filepath` resolution. Fourteen targeted tests passed, and the affected runtime suffix
  (219–361) passed after insertion; the prior prefix (1–218) was already green.

- Current stage: promoted serializer-registry precedence and cyclic Python-object round-trip
  coverage. The two targeted runtime probes passed, the new cyclic-object TLC case passed, and
  the affected runtime suffix (217–358) passed after insertion; the prior prefix (1–216) was
  already green.

- Current stage: promoted memoization runtime probes for duplicate-call reuse, closure-content
  identity, heterogeneous dictionary-key hashing, and unknown `ignore_for_cache` names. Four
  targeted tests passed, and the affected runtime suffix (213–356) passed after insertion; the
  prior prefix (1–212) was already green.

- Current stage: promoted the `Strategy` runtime bridge for initial capacity, overload scale-out,
  idle scale-in with a minimum block floor, and invalid zero-nodes-per-block input. The targeted
  four tests passed, and the affected runtime suffix (212–352) passed after insertion; the prior
  prefix (1–211) was already green.

- Current stage: promoted BlockProvider bad-state propagation probes for outstanding Future
  fan-out, completed-Future ordering, and callback-driven task-map mutation. Four targeted tests
  passed, and the affected runtime suffix (209–351) passed after the new entries were inserted;
  the prior prefix (1–208) was already green.

- Current stage: promoted Grid Engine and Torque cancellation, LSF missing-job status, and
  Radical Pilot removed-task callback probes. The targeted seven tests passed; the full runtime
  inventory passed in two contiguous segments through 348/348, while the existing Fixed TLC
  models remain covered by the 382-case gate.

- Current stage: promoted duplicate-status runtime probes for Grid Engine, LSF, Slurm, and
  Torque. All four current implementations reproduce the expected `ValueError`/`KeyError`
  failure on duplicate scheduler rows; their Fixed TLC models remain green. The complete
  foundational runtime suite passed 344/344 entries.

- Current stage: deepened `ParslClusterProviderUnknownJob` to a mixed status poll containing a
  valid known job and a stale unknown ID. The Fixed branch preserves the valid RUNNING update
  while returning MISSING for the stale ID; the Current branch still produces the raw CRASH/
  `KeyError` behavior. The runtime probe and complete foundational smoke suites passed 340/340
  runtime entries and 382/382 TLC cases.

- Current stage: promoted Work Queue and TaskVine duplicate/late-result collector boundaries.
  The fixed models ignore an already-consumed task identifier and preserve unrelated Futures;
  the Current models retain the collector-exit and unrelated-failure counterexample. Both
  runtime probes passed, and the complete foundational smoke suites passed 382/382 TLC cases
  and 339/339 runtime entries.

- Current stage: promoted monitoring shutdown boundaries into the foundational gate. The
  external-queue model checks that a stale `empty()` observation cannot strand a message, while
  the UDP drain-clock model checks that wall-clock rollback cannot extend shutdown indefinitely.
  Both fixed configurations passed TLC, both runtime probes passed, and the complete foundational
  smoke suites passed 380/380 TLC cases and 337/337 runtime entries.

- Current stage: added `ParslProviderStagingAdmission`, a compact cross-component model for
  provider provisioning, chunked file publication, DataFuture readiness, task admission, and
  scale-in/retry. The fixed configuration passed TLC; the current configuration produces the
  expected counterexamples for premature publication and capacity loss. The new staging-provider
  runtime bridge passed, and the complete foundational runtime suite passed 335/335.

- Current stage: promoted eleven concrete provider runtime bridges into the foundational gate:
  HTEX submit, Kubernetes cancel/submit, Azure and Google Cloud cancel, Condor cancel/empty
  submit, Flux cleanup/status/working-directory, and LocalProvider submit cleanup. The targeted
  provider batch ran 21 tests, and the complete foundational runtime suite passed 334/334.

- `e9503ff`: PBS Pro status-batch isolation. A malformed scheduler record must not prevent an
  independent valid record in the same response from being processed.
- `27a9e65`: monitoring worker cross-table atomicity. A committed `STATUS` write must not remain
  visible after the corresponding `TRY` update fails.
- `aab331c`: HTEX malformed-task continuation. A malformed task envelope must not stop the ZMQ
  ingress loop before a later valid task is queued.
- `656c5e7`: Globus token-schema validation. An incomplete cached service mapping must not expose
  a raw `KeyError` during authorizer construction.
- `b8c3e41`: Globus initialization race. Concurrent creation of `~/.parsl` must not turn ready
  directory state into `FileExistsError`.
- `00c18d9`: HTEX serialization-failure normalization. Non-`TypeError` serializer failures must
  not escape the public submit boundary as raw implementation exceptions.
- `7692d96`: recorded the HTEX serialization stage and its durable smoke inventory.
- `270d093`: refined HTEX result decoding with a corrupt-then-valid batch sequence; a bad frame
  must not strand the later Future.
- `9f9b4c1`: JobStatusPoller executor isolation. A provider/status failure in one executor must
  not suppress independent executors in the same polling tick.
- `1cc300f`: monitoring internal-queue drain. Shutdown must not exit the database loop while a
  pending internal message remains after a stale `empty()` observation.
- `af476ac`: ThreadPoolExecutor empty resource-spec validation. A falsy non-mapping resource
  specification must not bypass executor input validation.
- `0f6ccec`: HTEX callable-object serialization errors. A callable without `__name__` must not
  mask the original serialization TypeError with an `AttributeError`.
- `7178406`: extended the callable-object serialization-error refinement to Flux, confirming the
  same safe error-reporting condition across two concrete executors.
- Current stage: refined BUG-018 for TaskVine and Work Queue failure reports. A cancelled Future
  can raise from `set_exception` just as it can from `set_result`; both current models produce a
  two-state counterexample, while both fixed models complete in seven generated/four distinct
  states. Runtime probes exercise both collector branches.
- Current stage: refined BUG-135 for Radical-Pilot late `FAILED` callbacks. A callback arriving
  after cancellation can raise through `set_exception` just like the existing `DONE` path; the
  failure Current model produces a four-state counterexample and the Fixed model passes.
- Current stage: added MPI malformed-result cleanup. A corrupt pickle currently escapes
  `MPITaskScheduler.get_result`, leaving allocated nodes held while the ferry loop continues;
  the Current model produces a two-state leak counterexample and the Fixed model releases the
  allocation while publishing a terminal decode failure.
- Current stage: completed the provider ledger mapping for Slurm cancellation. Existing
  `ParslSlurmCancel` and `ParslSlurmCancelBatch` models plus the runtime probe document that a
  successful remote `scancel` can still raise on a stale local ID after partially updating a
  batch; this is now tracked as BUG-277.
- Current stage: refined BUG-084 for truthy user equality. An invalid join return whose
  `__eq__([])` returns `True` enters the empty-list branch and leaves the outer Future pending;
  the new Current model has a three-state counterexample and the Fixed model passes.
- Current stage: added `ParslJoinPartialCancellation`, which forces one list member to be
  observed successfully before a second member is cancelled. The Current model produces an
  eight-state/5-distinct callback-escape counterexample; the Fixed model passes in 10/5 states.
- Verification stage: the complete foundational regression passed after the join refinement:
  all 362 TLC smoke cases passed with `TLC_SIMULATE=10`, and all 233 Python runtime probes
  passed against the installed Parsl source. The runtime run emitted only existing resource
  warnings from temporary Parsl log handles; no test failed.
- Current stage: added `ParslHtexCancelledFailureResult`, the failure-payload counterpart to
  `ParslHtexCancelledResult`. The current HTEX result worker can escape after `set_exception`
  rejects a cancelled Future and its recovery call rejects again; the Current model produces a
  two-state counterexample, the Fixed model passes in seven generated/four distinct states, and
  the runtime probe reproduces the stranded later failure Future.
- Current stage: added `ParslFluxLateFailureCancelledFuture`, the failure counterpart to the
  existing late-success cancellation model. `_complete_future` can call `set_exception` on a
  cancelled wrapper after an underlying Flux job fails; the Current model produces a two-state
  counterexample, the Fixed model passes in four generated/two distinct states, and the concrete
  callback probe reproduces the `InvalidStateError`.
- Current stage: bridged the existing BUG-018 failure-path models to concrete collector probes.
  Work Queue and TaskVine each now exercise a cancelled first failure report followed by a live
  report; the current collector aborts and its finalizer fails the unrelated Future, matching the
  Current TLA+ semantics. The targeted result suites pass 11/11 tests.
- Current stage: added `ParslFluxCancelRunningRace`, which models `FluxFutureWrapper.cancel()`
  while the wrapper is RUNNING but the underlying Flux future still accepts cancellation. The
  Current model produces a two-state `NoRawCancelError` counterexample, the Fixed model passes in
  four generated/two distinct states, and the runtime probe reproduces the raw `RuntimeError` plus
  the inconsistent unfinished-wrapper state.
- Current stage: added `ParslScaleInResultShape` for malformed provider cancellation responses.
  A short boolean result list currently reaches a raw `_filter_scale_in_ids` assertion; the
  Current model produces a two-state counterexample, the Fixed model passes in four generated/two
  distinct states, and the runtime probe reproduces the assertion directly.
- Current stage: added `ParslAwsInstanceStateShape` for an empty EC2 reservation in
  `AWSProvider.get_instance_state`. The Current model produces a two-state `NoRawIndexError`
  counterexample, the Fixed model passes in four generated/two distinct states, and the provider
  probe reproduces the concrete `IndexError`.
- Current stage: added `ParslHtexRegistrationBlockId` for a null manager registration block ID.
  The current interchange reaches an internal assertion after decoding the ZMQ registration;
  the Current model produces a two-state `NoRawAssertion` counterexample, the Fixed model passes
  in four generated/two distinct states, and the manager-message runtime suite now passes 6/6.
- Current stage: promoted the existing `ParslMonitoringResourceHistory` model and SQLite bridge
  into the foundational smoke inventory. It checks append-only RESOURCE rows, out-of-order sample
  delivery, duplicate primary-key rejection, and latest-by-timestamp selection; the model and
  runtime probe are now part of the 369/236 regression gate.
- Current stage: promoted `tests/test_join_three_list_runtime.py` into the foundational runtime
  gate. The probe confirms three distinct inner Futures preserve four ordered output positions,
  including a duplicate reference, matching the existing `ParslJoinThreeList` model.
- Current stage: promoted six existing serialization and staging runtime bridges into the
  foundational gate. The probes now exercise closure/object snapshotting, serializer frame and
  header validation, clean-copy normalization, filesystem-radio atomic publication, and HTTP
  staging failure behavior against the installed Parsl source.
- Current stage: promoted eight clock/heartbeat runtime bridges into the foundational gate. The
  probes cover HTEX drain and heartbeat message timing, address-probe timeout propagation,
  provider polling after clock rollback, resource-monitor sampling, and monitoring batch deadlines.
- Current stage: promoted ten concrete provider runtime bridges into the foundational gate. The
  probes cover Local process and status lifecycle, AWS reservation/status shapes, Azure resource
  bookkeeping, and malformed/unknown job responses from Condor, Slurm, PBSPro, and Kubernetes.
- Current stage: promoted four join-composition runtime bridges into the foundational gate. The
  probes cover serialized callable values, nested error-root selection, callback-time list mutation,
  and duplicate input positions across retry attempts.
- Current stage: promoted five cross-component runtime bridges into the foundational gate. The
  probes cover HTEX result decode failure, result-forwarding ownership loss, optional monitoring
  message handling, scheduler-command timeout cleanup, and negative provider scale-in behavior.
- Current stage: added `ParslJoinRetryStaleResult`, a cross-layer TLA+ model for two logical join
  dependencies and bounded physical attempts. The Current branch accepts a late timed-out result
  and violates result consistency; the Fixed branch classifies it as stale. Fixed TLC passed in the
  370-case smoke, while the Current configuration produced the intended counterexample.
- Current stage: added `ParslJoinProviderMonitoring`, extending the cross-layer join model with
  data staging readiness, provider loss/reprovisioning, and monitoring queue persistence. Its
  Current branch again exposes stale-result acceptance; the Fixed branch passed standalone TLC.
- Current stage: added `ParslJoinZMQRetry`, which models task/result envelopes through framing,
  send/receive, decode, corruption rejection, and `(task, attempt)` resolution. The Fixed branch
  passed standalone TLC and the Current branch produced the intended stale-result violation.
  The model now also tracks mutable Python-object versions and serialization snapshots, with a
  dispatch invariant that catches live-object substitution after serialization.
- Current stage: added `ParslJoinFileStaging`, a two-chunk content/checksum/source-version model
  that gates join execution on safe publication. The Current branch publishes corrupt bytes and
  violates readiness/content safety; the Fixed branch passed standalone TLC.
- Current stage: added `ParslJoinMonitoringDB`, connecting terminal join status to queued and
  persisted monitoring rows. The Current branch loses terminal status on a duplicate write; the
  Fixed branch treats duplicates idempotently and passed standalone TLC.
- Current stage: promoted eight concrete provider/executor runtime bridges into the foundational
  gate: Flux cancellation races, Globus Compute submit overlap, HTEX cancellation admission,
  Local PID admission, poller close/duplicate registration, and scale-in result shape.
- Current stage: promoted four monitoring DB runtime bridges into the foundational gate. The probes
  cover batch boundaries, permanent insert/update errors, deferred worker messages, and duplicate
  observations against the installed SQLite-backed DatabaseManager.
- Current stage: added `ParslJoinHeartbeatRetry`, connecting logical clock and heartbeat expiry to
  task timeout, manager loss, reprovisioning, and stale-result rejection. The Current branch
  accepts a late expired-attempt completion; the Fixed branch passed standalone TLC.
- Current stage: added `ParslAbstractFullSmoke.cfg`, a positive integrated run with four tasks,
  dependency/join edges, memoization, object graphs, file outputs, two executors, three workers,
  provider capacity, heartbeat/task deadlines, and monitoring enabled. It passed standalone TLC.
- Current stage: added `ParslProviderTaskScaleRetry`, a provider-capacity model for admission,
  scale-in cancellation, retry, result completion, and monitoring. The Current branch leaves a
  running task without capacity; the Fixed branch moves it to `retry_wait` and passed standalone TLC.
- Current stage: promoted five timeout/heartbeat runtime bridges into the foundational gate:
  HTEX initial probe timeout, time-limited file open, bash cleanup, Python timeout parameters,
  and timer close behavior.
- Current stage: promoted nine scheduler/provider runtime bridges into the foundational gate:
  AWS cancel, Azure status, Condor submit, Flux submission failure, Google Cloud status, Grid
  Engine batch status, LSF status, PBSPro status, and Slurm status batch.
- Current stage: promoted six file-transfer provider runtime bridges into the foundational gate:
  Globus Compute resource/submit/shutdown behavior, Globus stage-in/out dependency wiring,
  Globus terminal transfer failure, and rsync stage-in/out ordering.
- Current stage: promoted ten serialization/ZMQ/HTEX runtime bridges into the foundational gate:
  serializer fallback/cache behavior, CurveZMQ certificate validation, monitoring-router failure,
  ambiguous and duplicate HTEX messages, submit-counter races, manager drain, and worker watchdog
  result races.
- Current stage: promoted six executor/task-transport runtime bridges into the foundational gate:
  ThreadPoolExecutor lifecycle/resource validation, invalid thread counts, ParslPoolExecutor map
  timeout semantics, real serialized ZMQ task execution, and LocalProvider stale cancellation.
- Current stage: promoted `ParslJoinEndToEnd` into the foundational TLC gate. The model keeps
  logical inner Futures separate from physical retry attempts and checks ordered join observation,
  cancellation/failure aggregation, terminal outer state, and result-shape safety in one compact
  cross-layer state machine.
- Current stage: promoted the compact `ParslHeartbeatRetry` model into the foundational TLC gate.
  It provides the simple clock/heartbeat baseline: monotonic manager expiry, task timeout,
  bounded retry, and rejection of late results before the more detailed provider/join timing
  compositions.
- Current stage: promoted `ParslMonitoringWorkflowDuration` into the foundational TLC gate. This
  small database-contract model checks that workflow duration survives the close/finalization
  update instead of being silently ignored by a schema mismatch.
- Current stage: promoted `ParslMonitoringZMQRouterFailure` into the foundational TLC gate. The
  compact transport model now checks that an unrecoverable monitoring receive channel reaches a
  terminal state instead of retrying indefinitely until an unrelated external stop.
- Current stage: promoted `ParslFilePathResolution` into the foundational TLC gate. The model
  separates local `file:` URLs from staged remote paths and rejects remote reads without a
  site-local annotation before the higher-level transfer/publication models run.
- Current stage: promoted `ParslSerializationZMQBridge` into the foundational TLC gate. This
  compact bridge connects serializer tokens and attempt IDs to framing, route validation,
  duplicate/discard handling, worker dispatch, result decoding, and stale-result rejection.
- Current stage: promoted all three `ParslExecuteTask` configurations into the foundational TLC
  gate. The worker-side baseline now checks valid value return, user exception propagation, and
  malformed payload rejection before invocation.
- Current stage: promoted `ParslBashAppOutcome` into the foundational TLC gate. The executor-side
  model separates shell exit, stdout side effects, declared output validation, and Future terminal
  success/failure so output publication cannot turn a failed Bash task into success.
- Current stage: promoted `ParslPoolExecutorMap` into the foundational TLC gate. The map iterator
  baseline now checks eager submission, ordered result consumption, iterator timeout as a caller
  deadline, and preservation of already-submitted tasks after timeout.
- Current stage: promoted the compact `ParslTorqueSubmit` provider model into the foundational TLC
  gate. Its success, empty-output, and qsub-failure configurations now check that scheduler output
  creates one pending resource only for a usable job identifier, while the runtime probe exercises
  the installed `TorqueProvider.submit` implementation including its multi-line response behavior.
- Current stage: promoted `ParslTaskVineShutdown` into the foundational TLC gate. The collector
  shutdown path now checks that outstanding Futures are failed with manager-failure semantics before
  the collector exits; the focused runtime probe invokes the installed collector implementation.
- Current stage: promoted `ParslTaskVineResults` into the foundational TLC gate. The result path now
  separates valid payloads, task exceptions, corrupt/missing output, no-result reports, and manager
  failure while preserving Future terminal-state and outstanding-task invariants.
- Current stage: promoted `ParslWorkQueueResults` into the foundational TLC gate. The Work Queue
  collector baseline now covers valid result files, serialized app exceptions, corrupt output,
  collector failure cleanup, and terminal-state stability for multiple task records.
- Current stage: promoted the Fixed `ParslCallableRetryTransport` configuration into the foundational
  TLC gate. Each retry captures an immutable callable/object snapshot; the Current configuration is
  retained as a deliberate TLC counterexample for late old-attempt acceptance, while the Fixed gate
  rejects it using attempt correlation.
- Current stage: promoted the Fixed `ParslCallableClosureMemo` configuration into the foundational
  TLC gate. It distinguishes callable closure payload contents from memoization identity; the Current
  configuration remains a counterexample where two closure values collide on a name/module key.
- Current stage: promoted all three `ParslStageOutFuture` modes into the foundational TLC gate.
  Separate stage-out now gates DataFuture readiness on publication, while in-task and no-stage modes
  complete output readiness with the application; dependent admission remains blocked until ready.
- Current stage: promoted the three `ParslRsyncStage` paths into the foundational TLC gate. Stage-in
  runs before the application, stage-out runs after it, and either transfer failure prevents false
  success while preserving the expected application execution ordering.
- Current stage: promoted `ParslMonitoringDeferred` into the foundational TLC gate. Worker status
  messages received before their TASK_INFO/TRY rows are deferred and replayed only after the foreign
  key exists; duplicate first observations are explicitly bounded and status rows stay admissible.
- Current stage: promoted the Fixed and valid `ParslTimerIntervalValidation` configurations into the
  foundational TLC gate. Negative intervals are rejected by the Fixed branch instead of becoming a
  zero-delay timer; the Current branch remains a deliberate counterexample and runtime probe.
- Current stage: promoted the basic `ParslCommandClient` reply and timeout configurations into the
  foundational TLC gate. A successful REQ/REP completes normally, while a response timeout poisons
  the client and prevents reuse of a request socket with unknown state.
- Current stage: promoted both `ParslJoinNoneResult` configurations into the foundational TLC gate.
  Single-Future and list joins preserve `None` as a successful result, keep list positions intact,
  and release the join handle only after all selected inner Futures are observed.
- Current stage: promoted the Fixed `ParslJoinReturnEquality` configuration into the foundational
  TLC gate. Invalid join returns now take a terminal validation-failure path before user-defined
  equality can raise; the Current and truthy-equality variants remain documented counterexamples.
- Current stage: promoted the Fixed `ParslJoinSingleCancellation` configuration into the foundational
  TLC gate. A cancelled inner Future now becomes terminal outer join failure; the Current branch
  remains a counterexample where `CancelledError` escapes and leaves the outer join pending.
- Current stage: promoted `ParslPollerBadState` into the foundational TLC gate. Provider polling,
  failure-threshold handling, outstanding-task failure, and scale-out/scale-in suppression after a
  bad executor state are now checked in one bounded provider state machine.
- Current stage: promoted the Fixed `ParslApplyDispatchBoundary` configuration into the foundational
  TLC gate. Malformed four-frame apply messages are rejected at the serialization facade before worker
  invocation; the Current configuration remains a deliberate arity counterexample.
- Current stage: promoted the Fixed and valid `ParslPythonTimeoutParameter` configurations into the
  foundational TLC gate. Non-positive Python-app timeout values are rejected before wrapper execution;
  the Current configuration remains a deliberate immediate-timeout counterexample.
- Current stage: promoted the Fixed and success `ParslTimeLimitedOpenTimeout` configurations into the
  foundational TLC gate. A missing file now produces an explicit timeout before `open()` is attempted;
  the Current configuration remains a raw FileNotFoundError counterexample.
- Current stage: promoted the Fixed `ParslTimerCloseTimeout` configuration into the foundational TLC
  gate. A timed close reports an explicit closing/timeout outcome while the callback remains alive;
  the Current configuration remains a premature-closed counterexample.
- Current stage: promoted normal and abnormal `ParslMonitoringClose` configurations into the
  foundational TLC gate. Both paths set the kill/drain state, while workflow finalization is emitted
  only when a start message exists and no prior workflow-end was processed.
- Current stage: promoted the Fixed `ParslHtexWorkerDrainClock` configuration into the foundational
  TLC gate. Worker drain deadlines now use monotonic elapsed time; the Current configuration remains
  a wall-clock rollback counterexample that suppresses a due drain message.
- Current stage: promoted the Fixed `ParslResourceMonitorClock` configuration into the foundational
  TLC gate. Remote resource-monitor sampling now uses an elapsed monotonic schedule despite wall-clock
  rollback; the Current configuration remains a suppressed-due-sample counterexample.
- Current stage: promoted the Fixed and positive `ParslMonitoringBatch` configurations into the
  foundational TLC gate. A zero batching interval still consumes an available message in the Fixed
  path; the Current configuration remains the empty-batch counterexample.
- Current stage: promoted the Fixed `ParslMonitoringBatchClock` configuration into the foundational
  TLC gate. Batch deadlines now use monotonic elapsed time; the Current configuration remains a wall-
  clock rollback counterexample that drains past the intended deadline.
- Current stage: promoted `ParslProviderKinds` into the foundational TLC gate. The provider-neutral
  state machine now checks scheduler submit/status translation, missing-job semantics, cancellation,
  scale-in, provider failure/recovery, and CPU/task-per-node admission together.
- Current stage: promoted `ParslBlockProviderBadState` into the foundational TLC gate. An unrecoverable
  provider error records its cause, fails all pending tasks, preserves already terminal tasks, and
  rejects later submissions.
- Current stage: promoted `ParslJoinDuplicates` into the foundational TLC gate. Ordered duplicate Future
  references preserve list positions and repeated failure entries, while duplicate callbacks do not
  alter aggregate results or join-handle cleanup.
- Current stage: promoted `ParslJoinErrorRootCause` into the foundational TLC gate. Nested propagated
  join failures now retain the first leaf exception, annotate sibling dependencies, and preserve the
  root-cause path used by `JoinError`.
- Current stage: promoted five monitoring lifecycle runtime bridges into the foundational gate:
  close/finalization, starter construction failure, zero batching threshold, authenticated malformed
  UDP payloads, and workflow-duration schema behavior.
- Current stage: strengthened the HTEX worker poll-priority runtime bridge to sustain three
  consecutive iterations where task and result sockets are both readable. The installed source
  continues to service the task socket first and leaves the result socket unread in every iteration;
  this is now aligned with the `ParslHtexWorkerPollPriority` TLC counterexample rather than a
  one-shot scheduling artifact.
- Current stage: reran the complete bounded v0.1 regression after the source-aligned refinements:
  all 617 TLC smoke cases and all 415 Python runtime probe entries passed. Added
  `docs/v0.1-report.md` as the fixed-scope handoff with component mapping, invariant classes,
  Current/Fixed interpretation, limitations, and exact reproduction commands.
- Current stage: tightened `ParslTaskTransport` result acceptance. A physical result now needs
  both a valid result envelope and a valid payload bit before it can resolve the logical Future;
  `ResultDecodeSafety` is checked by TLC and the real serialized-task ZMQ probe still passes.
- Current stage: added `ParslResultDecodeRetryMonitoring`, a bounded cross-layer model combining
  result decode failure, physical retry generation, late old-attempt delivery, and monitoring
  status persistence. The Current case reaches a stale-success monitoring counterexample; the
  Fixed case rejects the old result, resets the monitoring high-water mark at retry, and passes
  100,001 simulated states.
- Current stage: added a real runtime bridge for that composition. The installed HTEX result worker
  reproduces the orphaned Future after corrupt decode, and the installed SQLite monitoring schema
  accepts an older `try_id` at a newer timestamp; the probe records this as a Current observation
  while the Fixed generation rule remains model-level.
- Current stage: reconciled the documentation counts with the executable manifests: 617 TLC
  `run_case` entries, 416 foundational Python probe entries, and 648 repository-wide unittest
  methods. The README, overview, coverage matrix, and validation report now distinguish these
  scopes instead of mixing historical counts.
- Current stage: added a real `join_app` retry/monitoring bridge. A decorated join with a real
  retried inner Python app reaches inner `try_id = 1`, while the SQLite STATUS table still accepts
  a later timestamp for `try_id = 0`; the probe is now part of the 417-entry runtime gate.
- Current stage: added `ParslHTTPInTaskTransferGate`. The model connects HTTP response status,
  streamed chunks, temporary/final publication, and wrapped-task admission. Its Current case
  reproduces a non-2xx response reaching user code; the Fixed case requires successful complete
  publication. The real wrapper probe passes, and the full gate now contains 618 TLC cases,
  418 runtime entries, and 654 discovered unittest methods.
- Current stage: added `ParslMonitoringRemoteLifecycle`. The model connects periodic resource
  sampling, wall-clock rollback, monotonic scheduling, termination, and the unconditional final
  resource message. The real monitor bridge confirms rollback does not drop the final message.
  The full gate now contains 619 TLC cases, 419 runtime entries, and 655 discovered unittest
  methods.
- Current stage: added `ParslHTTPInTaskAdmission`, a joint status/Content-Length/task-admission
  refinement. It reuses the existing BUG-172 and BUG-288 observations without creating a
  duplicate ledger entry: Current admits a non-success short response, while Fixed blocks user
  code until both checks pass. The full gate now contains 620 TLC cases, 420 runtime entries,
  and 656 discovered unittest methods.
- Current stage: added `ParslRemoteExceptionTransport`. It models a nested
  `RemoteExceptionWrapper` cause surviving serialization and becoming a terminal Future failure;
  the real HTEX result worker probe verifies the leaf cause after decoding. The full gate now
  contains 621 TLC cases, 421 runtime entries, and 657 discovered unittest methods.
- Current stage: reconciled the existing `ParslFluxCancelSubmitRace` model with the bug ledger as
  BUG-329. This is distinct from ordinary late-result delivery: cancellation happens before the
  underlying Flux Future is bound, so a later bind/completion can still call `set_result` on the
  cancelled wrapper. The Current TLC case produces the callback-state counterexample, the Fixed
  case passes, and both runtime interleavings pass against the installed Flux wrapper. The ledger
  now contains 306 unique findings (74 executor/worker findings).
- Current stage: added `ParslFutureProjectionRetry`, refining `AppFuture.__getitem__`/`__getattr__`
  with logical-task retry state and physical-attempt identity. TLC explored 96 states with all
  dependency, attempt-correlation, stale-result, retry-bound, and terminal-stability invariants
  passing. A real retried Python app plus item projection completed successfully after two
  physical attempts. The foundational inventory is now 727 TLC configurations, 466 runtime
  entries, and 741 unittest methods.
- Current stage: added `ParslFutureProjectionRetryMonitoring`, connecting the logical projection
  retry path to monitoring attempt high-water state. The model requires the current attempt's
  terminal status before projection admission and isolates a late attempt-0 status. The SQLite
  runtime bridge and real retried Python projection pass. Inventory is now 728 TLC configurations,
  467 runtime entries, and 742 unittest methods.
- Current stage: added `ParslFutureProjectionRetryZMQ`, carrying the same logical/physical attempt
  boundary through serialized result envelopes. TLC checks attempt correlation, payload snapshot,
  stale-frame isolation, and projection safety; the runtime bridge uses in-process ZMQ and Parsl's
  serialized `TaskResult`. Inventory is now 729 TLC configurations, 468 runtime entries, and 743
  unittest methods.
- Current stage: added `ParslJoinMultiOutputMonitoring`, composing list-valued `join_app`
  completion, two independent stage-out/DataFuture transfers, output observation, and SQLite
  terminal status persistence. The model checks join dependency, output publication, completeness,
  and monitoring terminality; the real decorated join/DataManager/SQLite bridge passes. Inventory
  is now 730 TLC configurations, 469 runtime entries, and 744 unittest methods.
- Current stage: added `ParslHtexPollPriorityFutureTimeout`, composing the HTEX task/result poll
  ordering with a logical Future deadline and monitoring terminality. The Current runtime bridge
  reproduces a ready result remaining unconsumed through three deadline polls, while the Fixed TLC
  configuration requires result service or an explicit timeout. Inventory is now 731 TLC
  configurations, 470 runtime entries, and 745 unittest methods.
- Current stage: added `ParslJoinExceptionIdentity`, refining `join_app` failure aggregation from
  exception text to Python object identity. The fixed TLC case preserves the leaf exception as
  the nested and outer `JoinError.__cause__` while retaining sibling annotation, and the real
  `JoinError` runtime probe passes. Inventory is now 732 TLC configurations, 471 runtime entries,
  and 746 unittest methods.
- Verification stage: reran the complete foundational regression after the exception-identity
  addition. All 732 TLC configurations and all 471 runtime entries passed (`tlc_exit=0`,
  `runtime_exit=0`). The full logs were captured under `/tmp/parsl-regression-f515759.RHGlk8`.
- Current stage: added `ParslWorkQueueFileCacheIdentity`, refining Work Queue's real file-transfer
  cache boundary. The Current model and runtime probe show that two distinct `File("input.dat")`
  objects both produce `cache=False`, despite the documented filepath-based reuse contract; the
  Fixed model keys reuse by filepath. Inventory is now 733 TLC configurations, 472 runtime
  entries, and 747 unittest methods.
- Current stage: added `ParslFunctionEnvironmentCacheIdentity`, refining callable-content caching
  in the Work Queue/TaskVine package-preparation path. The Current TLC model and runtime probe
  force a recycled `id(fn)` and show a new function receiving the old dependency package; the
  Fixed model requires a content/snapshot key. Inventory is now 734 TLC configurations, 473
  runtime entries, and 748 unittest methods.

### Verification convention

Each stage is checked with a Current TLC configuration, a Fixed TLC configuration, and a targeted
runtime probe against the installed Parsl source when the boundary is concrete. The full smoke
runner is a bounded regression gate; it is not an exhaustive proof of all Parsl implementation
states.

### Next audit direction

Continue source-aligned refinement of executor/provider details and `join_app` composition. Prefer
new cross-layer models that connect logical Futures, physical attempts, transport/staging events,
and monitoring records rather than duplicating an existing single-boundary model.

## Scope note

The repository preserves the implementation artifacts and project decisions. It does not claim to
archive the external chat transcript or control platform-level conversation retention.

For continuity, treat this file as the durable handoff point: after each meaningful stage, update
the latest commit, verification counts, completed work, and next audit direction before pushing.
