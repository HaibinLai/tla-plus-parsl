--------------------------- MODULE ParslSlurmCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * SlurmProvider.cancel sends one scancel command for a batch of ids and then
 * marks each local resource CANCELLED.  A successful scheduler command that
 * includes a stale local id currently raises while indexing resources.
 *************************************************************************** *)

CONSTANTS CANCEL_SUCCEEDS, RESOURCE_PRESENT, USE_FIXED

States == {"ready", "cancelled", "failed"}
ResourceStates == {"running", "cancelled", "absent"}
VARIABLES state, resourceState
vars == <<state, resourceState>>

Init ==
    /\ CANCEL_SUCCEEDS \in BOOLEAN
    /\ RESOURCE_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ resourceState = IF RESOURCE_PRESENT THEN "running" ELSE "absent"

CancelFailure ==
    /\ state = "ready"
    /\ ~CANCEL_SUCCEEDS
    /\ state' = "failed"
    /\ UNCHANGED resourceState

CancelSuccess ==
    /\ state = "ready"
    /\ CANCEL_SUCCEEDS
    /\ state' = "cancelled"
    /\ resourceState' = IF USE_FIXED /\ RESOURCE_PRESENT
                           THEN "cancelled"
                           ELSE resourceState

Next ==
    \/ CancelFailure
    \/ CancelSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ resourceState \in ResourceStates

CancelStatusSafety ==
    state = "cancelled" => resourceState \in {"cancelled", "absent"}

=============================================================================
