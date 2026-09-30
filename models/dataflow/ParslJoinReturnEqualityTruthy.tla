--------------------------- MODULE ParslJoinReturnEqualityTruthy ---------------------------
EXTENDS Naturals

(***************************************************************************
 * join_app return-shape validation when an invalid object claims equality
 * with the empty list.  The current code takes the ``joinable == []`` branch
 * before checking the object's type, stores the object as ``joins``, and then
 * leaves the outer task pending when callback processing discovers the bad
 * shape.  USE_FIXED validates the type before any user equality operation.
 *************************************************************************** *)

CONSTANT USE_FIXED
States == {"body_done", "joining", "pending", "failed"}

VARIABLES state, equalityCalled
vars == <<state, equalityCalled>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "body_done"
    /\ equalityCalled = FALSE

ValidateReturn ==
    /\ state = "body_done"
    /\ IF USE_FIXED
          THEN /\ state' = "failed"
               /\ equalityCalled' = FALSE
          ELSE /\ state' = "joining"
               /\ equalityCalled' = TRUE

ProcessSpoofedEmpty ==
    /\ state = "joining"
    /\ state' = IF USE_FIXED THEN "failed" ELSE "pending"
    /\ UNCHANGED equalityCalled

Done ==
    /\ state \in {"failed", "pending"}
    /\ UNCHANGED vars

Next == ValidateReturn \/ ProcessSpoofedEmpty \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ equalityCalled \in BOOLEAN

InvalidReturnTerminal ==
    state \in {"failed", "pending"} => state = "failed"

NoUserEqualityOnInvalidType ==
    USE_FIXED => ~equalityCalled

=============================================================================
