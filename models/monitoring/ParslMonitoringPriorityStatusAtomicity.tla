-------------------- MODULE ParslMonitoringPriorityStatusAtomicity --------------------
EXTENDS Naturals

(***************************************************************************
 * Priority monitoring batch persistence.
 *
 * DatabaseManager handles one TASK_INFO batch through separate committed
 * TASK, STATUS, and TRY writes.  If the STATUS insert fails, the current
 * generic _insert handler swallows the error and the loop still inserts TRY,
 * leaving metadata without its corresponding status row.  The fixed branch
 * rolls back the whole logical batch before returning a terminal failure.
 *************************************************************************** *)

CONSTANT USE_FIXED

Phases == {"queued", "task_inserted", "status_inserted", "status_failed", "complete", "failed"}

VARIABLES phase, taskPresent, statusPresent, tryPresent
vars == <<phase, taskPresent, statusPresent, tryPresent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "queued"
    /\ taskPresent = FALSE
    /\ statusPresent = FALSE
    /\ tryPresent = FALSE

InsertTask ==
    /\ phase = "queued"
    /\ taskPresent' = TRUE
    /\ phase' = "task_inserted"
    /\ UNCHANGED <<statusPresent, tryPresent>>

InsertStatus ==
    /\ phase = "task_inserted"
    /\ statusPresent' = TRUE
    /\ phase' = "status_inserted"
    /\ UNCHANGED <<taskPresent, tryPresent>>

StatusFailure ==
    /\ phase = "task_inserted"
    /\ IF USE_FIXED
          THEN /\ phase' = "failed"
               /\ taskPresent' = FALSE
               /\ statusPresent' = FALSE
               /\ tryPresent' = FALSE
          ELSE /\ phase' = "status_failed"
               /\ UNCHANGED <<taskPresent, statusPresent, tryPresent>>

InsertTry ==
    /\ phase \in {"status_inserted", "status_failed"}
    /\ phase' = "complete"
    /\ tryPresent' = TRUE
    /\ UNCHANGED <<taskPresent, statusPresent>>

Next ==
    \/ InsertTask
    \/ InsertStatus
    \/ StatusFailure
    \/ InsertTry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in Phases
    /\ taskPresent \in BOOLEAN
    /\ statusPresent \in BOOLEAN
    /\ tryPresent \in BOOLEAN

BatchConsistency ==
    phase = "complete" => taskPresent /\ statusPresent /\ tryPresent

FixedFailureRollback ==
    USE_FIXED /\ phase = "failed" =>
        ~taskPresent /\ ~statusPresent /\ ~tryPresent

=============================================================================
