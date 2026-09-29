--------------------------- MODULE ParslHtexTaskContextType ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX task envelope context typing.  The ingress path indexes context and
 * immediately calls ``.get`` on it.  A decoded list/scalar context is
 * pickleable but is not a mapping, so the current loop can escape before the
 * task reaches the scheduler.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES state, queued
vars == <<state, queued>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "received"
    /\ queued = FALSE

ProcessMessage ==
    /\ state = "received"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ queued' = FALSE

Next == ProcessMessage \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"received", "ignored", "crashed"}
    /\ queued \in BOOLEAN

NoIngressCrash == state # "crashed"

=============================================================================
