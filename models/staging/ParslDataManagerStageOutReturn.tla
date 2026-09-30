--------------------------- MODULE ParslDataManagerStageOutReturn ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataManager.stage_out return contract.
 *
 * A staging provider may return no Future (the output DataFuture follows the
 * application Future), or may return an independent Future for a separate
 * transfer.  In both cases the published output must not become ready before
 * the application and the selected transfer have completed.
 ***************************************************************************)

CONSTANT WAIT_FOR_TRANSFER

AppStates == {"pending", "running", "done"}
TransferStates == {"not_started", "running", "done"}
OutputStates == {"blocked", "ready"}

VARIABLES app, transfer, output
vars == <<app, transfer, output>>

Init ==
    /\ WAIT_FOR_TRANSFER \in BOOLEAN
    /\ app = "pending"
    /\ transfer = "not_started"
    /\ output = "blocked"

StartApp ==
    /\ app = "pending"
    /\ app' = "running"
    /\ UNCHANGED <<transfer, output>>

FinishApp ==
    /\ app = "running"
    /\ app' = "done"
    /\ UNCHANGED <<transfer, output>>

StartStageOut ==
    /\ app = "done"
    /\ transfer = "not_started"
    /\ transfer' = IF WAIT_FOR_TRANSFER THEN "running" ELSE "done"
    /\ UNCHANGED <<app, output>>

FinishStageOut ==
    /\ transfer = "running"
    /\ transfer' = "done"
    /\ UNCHANGED <<app, output>>

PublishOutput ==
    /\ app = "done"
    /\ transfer = "done"
    /\ output = "blocked"
    /\ output' = "ready"
    /\ UNCHANGED <<app, transfer>>

Next ==
    \/ StartApp
    \/ FinishApp
    \/ StartStageOut
    \/ FinishStageOut
    \/ PublishOutput
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ app \in AppStates
    /\ transfer \in TransferStates
    /\ output \in OutputStates

OutputReadinessSafety ==
    output = "ready" => /\ app = "done" /\ transfer = "done"

StageOutChoiceSafety ==
    transfer = "done" => app = "done"

=============================================================================
