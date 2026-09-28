--------------------------- MODULE ParslGoogleCloudCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GoogleCloudProvider.cancel delegates to delete_instance but currently does
 * not update the local resource status.  A successful remote delete can thus
 * leave a locally RUNNING resource.  The FIXED branch marks it COMPLETED.
 *************************************************************************** *)

CONSTANTS DELETE_SUCCEEDS, RESOURCE_PRESENT, USE_FIXED

States == {"ready", "deleted", "failed"}
ResourceStates == {"running", "completed", "absent"}
VARIABLES state, resourceState
vars == <<state, resourceState>>

Init ==
    /\ DELETE_SUCCEEDS \in BOOLEAN
    /\ RESOURCE_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ resourceState = IF RESOURCE_PRESENT THEN "running" ELSE "absent"

DeleteFails ==
    /\ state = "ready"
    /\ ~DELETE_SUCCEEDS
    /\ state' = "failed"
    /\ UNCHANGED resourceState

DeleteSucceeds ==
    /\ state = "ready"
    /\ DELETE_SUCCEEDS
    /\ state' = "deleted"
    /\ resourceState' = IF USE_FIXED /\ RESOURCE_PRESENT
                           THEN "completed"
                           ELSE resourceState

Next ==
    \/ DeleteFails
    \/ DeleteSucceeds
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ resourceState \in ResourceStates

DeleteStatusSafety ==
    state = "deleted" => resourceState \in {"completed", "absent"}

=============================================================================
