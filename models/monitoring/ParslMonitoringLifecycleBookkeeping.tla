--------------------------- MODULE ParslMonitoringLifecycleBookkeeping ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Integrated monitoring database lifecycle bookkeeping.
 *
 * DatabaseManager tracks whether WORKFLOW, TASK, and TRY rows have been
 * inserted, and whether workflow finalization has completed.  The in-memory
 * markers must advance only after the corresponding database operation
 * succeeds; otherwise a swallowed write error reclassifies a later message as
 * an UPDATE and prevents recovery of the missing row.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES workflowRow, taskRow, tryRow, workflowEndRow,
          workflowSeen, taskSeen, trySeen, workflowEnded
vars == <<workflowRow, taskRow, tryRow, workflowEndRow,
          workflowSeen, taskSeen, trySeen, workflowEnded>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ workflowRow = FALSE
    /\ taskRow = FALSE
    /\ tryRow = FALSE
    /\ workflowEndRow = FALSE
    /\ workflowSeen = FALSE
    /\ taskSeen = FALSE
    /\ trySeen = FALSE
    /\ workflowEnded = FALSE

InsertWorkflowSuccess ==
    /\ ~workflowRow
    /\ workflowRow' = TRUE
    /\ workflowSeen' = TRUE
    /\ UNCHANGED <<taskRow, tryRow, workflowEndRow,
                    taskSeen, trySeen, workflowEnded>>

InsertWorkflowFailure ==
    /\ ~workflowRow
    /\ workflowRow' = FALSE
    /\ workflowSeen' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED <<taskRow, tryRow, workflowEndRow,
                    taskSeen, trySeen, workflowEnded>>

InsertTaskSuccess ==
    /\ workflowRow
    /\ ~taskRow
    /\ taskRow' = TRUE
    /\ taskSeen' = TRUE
    /\ UNCHANGED <<workflowRow, tryRow, workflowEndRow,
                    workflowSeen, trySeen, workflowEnded>>

InsertTaskFailure ==
    /\ workflowRow
    /\ ~taskRow
    /\ taskRow' = FALSE
    /\ taskSeen' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED <<workflowRow, tryRow, workflowEndRow,
                    workflowSeen, trySeen, workflowEnded>>

InsertTrySuccess ==
    /\ taskRow
    /\ ~tryRow
    /\ tryRow' = TRUE
    /\ trySeen' = TRUE
    /\ UNCHANGED <<workflowRow, taskRow, workflowEndRow,
                    workflowSeen, taskSeen, workflowEnded>>

InsertTryFailure ==
    /\ taskRow
    /\ ~tryRow
    /\ tryRow' = FALSE
    /\ trySeen' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED <<workflowRow, taskRow, workflowEndRow,
                    workflowSeen, taskSeen, workflowEnded>>

FinalizeSuccess ==
    /\ workflowRow
    /\ ~workflowEndRow
    /\ workflowEndRow' = TRUE
    /\ workflowEnded' = TRUE
    /\ UNCHANGED <<workflowRow, taskRow, tryRow,
                    workflowSeen, taskSeen, trySeen>>

FinalizeFailure ==
    /\ workflowRow
    /\ ~workflowEndRow
    /\ workflowEndRow' = FALSE
    /\ workflowEnded' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED <<workflowRow, taskRow, tryRow,
                    workflowSeen, taskSeen, trySeen>>

Next ==
    \/ InsertWorkflowSuccess
    \/ InsertWorkflowFailure
    \/ InsertTaskSuccess
    \/ InsertTaskFailure
    \/ InsertTrySuccess
    \/ InsertTryFailure
    \/ FinalizeSuccess
    \/ FinalizeFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ workflowRow \in BOOLEAN
    /\ taskRow \in BOOLEAN
    /\ tryRow \in BOOLEAN
    /\ workflowEndRow \in BOOLEAN
    /\ workflowSeen \in BOOLEAN
    /\ taskSeen \in BOOLEAN
    /\ trySeen \in BOOLEAN
    /\ workflowEnded \in BOOLEAN

WorkflowBookkeepingSafety == workflowSeen => workflowRow
TaskBookkeepingSafety == taskSeen => taskRow
TryBookkeepingSafety == trySeen => tryRow
WorkflowEndBookkeepingSafety == workflowEnded => workflowEndRow

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    WorkflowBookkeepingSafety
    TaskBookkeepingSafety
    TryBookkeepingSafety
    WorkflowEndBookkeepingSafety
