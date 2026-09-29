--------------------------- MODULE ParslMonitoringHubClose ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MonitoringHub.close lifecycle.
 *
 * The hub signals the DB process, waits for it, then closes and joins the
 * resource queue.  A second close call is a no-op because the active flag is
 * cleared before those cleanup actions are attempted again.
 *************************************************************************** *)

VARIABLES hubState, stopSignals, processJoins, queueCloses, queueJoins
vars == <<hubState, stopSignals, processJoins, queueCloses, queueJoins>>

Init ==
    /\ hubState = "active"
    /\ stopSignals = 0
    /\ processJoins = 0
    /\ queueCloses = 0
    /\ queueJoins = 0

Close ==
    /\ hubState = "active"
    /\ hubState' = "closed"
    /\ stopSignals' = stopSignals + 1
    /\ processJoins' = processJoins + 1
    /\ queueCloses' = queueCloses + 1
    /\ queueJoins' = queueJoins + 1

RepeatedClose ==
    /\ hubState = "closed"
    /\ UNCHANGED vars

Next ==
    \/ Close
    \/ RepeatedClose

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ hubState \in {"active", "closed"}
    /\ stopSignals \in Nat
    /\ processJoins \in Nat
    /\ queueCloses \in Nat
    /\ queueJoins \in Nat

CloseSafety ==
    hubState = "closed" =>
        /\ stopSignals = 1
        /\ processJoins = 1
        /\ queueCloses = 1
        /\ queueJoins = 1

IdempotentClose ==
    stopSignals <= 1 /\ processJoins <= 1 /\ queueCloses <= 1 /\ queueJoins <= 1

=============================================================================
