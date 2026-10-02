--------------------------- MODULE ParslFileTransferRetryMonitoring ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * File bytes, an asynchronous stage-out retry, DataFuture admission, and
 * monitoring.  A source-file mutation while a transfer is in flight creates
 * a stale physical result.  The Current branch publishes it as if it were
 * current; the Fixed branch records the stale transfer, retries, and exposes
 * only bytes for the current source version.
 ***************************************************************************)

CONSTANT USE_FIXED

TransferStates == {"idle", "sending", "stale", "ready"}
FutureStates == {"unresolved", "ready"}
ConsumerStates == {"blocked", "running", "done"}
MonitorStates == {"none", "stale", "published"}

VARIABLES sourceVersion, capturedVersion, transferState, dataFuture,
          consumerState, monitorState, observedVersion
vars == <<sourceVersion, capturedVersion, transferState, dataFuture,
          consumerState, monitorState, observedVersion>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ capturedVersion = -1
    /\ transferState = "idle"
    /\ dataFuture = "unresolved"
    /\ consumerState = "blocked"
    /\ monitorState = "none"
    /\ observedVersion = -1

BeginTransfer ==
    /\ transferState = "idle"
    /\ transferState' = "sending"
    /\ capturedVersion' = sourceVersion
    /\ UNCHANGED <<sourceVersion, dataFuture, consumerState,
                    monitorState, observedVersion>>

ModifySource ==
    /\ transferState = "sending"
    /\ sourceVersion = 0
    /\ sourceVersion' = 1
    /\ UNCHANGED <<capturedVersion, transferState, dataFuture,
                    consumerState, monitorState, observedVersion>>

PublishTransfer ==
    /\ transferState = "sending"
    /\ IF USE_FIXED /\ capturedVersion # sourceVersion
          THEN /\ transferState' = "stale"
               /\ monitorState' = "stale"
               /\ UNCHANGED <<dataFuture, consumerState, observedVersion>>
          ELSE /\ transferState' = "ready"
               /\ dataFuture' = "ready"
               /\ monitorState' = "published"
               /\ UNCHANGED <<consumerState, observedVersion>>
    /\ UNCHANGED <<sourceVersion, capturedVersion>>

RetryStale ==
    /\ transferState = "stale"
    /\ transferState' = "idle"
    /\ dataFuture' = "unresolved"
    /\ UNCHANGED <<sourceVersion, capturedVersion, consumerState,
                    monitorState, observedVersion>>

StartConsumer ==
    /\ consumerState = "blocked"
    /\ dataFuture = "ready"
    /\ consumerState' = "running"
    /\ UNCHANGED <<sourceVersion, capturedVersion, transferState,
                    dataFuture, monitorState, observedVersion>>

FinishConsumer ==
    /\ consumerState = "running"
    /\ consumerState' = "done"
    /\ observedVersion' = capturedVersion
    /\ UNCHANGED <<sourceVersion, capturedVersion, transferState,
                    dataFuture, monitorState>>

Next ==
    \/ BeginTransfer
    \/ ModifySource
    \/ PublishTransfer
    \/ RetryStale
    \/ StartConsumer
    \/ FinishConsumer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion \in 0..1
    /\ capturedVersion \in -1..1
    /\ transferState \in TransferStates
    /\ dataFuture \in FutureStates
    /\ consumerState \in ConsumerStates
    /\ monitorState \in MonitorStates
    /\ observedVersion \in -1..1

VersionPublicationSafety ==
    dataFuture = "ready" =>
        /\ transferState = "ready"
        /\ capturedVersion = sourceVersion
        /\ monitorState = "published"

DataFutureGate == consumerState = "running" => dataFuture = "ready"

ContentSafety ==
    consumerState = "done" => observedVersion = sourceVersion

StaleVisibility ==
    monitorState = "stale" => dataFuture = "unresolved"

=============================================================================
