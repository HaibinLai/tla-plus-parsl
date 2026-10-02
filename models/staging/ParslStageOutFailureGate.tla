--------------------------- MODULE ParslStageOutFailureGate ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Stage-out must remain causally gated by the application Future.
 *
 * DataManager.stage_out passes the application Future to the selected
 * provider.  A provider that publishes successful output after the
 * application has failed violates the logical-task/data-transfer boundary.
 ***************************************************************************)

CONSTANT USE_FIXED

AppStates == {"pending", "running", "succeeded", "failed"}
TransferStates == {"not_started", "running", "succeeded", "failed"}
OutputStates == {"blocked", "ready", "failed"}

VARIABLES app, transfer, output
vars == <<app, transfer, output>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ app = "pending"
    /\ transfer = "not_started"
    /\ output = "blocked"

StartApp ==
    /\ app = "pending"
    /\ app' = "running"
    /\ UNCHANGED <<transfer, output>>

FailApp ==
    /\ app = "running"
    /\ app' = "failed"
    /\ UNCHANGED <<transfer, output>>

StartTransfer ==
    /\ app = "failed"
    /\ transfer = "not_started"
    /\ transfer' = "running"
    /\ UNCHANGED <<app, output>>

FinishTransfer ==
    /\ transfer = "running"
    /\ IF USE_FIXED
          THEN transfer' = "failed"
          ELSE transfer' = "succeeded"
    /\ UNCHANGED <<app, output>>

Publish ==
    /\ transfer \in {"succeeded", "failed"}
    /\ output = "blocked"
    /\ IF transfer = "succeeded"
          THEN IF USE_FIXED
                  THEN output' = "failed"
                  ELSE output' = "ready"
          ELSE output' = "failed"
    /\ UNCHANGED <<app, transfer>>

Next == StartApp \/ FailApp \/ StartTransfer \/ FinishTransfer \/ Publish \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ app \in AppStates
    /\ transfer \in TransferStates
    /\ output \in OutputStates

FailureGate == app = "failed" => output # "ready"

=============================================================================
