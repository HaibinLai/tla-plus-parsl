--------------------------- MODULE ParslCondorEmptySubmitFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Condor empty submit response composed with task, Future, and monitoring.
 *
 * A successful condor_submit command with empty stdout causes the current
 * parser to index a missing job id and leak a raw error.  The fixed branch
 * turns that malformed admission result into one terminal failure visible to
 * the logical task, Future, and monitoring database.
 ***************************************************************************)

CONSTANT USE_FIXED

SubmitStates == {"waiting", "raw_error", "rejected"}
TaskStates == {"pending", "failed"}
FutureStates == {"pending", "failed"}
MonitorStates == {"none", "failed"}

VARIABLES submit, task, future, monitor
vars == <<submit, task, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ submit = "waiting"
    /\ task = "pending"
    /\ future = "pending"
    /\ monitor = "none"

ProcessEmptyResponse ==
    /\ submit = "waiting"
    /\ submit' = IF USE_FIXED THEN "rejected" ELSE "raw_error"
    /\ UNCHANGED <<task, future, monitor>>

PublishFailure ==
    /\ submit = "rejected"
    /\ task = "pending"
    /\ task' = "failed"
    /\ future' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED submit

Next ==
    \/ ProcessEmptyResponse
    \/ PublishFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ submit \in SubmitStates
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

NoRawEmptyResponse == submit # "raw_error"

FailurePropagation ==
    task = "failed" =>
        /\ future = "failed"
        /\ monitor = "failed"

TerminalFailureStability ==
    future = "failed" =>
        /\ task = "failed"
        /\ monitor = "failed"

=============================================================================
