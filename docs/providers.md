# Provider and scheduler models

These models cover provider allocation, polling, cancellation, status parsing, duplicate or
unknown jobs, scaling, and scheduler-specific behavior for AWS, Azure, Google Cloud, Slurm,
Condor, Grid Engine, LSF, PBS Pro, Torque, Kubernetes, and local providers.

Files live in [`models/providers/`](../models/providers/).

`ParslKubernetesCancelFutureMonitoring.tla` composes the Kubernetes delete response with the
executor Future and monitoring cancellation state. The Current branch propagates cancellation
even when the API reports a failed delete; the Fixed branch requires confirmed remote deletion.
This is a cross-layer refinement of BUG-189, backed by
`tests/test_kubernetes_cancel_future_monitoring_runtime.py`.

`ParslAwsTeardownStateCleanup.tla` models idempotent AWS state-file removal after infrastructure
teardown. The current provider leaks `FileNotFoundError` when the state path is already absent;
the fixed branch treats the missing file as completed cleanup.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslAwsTeardownStateCleanupCurrent.cfg models/providers/ParslAwsTeardownStateCleanup.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -config models/providers/ParslAwsTeardownStateCleanupFixed.cfg models/providers/ParslAwsTeardownStateCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_teardown_state_cleanup_runtime.py -v
```

This teardown cleanup boundary is recorded as BUG-310.

`ParslAwsLifecycle.tla` composes AWS submission, status polling, missing-response handling,
stale local records, and cancellation. The Current branch can abort when the cloud API omits a
status or when cancellation is requested after local bookkeeping has disappeared; the Fixed
branch treats missing observations as `unknown` and makes remote termination idempotent. This is
the compact provider-level composition model, while the narrower AWS models above preserve the
individual source-level findings.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslAwsLifecycleCurrent.cfg models/providers/ParslAwsLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslAwsLifecycleFixed.cfg models/providers/ParslAwsLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_submit_runtime.py tests/test_aws_status_runtime.py tests/test_aws_cancel_runtime.py -v
```

The composition is a regression model for the existing AWS provider findings; it does not claim
that every EC2 API detail is modeled.

`ParslAwsStateFileAtomicity.tla` models the persistence boundary in `AWSProvider`. The current
implementation writes JSON directly to the final state path; an interruption after truncation
can leave malformed state, and the next initialization may recreate infrastructure. The fixed
branch writes a temporary file and atomically publishes it, preserving the previous valid state.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsStateFileAtomicityCurrent.cfg models/providers/ParslAwsStateFileAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsStateFileAtomicityFixed.cfg models/providers/ParslAwsStateFileAtomicity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_state_file_atomicity_runtime.py -v
```

This interrupted-publication boundary is recorded as BUG-305.

`ParslProviderPolling.tla` is the compact provider lifecycle baseline. It separates block
submission from acceptance/rejection, status polling, transient API errors, unknown-status
failure, and cancellation rollback. `TargetSafety` keeps the provider target within capacity;
`CallSafety` ensures that an in-flight status or cancel operation names the matching block. The
model is intentionally provider-neutral and is the abstraction layer beneath the scheduler-
specific models below.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPolling.cfg models/providers/ParslProviderPolling.tla
```

`ParslAzureCancelBookkeeping.tla` models the post-delete local bookkeeping boundary. The current
Azure provider removes a VM from `instances` but leaves its `resources` entry present; the fixed
branch clears both records after remote deletion.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureCancelBookkeepingCurrent.cfg models/providers/ParslAzureCancelBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureCancelBookkeepingFixed.cfg models/providers/ParslAzureCancelBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_cancel_bookkeeping_runtime.py -v
```

This stale resource-map boundary is recorded as BUG-227.

`ParslAzureLifecycle.tla` composes Azure VM provisioning, status translation, and cancellation.
The Current branch retains partial VM/resource records after setup failure, under-reports a
running VM when status entries are reordered, and leaves a deleted VM in local bookkeeping. The
Fixed branch rolls back failed setup, selects status by meaning, and clears local records after
remote deletion.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslAzureLifecycleCurrent.cfg \
  models/providers/ParslAzureLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslAzureLifecycleFixed.cfg \
  models/providers/ParslAzureLifecycle.tla
```

`ParslCondorStatusUnknown.tla` models the Condor status projection boundary. The current
provider indexes every requested ID after polling, while the fixed branch returns an explicit
UNKNOWN result for IDs no longer present in local bookkeeping.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusUnknownCurrent.cfg models/providers/ParslCondorStatusUnknown.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorStatusUnknownFixed.cfg models/providers/ParslCondorStatusUnknown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_status_unknown_runtime.py -v
```

This stale Condor projection boundary is recorded as BUG-228.

`ParslCondorSubmitCount.tla` refines the Condor submission parser for multi-digit job counts.
For output such as `10 job(s) submitted to cluster ...`, the current implementation indexes
`line[0]` and registers only one process; the fixed branch parses the complete count token.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorSubmitCountCurrent.cfg models/providers/ParslCondorSubmitCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorSubmitCountFixed.cfg models/providers/ParslCondorSubmitCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorSubmitCountNormal.cfg models/providers/ParslCondorSubmitCount.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_submit_runtime.py -v
```

This multi-digit Condor count boundary is recorded as BUG-171.

`ParslLocalProviderExitStatus.tla` models the local provider's `.ec` exit-marker protocol. It
separates an in-flight `-` marker from numeric and malformed markers, process liveness, and a
prior cancellation request. Numeric exit codes take precedence over liveness/cancellation, and
the runtime bridge checks completion precedence and terminal-status caching against the real
`LocalProvider.status()` implementation.
The configuration is now part of the foundational smoke gate.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderExitStatus.cfg models/providers/ParslLocalProviderExitStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_provider_exit_status_runtime.py -v
```

`ParslDuplicateJobId.tla` models the reverse ownership maps maintained by
`BlockProviderExecutor.scale_out_facade`. The current path accepts a duplicate provider job ID
and overwrites `job_ids_to_block`, so one of two launched blocks is no longer addressable by its
job. The fixed branch rejects the duplicate before publishing it. The runtime probe uses a
provider double that intentionally returns the same ID twice.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslDuplicateJobIdCurrent.cfg models/providers/ParslDuplicateJobId.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslDuplicateJobIdFixed.cfg models/providers/ParslDuplicateJobId.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_duplicate_job_id_runtime.py -v
```

