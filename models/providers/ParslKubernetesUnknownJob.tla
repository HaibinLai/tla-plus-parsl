--------------------------- MODULE ParslKubernetesUnknownJob ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Kubernetes status lookup for an unknown local job id.
 *
 * status() currently indexes self.resources[jid] directly after polling, so a
 * stale id raises KeyError.  USE_FIXED represents returning an explicit
 * UNKNOWN JobStatus for an id absent from local bookkeeping.
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
