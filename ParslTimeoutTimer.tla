--------------------------- MODULE ParslTimeoutTimer ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of parsl.app.python.timeout and AutoCancelTimer.
 *
 * The timer is armed while the wrapped function runs.  A normal return or a
 * regular function exception exits the context manager and cancels the timer;
 * only a timer firing before function termination injects AppTimeout.
 ***************************************************************************)

CONSTANT FUNCTION_OUTCOME

Outcomes == {"success", "error"}
FunctionStates == {"idle", "running", "succeeded", "failed", "timed_out"}
TimerStates == {"new", "armed", "cancelled", "fired"}

VARIABLES functionState, timerState
vars == <<functionState, timerState>>

Init ==
    /\ FUNCTION_OUTCOME \in Outcomes
    /\ functionState = "idle"
    /\ timerState = "new"

Start ==
    /\ functionState = "idle"
    /\ functionState' = "running"
    /\ timerState' = "armed"

FunctionReturns ==
    /\ functionState = "running"
    /\ FUNCTION_OUTCOME = "success"
    /\ functionState' = "succeeded"
    /\ timerState' = "cancelled"

FunctionRaises ==
    /\ functionState = "running"
    /\ FUNCTION_OUTCOME = "error"
    /\ functionState' = "failed"
    /\ timerState' = "cancelled"

TimerFires ==
    /\ functionState = "running"
    /\ timerState = "armed"
    /\ functionState' = "timed_out"
    /\ timerState' = "fired"

Next ==
    \/ Start
    \/ FunctionReturns
    \/ FunctionRaises
    \/ TimerFires
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ functionState \in FunctionStates
    /\ timerState \in TimerStates

TimerCleanupSafety ==
    functionState \in {"succeeded", "failed"} => timerState = "cancelled"

TimeoutSafety ==
    functionState = "timed_out" => timerState = "fired"

=============================================================================