`ParslAwsStatusMissingResult.tla` checks the result-cardinality contract of
`AWSProvider.status`. When EC2 returns no reservation for a requested instance (for example,
after termination), the current method returns an empty list rather than one status per requested
ID. TLC finds the current two-state `CardinalitySafety` counterexample and checks the fixed
branch, which returns an explicit `UNKNOWN` status. The runtime probe uses the real provider with
an empty EC2 response.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsStatusMissingResultCurrent.cfg models/providers/ParslAwsStatusMissingResult.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsStatusMissingResultFixed.cfg models/providers/ParslAwsStatusMissingResult.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_status_missing_result_runtime.py -v
```

This missing-result cardinality boundary is recorded as BUG-143.

`ParslLocalPidAdmission.tla` models the LocalProvider launcher-PID admission boundary. The
current implementation parses any integer suffix, so `PID:0` is recorded as a running resource;
the fixed branch requires a strictly positive PID before publishing the resource. The runtime
probe uses the real provider with a fake successful launcher response and observes that
`os.kill(0, 0)` can make the resource look alive.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalPidAdmissionCurrent.cfg models/providers/ParslLocalPidAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalPidAdmissionFixed.cfg models/providers/ParslLocalPidAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalPidAdmissionNormal.cfg models/providers/ParslLocalPidAdmission.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_pid_admission_runtime.py -v
```

This non-positive launcher-PID boundary is recorded as BUG-212.

`ParslPbsproSubmitShape.tla` models the PBS Pro `qsub` response boundary. The current provider
records every non-empty stdout line as a job and returns the last line, so an extra warning line
can become a pseudo-job. The fixed branch requires one validated scheduler ID per submission.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPbsproSubmitShapeCurrent.cfg models/providers/ParslPbsproSubmitShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPbsproSubmitShapeFixed.cfg models/providers/ParslPbsproSubmitShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPbsproSubmitShapeNormal.cfg models/providers/ParslPbsproSubmitShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_submit_shape_runtime.py -v
```

This PBS Pro submit-response boundary is recorded as BUG-215.

`ParslPBSProLifecycle.tla` composes PBS Pro submission, qstat observations, local resource
ownership, and cancellation. The Current branch permits an empty successful `qsub` response to
publish an untrackable submission and can abort on foreign/malformed status records or stale
cancellation IDs. The Fixed branch rejects empty submissions, preserves running state for a
missing qstat record, isolates malformed/foreign observations, and makes stale cancellation
terminal. The existing PBS Pro runtime probes exercise the concrete parser boundaries.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslPBSProLifecycleCurrent.cfg models/providers/ParslPBSProLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslPBSProLifecycleFixed.cfg models/providers/ParslPBSProLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_pbspro*_runtime.py' -v
```

`ParslClusterStatusRequest.tla` captures the common `ClusterProvider.status` projection. A single
provider-specific `_status()` poll updates local resources, then the public method projects those
records back in the caller's requested order, including duplicate job IDs. The runtime probe uses
the real base-class method with a provider double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterStatusRequest.cfg models/providers/ParslClusterStatusRequest.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_cluster_status_request_runtime.py -v
```

`ParslClusterStatusUnknown.tla` refines the same base-class projection with a job ID that was
removed during the preceding scheduler poll. The current `ClusterProvider.status` performs an
unconditional `resources[jid]` lookup and aborts the whole request; the fixed branch preserves
one response per requested ID by returning an explicit `UNKNOWN` observation.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterStatusUnknownCurrent.cfg models/providers/ParslClusterStatusUnknown.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterStatusUnknownFixed.cfg models/providers/ParslClusterStatusUnknown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_cluster_status_unknown_runtime.py -v
```

This common cluster-provider stale-ID boundary is recorded as BUG-170.

`ParslAWSProviderCancel.tla` models EC2 cancellation after the remote termination call. The
current path can raise when local `resources`/`instances` bookkeeping has already forgotten the
ID; the fixed branch makes that cleanup idempotent. TLC finds the two-state `RemoteSuccessSafety`
counterexample in the stale-ID configuration and checks four generated/two distinct states in the
fixed and linger configurations.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAWSProviderCancelMissingCurrent.cfg models/providers/ParslAWSProviderCancel.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAWSProviderCancelMissingFixed.cfg models/providers/ParslAWSProviderCancel.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAWSProviderCancelLinger.cfg models/providers/ParslAWSProviderCancel.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_cancel_runtime.py -v
```

`ParslGoogleCloudZoneSelection.tla` models the region-to-zone lookup performed by
`GoogleCloudProvider.get_zone`. The current implementation silently returns `None` when no UP
zone matches the requested region, allowing construction to continue until a later API request
uses an invalid zone. The current configuration reaches `ZoneSelectionSafety` after two states;
the fixed configuration rejects the missing zone and checks four generated states. The runtime
probe uses a fake Compute Engine zones response and observes the current `None` result.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudZoneSelectionCurrent.cfg models/providers/ParslGoogleCloudZoneSelection.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudZoneSelectionFixed.cfg models/providers/ParslGoogleCloudZoneSelection.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudZoneSelectionValid.cfg models/providers/ParslGoogleCloudZoneSelection.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_googlecloud_zone_selection_runtime.py -v
```

`ParslGoogleCloudCancel.tla` models the GCE cancellation bookkeeping boundary. The current
provider returns success after the remote delete but leaves the local resource marked `RUNNING`;
the fixed branch marks it `COMPLETED`. TLC finds the two-state `DeleteStatusSafety` counterexample
in the current configuration and checks four generated/two distinct states in the fixed branch.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudCancel.cfg models/providers/ParslGoogleCloudCancel.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudCancelFixed.cfg models/providers/ParslGoogleCloudCancel.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_googlecloud_cancel_runtime.py -v
```

`ParslGoogleCloudStatus.tla` models status-table evolution at the GCE polling boundary. The
current implementation indexes the translation table directly, so an unknown provider state
crashes polling; the fixed branch maps it to `UNKNOWN`. TLC finds the two-state
`PollingSafety` counterexample in the current configuration and checks four generated/two
distinct states in both the fixed and known-state configurations.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudStatus.cfg models/providers/ParslGoogleCloudStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudStatusFixed.cfg models/providers/ParslGoogleCloudStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudStatusPresent.cfg models/providers/ParslGoogleCloudStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_googlecloud_status_runtime.py -v
```

