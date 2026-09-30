--------------------------- MODULE ParslScaleInResultShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BlockProviderExecutor assumes provider.cancel returns one boolean for
 * every requested job.  A malformed/partial provider response reaches a raw
 * assertion in _filter_scale_in_ids.  USE_FIXED models rejecting the shape
 * as a controlled scale-in failure instead of exposing AssertionError.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES requested, returned, outcome
vars == <<requested, returned, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ requested = 2
    /\ returned = 1
    /\ outcome = "pending"

Filter ==
    /\ requested # returned
    /\ outcome' = IF USE_FIXED THEN "rejected" ELSE "assertion"
    /\ UNCHANGED <<requested, returned>>

Done ==
    /\ outcome # "pending"
    /\ UNCHANGED vars

Next == Filter \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ requested = 2
    /\ returned = 1
    /\ outcome \in {"pending", "rejected", "assertion"}

NoRawAssertion ==
    outcome # "assertion"

ShapeFailureIsTerminal ==
    outcome = "rejected" => requested # returned

=============================================================================
