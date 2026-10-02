--------------------------- MODULE ParslSlurmMalformedFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Slurm status parsing composed with a logical task Future and monitoring.
 * A truncated scheduler record must not abort the polling pass: a later valid
 * completion for the same task still needs to reach the Future and database.
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

PollMalformed ==
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
    \/ PollMalformed
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

PollerProgress ==
    malformedSeen => poller = "ready"

CompletionPropagation ==
    task = "succeeded" =>
        /\ future = "succeeded"
        /\ monitor = "succeeded"

NoCrashOnMalformed ==
    poller # "crashed"

=============================================================================