`ParslGoogleCloudUnknownFutureMonitoring.tla` composes the unknown GCE status translation with
poller progress, Future completion, and monitoring publication. The Current branch aborts on the
unknown provider state before a healthy observation can complete the task; the Fixed branch maps
it to an isolated `UNKNOWN` observation and continues. `UnknownIsolation` and
`CompletionPropagation` make the cross-layer contract executable.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudUnknownFutureMonitoringCurrent.cfg models/providers/ParslGoogleCloudUnknownFutureMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGoogleCloudUnknownFutureMonitoringFixed.cfg models/providers/ParslGoogleCloudUnknownFutureMonitoring.tla
```

`ParslGoogleCloudLifecycle.tla` composes GCE instance submission, a status batch with one failed
remote lookup and one healthy VM, and subsequent cancellation. The Current branch aborts the
batch on the first API exception; the Fixed branch records `UNKNOWN` for the failed VM, preserves
the healthy observation, and keeps the instance cancellable.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslGoogleCloudLifecycleCurrent.cfg \
  models/providers/ParslGoogleCloudLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslGoogleCloudLifecycleFixed.cfg \
  models/providers/ParslGoogleCloudLifecycle.tla
```

`ParslPollerCloseScaleInRace.tla` refines the `JobStatusPoller.close(timeout)` lifecycle. The
current implementation calls `Timer.close`, then scales in every executor even when the timer
thread is still running a provider-status callback after the join timeout. The fixed branch keeps
the timer in a stopping state until the callback is quiescent and checks `ScaleInAfterPollQuiescence`.
The runtime probe uses the real `JobStatusPoller.close` method with a controlled live-thread and
executor double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPollerCloseScaleInRaceCurrent.cfg models/providers/ParslPollerCloseScaleInRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPollerCloseScaleInRaceFixed.cfg models/providers/ParslPollerCloseScaleInRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_poller_close_scale_in_runtime.py -v
```

This shutdown/concurrency boundary is recorded as BUG-122: scale-in can begin while the poller
callback thread remains alive after a timed join.

`ParslPollerDuplicateExecutor.tla` models repeated calls to
`JobStatusPoller.add_executors`. The current list-based registration appends the same pollable
executor more than once, so one timer tick can poll and later scale in it repeatedly. The fixed
branch makes registration idempotent. The runtime probe calls the concrete registration method
twice with the same executor double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPollerDuplicateExecutorCurrent.cfg models/providers/ParslPollerDuplicateExecutor.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPollerDuplicateExecutorFixed.cfg models/providers/ParslPollerDuplicateExecutor.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_poller_duplicate_executor_runtime.py -v
```

This registration-idempotence boundary is recorded as BUG-123: repeated registration appends the
same executor and duplicates poller/strategy work.

`ParslPollerExecutorIsolation.tla` models two independent executors in one
`JobStatusPoller.poll` tick. The current implementation has no per-executor exception boundary,
so a transient provider/status exception from the first executor terminates the polling callback
before the second executor is sampled. The fixed branch isolates the first failure and continues.
`tests/test_poller_executor_isolation_runtime.py` invokes the concrete poller with one failing
and one healthy executor double. This source-aligned boundary is recorded as BUG-269.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPollerExecutorIsolationCurrent.cfg models/providers/ParslPollerExecutorIsolation.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPollerExecutorIsolationFixed.cfg models/providers/ParslPollerExecutorIsolation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_poller_executor_isolation_runtime.py -v
```

`ParslKubernetesUnknownJob.tla` models a status request for an id absent from the provider's
local resource map. The current `status()` path raises `KeyError`; the fixed branch returns an
explicit UNKNOWN status. The runtime probe isolates the concrete lookup with an empty resource
map.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesUnknownJobCurrent.cfg models/providers/ParslKubernetesUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesUnknownJobFixed.cfg models/providers/ParslKubernetesUnknownJob.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_unknown_job_runtime.py -v
```

`ParslKubernetesCancelUnknownJob.tla` covers the corresponding cancellation race. If cleanup has
removed a pod from the local resource map before `cancel()` arrives, the current `_get_pod_name`
lookup raises `KeyError`; the fixed branch treats the stale cancel as a non-throwing no-op. TLC
finds the current `CancelDoesNotCrash` counterexample (4 states generated) and checks the fixed
branch (6 states generated). The runtime probe invokes the real provider with an empty resource
map.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesCancelUnknownJobCurrent.cfg models/providers/ParslKubernetesCancelUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesCancelUnknownJobFixed.cfg models/providers/ParslKubernetesCancelUnknownJob.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_cancel_unknown_runtime.py -v
```

`ParslKubernetesAdmission.tla` connects pod phases to executor admission. `submit()` creates a
Pending pod, but the current provider records the local job as RUNNING immediately, so a task can
be admitted before Kubernetes observes a Running pod. TLC finds `JobPhaseSafety` at depth 2. The
fixed branch keeps the job PENDING until `PollRunning` and checks 11 distinct states. The submit,
polling, and stale-job runtime probes cover the concrete provider methods.

This admission mismatch is recorded as BUG-126: the provider's local status can advertise
capacity before the pod is actually runnable.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesAdmissionCurrent.cfg models/providers/ParslKubernetesAdmission.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesAdmissionFixed.cfg models/providers/ParslKubernetesAdmission.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_submit_runtime.py tests/test_kubernetes_polling_runtime.py tests/test_kubernetes_unknown_job_runtime.py -v
```

`ParslKubernetesPolling.tla` refines the provider's read-error path. When a running pod cannot
be read, the current identity comparison fails to translate the local status to `UNKNOWN`; the
candidate fixed branch uses value-based state handling and exposes the uncertainty. TLC finds the
current `ErrorVisibility` counterexample (7 generated states) and checks 85 generated/23 distinct
fixed states. The runtime probe uses a real provider object with a failing Kubernetes client.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesPolling.cfg models/providers/ParslKubernetesPolling.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesPollingFixed.cfg models/providers/ParslKubernetesPolling.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_kubernetes_polling_runtime.py -v
```

`ParslKubernetesLifecycle.tla` composes the Kubernetes submit, polling, and cancellation
boundaries into one small state machine. It requires terminal snapshots to remain stable, makes
poll errors visible as `UNKNOWN`, and rejects a late pod phase after local cancellation. The
current configuration deliberately exposes stale-terminal and hidden-error counterexamples; the
fixed configuration is the smoke-gated baseline. The existing submit, polling, and cancellation
runtime probes provide source-level evidence for the individual transitions.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesLifecycleCurrent.cfg models/providers/ParslKubernetesLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslKubernetesLifecycleFixed.cfg models/providers/ParslKubernetesLifecycle.tla
```

