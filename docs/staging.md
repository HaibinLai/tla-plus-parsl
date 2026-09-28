# Staging and data-transfer models

These models cover stage-in/stage-out dependencies, FTP, HTTP, Rsync, Zip, Globus, file bytes,
partial cleanup, corruption, retries, and multi-output publication.

Files live in [`models/staging/`](../models/staging/).

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
