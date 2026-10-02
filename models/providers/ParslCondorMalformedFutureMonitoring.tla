--------------------------- MODULE ParslCondorMalformedFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Condor status command failure composed with task/Future progress.
 * condor_q can return a failed command together with a truncated line.  The
 * poller must preserve its local state and continue to a later valid status;
 * it must not strand the logical Future or monitoring record.
 ***************************************************************************)

CONSTANT USE_FIXED

PollerStates == {"idle", "ready", "crashed"}
TaskStates == {"running", "succeeded"}
FutureStates == {"pending", "succeeded"}
MonitorStates == {"none", "succeeded"}

VARIABLES poller, task, future, monitor, failureSeen
vars == <<poller, task, future, monitor, failureSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ poller = "idle"
    /\ task = "running"
    /\ future = "pending"
    /\ monitor = "none"
    /\ failureSeen = FALSE

PollFailedMalformed ==
    /\ poller = "idle"
    /\ poller' = IF USE_FIXED THEN "ready" ELSE "crashed"
    /\ failureSeen' = TRUE
    /\ UNCHANGED <<task, future, monitor>>

PollValidCompletion ==
    /\ poller = "ready"
    /\ task = "running"
    /\ poller' = "ready"
    /\ task' = "succeeded"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED failureSeen

Next ==
    \/ PollFailedMalformed
    \/ PollValidCompletion
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ poller \in PollerStates
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ failureSeen \in BOOLEAN

PollerProgress == failureSeen => poller = "ready"

CompletionPropagation ==
    task = "succeeded" =>
        /\ future = "succeeded"
        /\ monitor = "succeeded"

NoCrashOnFailedCommand == poller # "crashed"

=============================================================================
