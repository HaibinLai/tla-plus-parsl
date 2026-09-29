--------------------------- MODULE ParslJoinInternalExecutor ---------------------------
EXTENDS Naturals

(***************************************************************************
 * join_app executor admission.
 *
 * DataFlowKernel creates an internal ThreadPoolExecutor and join_app fixes
 * its executor choice to `_parsl_internal`.  The unsafe branch represents a
 * regression that routes the outer join task through the user's `all`
 * executor set instead.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES internalPresent, target, state
vars == <<internalPresent, target, state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ internalPresent = TRUE
    /\ target = "none"
    /\ state = "new"

DispatchJoin ==
    /\ state = "new"
    /\ target' = IF USE_FIXED THEN "_parsl_internal" ELSE "all"
    /\ state' = "dispatched"
    /\ UNCHANGED internalPresent

Next == DispatchJoin \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ internalPresent \in BOOLEAN
    /\ target \in {"none", "_parsl_internal", "all"}
    /\ state \in {"new", "dispatched"}

InternalExecutorSafety ==
    state = "dispatched" => internalPresent /\ target = "_parsl_internal"

=============================================================================