`ParslCondorUnknownJob.tla` covers the same stale-id boundary in Condor's status path. The
current provider raises `KeyError` when the requested id is absent from `resources`; the fixed
branch returns UNKNOWN. The runtime probe isolates the lookup with an empty resource map.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorUnknownJobCurrent.cfg models/providers/ParslCondorUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorUnknownJobFixed.cfg models/providers/ParslCondorUnknownJob.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_unknown_job_runtime.py -v
```

`ParslCondorLifecycle.tla` composes successful `condor_submit`, failed or malformed `condor_q`
responses, foreign records, and later cancellation. The Current branch aborts the resource
lifecycle at a status-parser boundary; the Fixed branch preserves the previous resource state,
ignores unrelated records, and reaches cancellation.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslCondorLifecycleCurrent.cfg \
  models/providers/ParslCondorLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslCondorLifecycleFixed.cfg \
  models/providers/ParslCondorLifecycle.tla
```

`ParslCondorMalformedStatusLine.tla` refines Condor polling to a successful command with a
truncated scheduler line. The current parser still indexes the missing state token and raises
`IndexError`; the fixed branch skips the malformed record and preserves the known RUNNING state.
TLC finds the current `NoParserCrash` counterexample (2 states generated) and checks the fixed
branch (4 states generated). The runtime probe drives the real parser with return code zero and a
one-token line.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorMalformedStatusLineCurrent.cfg models/providers/ParslCondorMalformedStatusLine.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorMalformedStatusLineFixed.cfg models/providers/ParslCondorMalformedStatusLine.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_malformed_status_line_runtime.py -v
```

`ParslCondorMalformedFutureMonitoring.tla` composes the failed/truncated `condor_q` boundary
with poller progress, Future completion, and monitoring publication. The Current branch crashes
before a later valid status can resolve the task; the Fixed branch preserves the poller and
reaches the normal terminal path. `PollerProgress` and `CompletionPropagation` are checked
together with the existing concrete malformed-line probe.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorMalformedFutureMonitoringCurrent.cfg models/providers/ParslCondorMalformedFutureMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorMalformedFutureMonitoringFixed.cfg models/providers/ParslCondorMalformedFutureMonitoring.tla
```

`ParslLocalTasksPerNode.tla` models the LocalProvider resource-input boundary. A zero
`tasks_per_node` value currently creates a process that fails in the generated launcher script;
the fixed branch rejects it before launch. The runtime probe submits `true` to a real local
provider and observes the failed job.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalTasksPerNodeCurrent.cfg models/providers/ParslLocalTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalTasksPerNodeFixed.cfg models/providers/ParslLocalTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalTasksPerNodeValid.cfg models/providers/ParslLocalTasksPerNode.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_tasks_per_node_runtime.py -v
```

This resource-admission boundary is recorded as BUG-112: zero `tasks_per_node` is accepted and
only surfaces as a failed local job after launch.

`ParslLocalProviderSubmitCleanup.tla` models the failed-launch path after
`LocalProvider.submit` has written its worker script. The current provider raises `SubmitException`
but leaves the newly-created `.sh` file in `script_dir`; the fixed branch removes the script
before reporting failure. The runtime probe patches only the launch command and calls the real
provider method.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderSubmitCleanupCurrent.cfg models/providers/ParslLocalProviderSubmitCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderSubmitCleanupFixed.cfg models/providers/ParslLocalProviderSubmitCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderSubmitCleanupSuccess.cfg models/providers/ParslLocalProviderSubmitCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_provider_submit_cleanup_runtime.py -v
```

This failed-provisioning cleanup boundary is recorded as BUG-121: a failed launch leaves the
newly-created LocalProvider submit script behind.

`ParslGridEngineStatusBatch.tla` refines Grid Engine polling with a truncated `qstat` record
followed by a valid record for the known job. The current parser indexes the missing state field
and aborts before applying the valid record; the candidate fixed path skips only the malformed
record and continues. The runtime probe drives the real `_status` parser with both records.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineStatusBatchCurrent.cfg models/providers/ParslGridEngineStatusBatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineStatusBatchFixed.cfg models/providers/ParslGridEngineStatusBatch.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_status_batch_runtime.py -v
```

`ParslGridEngineMissingStatus.tla` models a successful but empty `qstat` response. The current
Grid Engine provider marks every locally known job absent from the response as `COMPLETED`, even
when the scheduler has not supplied an explicit terminal record. The fixed branch preserves an
`UNKNOWN` observation until a job record is present. The runtime probe calls the real `_status`
method with an empty successful response.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineMissingStatusCurrent.cfg models/providers/ParslGridEngineMissingStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineMissingStatusFixed.cfg models/providers/ParslGridEngineMissingStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_missing_status_runtime.py -v
```

This successful-empty status boundary is recorded as BUG-243.

`ParslGridEngineSubmitShape.tla` models the submit admission boundary. The current provider
publishes any first non-empty successful `qsub` output line as a pending resource, including
warning text; the fixed branch requires a valid scheduler identifier before publication.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineSubmitShapeCurrent.cfg models/providers/ParslGridEngineSubmitShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineSubmitShapeFixed.cfg models/providers/ParslGridEngineSubmitShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineSubmitShapeNormal.cfg models/providers/ParslGridEngineSubmitShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_submit_shape_runtime.py -v
```

`ParslGridEngineEmptySubmit.tla` covers the empty-success response. The current provider returns
`None` after a zero exit code with no non-empty output; the fixed branch rejects the submission
before the scaling layer can publish an invalid block mapping.

`ParslGridEngineSubmit.tla` is the smaller lifecycle abstraction beneath those refinements. It
separates submit-script publication, qsub failure, empty successful output, and valid job-id
registration; the valid configuration is now part of the foundational smoke gate.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineEmptySubmitCurrent.cfg models/providers/ParslGridEngineEmptySubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineEmptySubmitFixed.cfg models/providers/ParslGridEngineEmptySubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslGridEngineEmptySubmitNormal.cfg models/providers/ParslGridEngineEmptySubmit.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_grid_engine_empty_submit_runtime.py -v
```

