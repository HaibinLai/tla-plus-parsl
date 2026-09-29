--------------------------- MODULE ParslTimerReentrantClose ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Re-entrant parsl.utils.Timer.close() from the timer's own callback.
 *
 * Timer.close sets the kill event and then joins its thread.  When a callback
 * calls close on that same Timer, the current implementation attempts to join
 * the current thread and leaks RuntimeError.  The fixed branch treats this as
 * an in-callback close: it sets the kill event and returns without joining.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"running", "callback", "closed", "error"}

VARIABLES timerState, callbackState, closeOutcome
vars == <<timerState, callbackState, closeOutcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ timerState = "running"
    /\ callbackState = "callback"
    /\ closeOutcome = "none"

CloseFromCallback ==
    /\ timerState = "running"
    /\ callbackState = "callback"
    /\ timerState' = IF USE_FIXED THEN "closed" ELSE "error"
    /\ callbackState' = IF USE_FIXED THEN "idle" ELSE "callback"
    /\ closeOutcome' = IF USE_FIXED THEN "returned" ELSE "join_error"

CallbackReturnsAfterError ==
    /\ timerState = "error"
    /\ callbackState = "callback"
    /\ timerState' = "closed"
    /\ callbackState' = "idle"
    /\ UNCHANGED closeOutcome

Next ==
    \/ CloseFromCallback
    \/ CallbackReturnsAfterError
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ timerState \in {"running", "callback", "closed", "error"}
    /\ callbackState \in {"callback", "idle"}
    /\ closeOutcome \in {"none", "returned", "join_error"}

ReentrantCloseSafety ==
    closeOutcome = "join_error" => USE_FIXED

ClosedCallbackSafety ==
    timerState = "closed" => callbackState = "idle"

=============================================================================
