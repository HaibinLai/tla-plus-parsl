--------------------------- MODULE ParslThreadExecutorFutureLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * The ThreadPoolExecutor delegates to concurrent.futures.Future.  A queued
 * Future can be cancelled, but a Future whose callable has started cannot;
 * shutdown waits for accepted work and does not interrupt running callables.
 ***************************************************************************)

VARIABLES taskState, cancelReturned, resultPublished, shutdown
vars == <<taskState, cancelReturned, resultPublished, shutdown>>

TaskStates == {"pending", "running", "succeeded", "cancelled"}

Init ==
    /\ taskState = "pending"
    /\ cancelReturned = "not_called"
    /\ resultPublished = FALSE
    /\ shutdown = FALSE

Start ==
    /\ taskState = "pending"
    /\ taskState' = "running"
    /\ UNCHANGED <<cancelReturned, resultPublished, shutdown>>

CancelPending ==
    /\ taskState = "pending"
    /\ taskState' = "cancelled"
    /\ cancelReturned' = "true"
    /\ UNCHANGED <<resultPublished, shutdown>>

CancelRunning ==
    /\ taskState = "running"
    /\ taskState' = "running"
    /\ cancelReturned' = "false"
    /\ UNCHANGED <<resultPublished, shutdown>>

Finish ==
    /\ taskState = "running"
    /\ taskState' = "succeeded"
    /\ resultPublished' = TRUE
    /\ UNCHANGED <<cancelReturned, shutdown>>

Shutdown ==
    /\ shutdown = FALSE
    /\ shutdown' = TRUE
    /\ UNCHANGED <<taskState, cancelReturned, resultPublished>>

Next ==
    \/ Start
    \/ CancelPending
    \/ CancelRunning
    \/ Finish
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in TaskStates
    /\ cancelReturned \in {"not_called", "true", "false"}
    /\ resultPublished \in BOOLEAN
    /\ shutdown \in BOOLEAN

CancelledIsTerminal == taskState = "cancelled" => ~resultPublished
RunningNotCancellable == taskState = "running" => cancelReturned # "true"
ResultOnlyAfterRun == resultPublished => taskState = "succeeded"
ShutdownDoesNotCancel == shutdown => taskState # "cancelled" \/ cancelReturned = "true"

=============================================================================
SPECIFICATION Spec
INVARIANTS TypeOK CancelledIsTerminal RunningNotCancellable
    ResultOnlyAfterRun ShutdownDoesNotCancel
