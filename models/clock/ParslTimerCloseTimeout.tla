--------------------------- MODULE ParslTimerCloseTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * parsl.utils.Timer.close(timeout) while a callback is still executing.
 *
 * close sets the kill event and joins with the supplied timeout.  The current
 * method returns None even if the callback thread remains alive. USE_FIXED
 * models an explicit closing outcome rather than reporting a completed close.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES timerState, callbackState, closeOutcome
vars == <<timerState, callbackState, closeOutcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ timerState = "running"
    /\ callbackState = "running"
    /\ closeOutcome = "none"

CloseTimesOut ==
    /\ timerState = "running"
    /\ callbackState = "running"
    /\ timerState' = IF USE_FIXED THEN "closing" ELSE "closed"
    /\ callbackState' = "running"
    /\ closeOutcome' = IF USE_FIXED THEN "timeout" ELSE "returned"

CallbackReturns ==
    /\ timerState \in {"closing", "closed"}
    /\ callbackState = "running"
    /\ timerState' = "closed"
    /\ callbackState' = "idle"
    /\ UNCHANGED closeOutcome

Next ==
    \/ CloseTimesOut
    \/ CallbackReturns
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ timerState \in {"running", "closing", "closed"}
    /\ callbackState \in {"running", "idle"}
    /\ closeOutcome \in {"none", "returned", "timeout"}

CloseQuiescenceSafety ==
    closeOutcome = "returned" => callbackState = "idle"

=============================================================================
