--------------------------- MODULE ParslCondorStatusUnknown ---------------------------
EXTENDS Naturals

\* CondorProvider.status projection for stale requested IDs.
\* The current override indexes every requested ID in ``resources`` after
\* polling, so a locally removed ID raises instead of returning UNKNOWN.

CONSTANT FIXED

VARIABLES resourcePresent, outcome
vars == <<resourcePresent, outcome>>

Init ==
    /\ FIXED \in BOOLEAN
    /\ resourcePresent = FALSE
    /\ outcome = "not_returned"

ProjectStatus ==
    /\ ~resourcePresent
    /\ outcome' = IF FIXED THEN "unknown" ELSE "key_error"
    /\ UNCHANGED resourcePresent

Next == ProjectStatus \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ FIXED \in BOOLEAN
    /\ resourcePresent \in BOOLEAN
    /\ outcome \in {"not_returned", "unknown", "key_error"}

StatusCardinalitySafety ==
    outcome # "key_error"

NoRawProjectionError ==
    outcome # "key_error"

=============================================================================
