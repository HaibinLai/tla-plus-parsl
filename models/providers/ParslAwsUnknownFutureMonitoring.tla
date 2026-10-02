--------------------------- MODULE ParslAwsUnknownFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWS stale-instance status composed with Future and monitoring progress.
 * An EC2 instance absent from local resources must be isolated as UNKNOWN so
 * a healthy peer/status observation can still complete its logical task.
 ***************************************************************************)

CONSTANT USE_FIXED

PollerStates == {"reported", "ready", "crashed"}
TaskStates == {"running", "succeeded"}
FutureStates == {"pending", "succeeded"}
MonitorStates == {"none", "succeeded"}

VARIABLES poller, task, future, monitor, unknownSeen
vars == <<poller, task, future, monitor, unknownSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ poller = "reported"
    /\ task = "running"
    /\ future = "pending"
    /\ monitor = "none"
    /\ unknownSeen = FALSE

HandleUnknownInstance ==
    /\ poller = "reported"
    /\ poller' = IF USE_FIXED THEN "ready" ELSE "crashed"
    /\ unknownSeen' = TRUE
    /\ UNCHANGED <<task, future, monitor>>

ObserveHealthyPeer ==
    /\ poller = "ready"
    /\ task = "running"
    /\ poller' = "ready"
    /\ task' = "succeeded"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED unknownSeen

Next ==
    \/ HandleUnknownInstance
    \/ ObserveHealthyPeer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ poller \in PollerStates
    /\ task \in TaskStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ unknownSeen \in BOOLEAN

UnknownIsolation == unknownSeen => poller = "ready"

CompletionPropagation ==
    task = "succeeded" =>
        /\ future = "succeeded"
        /\ monitor = "succeeded"

NoCrashOnUnknown == poller # "crashed"

=============================================================================
