--------------------------- MODULE ParslAzureCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.cancel deletes a VM and then removes its id from
 * ``instances``.  If the cloud deletion succeeds but the local id is already
 * absent, Python's list.remove raises ValueError and the current method
 * reports False.  The FIXED branch treats that idempotent local cleanup as a
 * successful cancellation.
 ***************************************************************************)

CONSTANTS LINGER, INSTANCE_PRESENT, DELETE_SUCCEEDS, FIXED

CancelStates == {"ready", "ignored", "cancelled", "failed"}
VARIABLES cancelState, instancePresent
vars == <<cancelState, instancePresent>>

Init ==
    /\ LINGER \in BOOLEAN
    /\ INSTANCE_PRESENT \in BOOLEAN
    /\ DELETE_SUCCEEDS \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ cancelState = "ready"
    /\ instancePresent = INSTANCE_PRESENT

IgnoreLinger ==
    /\ cancelState = "ready"
    /\ LINGER
    /\ cancelState' = "ignored"
    /\ UNCHANGED instancePresent

DeleteFails ==
    /\ cancelState = "ready"
    /\ ~LINGER
    /\ ~DELETE_SUCCEEDS
    /\ cancelState' = "failed"
    /\ UNCHANGED instancePresent

DeleteSucceedsWithLocalId ==
    /\ cancelState = "ready"
    /\ ~LINGER
    /\ DELETE_SUCCEEDS
    /\ INSTANCE_PRESENT
    /\ cancelState' = "cancelled"
    /\ instancePresent' = FALSE

DeleteSucceedsWithoutLocalId ==
    /\ cancelState = "ready"
    /\ ~LINGER
    /\ DELETE_SUCCEEDS
    /\ ~INSTANCE_PRESENT
    /\ IF FIXED
          THEN cancelState' = "cancelled"
          ELSE cancelState' = "failed"
    /\ UNCHANGED instancePresent

Next ==
    \/ IgnoreLinger
    \/ DeleteFails
    \/ DeleteSucceedsWithLocalId
    \/ DeleteSucceedsWithoutLocalId
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ cancelState \in CancelStates
    /\ instancePresent \in BOOLEAN

CancelSafety ==
    cancelState = "cancelled" => ~instancePresent

SuccessfulDeleteSafety ==
    DELETE_SUCCEEDS /\ ~LINGER => cancelState # "failed"

LingerSafety ==
    cancelState = "ignored" => LINGER

=============================================================================
