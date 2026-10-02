--------------------------- MODULE ParslGridEngineEmptySubmitFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Grid Engine empty qsub output composed with task, Future, and monitoring.
 *
 * A successful qsub command can still return no job identifier.  The unsafe
 * path returns None, leaving the scaling layer with an unusable submission
 * and an unresolved logical Future.  The fixed path rejects the submission
 * and publishes one terminal failure across the upper layers.
 ***************************************************************************)

CONSTANT USE_FIXED

SubmitStates == {"waiting", "returned_none", "rejected"}
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

ProcessEmptyOutput ==
    /\ submit = "waiting"
    /\ submit' = IF USE_FIXED THEN "rejected" ELSE "returned_none"
    /\ UNCHANGED <<task, future, monitor>>

PublishFailure ==
    /\ submit = "rejected"
    /\ task = "pending"
    /\ task' = "failed"
    /\ future' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED submit

Next ==
    \/ ProcessEmptyOutput
    \/ PublishFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ submit \in SubmitStates
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

NoUnusableSubmit == submit # "returned_none"

FailurePropagation ==
    task = "failed" => /\ future = "failed" /\ monitor = "failed"

TerminalFailureStability ==
    future = "failed" => task = "failed" /\ monitor = "failed"

=============================================================================
