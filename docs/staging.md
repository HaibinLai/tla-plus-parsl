# Staging and data-transfer models

These models cover stage-in/stage-out dependencies, FTP, HTTP, Rsync, Zip, Globus, file bytes,
partial cleanup, corruption, retries, and multi-output publication.

Files live in [`models/staging/`](../models/staging/).

The compact cross-layer model [`ParslDataReadyExecution`](../models/core/ParslDataReadyExecution.tla)
connects the staging abstraction to task execution. It transfers bounded symbolic chunks, detects
a source-version change during stage-in, exposes a DataFuture only after publication, and blocks a
dependent task until that Future is ready. Its current branch intentionally publishes the captured
old version; the fixed branch marks the transfer stale and retries before execution.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataReadyExecutionCurrent.cfg models/core/ParslDataReadyExecution.tla
java -cp tla2tools.jar tlc2.TLC -config models/core/ParslDataReadyExecutionFixed.cfg models/core/ParslDataReadyExecution.tla
```

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

`ParslGlobusTransferTimeout.tla` models a Globus transfer that remains `ACTIVE`. The current
`Globus.transfer_file` passes a 60-second timeout to each `task_wait` call but has no overall poll
deadline, so the stage Future can remain pending forever. The fixed branch turns a bounded poll
budget into an explicit timeout outcome. `tests/test_globus_transfer_timeout_runtime.py` stops
the real loop after several active polls to demonstrate the missing outer bound.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityCurrent.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityFixed.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenFileAtomicityValid.cfg models/staging/ParslGlobusTokenFileAtomicity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_token_file_atomicity_runtime.py -v
```

`ParslGlobusTokenSchema.tla` covers the next credential boundary: a JSON token file may parse
successfully while missing the `transfer.api.globus.org` service record. The current
`_get_native_app_authorizer` path treats that truthy mapping as usable and exposes a raw
`KeyError`; the fixed branch rejects the schema and re-enters authentication. The runtime probe
uses the real classmethod with a deliberately incomplete token mapping.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenSchemaCurrent.cfg models/staging/ParslGlobusTokenSchema.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTokenSchemaFixed.cfg models/staging/ParslGlobusTokenSchema.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_token_schema_runtime.py -v
```

This credential-schema boundary is recorded as BUG-266.

`ParslGlobusInitRace.tla` models the directory-creation boundary in `Globus.init`. The current
implementation checks whether `~/.parsl` exists and then calls `os.mkdir` as separate operations.
If another initializer creates the directory between those operations, the second initializer
raises `FileExistsError` even though the required directory is ready. The fixed branch treats an
already-created directory as successful initialization. `tests/test_globus_init_race_runtime.py`
reproduces the exception with a deterministic `isdir`/`mkdir` interleaving against the installed
Globus implementation. This source-aligned finding is recorded as BUG-267.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusInitRaceCurrent.cfg models/staging/ParslGlobusInitRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusInitRaceFixed.cfg models/staging/ParslGlobusInitRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_init_race_runtime.py -v
```

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTransferTimeoutCurrent.cfg models/staging/ParslGlobusTransferTimeout.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslGlobusTransferTimeoutFixed.cfg models/staging/ParslGlobusTransferTimeout.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_globus_transfer_timeout_runtime.py -v
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

`ParslRsyncQuoting.tla` models the command-construction boundary in the same wrapper. The current
implementation interpolates source and destination paths into `os.system`, so a valid path with
spaces is split by the shell; the fixed branch quotes each argument. The runtime probe inspects
the actual command built by the real wrapper.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncQuotingCurrent.cfg models/staging/ParslRsyncQuoting.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncQuotingFixed.cfg models/staging/ParslRsyncQuoting.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslRsyncQuotingNormal.cfg models/staging/ParslRsyncQuoting.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_rsync_quoting_runtime.py -v
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
new source version, and checks 76 distinct states (261 generated). `CorruptChunk` is bounded to
one mutation per clean in-flight chunk so repair/retransmission remains finite. `ParslFileBytes.tla` contains the more detailed
multi-file byte/checksum abstraction; this model focuses on the version/publication boundary.

