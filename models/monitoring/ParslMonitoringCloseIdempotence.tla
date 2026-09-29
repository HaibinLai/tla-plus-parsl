--------------------------- MODULE ParslMonitoringCloseIdempotence ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager.close idempotence.
 *
 * An abnormal close with a workflow start message emits one finalization
 * update.  The current implementation leaves workflow_end false, so a
 * second close emits the same update again; the fixed branch records the
 * finalization and makes later closes no-ops.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLE state, finalizationCount, killSet
vars == <<state, finalizationCount, killSet>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "open"
    /\ finalizationCount = 0
    /\ killSet = FALSE

Close ==
    /\ finalizationCount < 2
    /\ IF USE_FIXED
          THEN /\ state = "open"
              /\ state' = "closed"
              /\ finalizationCount' = finalizationCount + 1
          ELSE /\ state' = "closed"
              /\ finalizationCount' = finalizationCount + 1
    /\ killSet' = TRUE

Next == Close \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"open", "closed"}
    /\ finalizationCount \in 0..2
    /\ killSet \in BOOLEAN

FinalizationSafety == finalizationCount <= 1
CloseSafety == state = "closed" => killSet

=============================================================================
