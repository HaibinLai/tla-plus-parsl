--------------------------- MODULE ParslAwsUnknownInstance ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.status and stale EC2 instance ids.
 *
 * EC2 can report an instance that is not present in the provider's local
 * resources map (for example after an external termination/replacement). The
 * current status loop indexes that map directly.  USE_FIXED models treating
 * the observation as an UNKNOWN status instead of aborting the poll.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, returned, localKnown
vars == <<state, returned, localKnown>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "reported"
    /\ returned = "none"
    /\ localKnown = FALSE

HandleReportedInstance ==
    /\ state = "reported"
    /\ state' = IF USE_FIXED THEN "unknown" ELSE "crashed"
    /\ returned' = IF USE_FIXED THEN "unknown" ELSE "none"
    /\ UNCHANGED localKnown

Next == HandleReportedInstance \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"reported", "unknown", "crashed"}
    /\ returned \in {"none", "unknown"}
    /\ localKnown \in BOOLEAN

UnknownObservationSafety ==
    state = "unknown" => returned = "unknown"

PollDoesNotCrash == state # "crashed"

=============================================================================
