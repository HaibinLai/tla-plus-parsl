# Parsl abstraction bug ledger

This ledger records behaviors that the bounded TLA+ models and concrete runtime probes have
reproduced. A `Current` finding describes the behavior observed in the inspected Parsl source;
`Fixed` is a candidate protocol/model change, not a claim that Parsl source has already been
patched. Each new model stage should add an entry here with a source path, a TLC configuration,
and a runtime probe when one is available.

| ID | Component | Current behavior / risk | Evidence | Candidate safety condition | Status |
| --- | --- | --- | --- | --- | --- |
| BUG-001 | DFK retry/result delivery | A result arriving after a physical attempt timed out can resolve the logical Future while its retry number is still current. | `ParslEndToEnd.cfg` (`CurrentAttemptResultSafety`); `tests/test_end_to_end_runtime.py` | Only a result from an attempt in `succeeded` state may resolve the Future. | Reproduced; model fixed branch passes |
| BUG-002 | HTEX result worker | A result for a cancelled/terminal Future is delivered through `Future.set_result` after the task is popped from `_tasks`, raising `InvalidStateError` and losing bookkeeping. | `tests/test_htex_result_queue_runtime.py`; `ParslZMQSerializationEndToEnd.tla` (`TerminalResultSafety`) | Terminal Futures must reject or ignore late result frames without removing unrelated bookkeeping. | Reproduced; candidate fixed model passes |
| BUG-003 | Google Cloud provider | `GoogleCloudProvider.get_zone` returns `None` when no matching UP zone exists; construction can continue until a later API request uses an invalid zone. | `ParslGoogleCloudZoneSelectionCurrent.cfg`; `tests/test_googlecloud_zone_selection_runtime.py` | Zone selection must reject a missing match before submission. | Reproduced; candidate fixed model passes |
| BUG-004 | HTEX manager/result path | Manager heartbeat expiry can lose an in-flight task; a synthetic result envelope may be dropped before the client Future is resolved. | `ParslHtexManagerLoss.tla`; `tests/test_htex_manager_loss_runtime.py` | Manager-loss handling must classify the attempt and deliver one terminal result/error envelope. | Reproduced; candidate fixed model passes |
| BUG-005 | Monitoring database delivery | An older monitoring event can overwrite a newer logical status when queue delivery is reordered. | `ParslMonitoringDelivery.tla`; monitoring delivery runtime probes | Database view must preserve a version high-water mark and ignore stale events. | Reproduced; candidate fixed model passes |
| BUG-006 | Serialization/object identity | Independently serializing a callable closure and an argument can break shared mutable-object identity after decode. | `ParslCallableArgumentAlias.tla`; `tests/test_callable_argument_alias_runtime.py` | Serialization of one task graph must preserve intentional aliases. | Reproduced; candidate fixed model passes |
| BUG-007 | Stage-out/content versioning | A source file changed during asynchronous transfer can publish bytes from an obsolete version. | `ParslFileTransferRetry.tla`; staging runtime probes | Publish only a checksum/version-matched transfer, otherwise retry or mark stale. | Reproduced; candidate fixed model passes |
| BUG-008 | `join_app` list semantics | Treating a list of inner Futures as a set loses duplicate positions and can change the outer result shape. | `ParslJoinComplete.tla`; `tests/test_join_retry_duplicates_runtime.py` | Preserve ordered list positions, including duplicate Future references. | Reproduced; candidate fixed model passes |
| BUG-009 | Monitoring shutdown | A late producer can enqueue after the migration loop observes an empty queue and exits, stranding the message. | `ParslMonitoringShutdownRace.tla`; shutdown-race runtime probe | Queue shutdown requires producer closure before an empty observation is terminal. | Reproduced; candidate fixed model passes |
| BUG-010 | Provider polling | Several provider status paths index local resource maps with stale/unknown job IDs and raise `KeyError`, aborting a polling pass. | Kubernetes, Condor, AWS, LocalProvider focused models and probes | Unknown jobs should produce an explicit status or non-throwing stale observation. | Reproduced in focused providers; source fixes pending |

The ledger is intentionally separate from the coverage matrix: the matrix describes modeled
surface area, while this file records concrete failure hypotheses and their evidence. Findings are
not automatically confirmed defects in every Parsl deployment; they identify protocol behavior
that deserves source-level review or a targeted patch.
