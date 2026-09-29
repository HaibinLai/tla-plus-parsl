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

VARIABLES state, returned, resourcePresent
vars == <<state, returned, resourcePresent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "active"
    /\ returned = "none"
    /\ resourcePresent = TRUE

Cleanup ==
    /\ state = "active"
    /\ state' = "cleaned"
    /\ resourcePresent' = FALSE
    /\ UNCHANGED returned

Lookup ==
    /\ state = "cleaned"
    /\ state' = IF USE_FIXED THEN "unknown" ELSE "crashed"
    /\ returned' = IF USE_FIXED THEN "unknown" ELSE "none"
    /\ UNCHANGED resourcePresent

Next == Cleanup \/ Lookup \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"active", "cleaned", "unknown", "crashed"}
    /\ returned \in {"none", "unknown"}
    /\ resourcePresent \in BOOLEAN

UnknownStatusSafety == state = "unknown" => returned = "unknown"

PollDoesNotCrash == state # "crashed"

CleanupBoundary == state = "cleaned" => ~resourcePresent

=============================================================================
