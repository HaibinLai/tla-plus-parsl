--------------------------- MODULE ParslJoinCallbackMultiplicity ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Callback multiplicity for duplicate join-list positions.
 *
 * join_app registers one done-callback per list position.  If the same
 * Future occurs twice, completion schedules two callbacks.  The callbacks
 * must be processed independently, while only the first callback that sees
 * all inner Futures terminal may finalize the outer Future.
 ***************************************************************************)

INNER == {"I1", "I2"}
JoinInputs == <<"I1", "I1", "I2">>
InnerStates == {"pending", "succeeded", "failed"}
OuterStates == {"joining", "succeeded", "failed"}

VARIABLES innerState, callbackQueue, processed, outerState,
          outerResult, finalizeCount
vars == <<innerState, callbackQueue, processed, outerState,
           outerResult, finalizeCount>>

Init ==
    /\ innerState = [i \in INNER |-> "pending"]
    /\ callbackQueue = <<>>
    /\ processed = 0
    /\ outerState = "joining"
    /\ outerResult = <<>>
    /\ finalizeCount = 0

CompleteI1 ==
    /\ innerState["I1"] = "pending"
    /\ innerState' = [innerState EXCEPT !["I1"] = "succeeded"]
    /\ callbackQueue' = callbackQueue \o <<"I1", "I1">>
    /\ UNCHANGED <<processed, outerState, outerResult, finalizeCount>>

CompleteI2 ==
    /\ innerState["I2"] = "pending"
    /\ innerState' = [innerState EXCEPT !["I2"] = "succeeded"]
    /\ callbackQueue' = Append(callbackQueue, "I2")
    /\ UNCHANGED <<processed, outerState, outerResult, finalizeCount>>

FailI1 ==
    /\ innerState["I1"] = "pending"
    /\ innerState' = [innerState EXCEPT !["I1"] = "failed"]
    /\ callbackQueue' = callbackQueue \o <<"I1", "I1">>
    /\ UNCHANGED <<processed, outerState, outerResult, finalizeCount>>

FailI2 ==
    /\ innerState["I2"] = "pending"
    /\ innerState' = [innerState EXCEPT !["I2"] = "failed"]
    /\ callbackQueue' = Append(callbackQueue, "I2")
    /\ UNCHANGED <<processed, outerState, outerResult, finalizeCount>>

AllDone == \A j \in INNER : innerState[j] # "pending"
HasFailure == \E j \in INNER : innerState[j] = "failed"

RunCallback ==
    /\ Len(callbackQueue) > 0
    /\ LET i == Head(callbackQueue) IN
        /\ callbackQueue' = Tail(callbackQueue)
        /\ processed' = processed + 1
        /\ IF outerState = "joining" /\ AllDone /\ HasFailure
           THEN /\ outerState' = "failed"
                /\ outerResult' = <<>>
                /\ finalizeCount' = finalizeCount + 1
           ELSE IF outerState = "joining" /\ AllDone
                THEN /\ outerState' = "succeeded"
                     /\ outerResult' = <<"I1:result", "I1:result", "I2:result">>
                     /\ finalizeCount' = finalizeCount + 1
                ELSE /\ UNCHANGED <<outerState, outerResult, finalizeCount>>
    /\ UNCHANGED innerState

Next ==
    \/ CompleteI1
    \/ CompleteI2
    \/ FailI1
    \/ FailI2
    \/ RunCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ innerState \in [INNER -> InnerStates]
    /\ callbackQueue \in Seq(INNER)
    /\ processed \in 0..(Len(JoinInputs) + 1)
    /\ outerState \in OuterStates
    /\ outerResult \in Seq(STRING)
    /\ finalizeCount \in 0..1

DuplicatePositionSafety ==
    outerState = "succeeded" => outerResult = <<"I1:result", "I1:result", "I2:result">>

SingleFinalizationSafety ==
    finalizeCount <= 1

CallbackDrainSafety ==
    outerState \in {"succeeded", "failed"} => finalizeCount = 1

=============================================================================
