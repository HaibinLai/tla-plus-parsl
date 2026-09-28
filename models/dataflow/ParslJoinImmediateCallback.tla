--------------------------- MODULE ParslJoinImmediateCallback ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * join_app registration race.
 *
 * An inner Future can already be complete when the outer join registers its
 * callback.  add_done_callback may invoke the callback immediately, so the
 * outer task must enter joining state and install its lock before registration.
 ***************************************************************************)

InnerStates == {"unresolved", "succeeded"}
OuterStates == {"new", "joining", "succeeded"}

VARIABLES outerState, innerState, callbackPending, callbackLock, result
vars == <<outerState, innerState, callbackPending, callbackLock, result>>

Init ==
    /\ outerState = "new"
    /\ innerState = [i \in {"I1", "I2"} |->
          IF i = "I1" THEN "succeeded" ELSE "unresolved"]
    /\ callbackPending = {}
    /\ callbackLock = FALSE
    /\ result = <<>>

RegisterAlreadyDone ==
    /\ outerState = "new"
    /\ innerState["I1"] = "succeeded"
    /\ outerState' = "joining"
    /\ callbackPending' = {"I1"}
    /\ UNCHANGED <<innerState, callbackLock, result>>

CompleteSecond ==
    /\ outerState = "joining"
    /\ innerState["I2"] = "unresolved"
    /\ innerState' = [innerState EXCEPT !["I2"] = "succeeded"]
    /\ callbackPending' = callbackPending \cup {"I2"}
    /\ UNCHANGED <<outerState, callbackLock, result>>

StartCallback(i) ==
    /\ outerState = "joining"
    /\ i \in callbackPending
    /\ ~callbackLock
    /\ callbackPending' = callbackPending \ {i}
    /\ callbackLock' = TRUE
    /\ UNCHANGED <<outerState, innerState, result>>

RunCallback ==
    /\ outerState = "joining"
    /\ callbackLock
    /\ callbackLock' = FALSE
    /\ IF \A i \in {"I1", "I2"} : innerState[i] = "succeeded"
       THEN /\ outerState' = "succeeded"
            /\ result' = <<"I1:result", "I2:result">>
       ELSE /\ UNCHANGED <<outerState, result>>
    /\ UNCHANGED <<innerState, callbackPending>>

Next ==
    \/ RegisterAlreadyDone
    \/ CompleteSecond
    \/ \E i \in {"I1", "I2"} : StartCallback(i)
    \/ RunCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ innerState \in [{"I1", "I2"} -> InnerStates]
    /\ callbackPending \subseteq {"I1", "I2"}
    /\ callbackLock \in BOOLEAN
    /\ result \in Seq(STRING)

RegistrationSafety ==
    outerState = "new" =>
        /\ callbackPending = {}
        /\ ~callbackLock

CompletionSafety ==
    outerState = "succeeded" =>
        /\ innerState["I1"] = "succeeded"
        /\ innerState["I2"] = "succeeded"
        /\ result = <<"I1:result", "I2:result">>

=============================================================================
