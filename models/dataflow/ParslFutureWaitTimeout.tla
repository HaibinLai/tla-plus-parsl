--------------------------- MODULE ParslFutureWaitTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Distinguish a caller-side Future.result(timeout=...) from Parsl's app
 * walltime.  The former only stops waiting in the caller; it must not cancel
 * the physical task or reject its Future.  The latter changes the app and
 * Future outcome.
 ***************************************************************************)

AppStates == {"pending", "running", "done", "failed"}
FutureStates == {"unresolved", "resolved", "rejected"}
WaitStates == {"idle", "expired", "returned"}

VARIABLES appState, futureState, waitState
vars == <<appState, futureState, waitState>>

Init ==
    /\ appState = "pending"
    /\ futureState = "unresolved"
    /\ waitState = "idle"

StartApp ==
    /\ appState = "pending"
    /\ appState' = "running"
    /\ UNCHANGED <<futureState, waitState>>

ClientWaitTimeout ==
    /\ appState = "running"
    /\ waitState = "idle"
    /\ waitState' = "expired"
    /\ UNCHANGED <<appState, futureState>>

ClientWaitAgain ==
    /\ waitState = "expired"
    /\ appState = "running"
    /\ waitState' = "returned"
    /\ UNCHANGED <<appState, futureState>>

CompleteApp ==
    /\ appState = "running"
    /\ appState' = "done"
    /\ futureState' = "resolved"
    /\ UNCHANGED waitState

AppWallTimeout ==
    /\ appState = "running"
    /\ appState' = "failed"
    /\ futureState' = "rejected"
    /\ UNCHANGED waitState

Next ==
    \/ StartApp
    \/ ClientWaitTimeout
    \/ ClientWaitAgain
    \/ CompleteApp
    \/ AppWallTimeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ appState \in AppStates
    /\ futureState \in FutureStates
    /\ waitState \in WaitStates

ClientTimeoutIsolation ==
    waitState = "expired" /\ appState = "running"
        => futureState = "unresolved"

FutureConsistency ==
    /\ futureState = "resolved" => appState = "done"
    /\ futureState = "rejected" => appState = "failed"

WallTimeoutConsistency ==
    appState = "failed" => futureState = "rejected"

=============================================================================
