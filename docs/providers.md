# Provider and scheduler models

These models cover provider allocation, polling, cancellation, status parsing, duplicate or
unknown jobs, scaling, and scheduler-specific behavior for AWS, Azure, Google Cloud, Slurm,
Condor, Grid Engine, LSF, PBS Pro, Torque, Kubernetes, and local providers.

Files live in [`models/providers/`](../models/providers/).

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
