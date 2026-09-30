--------------------------- MODULE ParslAwsInstanceStateShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.get_instance_state assumes every reservation contains at
 * least one instance and indexes Instances[0].  USE_FIXED models skipping a
 * malformed/empty reservation while preserving the state-refresh loop.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES reservationShape, refreshState
vars == <<reservationShape, refreshState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ reservationShape = "empty"
    /\ refreshState = "pending"

Refresh ==
    /\ reservationShape = "empty"
    /\ refreshState' = IF USE_FIXED THEN "skipped" ELSE "index-error"
    /\ UNCHANGED reservationShape

Done ==
    /\ refreshState # "pending"
    /\ UNCHANGED vars

Next == Refresh \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ reservationShape = "empty"
    /\ refreshState \in {"pending", "skipped", "index-error"}

NoRawIndexError ==
    refreshState # "index-error"

EmptyReservationIsolated ==
    refreshState = "skipped" => reservationShape = "empty"

=============================================================================
