--------------------------- MODULE ParslDataFutureCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of DataFuture.parent_callback.
 *
 * The current callback checks only the parent's exception slot.  A cancelled
 * parent has no exception, so the current path publishes the file as ready.
 * USE_FIXED models a candidate guard that propagates cancellation instead.
 ***************************************************************************)

CONSTANT USE_FIXED

ParentStates == {"pending", "succeeded", "failed", "cancelled"}
DataStates == {"pending", "available", "failed"}

VARIABLES parentState, dataState
vars == <<parentState, dataState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ parentState = "pending"
    /\ dataState = "pending"

ParentSucceeds ==
    /\ parentState = "pending"
    /\ parentState' = "succeeded"
    /\ UNCHANGED dataState

ParentFails ==
    /\ parentState = "pending"
    /\ parentState' = "failed"
    /\ UNCHANGED dataState

ParentCancels ==
    /\ parentState = "pending"
    /\ parentState' = "cancelled"
    /\ UNCHANGED dataState

ParentCallback ==
    /\ parentState # "pending"
    /\ dataState = "pending"
    /\ IF parentState = "failed" THEN
           dataState' = "failed"
       ELSE IF parentState = "cancelled" /\ USE_FIXED THEN
           dataState' = "failed"
       ELSE
           dataState' = "available"
    /\ UNCHANGED parentState

Next ==
    \/ ParentSucceeds
    \/ ParentFails
    \/ ParentCancels
    \/ ParentCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ parentState \in ParentStates
    /\ dataState \in DataStates

FailurePropagationSafety ==
    /\ parentState = "failed" /\ dataState # "pending" => dataState = "failed"
    /\ parentState = "cancelled" /\ dataState # "pending" => dataState = "failed"

AvailabilitySafety ==
    dataState = "available" => parentState = "succeeded"

=============================================================================
