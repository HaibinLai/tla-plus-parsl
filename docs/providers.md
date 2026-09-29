# Provider and scheduler models

These models cover provider allocation, polling, cancellation, status parsing, duplicate or
unknown jobs, scaling, and scheduler-specific behavior for AWS, Azure, Google Cloud, Slurm,
Condor, Grid Engine, LSF, PBS Pro, Torque, Kubernetes, and local providers.

Files live in [`models/providers/`](../models/providers/).

`ParslAzureStatusBookkeeping.tla` checks consistency between the status returned by Azure and
the provider's local `resources` map. The current `status()` method translates `VM running` but
does not write that value back, leaving local bookkeeping at PENDING. The fixed branch records
the translated status. The runtime probe uses a fake Azure VM response.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureStatusBookkeepingCurrent.cfg models/providers/ParslAzureStatusBookkeeping.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslAzureStatusBookkeepingFixed.cfg models/providers/ParslAzureStatusBookkeeping.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_azure_status_bookkeeping_runtime.py -v
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

`ParslSlurmMalformedLine.tla` covers truncated non-empty records from `sacct` or `squeue`.
The current parser unpacks every line into a job id and state, so a line missing the state token
raises `ValueError` and aborts the polling pass. The fixed branch skips malformed records and
preserves known local state. The runtime probe invokes the concrete Slurm parser with a one-token
line.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmMalformedLineCurrent.cfg models/providers/ParslSlurmMalformedLine.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslSlurmMalformedLineFixed.cfg models/providers/ParslSlurmMalformedLine.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_slurm_malformed_line_runtime.py -v
```

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
baseline on rollback. [`tests/test_provider_poll_clock_runtime.py`](../tests/test_provider_poll_clock_runtime.py)
reproduces the current behavior with a fake provider and also checks the normal elapsed-time path.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPollClockRollbackCurrent.cfg models/providers/ParslProviderPollClockRollback.tla
java -cp tla2tools.jar tlc2.TLC -config models/providers/ParslProviderPollClockRollbackFixed.cfg models/providers/ParslProviderPollClockRollback.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_provider_poll_clock_runtime.py -v
```

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
