# Provider and scheduler models

These models cover provider allocation, polling, cancellation, status parsing, duplicate or
unknown jobs, scaling, and scheduler-specific behavior for AWS, Azure, Google Cloud, Slurm,
Condor, Grid Engine, LSF, PBS Pro, Torque, Kubernetes, and local providers.

Files live in [`models/providers/`](../models/providers/).

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

`ParslClusterStatusRequest.tla` captures the common `ClusterProvider.status` projection. A single
provider-specific `_status()` poll updates local resources, then the public method projects those
records back in the caller's requested order, including duplicate job IDs. The runtime probe uses
the real base-class method with a provider double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslClusterStatusRequest.cfg models/providers/ParslClusterStatusRequest.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_cluster_status_request_runtime.py -v
```

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

`ParslCondorUnknownJob.tla` covers the same stale-id boundary in Condor's status path. The
current provider raises `KeyError` when the requested id is absent from `resources`; the fixed
branch returns UNKNOWN. The runtime probe isolates the lookup with an empty resource map.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorUnknownJobCurrent.cfg models/providers/ParslCondorUnknownJob.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslCondorUnknownJobFixed.cfg models/providers/ParslCondorUnknownJob.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_condor_unknown_job_runtime.py -v
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

This compatibility-boundary finding is recorded as BUG-117: the fallback accepts an incomplete
final batch even when `strict=True`.

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
cancellation precedence. `tests/test_local_provider_runtime.py` reproduces the same behavior with
a fake `.ec` file and a dead process.

`ParslClusterSubmitScript.tla` covers the common `ClusterProvider._write_submit_script` boundary.
Valid template substitution publishes the script; missing template keys map to
`SchedulerMissingArgs`, while target I/O failures map to `ScriptPathError`. The runtime probe
checks all three outcomes against the real base-class method.

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
