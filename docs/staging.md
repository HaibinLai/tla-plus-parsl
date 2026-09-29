# Staging and data-transfer models

These models cover stage-in/stage-out dependencies, FTP, HTTP, Rsync, Zip, Globus, file bytes,
partial cleanup, corruption, retries, and multi-output publication.

Files live in [`models/staging/`](../models/staging/).

`ParslRsyncPartialCleanup.tla` models a failed RSync stage-in after a destination has received
partial bytes. The current wrapper raises on the non-zero `rsync` result but leaves the partial
path in place; the fixed branch removes it before reporting failure. The runtime probe exercises
the real wrapper with a temporary destination and a failed command.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncPartialCleanupCurrent.cfg models/staging/ParslRsyncPartialCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncPartialCleanupFixed.cfg models/staging/ParslRsyncPartialCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_rsync_partial_cleanup_runtime.py -v
```

`ParslDataFutureTransfer.tla` connects producer completion, chunked stage-out,
`DataFuture` readiness, and consumer admission. The current configuration allows
publication after a single received chunk and violates `AtomicPublishSafety`; the
fixed configuration requires every chunk to pass checksum validation before the
consumer can run.

The action mapping follows the current source structure:

- `StartStageOut`/`PublishStageOut` abstract `DataManager.stage_out` and the
  output `DataFuture` wiring in `parsl/dataflow/dflow.py`.
- `StartConsumer` is the dependency gate in the DFK: a task that receives a
  `DataFuture` cannot be admitted until that future is complete.
- `SendChunk`, `ReceiveChunk`, `RejectCorrupt`, and `RepairChunk` abstract the
  staging provider's transfer and retry boundary. `bufferToken` represents the
  receiver-side temporary content; publication is the visibility point.

Run the two checks with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataFutureTransfer.cfg models/staging/ParslDataFutureTransfer.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataFutureTransferFixed.cfg models/staging/ParslDataFutureTransfer.tla
```

`ParslDataFutureCancellationPropagation.tla` isolates the parent-cancellation boundary in
`DataFuture.parent_callback`. The current truthiness check treats a cancelled parent as a ready
file, while the fixed branch propagates a non-success terminal state. The existing
`tests/test_datafuture_cancellation_runtime.py` probe reproduces the current behavior with real
`Future` and `DataFuture` objects.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataFutureCancellationPropagationCurrent.cfg models/staging/ParslDataFutureCancellationPropagation.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataFutureCancellationPropagationFixed.cfg models/staging/ParslDataFutureCancellationPropagation.tla
```

`ParslFilePathResolution.tla` isolates the lower-level `File.filepath` contract in
`parsl/data_provider/files.py`. It checks that a `file:` URI resolves directly, that a
`local_path` annotation takes precedence after staging, and that a remote URI without a
local annotation is rejected rather than guessed as a POSIX path. The runtime probe in
`tests/test_file_path_runtime.py` exercises the same three cases against the Python class.

Run it with:

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFilePathResolution.cfg models/staging/ParslFilePathResolution.tla
```

`ParslDataManagerStageInOrdering.tla` models a failure boundary in
`DataManager.optionally_stage_in`: the current order starts `stage_in` before calling
`replace_task`. If wrapper construction raises, the separate stage-in Future can remain
running after the task has failed. The current configuration produces the expected
`NoOrphanTransfer` counterexample; the fixed configuration prepares the wrapper first and
passes the invariant with 4 generated/2 distinct states. The runtime probe uses a fake provider
whose real pending `Future` demonstrates the orphaned transfer.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataManagerStageInOrderingCurrent.cfg models/staging/ParslDataManagerStageInOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataManagerStageInOrderingFixed.cfg models/staging/ParslDataManagerStageInOrdering.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_data_manager_stage_in_ordering_runtime.py -v
```

`ParslDataManagerStageOutOrdering.tla` checks the analogous output path in
`DataFlowKernel._add_output_deps`: `stage_out` starts a separate transfer before
`replace_task_stage_out` constructs the application wrapper. A wrapper exception can therefore
leave an active stage-out Future after task setup fails. The current model violates
`NoOrphanTransfer`; the fixed ordering model passes with 4 generated/2 distinct states. The
runtime probe reproduces the pending transfer with a fake provider.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataManagerStageOutOrderingCurrent.cfg models/staging/ParslDataManagerStageOutOrdering.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataManagerStageOutOrderingFixed.cfg models/staging/ParslDataManagerStageOutOrdering.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_data_manager_stage_out_ordering_runtime.py -v
```

`ParslFTPPartialCleanup.tla` models FTP stage-in failure after a response chunk has already been
written. The current `_ftp_stage_in` path leaves the partial destination visible when
`retrbinary` raises; the fixed branch removes it before reporting failure. The runtime probe
injects a fake FTP connection into the real staging function.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPPartialCleanupCurrent.cfg models/staging/ParslFTPPartialCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPPartialCleanupFixed.cfg models/staging/ParslFTPPartialCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_ftp_partial_cleanup_runtime.py -v
```

`ParslHTTPStatusValidation.tla` models the HTTP response-status boundary. The current in-task
wrapper writes a 404 response body and starts the user task because it never checks the status
code; the fixed branch rejects non-2xx responses before publication. The runtime probe uses a
fake 404 `requests` response against the real wrapper.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStatusValidationCurrent.cfg models/staging/ParslHTTPStatusValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStatusValidationFixed.cfg models/staging/ParslHTTPStatusValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPStatusValidationSuccess.cfg models/staging/ParslHTTPStatusValidation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_http_status_validation_runtime.py -v
```

`ParslZipPathValidation.tla` models malformed `zip:` URLs. The current provider checks only the
scheme, so a path without the required `.zip/` separator is accepted and `zip_path_split` derives
truncated archive and member paths. The fixed branch rejects the URL before staging. The runtime
probe exercises the real `ZipFileStaging` and `zip_path_split` functions.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslZipPathValidationCurrent.cfg models/staging/ParslZipPathValidation.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslZipPathValidationFixed.cfg models/staging/ParslZipPathValidation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zip_path_validation_runtime.py -v
```
