--------------------------- MODULE ParslPBSProMalformedJSON ---------------------------
EXTENDS Naturals

(***************************************************************************
 * PBSProProvider._status parses qstat JSON without a parse-error boundary.
 * A truncated or otherwise malformed response can terminate polling instead
 * of preserving the last known resource state.  USE_FIXED models catching
 * the decode error and retaining that state for the next poll.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES response, state, jobStatus
vars == <<response, state, jobStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ response = "malformed"
    /\ state = "idle"
    /\ jobStatus = "running"

Poll ==
    /\ state = "idle"
    /\ state' = IF USE_FIXED THEN "preserved" ELSE "crashed"
    /\ UNCHANGED <<response, jobStatus>>

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ response = "malformed"
    /\ state \in {"idle", "preserved", "crashed"}
    /\ jobStatus = "running"

PollingSafety == state # "crashed"
=============================================================================
