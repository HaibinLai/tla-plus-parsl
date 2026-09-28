--------------------------- MODULE ParslPythonTimeoutCatch ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Python-app walltime injection boundary.
 *
 * parsl.app.python.timeout injects AppTimeout into the worker thread.  A
 * user function can catch that exception and return normally, which means
 * the Future is resolved despite the elapsed walltime.  CATCHES_TIMEOUT
 * represents the current observable path; the fixed path rejects the catch.
 ***************************************************************************)

CONSTANT CATCHES_TIMEOUT

Phases == {"idle", "running", "injected", "succeeded", "timed_out"}

VARIABLES phase
vars == <<phase>>

Init ==
    /\ CATCHES_TIMEOUT \in BOOLEAN
    /\ phase = "idle"

Start ==
    /\ phase = "idle"
    /\ phase' = "running"

InjectTimeout ==
    /\ phase = "running"
    /\ phase' = "injected"

CatchTimeout ==
    /\ phase = "injected"
    /\ CATCHES_TIMEOUT
    /\ phase' = "succeeded"

PropagateTimeout ==
    /\ phase = "injected"
    /\ phase' = "timed_out"

Next ==
    \/ Start
    \/ InjectTimeout
    \/ CatchTimeout
    \/ PropagateTimeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK == phase \in Phases

TimeoutSafety == phase = "succeeded" => FALSE

=============================================================================
