--------------------------- MODULE ParslPeriodicTimer ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of parsl.utils.Timer and the JobStatusPoller/checkpoint
 * timers built on top of it.
 *
 * Timer invokes its callback once immediately, then periodically.  Callback
 * exceptions are logged and do not terminate the timer thread.  close() sets
 * the kill event and joins the thread; after the close boundary no new
 * callbacks are started.
 ***************************************************************************)

CONSTANT MAX_CALLBACKS

TimerStates == {"new", "running", "closed"}
CallbackStates == {"idle", "running", "succeeded", "failed"}

VARIABLES timerState, callbackState, callbackCount, failureCount
vars == <<timerState, callbackState, callbackCount, failureCount>>

Init ==
    /\ MAX_CALLBACKS \in Nat
    /\ timerState = "new"
    /\ callbackState = "idle"
    /\ callbackCount = 0
    /\ failureCount = 0

Start ==
    /\ timerState = "new"
    /\ callbackState = "idle"
    /\ timerState' = "running"
    /\ callbackState' = "running"
    /\ callbackCount' = 1
    /\ failureCount' = 0

CallbackSucceeds ==
    /\ timerState = "running"
    /\ callbackState = "running"
    /\ callbackState' = "succeeded"
    /\ UNCHANGED <<timerState, callbackCount, failureCount>>

CallbackFails ==
    /\ timerState = "running"
    /\ callbackState = "running"
    /\ callbackState' = "failed"
    /\ failureCount' = failureCount + 1
    /\ UNCHANGED <<timerState, callbackCount>>

NextCallback ==
    /\ timerState = "running"
    /\ callbackState \in {"succeeded", "failed"}
    /\ callbackCount < MAX_CALLBACKS
    /\ callbackState' = "running"
    /\ callbackCount' = callbackCount + 1
    /\ UNCHANGED <<timerState, failureCount>>

Close ==
    /\ timerState = "running"
    /\ callbackState \in {"succeeded", "failed"}
    /\ timerState' = "closed"
    /\ callbackState' = "idle"
    /\ UNCHANGED <<callbackCount, failureCount>>

Next ==
    \/ Start
    \/ CallbackSucceeds
    \/ CallbackFails
    \/ NextCallback
    \/ Close
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ timerState \in TimerStates
    /\ callbackState \in CallbackStates
    /\ callbackCount \in Nat
    /\ failureCount \in Nat
    /\ callbackCount <= MAX_CALLBACKS
    /\ failureCount <= callbackCount

ImmediateCallback == timerState = "running" => callbackCount >= 1

FailureDoesNotStop ==
    failureCount > 0 => timerState \in {"running", "closed"}

ClosedIsQuiescent ==
    timerState = "closed" => callbackState = "idle"

=============================================================================
