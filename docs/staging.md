# Staging and data-transfer models

These models cover stage-in/stage-out dependencies, FTP, HTTP, Rsync, Zip, Globus, file bytes,
partial cleanup, corruption, retries, and multi-output publication.

Files live in [`models/staging/`](../models/staging/).

`ParslGlobusEndpointPath.tla` models the working-directory and endpoint-path guard in
`GlobusStaging._get_globus_endpoint`. The current code accepts the working directory itself but
rejects a valid absolute `local_path` below it because it compares the local path with the common
path rather than accepting descendants. The current configuration produces a counterexample;
the fixed configuration accepts the descendant path while still rejecting a missing working
directory or an unrelated path. `tests/test_globus_endpoint_path_runtime.py` probes the real
helper and records the current rejection.

`ParslFileCleanCopy.tla` models `File.cleancopy()`, which preserves immutable URL metadata while
clearing mutable site-local staging metadata. The current/unsafe branch aliases the old
`local_path` into the copy; the fixed branch produces a clean object. TLC finds the current
two-state `LocalPathIsClean` counterexample and checks four generated/two distinct states in the
fixed branch. The runtime probe checks that the real implementation preserves the original
annotation and gives the copy no local path.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusEndpointPathCurrent.cfg models/staging/ParslGlobusEndpointPath.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusEndpointPathFixed.cfg models/staging/ParslGlobusEndpointPath.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusEndpointPathValid.cfg models/staging/ParslGlobusEndpointPath.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFileCleanCopyCurrent.cfg models/staging/ParslFileCleanCopy.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFileCleanCopyFixed.cfg models/staging/ParslFileCleanCopy.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_endpoint_path_runtime.py -v
/tmp/parsl-venv/bin/python -m unittest tests/test_file_clean_copy_runtime.py -v
```

`ParslGlobusTokenFileAtomicity.tla` models the Globus OAuth token cache. The current
`Globus._save_tokens_to_file` opens the destination with `"w"` before JSON serialization, so a
serialization failure truncates the last valid token file. The fixed branch serializes to a
temporary file and replaces the destination only after success. The runtime probe uses a real
temporary file and the real classmethod with a failing JSON encoder.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityCurrent.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityFixed.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityValid.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_token_file_atomicity_runtime.py -v
```

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

`ParslFileTransferRetry.tla` adds source-content versions to that protocol. If the source file
changes while an asynchronous stage-out is transferring, the current branch publishes the old
captured version and marks the DataFuture ready. TLC finds a `PublicationSafety` counterexample
at depth 8 (133 states generated). The fixed branch marks the transfer stale, retries from the
new source version, and checks 54 distinct states. `ParslFileBytes.tla` contains the more detailed
multi-file byte/checksum abstraction; this model focuses on the version/publication boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFileTransferRetryCurrent.cfg models/staging/ParslFileTransferRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFileTransferRetryFixed.cfg models/staging/ParslFileTransferRetry.tla
```

The direct rsync wrapper boundary is also exercised by
`tests/test_rsync_stageout_version_runtime.py`: a deterministic copy reads version 0, the source
changes to version 1, and the current wrapper still reports success for the old bytes because it
does not carry a source-version or checksum check.

`BeginStageOut`, `SendChunk`, `ReceiveChunk`, and `Publish` correspond to the DataManager/provider
stage-out Future and its temporary buffer; `StartConsumer` is the DFK DataFuture dependency gate.
The concrete byte and DataFuture probes remain in `tests/test_datafuture_runtime.py`,
`tests/test_multi_output_stageout_runtime.py`, and the staging-provider runtime tests.

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

`ParslInputListMutation.tla` covers the caller-owned collection boundary in
`DataFlowKernel._add_input_deps`. The current implementation rewrites the `inputs` list in place
while replacing file descriptors with staged values; the candidate fixed branch copies the list
before rewriting. TLC finds the current two-state `CallerListPreserved` counterexample and checks
the fixed four-state model. The runtime probe invokes the real DFK helper with a staging double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslInputListMutationCurrent.cfg models/dataflow/ParslInputListMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslInputListMutationFixed.cfg models/dataflow/ParslInputListMutation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_input_list_mutation_runtime.py -v
```

`ParslOutputListMutation.tla` covers the corresponding caller-owned collection boundary in
`DataFlowKernel._add_output_deps`. The current implementation rewrites the `outputs` list in
place while replacing descriptors with clean copies for stage-out; the candidate fixed branch
copies the list before rewriting. TLC finds the current two-state `CallerListPreserved`
counterexample and checks the fixed four-state model. The runtime probe invokes the real DFK
helper with a staging double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslOutputListMutationCurrent.cfg models/dataflow/ParslOutputListMutation.tla
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslOutputListMutationFixed.cfg models/dataflow/ParslOutputListMutation.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_output_list_mutation_runtime.py -v
```

`ParslStagingProviderDispatch.tla` models the provider-selection contract in
`DataManager.stage_in` and `stage_out`: providers are checked in configured order, the first
capable provider owns the operation, and a `None` result means that provider completed setup
without creating a wait Future. A Future result creates a dependency gate before the task runs;
no capable provider is an explicit error. `tests/test_staging_provider_dispatch_runtime.py`
exercises these paths against the real `DataManager` with small provider doubles. This stage did
not reproduce a new defect; it makes the dispatch and DataFuture readiness boundary executable.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslStagingProviderDispatchCurrent.cfg models/staging/ParslStagingProviderDispatch.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_staging_provider_dispatch_runtime.py -v
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

`ParslFTPConnectionCleanup.tla` models the FTP socket lifetime around `retrbinary`. The current
failure path leaves the connection open when transfer raises; the fixed branch closes it before
reporting failure. TLC finds the two-state `FailureCleanupSafety` counterexample and checks four
generated/two distinct states in the fixed and success configurations. The runtime probe injects
a failing FTP connection and observes the missing `quit()` call.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPConnectionCleanupCurrent.cfg models/staging/ParslFTPConnectionCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPConnectionCleanupFixed.cfg models/staging/ParslFTPConnectionCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslFTPConnectionCleanupSuccess.cfg models/staging/ParslFTPConnectionCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_ftp_connection_cleanup_runtime.py -v
```

`ParslHTTPPartialCleanup.tla` models HTTP response streaming into a destination file. The current
path publishes the first chunk before a later read failure; the fixed branch removes the partial
bytes before reporting failure. TLC finds the three-state `FailurePublicationSafety`
counterexample and checks six generated/three distinct states in the fixed and success
configurations.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPPartialCleanupCurrent.cfg models/staging/ParslHTTPPartialCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPPartialCleanupFixed.cfg models/staging/ParslHTTPPartialCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPPartialCleanupSuccess.cfg models/staging/ParslHTTPPartialCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_http_partial_cleanup_runtime.py -v
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

`ParslZipStageOut.tla` models archive publication followed by source cleanup. If cleanup fails,
the current retry appends a second member with the same name; the fixed branch replaces the
existing member atomically. The model now checks `NoDuplicateArchiveEntry` in both configurations:
the retry/current configuration produces a counterexample, while the fixed configuration passes.
The real `tests/test_zip_file_transfer_runtime.py` probe observes two archive entries after the
cleanup failure and retry, while preserving the latest bytes on normal ZIP lookup.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslZipStageOutRetry.cfg models/staging/ParslZipStageOut.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslZipStageOutRetryFixed.cfg models/staging/ParslZipStageOut.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zip_file_transfer_runtime.py -v
```
