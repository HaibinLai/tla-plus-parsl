--------------------------- MODULE ParslHTTPInTaskCleanupGate ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP in-task staging composition: response lifetime, destination bytes,
 * and wrapped-task admission. A stream failure must not leave a published
 * partial input or an open response, even though user code is blocked.
 ***************************************************************************
 *)

CONSTANT USE_FIXED
TransferStates == {"idle", "partial", "complete", "failed"}
ResponseStates == {"open", "closed"}
AppStates == {"blocked", "ran"}

VARIABLES transfer, response, visible, app
vars == <<transfer, response, visible, app>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "idle"
    /\ response = "open"
    /\ visible = FALSE
    /\ app = "blocked"

StreamFailure ==
    /\ transfer = "idle"
    /\ transfer' = "partial"
    /\ visible' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ response' = "open"
    /\ UNCHANGED app

CleanupFailure ==
    /\ transfer = "partial"
    /\ transfer' = "failed"
    /\ response' = "closed"
    /\ visible' = IF USE_FIXED THEN FALSE ELSE visible
    /\ UNCHANGED app

SuccessfulTransfer ==
    /\ transfer = "idle"
    /\ transfer' = "complete"
    /\ response' = "closed"
    /\ visible' = TRUE
    /\ app' = "ran"

Next == StreamFailure \/ CleanupFailure \/ SuccessfulTransfer \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ transfer \in TransferStates
    /\ response \in ResponseStates
    /\ visible \in BOOLEAN
    /\ app \in AppStates

FailureCleanup == transfer = "failed" => response = "closed" /\ ~visible
AdmissionSafety == app = "ran" => transfer = "complete" /\ visible

=========================================================================================
