--------------------------- MODULE ParslPBSProMalformedFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * PBS Pro qstat JSON decode composed with task/Future progress.  A malformed
 * response must be isolated so the next valid poll can complete the logical
 * task and publish its monitoring status.
 ***************************************************************************)

CONSTANT USE_FIXED

PollerStates == {"idle", "ready", "crashed"}
TaskStates == {"running", "succeeded"}
FutureStates == {"pending", "succeeded"}
MonitorStates == {"none", "succeeded"}

VARIABLES poller, task, future, monitor, malformedSeen
vars == <<poller, task, future, monitor, malformedSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ poller = "idle"
    /\ task = "running"
    /\ future = "pending"
    /\ monitor = "none"
    /\ malformedSeen = FALSE

PollMalformedJSON ==
    /\ poller = "idle"
    /\ poller' = IF USE_FIXED THEN "ready" ELSE "crashed"
    /\ malformedSeen' = TRUE
    /\ UNCHANGED <<task, future, monitor>>

PollValidCompletion ==
    /\ poller = "ready"
    /\ task = "running"
    /\ poller' = "ready"
    /\ task' = "succeeded"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED malformedSeen

Next ==
    \/ PollMalformedJSON
    \/ PollValidCompletion
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ poller \in PollerStates
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ malformedSeen \in BOOLEAN

PollerProgress == malformedSeen => poller = "ready"

CompletionPropagation ==
    task = "succeeded" =>
        /\ future = "succeeded"
        /\ monitor = "succeeded"

NoCrashOnMalformed == poller # "crashed"

=============================================================================
