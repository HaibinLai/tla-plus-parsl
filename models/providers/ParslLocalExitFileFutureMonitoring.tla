--------------------------- MODULE ParslLocalExitFileFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider live-process status composed with Future/monitoring.
 * A missing .ec exit-code file is a transient observation.  The poller must
 * preserve the running task and later propagate an explicit process failure.
 ***************************************************************************)

CONSTANT USE_FIXED

PollStates == {"ready", "observed", "crashed"}
ProcessStates == {"running", "failed"}
FutureStates == {"pending", "failed"}
MonitorStates == {"none", "failed"}

VARIABLES pollState, processState, status, future, monitor
vars == <<pollState, processState, status, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollState = "ready"
    /\ processState = "running"
    /\ status = "running"
    /\ future = "pending"
    /\ monitor = "none"

ReadMissingExitFile ==
    /\ pollState = "ready"
    /\ pollState' = IF USE_FIXED THEN "observed" ELSE "crashed"
    /\ status' = IF USE_FIXED THEN "unknown" ELSE status
    /\ UNCHANGED <<processState, future, monitor>>

ObserveProcessFailure ==
    /\ pollState = "observed"
    /\ status = "unknown"
    /\ pollState' = "observed"
    /\ processState' = "failed"
    /\ status' = "failed"
    /\ future' = "failed"
    /\ monitor' = "failed"

Next ==
    \/ ReadMissingExitFile
    \/ ObserveProcessFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollState \in PollStates
    /\ processState \in ProcessStates
    /\ status \in {"running", "unknown", "failed"}
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

PollerProgress == pollState # "crashed"

FailurePropagation ==
    future = "failed" => processState = "failed" /\ monitor = "failed"

UnknownObservation == pollState = "observed" => status \in {"unknown", "failed"}

=============================================================================
