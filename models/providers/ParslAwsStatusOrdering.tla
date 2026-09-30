--------------------------- MODULE ParslAwsStatusOrdering ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.status must preserve the order of the requested job IDs.
 * EC2 reservations are allowed to arrive in another order.  The current
 * implementation appends states as returned by EC2, while USE_FIXED models
 * an ID-keyed projection back onto the request sequence.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, firstReturned, secondReturned
vars == <<phase, firstReturned, secondReturned>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ firstReturned = "none"
    /\ secondReturned = "none"

PollReversedReservations ==
    /\ phase = "ready"
    /\ phase' = "complete"
    /\ firstReturned' = IF USE_FIXED THEN "running" ELSE "completed"
    /\ secondReturned' = IF USE_FIXED THEN "completed" ELSE "running"

Next == PollReversedReservations \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"ready", "complete"}
    /\ firstReturned \in {"none", "running", "completed"}
    /\ secondReturned \in {"none", "running", "completed"}

OrderSafety ==
    phase = "complete" =>
        /\ firstReturned = "running"
        /\ secondReturned = "completed"

=============================================================================