`ParslGridEngineLifecycle.tla` composes Grid Engine qsub admission, qstat observations, local
resource ownership, and qdel cancellation. The Current branch can treat a missing job as
completed, abort on malformed/duplicate/foreign rows, or crash on a stale cancellation record.
The Fixed branch requires explicit terminal evidence, isolates invalid rows, and makes stale
cancellation terminal. Existing Grid Engine runtime probes cover the concrete paths.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslGridEngineLifecycleCurrent.cfg models/providers/ParslGridEngineLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslGridEngineLifecycleFixed.cfg models/providers/ParslGridEngineLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_grid_engine*_runtime.py' -v
```

`ParslSlurmEmptyJobId.tla` models the default submit regex boundary. The current `\\S*` capture
accepts an empty identifier from a truncated success line and publishes an empty resource key;
the fixed branch requires a non-empty ID before registration.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmEmptyJobIdCurrent.cfg models/providers/ParslSlurmEmptyJobId.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmEmptyJobIdFixed.cfg models/providers/ParslSlurmEmptyJobId.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmEmptyJobIdNormal.cfg models/providers/ParslSlurmEmptyJobId.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_empty_job_id_runtime.py -v
```

`ParslTorqueSubmitShape.tla` models the multi-line qsub response boundary. The current provider
registers every non-empty line and returns the last one; the fixed branch validates and publishes
exactly one scheduler identifier.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueSubmitShapeCurrent.cfg models/providers/ParslTorqueSubmitShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueSubmitShapeFixed.cfg models/providers/ParslTorqueSubmitShape.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueSubmitShapeNormal.cfg models/providers/ParslTorqueSubmitShape.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_submit_shape_runtime.py -v
```

`ParslLocalProviderCancelUnknown.tla` models cancellation after a local job has already been
removed from `resources`. The current `LocalProvider.cancel()` indexes the missing id and raises
`KeyError`; the fixed branch treats the stale cancellation as an unsuccessful, non-throwing
result. The runtime probe calls the real provider with an empty resource map.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderCancelUnknownCurrent.cfg models/providers/ParslLocalProviderCancelUnknown.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderCancelUnknownFixed.cfg models/providers/ParslLocalProviderCancelUnknown.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_provider_cancel_unknown_runtime.py -v
```

This cancellation-idempotence boundary is recorded as BUG-116: a stale local job ID raises
`KeyError` instead of being handled as a cancellation miss.

`ParslLocalCancelFailure.tla` covers the adjacent command-result boundary: a non-zero local kill
must not be returned as successful cancellation while the resource is still running. The runtime
probe is `tests/test_local_cancel_failure_runtime.py`.

ParslLocalUnknownJobStatus.tla models the analogous stale-id boundary in LocalProvider.status().
The refined lifecycle explicitly removes a resource before a polling pass requests its old id;
the current result comprehension then indexes the missing entry and raises KeyError. The fixed
branch returns an explicit UNKNOWN status. TLC finds the current PollDoesNotCrash counterexample
(4 states generated) and checks the fixed branch (6 states generated). The runtime probe invokes
the real provider after removing a local resource entry.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalUnknownJobStatusCurrent.cfg models/providers/ParslLocalUnknownJobStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalUnknownJobStatusFixed.cfg models/providers/ParslLocalUnknownJobStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_unknown_job_status_runtime.py -v
```

`ParslLocalExitFileMissing.tla` models a live LocalProvider process whose `.ec` exit-code file is
not visible yet. The current `status()` path reads that file before its parse exception guard, so a
transient `FileNotFoundError` escapes and aborts the polling pass. The fixed branch records an
explicit UNKNOWN observation and keeps polling. TLC finds the current two-state counterexample
and checks the fixed two-state behavior; the runtime probe invokes the real provider with a
missing-file double. This boundary is recorded as BUG-147.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalExitFileMissingCurrent.cfg models/providers/ParslLocalExitFileMissing.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalExitFileMissingFixed.cfg models/providers/ParslLocalExitFileMissing.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_exit_file_missing_runtime.py -v
```

