--------------------------- MODULE ParslJoinReturnEquality ---------------------------
EXTENDS Naturals

(***************************************************************************
 * join_app return-shape validation.
 *
 * DataFlowKernel currently evaluates ``joinable == []`` before checking
 * whether the value is a Future or list.  A user object with an exception-
 * raising __eq__ can therefore escape the callback and leave the outer Future
 * unresolved.  The fixed branch validates the type first and produces the
 * normal terminal TypeError path.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"body_done", "pending", "failed", "callback_error"}

VARIABLES state, equalityRaised
vars == <<state, equalityRaised>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "body_done"
    /\ equalityRaised = FALSE

ValidateReturn ==
    /\ state = "body_done"
    /\ IF USE_FIXED
          THEN /\ state' = "failed"
               /\ equalityRaised' = FALSE
          ELSE /\ state' = "callback_error"
               /\ equalityRaised' = TRUE

Next ==
    \/ ValidateReturn
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ equalityRaised \in BOOLEAN

ReturnValidationSafety ==
    state = "callback_error" => USE_FIXED

TerminalValidationSafety ==
    state = "failed" => ~equalityRaised

=============================================================================
