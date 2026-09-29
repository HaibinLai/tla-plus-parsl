# Provider and scheduler models

These models cover provider allocation, polling, cancellation, status parsing, duplicate or
unknown jobs, scaling, and scheduler-specific behavior for AWS, Azure, Google Cloud, Slurm,
Condor, Grid Engine, LSF, PBS Pro, Torque, Kubernetes, and local providers.

Files live in [`models/providers/`](../models/providers/).

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
