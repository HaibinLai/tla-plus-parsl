----------------------- MODULE ParslJoinCallbackMonitoring -----------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Join callback and monitoring publication.
 *
 * A completed inner Future can schedule duplicate callbacks.  The real
 * DataFlowKernel holds the join lock and checks the outer state before
 * publishing the terminal result.  The Current branch models a callback
 * that publishes another terminal monitoring row after the outer join has
 * already completed; the Fixed branch makes terminal publication idempotent.
 *************************************************************************** *)

CONSTANT USE_FIXED

InnerStates == {"pending", "done"}
OuterStates == {"joining", "succeeded"}
FutureStates == {"pending", "done"}
MonitorStatuses == {"succeeded"}

VARIABLES inner, outer, future, callbackPending, rows
vars == <<inner, outer, future, callbackPending, rows>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ inner = "pending"
    /\ outer = "joining"
    /\ future = "pending"
    /\ callbackPending = 0
    /\ rows = <<>>

CompleteInner ==
    /\ inner = "pending"
    /\ inner' = "done"
    /\ callbackPending' = callbackPending + 1
    /\ UNCHANGED <<outer, future, rows>>

DuplicateCallback ==
    /\ inner = "done"
    /\ callbackPending < 2
    /\ callbackPending' = callbackPending + 1
    /\ UNCHANGED <<inner, outer, future, rows>>

RunCallback ==
    /\ callbackPending > 0
    /\ callbackPending' = callbackPending - 1
    /\ IF outer = "joining" /\ inner = "done"
          THEN /\ outer' = "succeeded"
               /\ future' = "done"
               /\ rows' = Append(rows, "succeeded")
          ELSE IF USE_FIXED
               THEN /\ UNCHANGED <<outer, future, rows>>
               ELSE /\ rows' = Append(rows, "succeeded")
                    /\ UNCHANGED <<outer, future>>
    /\ UNCHANGED inner

Next ==
    \/ CompleteInner
    \/ DuplicateCallback
    \/ RunCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ inner \in InnerStates
    /\ outer \in OuterStates
    /\ future \in FutureStates
    /\ callbackPending \in 0..2
    /\ rows \in Seq(MonitorStatuses)

TerminalPublicationBound == Len(rows) <= 1
FutureMonitoringConsistency == future = "done" => outer = "succeeded" /\ Len(rows) >= 1
NoPrematureMonitoring == Len(rows) > 0 => inner = "done"

=============================================================================
