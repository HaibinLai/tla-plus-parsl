--------------------------- MODULE ParslAwsEmptySubmitFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWS empty-submit response composed with task, Future, and monitoring.
 *
 * AWSProvider.submit can receive an EC2 launch response with no instances.
 * The unsafe path crashes while unpacking the response, leaving the logical
 * task and its Future unresolved.  The fixed path converts the provider
 * failure into a terminal task/Future/monitoring failure.
 ***************************************************************************)

CONSTANT USE_FIXED

SubmitStates == {"empty_response", "failed", "crashed"}
TaskStates == {"pending", "failed"}
FutureStates == {"pending", "failed"}
MonitorStates == {"none", "failed"}

VARIABLES submit, task, future, monitor
vars == <<submit, task, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ submit = "empty_response"
    /\ task = "pending"
    /\ future = "pending"
    /\ monitor = "none"

HandleEmptyResponse ==
    /\ submit = "empty_response"
    /\ submit' = IF USE_FIXED THEN "failed" ELSE "crashed"
    /\ UNCHANGED <<task, future, monitor>>

PublishFailure ==
    /\ submit = "failed"
    /\ task = "pending"
    /\ task' = "failed"
    /\ future' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED submit

Next ==
    \/ HandleEmptyResponse
    \/ PublishFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ submit \in SubmitStates
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

NoCrashOnSubmit == submit # "crashed"

FailurePropagation ==
    task = "failed" => /\ future = "failed" /\ monitor = "failed"

TerminalFailureStability ==
    future = "failed" => task = "failed" /\ monitor = "failed"

=============================================================================
