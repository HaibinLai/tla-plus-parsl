--------------------------- MODULE ParslHTTPPartialCleanupFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP partial-file cleanup composed with DataFuture/task failure.
 *
 * HTTP staging writes chunks directly to the destination.  When a later
 * response read fails, the Current branch leaves earlier bytes visible while
 * the dependent Future remains pending.  The Fixed branch removes the
 * partial publication and propagates failure through task, Future, and
 * monitoring state.
 ***************************************************************************)

CONSTANTS TRANSFER_FAILS, USE_FIXED

States == {"fetching", "streaming", "failed", "completed"}
FutureStates == {"pending", "failed", "ready"}
TaskStates == {"blocked", "failed", "running"}
MonitorStates == {"none", "failed", "ready"}

VARIABLES state, bytesPublished, dataFuture, task, monitor
vars == <<state, bytesPublished, dataFuture, task, monitor>>

Init ==
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "fetching"
    /\ bytesPublished = 0
    /\ dataFuture = "pending"
    /\ task = "blocked"
    /\ monitor = "none"

FirstChunk ==
    /\ state = "fetching"
    /\ state' = "streaming"
    /\ bytesPublished' = 1
    /\ UNCHANGED <<dataFuture, task, monitor>>

LaterChunk ==
    /\ state = "streaming"
    /\ TRANSFER_FAILS
    /\ state' = "failed"
    /\ bytesPublished' = IF USE_FIXED THEN 0 ELSE bytesPublished
    /\ dataFuture' = IF USE_FIXED THEN "failed" ELSE dataFuture
    /\ task' = IF USE_FIXED THEN "failed" ELSE task
    /\ monitor' = IF USE_FIXED THEN "failed" ELSE monitor

Complete ==
    /\ state = "streaming"
    /\ ~TRANSFER_FAILS
    /\ state' = "completed"
    /\ dataFuture' = "ready"
    /\ task' = "running"
    /\ monitor' = "ready"
    /\ UNCHANGED bytesPublished

Next ==
    \/ FirstChunk
    \/ LaterChunk
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ TRANSFER_FAILS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ bytesPublished \in 0..1
    /\ dataFuture \in FutureStates
    /\ task \in TaskStates
    /\ monitor \in MonitorStates

FailurePublicationSafety == state = "failed" => bytesPublished = 0

FailurePropagation ==
    task = "failed" =>
        /\ dataFuture = "failed"
        /\ monitor = "failed"

ReadinessSafety ==
    dataFuture = "ready" =>
        /\ state = "completed"
        /\ bytesPublished = 1
        /\ monitor = "ready"

=============================================================================
