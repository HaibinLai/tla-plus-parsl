--------------------------- MODULE ParslMonitoringWorkflowEndBookkeeping ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring WORKFLOW end-update bookkeeping.
 *
 * DatabaseManager sets workflow_end after calling _update, even when the
 * update failed and was swallowed. A later close therefore skips the update
 * permanently.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"ready", "updating", "failed", "updated", "closed", "lost"}

VARIABLES state, workflowEnd, rowUpdated
vars == <<state, workflowEnd, rowUpdated>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ workflowEnd = FALSE
    /\ rowUpdated = FALSE

BeginUpdate ==
    /\ state = "ready"
    /\ state' = "updating"
    /\ UNCHANGED <<workflowEnd, rowUpdated>>

UpdateSuccess ==
    /\ state = "updating"
    /\ state' = "updated"
    /\ workflowEnd' = TRUE
    /\ rowUpdated' = TRUE

UpdateFailure ==
    /\ state = "updating"
    /\ state' = "failed"
    /\ workflowEnd' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED rowUpdated

CloseAfterFailure ==
    /\ state = "failed"
    /\ workflowEnd
    /\ state' = "lost"
    /\ UNCHANGED <<workflowEnd, rowUpdated>>

RetryAfterFailure ==
    /\ state = "failed"
    /\ ~workflowEnd
    /\ state' = "updating"
    /\ UNCHANGED <<workflowEnd, rowUpdated>>

Next ==
    \/ BeginUpdate
    \/ UpdateSuccess
    \/ UpdateFailure
    \/ CloseAfterFailure
    \/ RetryAfterFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ workflowEnd \in BOOLEAN
    /\ rowUpdated \in BOOLEAN

EndBookkeepingSafety == workflowEnd => rowUpdated
LostEndSafety == state = "lost" => rowUpdated

=============================================================================
