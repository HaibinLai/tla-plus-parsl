--------------------------- MODULE ParslHtexAmbiguousResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX result message containing both result and exception fields.
 *
 * A valid result frame should carry exactly one terminal payload.  The
 * current worker checks for result first and silently ignores an accompanying
 * exception.  The fixed branch rejects the ambiguous frame as malformed.
 ***************************************************************************)

CONSTANT USE_FIXED

FutureStates == {"pending", "succeeded", "failed"}
WorkerStates == {"alive", "failed"}

VARIABLES futureState, workerState, ambiguousConsumed
vars == <<futureState, workerState, ambiguousConsumed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ futureState = "pending"
    /\ workerState = "alive"
    /\ ambiguousConsumed = FALSE

ReceiveAmbiguous ==
    /\ futureState = "pending"
    /\ ambiguousConsumed' = TRUE
    /\ IF USE_FIXED
          THEN /\ futureState' = "failed"
               /\ workerState' = "alive"
          ELSE /\ futureState' = "succeeded"
               /\ workerState' = "alive"

NoAmbiguousSuccess ==
    ambiguousConsumed => futureState # "succeeded"

Next == ReceiveAmbiguous \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ futureState \in FutureStates
    /\ workerState \in WorkerStates
    /\ ambiguousConsumed \in BOOLEAN

AmbiguousSafety ==
    ambiguousConsumed => futureState = "failed" /\ workerState = "alive"

=============================================================================
