--------------------------- MODULE ParslAzureStatusShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.status requests ``expand='instanceView'`` but assumes the
 * returned VM has a non-null instance_view object.  A response without that
 * object raises AttributeError before the existing short-list IndexError
 * handler can map the observation to PENDING.  USE_FIXED treats a missing
 * view as a non-terminal PENDING observation.
 ***************************************************************************)

CONSTANT VIEW_KIND, USE_FIXED
ViewKinds == {"missing", "short", "valid"}
Outcomes == {"waiting", "pending", "running", "crash"}

VARIABLES phase, outcome
vars == <<phase, outcome>>

Init ==
    /\ VIEW_KIND \in ViewKinds
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "queried"
    /\ outcome = "waiting"

HandleMissingView ==
    /\ phase = "queried"
    /\ VIEW_KIND = "missing"
    /\ phase' = "complete"
    /\ outcome' = IF USE_FIXED THEN "pending" ELSE "crash"

HandleShortView ==
    /\ phase = "queried"
    /\ VIEW_KIND = "short"
    /\ phase' = "complete"
    /\ outcome' = "pending"

HandleValidView ==
    /\ phase = "queried"
    /\ VIEW_KIND = "valid"
    /\ phase' = "complete"
    /\ outcome' = "running"

Next == HandleMissingView \/ HandleShortView \/ HandleValidView \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"queried", "complete"}
    /\ outcome \in Outcomes

StatusShapeSafety ==
    phase = "complete" => outcome # "crash"

=============================================================================
