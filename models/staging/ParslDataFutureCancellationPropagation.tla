--------------------------- MODULE ParslDataFutureCancellationPropagation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFuture.parent_callback cancellation propagation.
 *
 * concurrent.futures represents a cancelled parent with no ordinary
 * exception object.  The current truthiness check therefore publishes the
 * represented file as a successful result.  USE_FIXED treats cancellation as
 * a non-success terminal state instead.
 ***************************************************************************)

CONSTANT USE_FIXED

ParentStates == {"cancelled"}
DataStates == {"pending", "ready", "failed"}

VARIABLES parentState, dataState
vars == <<parentState, dataState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ parentState = "cancelled"
    /\ dataState = "pending"

ParentCallback ==
    /\ parentState = "cancelled"
    /\ dataState = "pending"
    /\ dataState' = IF USE_FIXED THEN "failed" ELSE "ready"
    /\ UNCHANGED parentState

Next ==
    \/ ParentCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ parentState \in ParentStates
    /\ dataState \in DataStates

CancellationPropagationSafety ==
    parentState = "cancelled" => dataState # "ready"

=============================================================================
