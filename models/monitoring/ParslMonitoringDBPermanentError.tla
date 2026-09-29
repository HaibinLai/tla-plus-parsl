--------------------------- MODULE ParslMonitoringDBPermanentError ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager._insert on a permanent database error.
 *
 * The current implementation catches every non-OperationalError, rolls back,
 * and returns after the batch has already been removed from its queue.  The
 * message is therefore lost.  USE_FIXED models retaining the batch for a
 * later retry instead.
 ***************************************************************************)

CONSTANT USE_FIXED

MessageStates == {"queued", "writing", "stored", "lost"}
ErrorStates == {"none", "permanent"}

VARIABLES messageState, errorState
vars == <<messageState, errorState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ messageState = "queued"
    /\ errorState = "none"

BeginInsert ==
    /\ messageState = "queued"
    /\ messageState' = "writing"
    /\ UNCHANGED errorState

PermanentFailure ==
    /\ messageState = "writing"
    /\ errorState = "none"
    /\ errorState' = "permanent"
    /\ messageState' = IF USE_FIXED THEN "queued" ELSE "lost"

RetryStored ==
    /\ messageState = "writing"
    /\ errorState = "permanent"
    /\ USE_FIXED
    /\ messageState' = "stored"
    /\ UNCHANGED errorState

Next ==
    \/ BeginInsert
    \/ PermanentFailure
    \/ RetryStored
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ messageState \in MessageStates
    /\ errorState \in ErrorStates

PermanentErrorRetention ==
    errorState = "permanent" => messageState # "lost"

=============================================================================
