--------------------------- MODULE ParslMonitoringClose ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager.close finalizes a workflow only when a start message exists
 * and the normal workflow-end message has not already been processed.  It then
 * switches batching to an infinite drain interval and signals shutdown.
 *************************************************************************** *)

CONSTANTS WORKFLOW_ENDED, START_MESSAGE_PRESENT

States == {"open", "closed"}
VARIABLES state, updateSent, killSet, infiniteBatching
vars == <<state, updateSent, killSet, infiniteBatching>>

Init ==
    /\ WORKFLOW_ENDED \in BOOLEAN
    /\ START_MESSAGE_PRESENT \in BOOLEAN
    /\ state = "open"
    /\ updateSent = FALSE
    /\ killSet = FALSE
    /\ infiniteBatching = FALSE

Close ==
    /\ state = "open"
    /\ state' = "closed"
    /\ updateSent' = START_MESSAGE_PRESENT /\ ~WORKFLOW_ENDED
    /\ killSet' = TRUE
    /\ infiniteBatching' = TRUE

Next ==
    \/ Close
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ updateSent \in BOOLEAN
    /\ killSet \in BOOLEAN
    /\ infiniteBatching \in BOOLEAN

CloseSafety ==
    state = "closed" => killSet /\ infiniteBatching

FinalizationSafety ==
    updateSent => START_MESSAGE_PRESENT /\ ~WORKFLOW_ENDED

=============================================================================
