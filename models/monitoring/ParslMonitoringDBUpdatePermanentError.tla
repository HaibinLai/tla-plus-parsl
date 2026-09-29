--------------------------- MODULE ParslMonitoringDBUpdatePermanentError ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager._update on a permanent database error.
 *
 * The update path catches every non-OperationalError, rolls back, and
 * returns after the caller has drained the batch.  The fixed branch retains
 * the message for a later retry instead of silently losing the update.
 ***************************************************************************)

CONSTANT USE_FIXED

MessageStates == {"queued", "writing", "updated", "lost"}
ErrorStates == {"none", "permanent"}

VARIABLES messageState, errorState
vars == <<messageState, errorState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ messageState = "queued"
    /\ errorState = "none"

BeginUpdate ==
    /\ messageState = "queued"
    /\ messageState' = "writing"
    /\ UNCHANGED errorState

PermanentFailure ==
    /\ messageState = "writing"
    /\ errorState = "none"
    /\ errorState' = "permanent"
    /\ messageState' = IF USE_FIXED THEN "queued" ELSE "lost"

RetryUpdated ==
    /\ messageState = "writing"
    /\ errorState = "permanent"
    /\ USE_FIXED
    /\ messageState' = "updated"
    /\ UNCHANGED errorState

Next ==
    \/ BeginUpdate
    \/ PermanentFailure
    \/ RetryUpdated
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ messageState \in MessageStates
    /\ errorState \in ErrorStates

PermanentErrorRetention ==
    errorState = "permanent" => messageState # "lost"

=============================================================================
