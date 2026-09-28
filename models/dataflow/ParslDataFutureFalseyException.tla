--------------------------- MODULE ParslDataFutureFalseyException ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFuture.parent_callback tests the parent exception with truthiness.
 * A user exception may define __bool__ = FALSE, so the current path treats
 * that failed parent as success; the FIXED branch tests exception presence.
 *************************************************************************** *)

CONSTANTS FALSEY_EXCEPTION, USE_FIXED
VARIABLES parentState, dataState
vars == <<parentState, dataState>>

Init ==
    /\ FALSEY_EXCEPTION \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ parentState = "failed"
    /\ dataState = "pending"

Propagate ==
    /\ parentState = "failed"
    /\ dataState = "pending"
    /\ dataState' =
          IF FALSEY_EXCEPTION /\ ~USE_FIXED THEN "success"
          ELSE "failed"
    /\ UNCHANGED parentState

Next ==
    \/ Propagate
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ parentState \in {"failed"}
    /\ dataState \in {"pending", "success", "failed"}

FailurePropagationSafety ==
    parentState = "failed" => dataState # "success"

=============================================================================