The smoke configurations reduce the transfer to one chunk while retaining source-version change,
checksum corruption, stale retry, atomic publication, and consumer-readiness invariants.
The smoke current configuration reaches its expected counterexample in 39 generated / 17 distinct
states; the fixed configuration passes in 39 generated / 16 distinct states at depth 7.

The symbolic byte/checksum path is also exercised against a real local archive transfer by
`tests/test_file_bytes_transfer_runtime.py`.  The probe splits binary content into bounded chunks,
records a SHA-256 checksum for each chunk, stages the file through the real Zip provider, and
checks both byte-for-byte equality and per-chunk checksums after stage-in.
The same probe corrupts a stored archive payload and verifies that Zip CRC failure is raised
before the destination becomes visible.

For a quick complete TLC check, `ParslFileBytesSmoke.cfg` reduces the detailed abstraction to one
file and one chunk (99 states generated, 44 distinct states). The detailed configuration remains
available for multi-file and multi-chunk exploration; corruption is bounded to one mutation per
clean in-flight chunk before a retry can resend it.
The two-chunk `ParslFileBytes.cfg` configuration is now also in the foundational smoke gate, so
the default regression checks the full bounded content/checksum path rather than only its one-chunk
smoke reduction.

`ParslDataManagerStageOutReturn.tla` models the two return shapes of `DataManager.stage_out`: a
provider may return `None`, in which case the output `DataFuture` follows the application Future,
or return an independent Future for a separate transfer. The output is publishable only after the
application and the selected transfer are complete. Both paths are checked against the real
`DataManager` by `tests/test_data_manager_stage_out_return_runtime.py`.

```bash
/tmp/parsl-venv/bin/python -m unittest tests/test_file_bytes_transfer_runtime.py -v
```

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

`ParslDataManagerCache.tla` isolates the matching stage-in cache boundary. A transfer captures a
source version before filling a temporary buffer; if the source changes while the copy is in
flight, the current branch publishes the captured version as ready. The fixed branch rejects the
stale buffer, retries from the new version, and admits consumers only after an atomic
version-matching publication. `StartStage`, `CopyComplete`, and the publish actions abstract the
DataManager staging Future; `StartConsumerA/B` abstract DFK dependency admission.

`ParslGlobusStageDependency.tla` is the small dependency-wiring model beneath the concrete Globus
transfer paths. It keeps the parent DataFuture attached to stage-in and the application Future
attached to stage-out, so neither transfer can start before its producer is ready. The model is
now part of the foundational smoke gate.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataManagerCacheCurrent.cfg models/staging/ParslDataManagerCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslDataManagerCacheFixed.cfg models/staging/ParslDataManagerCache.tla
```

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

This file-publication boundary is recorded as BUG-105: a failed FTP stream leaves partial bytes
at the final destination instead of cleaning up or publishing atomically.

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

`ParslHTTPExistingDestination.tla` refines the same boundary when the destination already holds
a valid previous version. The current `open(..., "wb")` truncates that version before the stream
completes, so a later read failure leaves only the new partial bytes. The fixed branch preserves
the old version until a completed transfer can be atomically published. The runtime probe uses a
real HTTP staging wrapper and an existing temporary file.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPExistingDestinationCurrent.cfg models/staging/ParslHTTPExistingDestination.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPExistingDestinationFixed.cfg models/staging/ParslHTTPExistingDestination.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_http_existing_destination_runtime.py -v
```

This content-preservation boundary is recorded as BUG-138.

`ParslHTTPConnectionCleanup.tla` isolates response lifetime from destination publication. The
current HTTP wrapper does not close a streaming `requests.Response` when `iter_content` raises;
the fixed branch closes it in a finally-equivalent path. The runtime probe uses a response double
that yields one chunk and then fails, checking both the leaked response and partial destination.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPConnectionCleanupCurrent.cfg models/staging/ParslHTTPConnectionCleanup.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPConnectionCleanupFixed.cfg models/staging/ParslHTTPConnectionCleanup.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_http_connection_cleanup_runtime.py -v
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