`ParslWalltimeParsing.tla` models the provider walltime conversion in
[`parsl/utils.py`](https://github.com/Parsl/Parsl/blob/master/parsl/utils.py). The current
`wtime_to_minutes` implementation truncates seconds, so a positive request such as `00:00:59`
becomes zero minutes. The fixed branch rounds a positive sub-minute request up to one minute;
the valid branch covers zero and whole-minute durations. The runtime probe checks the current
conversion against the real helper.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslWalltimeParsingCurrent.cfg models/providers/ParslWalltimeParsing.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslWalltimeParsingFixed.cfg models/providers/ParslWalltimeParsing.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslWalltimeParsingValid.cfg models/providers/ParslWalltimeParsing.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_walltime_parsing_runtime.py -v
```

This duration-conversion boundary is recorded as BUG-120: a positive sub-minute walltime is
truncated to zero scheduler minutes.

`ParslAzureStatusBookkeeping.tla` checks consistency between the status returned by Azure and
the provider's local `resources` map. The current `status()` method translates `VM running` but
does not write that value back, leaving local bookkeeping at PENDING. The fixed branch records
the translated status. The runtime probe uses a fake Azure VM response.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureStatusBookkeepingCurrent.cfg models/providers/ParslAzureStatusBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureStatusBookkeepingFixed.cfg models/providers/ParslAzureStatusBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_status_bookkeeping_runtime.py -v
```

`ParslAwsUnknownInstance.tla` models an EC2 status response containing an instance absent from
`AWSProvider.resources`. The current status loop indexes the local map directly, so a stale or
externally-created instance raises `KeyError` and aborts the poll. The fixed branch records an
explicit UNKNOWN observation and keeps the polling pass alive. TLC finds the current
`PollDoesNotCrash` counterexample (2 states generated) and checks the fixed branch (4 states
generated). The runtime probe invokes the real AWS provider method with a fake EC2 response.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsUnknownInstanceCurrent.cfg models/providers/ParslAwsUnknownInstance.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsUnknownInstanceFixed.cfg models/providers/ParslAwsUnknownInstance.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_unknown_instance_runtime.py -v
```

`ParslAwsSubmitEmptyResponse.tla` models an EC2 launch response with no instances. The current
`submit()` destructures the empty list before checking the result, raising `ValueError`; the fixed
branch treats it as a failed submission and leaves `resources` unchanged. TLC finds the current
`SubmitDoesNotCrash` counterexample (2 states generated) and checks the fixed branch (4 states
generated). `tests/test_aws_submit_runtime.py` drives the real method and reproduces the empty
response exception.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsSubmitEmptyResponseCurrent.cfg models/providers/ParslAwsSubmitEmptyResponse.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAwsSubmitEmptyResponseFixed.cfg models/providers/ParslAwsSubmitEmptyResponse.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_aws_submit_runtime.py -v
```

`ParslTorqueStatusFailure.tla` models the return-code boundary around `qstat`. The current
Torque parser ignores a non-zero command result and still consumes stdout, so stale output can
overwrite a running local resource. The fixed branch returns early and preserves the known
status. The runtime probe supplies a failed command with a stale completion line.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueStatusFailureCurrent.cfg models/providers/ParslTorqueStatusFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueStatusFailureFixed.cfg models/providers/ParslTorqueStatusFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_status_failure_runtime.py -v
```

`ParslTorqueDuplicateStatus.tla` models duplicate scheduler rows in the same `qstat` response.
The current parser removes the same local job twice and raises `ValueError`; the fixed branch
ignores the duplicate while preserving polling progress. TLC finds the three-state
`DuplicateSafety` counterexample in the current configuration and checks six generated/three
distinct states in both fixed and unique-row configurations.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueDuplicateStatusCurrent.cfg models/providers/ParslTorqueDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueDuplicateStatusFixed.cfg models/providers/ParslTorqueDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueDuplicateStatusUnique.cfg models/providers/ParslTorqueDuplicateStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_duplicate_status_runtime.py -v
```

`ParslTorqueMissingStatus.tla` models a successful but empty `qstat` response. The current
Torque provider marks every locally known job absent from the response as `COMPLETED`, even when
the scheduler has not supplied an explicit terminal record. The fixed branch preserves an
`UNKNOWN` observation until a job record is present. The runtime probe calls the real `_status`
method with an empty successful response.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueMissingStatusCurrent.cfg models/providers/ParslTorqueMissingStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueMissingStatusFixed.cfg models/providers/ParslTorqueMissingStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_missing_status_runtime.py -v
```

This successful-empty status boundary is recorded as BUG-241.

`ParslTorqueLifecycle.tla` composes Torque submission, qstat observations, local resource
ownership, and qdel cancellation. The Current branch can treat a missing qstat row as completion,
abort on foreign or malformed rows, and report a successful cancellation as completion. The Fixed
branch requires explicit terminal evidence, isolates bad rows, and preserves cancellation as a
terminal cancelled state. Existing Torque runtime probes cover the concrete submit, status, and
cancel paths.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslTorqueLifecycleCurrent.cfg models/providers/ParslTorqueLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslTorqueLifecycleFixed.cfg models/providers/ParslTorqueLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_torque*_runtime.py' -v
```

`ParslLSFDuplicateStatus.tla` covers the analogous LSF `bjobs` response. The current set-based
bookkeeping raises `KeyError` on a duplicate job line; the fixed branch ignores the second line.
TLC checks six generated/three distinct states in the fixed and unique-row configurations.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFDuplicateStatusCurrent.cfg models/providers/ParslLSFDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFDuplicateStatusFixed.cfg models/providers/ParslLSFDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFDuplicateStatusUnique.cfg models/providers/ParslLSFDuplicateStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_lsf_duplicate_status_runtime.py -v
```

`ParslSlurmMalformedLine.tla` covers truncated non-empty records from `sacct` or `squeue`.
The current parser unpacks every line into a job id and state, so a line missing the state token
raises `ValueError` and aborts the polling pass. The fixed branch skips malformed records and
preserves known local state. The runtime probe invokes the concrete Slurm parser with a one-token
line.

This malformed-record boundary is recorded as BUG-130 because one bad scheduler line can abort
the entire status poll.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmMalformedLineCurrent.cfg models/providers/ParslSlurmMalformedLine.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmMalformedLineFixed.cfg models/providers/ParslSlurmMalformedLine.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_malformed_line_runtime.py -v
```

`ParslSlurmMalformedFutureMonitoring.tla` composes BUG-130's parser boundary with a logical
task, its Future, and monitoring publication. The Current branch crashes the poller after the
truncated line, so a later valid completion cannot propagate; the Fixed branch skips the bad
record and reaches the normal terminal path. `PollerProgress` and `CompletionPropagation` make
that cross-layer requirement executable.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmMalformedFutureMonitoringCurrent.cfg models/providers/ParslSlurmMalformedFutureMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmMalformedFutureMonitoringFixed.cfg models/providers/ParslSlurmMalformedFutureMonitoring.tla
```

`ParslSlurmDuplicateStatus.tla` models duplicate scheduler rows for the same Slurm job. The
current missing-job bookkeeping removes the ID twice and raises `KeyError`; the fixed branch
ignores the duplicate and continues polling. TLC checks six generated/three distinct states in
the fixed and unique-row configurations.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmDuplicateStatusCurrent.cfg models/providers/ParslSlurmDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmDuplicateStatusFixed.cfg models/providers/ParslSlurmDuplicateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmDuplicateStatusUnique.cfg models/providers/ParslSlurmDuplicateStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_duplicate_status_runtime.py -v
```

`ParslSlurmBatchStrict.tla` models the Python-version fallback for Slurm's `batched` helper.
On Python versions before 3.12, the fallback accepts `strict=True` but yields a short final
batch instead of raising for an incomplete batch. The fixed branch enforces the standard strict
contract. The runtime probe calls the real helper with three items and a batch size of two.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmBatchStrictCurrent.cfg models/providers/ParslSlurmBatchStrict.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmBatchStrictFixed.cfg models/providers/ParslSlurmBatchStrict.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmBatchStrictValid.cfg models/providers/ParslSlurmBatchStrict.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_batch_strict_runtime.py -v
```

`ParslSlurmCancelBatch.tla` refines cancellation to a known job followed by a stale local ID.
The current batch marks the known prefix cancelled and then raises on the stale entry; the fixed
branch treats the stale ID as an idempotent miss and completes the batch. The runtime probe in
`tests/test_slurm_cancel_runtime.py` checks the partial-progress behavior.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmCancelBatchCurrent.cfg models/providers/ParslSlurmCancelBatch.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmCancelBatchFixed.cfg models/providers/ParslSlurmCancelBatch.tla
```

`ParslSlurmLifecycle.tla` composes the provider path from a valid `sbatch` admission through
foreign, malformed, and duplicate scheduler records to cancellation. The Current branch aborts
the lifecycle on one of those parser/bookkeeping boundaries; the Fixed branch isolates records,
preserves the local resource, and treats a stale cancellation ID as idempotent.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslSlurmLifecycleCurrent.cfg \
  models/providers/ParslSlurmLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=50000 -seed 1 \
  -config models/providers/ParslSlurmLifecycleFixed.cfg \
  models/providers/ParslSlurmLifecycle.tla
```

`ParslSlurmTasksPerNode.tla` covers submit-time resource validation when `cores_per_node` is
configured. The current `SlurmProvider.submit` divides by `tasks_per_node` before validating it,
so zero reaches a raw `ZeroDivisionError`; the fixed branch rejects the request before script
construction. This boundary is recorded as BUG-169 and is exercised by
`tests/test_slurm_tasks_per_node_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmTasksPerNodeCurrent.cfg models/providers/ParslSlurmTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmTasksPerNodeFixed.cfg models/providers/ParslSlurmTasksPerNode.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_tasks_per_node_runtime.py -v
```

This compatibility-boundary finding is recorded as BUG-117: the fallback accepts an incomplete
final batch even when `strict=True`.

`ParslLSFSubmit.tla` is the compact LSF `bsub` submission lifecycle. It separates script writing,
command failure, successful-but-unparseable output, and valid marker/job-id registration; only the
valid path creates a pending resource. The valid configuration is now part of the foundational
smoke gate.

`ParslLSFResourceValidation.tla` models LSF's core-based resource derivation. The current
constructor rejects zero `cores_per_node` but accepts a negative value and computes a negative
`nodes_per_block`; the fixed branch rejects all non-positive values. The runtime probe invokes
the real constructor with `request_by_nodes=False`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFResourceValidationCurrent.cfg models/providers/ParslLSFResourceValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFResourceValidationFixed.cfg models/providers/ParslLSFResourceValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFResourceValidationValid.cfg models/providers/ParslLSFResourceValidation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_lsf_resource_validation_runtime.py -v
```

This resource-derivation boundary is recorded as BUG-115: a negative `cores_per_node` produces
negative node capacity instead of a configuration error.

`ParslTorqueTasksPerNode.tla` models Torque's documented `tasks_per_node` constraint. The
current `submit()` path forwards a zero or negative value to the launcher and generated job
configuration; the fixed branch rejects non-positive values before script construction. The
runtime probe uses the real provider with a recording launcher and a failed scheduler command.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueTasksPerNodeCurrent.cfg models/providers/ParslTorqueTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueTasksPerNodeFixed.cfg models/providers/ParslTorqueTasksPerNode.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslTorqueTasksPerNodeValid.cfg models/providers/ParslTorqueTasksPerNode.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_torque_tasks_per_node_runtime.py -v
```

This resource-admission boundary is recorded as BUG-119: negative `tasks_per_node` reaches the
Torque launcher instead of being rejected before script construction.

`ParslCondorCancel.tla` models Condor's chunked cancellation boundary. A successful scheduler
cancel transitions only locally owned resources, leaves unknown IDs absent, and reports one
success result per requested ID; a failed chunk preserves local state and reports failure. The
normal configuration is now part of the foundational smoke gate.

`ParslCondorChunkSize.tla` models Condor's `cmd_chunk_size` batching parameter. The current
`_chunker` helper silently treats a zero size as an unbounded chunk; the fixed branch rejects
non-positive sizes before scheduler polling or cancellation. The runtime probe calls the real
helper with two job ids and a zero size.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorChunkSizeCurrent.cfg models/providers/ParslCondorChunkSize.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorChunkSizeFixed.cfg models/providers/ParslCondorChunkSize.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorChunkSizeValid.cfg models/providers/ParslCondorChunkSize.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_chunk_size_runtime.py -v
```

This provider-configuration boundary is recorded as BUG-111: nonpositive `cmd_chunk_size` values
are accepted and collapse batching into one unbounded scheduler command.

`ParslSlurmForeignJob.tla` audits the status parser's local-resource boundary. Slurm output can
contain a job id that is already forgotten locally or belongs to another submission; the current
implementation indexes it directly and raises `KeyError`. The fixed branch ignores foreign
records and keeps polling local jobs. The runtime probe drives the real `_status` method with a
foreign scheduler line.

`ParslProviderStatusBatch.tla` is the provider-neutral abstraction beneath that scheduler-specific
path. It bounds batch size, preserves all previously observed states when the scheduler command
fails, and makes missing jobs explicit rather than silently mixing partial updates. The full
configuration is now part of the foundational smoke gate.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmForeignJobCurrent.cfg models/providers/ParslSlurmForeignJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmForeignJobFixed.cfg models/providers/ParslSlurmForeignJob.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_foreign_job_runtime.py -v
```

`ParslPBSProMalformedJSON.tla` covers the parser boundary before PBS Pro job-id lookup. A
malformed `qstat -x -F json` response currently lets `json.loads` raise out of `_status`, while
the fixed branch preserves the last known status for the next polling cycle. The runtime probe
invokes the real PBS Pro status method with truncated JSON.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProMalformedJSONCurrent.cfg models/providers/ParslPBSProMalformedJSON.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProMalformedJSONFixed.cfg models/providers/ParslPBSProMalformedJSON.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_malformed_json_runtime.py -v
```

`ParslPBSProMalformedFutureMonitoring.tla` composes the malformed `qstat` JSON boundary with
poller progress, Future completion, and monitoring publication. The Current branch crashes before
a later valid poll can resolve the task; the Fixed branch isolates the decode error and reaches
the normal terminal path. `PollerProgress` and `CompletionPropagation` are checked together with
the concrete PBS Pro runtime probe.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProMalformedFutureMonitoringCurrent.cfg models/providers/ParslPBSProMalformedFutureMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPBSProMalformedFutureMonitoringFixed.cfg models/providers/ParslPBSProMalformedFutureMonitoring.tla
```

`ParslPbsproMissingStatus.tla` models the successful-but-incomplete `qstat` boundary. The
current provider marks every locally known job absent from the response as `COMPLETED`, even
when the scheduler returned an empty `Jobs` object. The fixed branch preserves a non-terminal
`UNKNOWN` observation until an explicit record is received. The runtime probe calls the real
PBS Pro `_status` method with an empty successful response.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPbsproMissingStatusCurrent.cfg models/providers/ParslPbsproMissingStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPbsproMissingStatusFixed.cfg models/providers/ParslPbsproMissingStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_missing_status_runtime.py -v
```

This successful-empty status boundary is recorded as BUG-236.

`ParslPbsproStatusBatchIsolation.tla` composes the same parser boundary with a two-job polling
batch: one malformed JSON record and one valid running record. The current implementation aborts
inside the malformed record before the independent valid observation is processed. The fixed
branch isolates the malformed entry as `UNKNOWN`, preserves the polling loop, and still records
the valid job. The runtime probe feeds the real `_status` method both records and confirms that
the current branch raises before processing the valid record.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPbsproStatusBatchIsolationCurrent.cfg models/providers/ParslPbsproStatusBatchIsolation.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslPbsproStatusBatchIsolationFixed.cfg models/providers/ParslPbsproStatusBatchIsolation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pbspro_status_batch_isolation_runtime.py -v
```

This batch-isolation boundary is recorded as BUG-264.

`ParslProviderPollClockRollback.tla` models `BlockProviderExecutor.poll_facade` from
[`executors/status_handling.py`](https://github.com/Parsl/Parsl/blob/master/parsl/executors/status_handling.py).
The current wall-clock guard can suppress provider status polling after `time.time()` moves
backward; TLC finds the two-state rollback counterexample. The fixed branch resets its polling
baseline on rollback. [`tests/test_provider_poll_clock_rollback_runtime.py`](../tests/test_provider_poll_clock_rollback_runtime.py)
reproduces the current behavior with a fake provider and a backward wall-clock step.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPollClockRollbackCurrent.cfg models/providers/ParslProviderPollClockRollback.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPollClockRollbackFixed.cfg models/providers/ParslProviderPollClockRollback.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_provider_poll_clock_rollback_runtime.py -v
```

The concrete wall-clock probe is recorded as BUG-118: a backward clock step suppresses a due
provider poll until the old wall-clock baseline is reached.

`ParslLocalProvider.tla` models the `.ec` exit marker, process liveness, cancellation marker, and
status polling race. The current configuration allows a late successful exit marker to override a
previous cancellation request and violates `StrictCancellation`; the fixed configuration gives
cancellation precedence. `tests/test_local_provider_exit_status_runtime.py` reproduces the same
source behavior with a fake `.ec` file and a cancellation marker.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderCurrent.cfg models/providers/ParslLocalProvider.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLocalProviderFixed.cfg models/providers/ParslLocalProvider.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_provider_exit_status_runtime.py -v
```

`ParslLocalLifecycle.tla` is the small composition boundary for the local provider. It connects
submission, process start, `.ec` status interpretation, local-resource loss, and cancellation.
The Current branch reproduces an abort when cancellation reaches a stale local record; the Fixed
branch makes that cancellation terminal and idempotent. The existing end-to-end
`test_local_provider_runtime.py` probe supplies the concrete process, exit-file, and cancellation
checks for this composition.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslLocalLifecycleCurrent.cfg models/providers/ParslLocalLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslLocalLifecycleFixed.cfg models/providers/ParslLocalLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_local_provider_runtime.py -v
```

`ParslCondorEmptySubmit.tla` models the successful-but-empty `condor_submit` response boundary in
`CondorProvider.submit`. The current parser builds an empty job-ID list and then indexes its first
element, leaking `IndexError` instead of reporting a failed provisioning request. The fixed branch
rejects the empty response before indexing it. The runtime probe uses a fake successful command
with empty stdout and checks that no resource is published.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorEmptySubmitCurrent.cfg models/providers/ParslCondorEmptySubmit.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorEmptySubmitFixed.cfg models/providers/ParslCondorEmptySubmit.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_empty_submit_runtime.py -v
```

`ParslClusterSubmitScript.tla` covers the common `ClusterProvider._write_submit_script` boundary.
Valid template substitution publishes the script; missing template keys map to
`SchedulerMissingArgs`, while target I/O failures map to `ScriptPathError`. The runtime probe
checks all three outcomes against the real base-class method.
The valid configuration is now part of the foundational smoke gate; the two error configurations
remain explicit companion checks for failure mapping and publication safety.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterSubmitScript.cfg models/providers/ParslClusterSubmitScript.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterSubmitScriptMissingKey.cfg models/providers/ParslClusterSubmitScript.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterSubmitScriptIOError.cfg models/providers/ParslClusterSubmitScript.tla
```

`ParslLSFMissingJob.tla` refines the concrete LSF `bjobs` polling behavior. When an active job
is absent from the scheduler output, the current provider marks it `COMPLETED`, even though the
absence can also represent a failed job and the source comment notes that failure information is
lost. The fixed branch retains `UNKNOWN` until an explicit scheduler terminal state is seen.
The runtime probe invokes `LSFProvider._status` with empty `bjobs` output.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFMissingJobCurrent.cfg models/providers/ParslLSFMissingJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFMissingJobFixed.cfg models/providers/ParslLSFMissingJob.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_lsf_missing_job_runtime.py -v
```

`ParslLSFMissingJobFutureMonitoring.tla` composes this missing-job result with the logical
Future and monitoring row. The Current branch publishes `succeeded` immediately on absence;
the Fixed branch keeps the Future pending as `UNKNOWN` and only publishes failure after an
explicit terminal observation. `MissingJobSafety`, `SuccessPropagation`, and
`FailurePropagation` check the cross-layer contract.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFMissingJobFutureMonitoringCurrent.cfg models/providers/ParslLSFMissingJobFutureMonitoring.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslLSFMissingJobFutureMonitoringFixed.cfg models/providers/ParslLSFMissingJobFutureMonitoring.tla
```

`ParslLSFLifecycle.tla` composes LSF `bsub` admission, `bjobs` observations, local resource
ownership, and `bkill` cancellation. The Current branch can treat a missing job as completed,
abort on duplicate/foreign/malformed records, or crash when cancellation targets a stale local
record. The Fixed branch requires explicit terminal evidence, isolates invalid rows, and makes
stale cancellation terminal. Existing LSF runtime probes cover the concrete submit, status, and
cancel paths.

```bash
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslLSFLifecycleCurrent.cfg models/providers/ParslLSFLifecycle.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=10000 -seed 1 -config models/providers/ParslLSFLifecycleFixed.cfg models/providers/ParslLSFLifecycle.tla
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_lsf*_runtime.py' -v
```
