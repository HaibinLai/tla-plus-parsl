--------------------------- MODULE ParslJoinDuplicateCancellation ---------------------------
EXTENDS Naturals

CONSTANT USE_FIXED

VARIABLES innerState, callbacks, processed, outerState, callbackRaised
vars == <<innerState, callbacks, processed, outerState, callbackRaised>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ innerState = "pending"
    /\ callbacks = IF USE_FIXED THEN 1 ELSE 2
    /\ processed = 0
    /\ outerState = "joining"
    /\ callbackRaised = FALSE

CancelInner ==
    /\ innerState = "pending"
    /\ innerState' = "cancelled"
    /\ UNCHANGED <<callbacks, processed, outerState, callbackRaised>>

RunCallback ==
    /\ innerState = "cancelled"
    /\ processed < callbacks
    /\ processed' = processed + 1
    /\ IF ~USE_FIXED
       THEN /\ callbackRaised' = TRUE
            /\ UNCHANGED outerState
       ELSE /\ callbackRaised' = FALSE
            /\ outerState' = IF processed + 1 = callbacks THEN "failed" ELSE "joining"
    /\ UNCHANGED <<innerState, callbacks>>

Next == CancelInner \/ RunCallback \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ innerState \in {"pending", "cancelled"}
    /\ callbacks \in 1..2
    /\ processed in 0..2
    /\ outerState \in {"joining", "failed"}
    /\ callbackRaised \in BOOLEAN

CallbackMultiplicitySafety == USE_FIXED => callbacks = 1
CancellationTerminalSafety == USE_FIXED => (outerState = "failed" => processed = callbacks)
NoEscapedCancellationCallback == USE_FIXED => ~callbackRaised

=============================================================================