`ParslHTTPContentLength.tla` refines HTTP content validation beyond status codes. The current
in-task wrapper publishes the bytes yielded by `iter_content` and runs the user function even
when a response advertises five bytes but yields only three. The fixed branch rejects the short
transfer before task execution. The runtime probe drives the real wrapper with a truncated
response double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPContentLengthCurrent.cfg models/staging/ParslHTTPContentLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPContentLengthFixed.cfg models/staging/ParslHTTPContentLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPContentLengthNormal.cfg models/staging/ParslHTTPContentLength.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_http_content_length_runtime.py -v
```

This content-length boundary is recorded as BUG-172.

`ParslHTTPSeparateContentLength.tla` applies the same declared-length invariant to the separate
task helper (`_http_stage_in`). The current path accepts a response advertising five bytes while
yielding three; the fixed path rejects the short transfer before completing stage-in.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPSeparateContentLengthCurrent.cfg models/staging/ParslHTTPSeparateContentLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPSeparateContentLengthFixed.cfg models/staging/ParslHTTPSeparateContentLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPSeparateContentLengthNormal.cfg models/staging/ParslHTTPSeparateContentLength.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_http_separate_content_length_runtime.py -v
```

`ParslHTTPSeparateStatus.tla` covers the separate-task HTTP helper (`_http_stage_in`). The
current helper writes any response body and completes successfully even for a non-2xx response;
the fixed branch validates the status before publishing the staged input.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPSeparateStatusCurrent.cfg models/staging/ParslHTTPSeparateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPSeparateStatusFixed.cfg models/staging/ParslHTTPSeparateStatus.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslHTTPSeparateStatusNormal.cfg models/staging/ParslHTTPSeparateStatus.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_http_separate_status_runtime.py -v
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

`ParslZipStageIn.tla` models the corresponding archive-member write boundary. The current path
leaves a partial final output after a write failure; the fixed branch discards it. TLC finds the
three-state `AtomicPublishSafety` counterexample in the current configuration and checks six
generated/three distinct states in the fixed branch.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslZipStageInCurrent.cfg models/staging/ParslZipStageIn.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslZipStageInFixed.cfg models/staging/ParslZipStageIn.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zip_file_transfer_runtime.py -v
```

`ParslMultiOutputVersionedStageOut.tla` combines the multi-output readiness boundary with source
versioning. The current branch can release one output before its sibling or publish bytes from an
obsolete source version; the fixed branch requires both transfers to be ready and version-matched
before releasing either consumer. TLC checks 100,142 simulated fixed states.

`ParslMultiOutputStageOut.tla` is the smaller application-gate abstraction beneath that versioned
model. It gives each output its own stage-out Future while requiring all outputs to wait on the
same application Future; the normal configuration is part of the foundational smoke gate, and
`ParslMultiOutputStageOutEarly.cfg` is retained as the executable early-publication counterexample.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslMultiOutputVersionedStageOutCurrent.cfg models/staging/ParslMultiOutputVersionedStageOut.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslMultiOutputVersionedStageOutFixed.cfg models/staging/ParslMultiOutputVersionedStageOut.tla
```

`ParslThreeOutputVersionedStageOut.tla` extends that atomic publication boundary to three output
files. A source-version change or failure of one transfer cannot make any output Future visible
until all three outputs are ready at the same source version. The fixed branch also retries an
individual failed output before publishing the set.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslThreeOutputVersionedStageOutCurrent.cfg models/staging/ParslThreeOutputVersionedStageOut.tla
java -cp tla2tools.jar tlc2.TLC -config models/staging/ParslThreeOutputVersionedStageOutFixed.cfg models/staging/ParslThreeOutputVersionedStageOut.tla
```
