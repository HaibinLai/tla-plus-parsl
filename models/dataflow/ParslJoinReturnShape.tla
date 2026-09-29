--------------------------- MODULE ParslJoinReturnShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * join_app return-shape validation.
 *
 * DataFlowKernel accepts a single Future, a list containing only Futures, or
 * an empty list.  A tuple, scalar, or mixed list is rejected before callback
 * registration.  This small model makes that admission boundary explicit.
 *************************************************************************** *)

CONSTANT RETURN_SHAPE

Shapes == {"future", "future-list", "empty-list", "tuple", "scalar", "mixed-list"}
VARIABLES state, callbacksRegistered
vars == <<state, callbacksRegistered>>

Init ==
    /\ RETURN_SHAPE \in Shapes
    /\ state = "executing"
    /\ callbacksRegistered = FALSE

ValidateReturn ==
    /\ state = "executing"
    /\ IF RETURN_SHAPE \in {"future", "future-list", "empty-list"}
       THEN /\ state' = "joining"
            /\ callbacksRegistered' = (RETURN_SHAPE = "future-list")
       ELSE /\ state' = "failed"
            /\ callbacksRegistered' = FALSE

Next ==
    \/ ValidateReturn
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ RETURN_SHAPE \in Shapes
    /\ state \in {"executing", "joining", "failed"}
    /\ callbacksRegistered \in BOOLEAN

AcceptedShapeSafety ==
    state = "joining" => RETURN_SHAPE \in {"future", "future-list", "empty-list"}

InvalidShapeSafety ==
    state = "failed" =>
        RETURN_SHAPE \in {"tuple", "scalar", "mixed-list"}
        /\ ~callbacksRegistered

=============================================================================
