--------------------------- MODULE ParslJoinPartialCancellation ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * List-valued join cancellation after a partial callback sequence.  One
 * inner Future has already succeeded and been observed while another remains
 * pending.  When the second Future is cancelled, the current callback path
 * raises while the outer task is still joining; USE_FIXED converts the
 * cancellation into a terminal outer failure.
 *************************************************************************** *)

CONSTANT USE_FIXED
INNER == {"first", "second"}

VARIABLES innerState, observed, callbackPending, outerState, callbackRaised
vars == <<innerState, observed, callbackPending, outerState, callbackRaised>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ innerState = [i \in INNER |-> "pending"]
    /\ observed = {}
    /\ callbackPending = {}
    /\ outerState = "joining"
    /\ callbackRaised = FALSE

CompleteFirst ==
    /\ innerState["first"] = "pending"
    /\ innerState' = [innerState EXCEPT !["first"] = "succeeded"]
    /\ callbackPending' = callbackPending \cup {"first"}
    /\ UNCHANGED <<observed, outerState, callbackRaised>>

ObserveFirst ==
    /\ innerState["first"] = "succeeded"
    /\ "first" \notin observed
    /\ observed' = observed \cup {"first"}
    /\ callbackPending' = callbackPending \ {"first"}
    /\ UNCHANGED <<innerState, outerState, callbackRaised>>

CancelSecond ==
    /\ innerState["second"] = "pending"
    /\ "first" \in observed
    /\ innerState' = [innerState EXCEPT !["second"] = "cancelled"]
    /\ callbackPending' = callbackPending \cup {"second"}
    /\ UNCHANGED <<observed, outerState, callbackRaised>>

HandleSecond ==
    /\ innerState["second"] = "cancelled"
    /\ "second" \in callbackPending
    /\ callbackPending' = callbackPending \ {"second"}
    /\ IF USE_FIXED
          THEN /\ outerState' = "failed"
               /\ callbackRaised' = FALSE
          ELSE /\ outerState' = "joining"
               /\ callbackRaised' = TRUE
    /\ UNCHANGED <<innerState, observed>>

Done ==
    /\ outerState \in {"joining", "failed"}
    /\ UNCHANGED vars

Next == CompleteFirst \/ ObserveFirst \/ CancelSecond \/ HandleSecond \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ innerState \in [INNER -> {"pending", "succeeded", "cancelled"}]
    /\ observed \subseteq INNER
    /\ callbackPending \subseteq INNER
    /\ outerState \in {"joining", "failed"}
    /\ callbackRaised \in BOOLEAN

PartialCancellationTerminal ==
    innerState["second"] = "cancelled" /\ "second" \notin callbackPending
        => outerState = "failed"

NoCallbackEscape ==
    outerState = "failed" => ~callbackRaised

=============================================================================
