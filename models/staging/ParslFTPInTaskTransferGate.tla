--------------------------- MODULE ParslFTPInTaskTransferGate ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FTP in-task staging combines byte publication, connection cleanup, and
 * user-function admission.  The current wrapper writes directly to the
 * final path and calls quit only after a successful transfer.
 ***************************************************************************
 *)

CONSTANT USE_FIXED
TransferStates == {"idle", "partial", "complete", "failed"}
ConnectionStates == {"open", "closed"}
AppStates == {"blocked", "ran"}

VARIABLES transfer, connection, app, visible
vars == <<transfer, connection, app, visible>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "idle"
    /\ connection = "open"
    /\ app = "blocked"
    /\ visible = FALSE

ChunkThenFailure ==
    /\ transfer = "idle"
    /\ transfer' = "partial"
    /\ visible' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ connection' = "open"
    /\ UNCHANGED app

HandleFailure ==
    /\ transfer = "partial"
    /\ transfer' = "failed"
    /\ connection' = "closed"
    /\ visible' = IF USE_FIXED THEN FALSE ELSE visible
    /\ UNCHANGED app

CompleteTransfer ==
    /\ transfer = "idle"
    /\ transfer' = "complete"
    /\ connection' = "closed"
    /\ visible' = TRUE
    /\ app' = "ran"

Next == ChunkThenFailure \/ HandleFailure \/ CompleteTransfer \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ transfer \in TransferStates
    /\ connection \in ConnectionStates
    /\ app \in AppStates
    /\ visible \in BOOLEAN

FailureCleanup == transfer = "failed" => connection = "closed" /\ ~visible
AdmissionSafety == app = "ran" => transfer = "complete" /\ visible

=========================================================================================
