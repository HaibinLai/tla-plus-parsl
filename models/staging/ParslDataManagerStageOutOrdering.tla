--------------------------- MODULE ParslDataManagerStageOutOrdering ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataManager/DataFlowKernel stage-out ordering.
 *
 * The output path starts provider.stage_out before it asks the provider to
 * replace/wrap the application function.  If wrapper construction fails, a
 * separate stage-out Future can remain active after task setup has failed.
 * USE_FIXED models preparing the wrapper before starting the transfer.
 ***************************************************************************)

CONSTANTS USE_FIXED, WRAPPER_OK

TransferStates == {"not_started", "running", "completed"}
WrapperStates == {"unknown", "ready", "failed"}
TaskStates == {"pending", "ready", "failed"}

VARIABLES transfer, wrapper, task
vars == <<transfer, wrapper, task>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ WRAPPER_OK \in BOOLEAN
    /\ transfer = "not_started"
    /\ wrapper = "unknown"
    /\ task = "pending"

StartTransferCurrent ==
    /\ ~USE_FIXED
    /\ transfer = "not_started"
    /\ transfer' = "running"
    /\ UNCHANGED <<wrapper, task>>

PrepareWrapperFixed ==
    /\ USE_FIXED
    /\ transfer = "not_started"
    /\ wrapper = "unknown"
    /\ IF WRAPPER_OK
          THEN /\ wrapper' = "ready"
               /\ UNCHANGED task
          ELSE /\ wrapper' = "failed"
               /\ task' = "failed"
    /\ UNCHANGED transfer

PrepareWrapperCurrent ==
    /\ ~USE_FIXED
    /\ transfer = "running"
    /\ wrapper = "unknown"
    /\ IF WRAPPER_OK
          THEN /\ wrapper' = "ready"
               /\ UNCHANGED task
          ELSE /\ wrapper' = "failed"
               /\ task' = "failed"
    /\ UNCHANGED transfer

StartTransferFixed ==
    /\ USE_FIXED
    /\ wrapper = "ready"
    /\ transfer = "not_started"
    /\ transfer' = "running"
    /\ UNCHANGED <<wrapper, task>>

CompleteTransfer ==
    /\ transfer = "running"
    /\ transfer' = "completed"
    /\ task' = "ready"
    /\ UNCHANGED wrapper

Next ==
    \/ StartTransferCurrent
    \/ PrepareWrapperFixed
    \/ PrepareWrapperCurrent
    \/ StartTransferFixed
    \/ CompleteTransfer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ transfer \in TransferStates
    /\ wrapper \in WrapperStates
    /\ task \in TaskStates

NoOrphanTransfer ==
    task = "failed" => transfer # "running"

ReadyRequiresTransfer ==
    task = "ready" => transfer = "completed"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    NoOrphanTransfer
    ReadyRequiresTransfer
