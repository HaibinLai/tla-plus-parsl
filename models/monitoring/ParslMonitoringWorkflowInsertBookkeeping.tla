--------------------------- MODULE ParslMonitoringWorkflowInsertBookkeeping ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring WORKFLOW start-row bookkeeping.
 *
 * DatabaseManager records workflow_start_message after calling _insert, even
 * when the insert failed. During close(), that in-memory marker causes an
 * UPDATE against a workflow row that was never created.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"new", "inserting", "failed", "stored", "closing", "lost"}

VARIABLES state, bookkeeping, rowPresent
vars == <<state, bookkeeping, rowPresent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ bookkeeping = FALSE
    /\ rowPresent = FALSE

BeginInsert ==
    /\ state = "new"
    /\ state' = "inserting"
    /\ bookkeeping' = IF USE_FIXED THEN bookkeeping ELSE TRUE
    /\ UNCHANGED rowPresent

InsertSuccess ==
    /\ state = "inserting"
    /\ state' = "stored"
    /\ bookkeeping' = TRUE
    /\ rowPresent' = TRUE

InsertFailure ==
    /\ state = "inserting"
    /\ state' = "failed"
    /\ bookkeeping' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED rowPresent

CloseWorkflow ==
    /\ state = "failed"
    /\ bookkeeping
    /\ state' = IF rowPresent THEN "closing" ELSE "lost"
    /\ UNCHANGED <<bookkeeping, rowPresent>>

Next ==
    \/ BeginInsert
    \/ InsertSuccess
    \/ InsertFailure
    \/ CloseWorkflow
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ bookkeeping \in BOOLEAN
    /\ rowPresent \in BOOLEAN

BookkeepingSafety == bookkeeping => rowPresent
LostWorkflowSafety == state = "lost" => rowPresent

=============================================================================
