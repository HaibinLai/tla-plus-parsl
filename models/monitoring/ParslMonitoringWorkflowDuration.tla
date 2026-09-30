--------------------------- MODULE ParslMonitoringWorkflowDuration ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager.close computes workflow_duration and passes it to a bulk
 * update.  The current WORKFLOW schema has no such column, and SQLAlchemy's
 * bulk_update_mappings silently ignores the unknown field.  USE_FIXED models
 * a schema/update contract that persists the duration explicitly.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES phase, message, stored, outcome
vars == <<phase, message, stored, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "close"
    /\ message = "duration-present"
    /\ stored = FALSE
    /\ outcome = "waiting"

UpdateWorkflow ==
    /\ phase = "close"
    /\ phase' = "complete"
    /\ stored' = USE_FIXED
    /\ outcome' = IF USE_FIXED THEN "persisted" ELSE "silently-dropped"
    /\ UNCHANGED message

Next == UpdateWorkflow \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"close", "complete"}
    /\ message = "duration-present"
    /\ stored \in BOOLEAN
    /\ outcome \in {"waiting", "persisted", "silently-dropped"}

DurationPersistenceSafety == phase = "complete" => stored
=============================================================================
