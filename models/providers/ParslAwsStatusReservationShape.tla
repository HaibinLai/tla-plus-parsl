--------------------------- MODULE ParslAwsStatusReservationShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.status assumes every reservation contains an Instances list.
 * A successful but partial describe_instances response can omit that nested
 * field, raising KeyError before later healthy reservations are processed.
 * USE_FIXED models isolating the malformed reservation as UNKNOWN.
 ***************************************************************************)

CONSTANT RESPONSE_SHAPE, USE_FIXED
VARIABLES phase, malformed_status, healthy_status, outcome
vars == <<phase, malformed_status, healthy_status, outcome>>

Init ==
    /\ RESPONSE_SHAPE \in {"valid", "missing_instances"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "query"
    /\ malformed_status = "running"
    /\ healthy_status = "running"
    /\ outcome = "waiting"

HandleReservation ==
    /\ phase = "query"
    /\ RESPONSE_SHAPE = "missing_instances"
    /\ phase' = "complete"
    /\ malformed_status' = IF USE_FIXED THEN "unknown" ELSE malformed_status
    /\ healthy_status' = IF USE_FIXED THEN "running" ELSE "unobserved"
    /\ outcome' = IF USE_FIXED THEN "isolated" ELSE "crash"

HandleValid ==
    /\ phase = "query"
    /\ RESPONSE_SHAPE = "valid"
    /\ phase' = "complete"
    /\ malformed_status' = "running"
    /\ healthy_status' = "running"
    /\ outcome' = "complete"

Next == HandleReservation \/ HandleValid \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"query", "complete"}
    /\ malformed_status \in {"running", "unknown"}
    /\ healthy_status \in {"running", "unobserved"}
    /\ outcome \in {"waiting", "isolated", "complete", "crash"}

NestedShapeSafety == phase = "complete" => outcome # "crash"
HealthyObservationPreserved ==
    phase = "complete" /\ RESPONSE_SHAPE = "missing_instances" /\ USE_FIXED
        => healthy_status = "running"
=============================================================================
