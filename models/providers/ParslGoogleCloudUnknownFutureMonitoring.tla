--------------------------- MODULE ParslGoogleCloudUnknownFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GCE status translation composed with Future and monitoring progress.
 * Unknown provider states should become an isolated UNKNOWN observation, not
 * abort the poller before a healthy instance can complete its task.
 ***************************************************************************)

CONSTANT USE_FIXED

PollerStates == {"idle", "ready", "crashed"}
TaskStates == {"running", "succeeded"}
FutureStates == {"pending", "succeeded"}
MonitorStates == {"none", "succeeded"}

VARIABLES poller, task, future, monitor, unknownSeen
vars == <<poller, task, future, monitor, unknownSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ poller = "idle"
    /\ task = "running"
    /\ future = "pending"
    /\ monitor = "none"
    /\ unknownSeen = FALSE

ObserveUnknown ==
    /\ poller = "idle"
    /\ poller' = IF USE_FIXED THEN "ready" ELSE "crashed"
    /\ unknownSeen' = TRUE
    /\ UNCHANGED <<task, future, monitor>>

ObserveHealthyCompletion ==
    /\ poller = "ready"
    /\ task = "running"
    /\ poller' = "ready"
    /\ task' = "succeeded"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED unknownSeen

Next ==
    \/ ObserveUnknown
    \/ ObserveHealthyCompletion
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
