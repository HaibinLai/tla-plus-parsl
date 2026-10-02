--------------------------- MODULE ParslFTPPartialCleanupFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FTP partial-file cleanup composed with DataFuture/task failure.
 *
 * FTP stage-in writes bytes directly to the destination.  If the stream
 * fails after a partial write, the Current branch leaves those bytes visible
 * while the dependent Future remains pending.  The Fixed branch removes the
 * partial publication and propagates one terminal failure to the Future,
 * task, and monitoring state.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"fetching", "streaming", "failed"}
FutureStates == {"pending", "failed"}
TaskStates == {"blocked", "failed"}
MonitorStates == {"none", "failed"}

VARIABLES phase, bytesVisible, dataFuture, task, monitor
vars == <<phase, bytesVisible, dataFuture, task, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "fetching"
    /\ bytesVisible = 0
    /\ dataFuture = "pending"
    /\ task = "blocked"
    /\ monitor = "none"

FirstChunk ==
    /\ phase = "fetching"
    /\ phase' = "streaming"
    /\ bytesVisible' = 1
    /\ UNCHANGED <<dataFuture, task, monitor>>

TransferFailure ==
    /\ phase = "streaming"
    /\ phase' = "failed"
    /\ bytesVisible' = IF USE_FIXED THEN 0 ELSE bytesVisible
    /\ dataFuture' = IF USE_FIXED THEN "failed" ELSE dataFuture
    /\ task' = IF USE_FIXED THEN "failed" ELSE task
    /\ monitor' = IF USE_FIXED THEN "failed" ELSE monitor

Next ==
    \/ FirstChunk
    \/ TransferFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in Phases
    /\ bytesVisible \in 0..1
    /\ dataFuture \in FutureStates
    /\ task \in TaskStates
    /\ monitor \in MonitorStates

FailurePublicationSafety == phase = "failed" => bytesVisible = 0

FailurePropagation ==
    task = "failed" =>
        /\ dataFuture = "failed"
        /\ monitor = "failed"

NoFalseReadiness == dataFuture = "pending" => task = "blocked"

=============================================================================
