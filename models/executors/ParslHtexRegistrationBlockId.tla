--------------------------- MODULE ParslHtexRegistrationBlockId ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX registration accepts a decoded manager record and later asserts that
 * block_id is not None. A pickleable registration with a null block id
 * therefore escapes the manager-message loop as AssertionError. USE_FIXED
 * models rejecting the registration before publishing manager state.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES blockId, managerState, outcome
vars == <<blockId, managerState, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ blockId = "none"
    /\ managerState = "unknown"
    /\ outcome = "pending"

Register ==
    /\ blockId = "none"
    /\ managerState' = IF USE_FIXED THEN "rejected" ELSE "published"
    /\ outcome' = IF USE_FIXED THEN "rejected" ELSE "assertion"
    /\ UNCHANGED blockId

Done ==
    /\ outcome # "pending"
    /\ UNCHANGED vars

Next == Register \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ blockId = "none"
    /\ managerState \in {"unknown", "rejected", "published"}
    /\ outcome \in {"pending", "rejected", "assertion"}

NoRawAssertion == outcome # "assertion"
NoNullManagerPublication == managerState = "published" => blockId # "none"

=============================================================================
