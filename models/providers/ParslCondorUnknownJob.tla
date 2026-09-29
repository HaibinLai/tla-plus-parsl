--------------------------- MODULE ParslCondorUnknownJob ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Condor status lookup for a stale local job id.
 *
 * CondorProvider.status polls its local resource map and then indexes every
 * requested id directly.  An id forgotten locally therefore raises KeyError;
 * USE_FIXED represents returning an explicit UNKNOWN status instead.
 *************************************************************************** *)

CONSTANT USE_FIXED
VARIABLES state, returnedUnknown
vars == <<state, returnedUnknown>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"
    /\ returnedUnknown = FALSE

Lookup ==
    /\ state = "requested"
    /\ state' = IF USE_FIXED THEN "unknown" ELSE "crashed"
    /\ returnedUnknown' = USE_FIXED

Next == Lookup \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"requested", "unknown", "crashed"}
    /\ returnedUnknown \in BOOLEAN

UnknownSafety == state = "unknown" => returnedUnknown
NoLookupCrash == state # "crashed"
=============================================================================
