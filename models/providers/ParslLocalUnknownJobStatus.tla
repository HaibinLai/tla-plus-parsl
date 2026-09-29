--------------------------- MODULE ParslLocalUnknownJobStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider.status and a stale local job id.
 *
 * A poll can retain an id after the provider has removed its resource entry.
 * The current return comprehension indexes the missing id directly.  The
 * fixed branch returns an explicit UNKNOWN status for that observation.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, returned
vars == <<state, returned>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"
    /\ returned = "none"

Lookup ==
    /\ state = "requested"
    /\ state' = IF USE_FIXED THEN "unknown" ELSE "crashed"
    /\ returned' = IF USE_FIXED THEN "unknown" ELSE "none"

Next == Lookup \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"requested", "unknown", "crashed"}
    /\ returned \in {"none", "unknown"}

UnknownStatusSafety == state = "unknown" => returned = "unknown"

PollDoesNotCrash == state # "crashed"

=============================================================================
