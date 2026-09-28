--------------------------- MODULE ParslExecutorShutdown ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Concrete executor shutdown contracts.
 *
 * ThreadPoolExecutor waits for accepted work to finish.  WorkQueue's
 * collector marks work left behind by a stopped submit/collector process as
 * failed.  HighThroughputExecutor closes the interchange first; an explicit
 * loss step represents the resulting in-flight task cleanup without claiming
 * that workers themselves were synchronously killed.
 ***************************************************************************)

EXECUTORS == {"threads", "workqueue", "htex"}
MAX_TASKS == 2
States == {"down", "running", "shutting", "stopped"}
Channels == {"open", "stopping", "closed"}

VARIABLES state, channel, accepted, completed, failed, shutdownRequested,
          rejected
vars == <<state, channel, accepted, completed, failed,
          shutdownRequested, rejected>>

Init ==
    /\ state = [e \in EXECUTORS |-> "down"]
    /\ channel = [e \in EXECUTORS |-> "closed"]
    /\ accepted = [e \in EXECUTORS |-> 0]
    /\ completed = [e \in EXECUTORS |-> 0]
    /\ failed = [e \in EXECUTORS |-> 0]
    /\ shutdownRequested = [e \in EXECUTORS |-> FALSE]
    /\ rejected = [e \in EXECUTORS |-> 0]

Start(e) ==
    /\ state[e] = "down"
    /\ state' = [state EXCEPT ![e] = "running"]
    /\ channel' = [channel EXCEPT ![e] = "open"]
    /\ UNCHANGED <<accepted, completed, failed, shutdownRequested, rejected>>

Submit(e) ==
    /\ state[e] = "running"
    /\ accepted[e] < MAX_TASKS
    /\ accepted' = [accepted EXCEPT ![e] = @ + 1]
    /\ UNCHANGED <<state, channel, completed, failed, shutdownRequested, rejected>>

RejectAfterShutdown(e) ==
    /\ shutdownRequested[e]
    /\ rejected[e] < MAX_TASKS
    /\ rejected' = [rejected EXCEPT ![e] = @ + 1]
    /\ UNCHANGED <<state, channel, accepted, completed, failed,
                   shutdownRequested>>

BeginShutdown(e) ==
    /\ state[e] = "running"
    /\ state' = [state EXCEPT ![e] = "shutting"]
    /\ shutdownRequested' = [shutdownRequested EXCEPT ![e] = TRUE]
    /\ channel' = [channel EXCEPT ![e] =
          IF e = "threads" THEN "open"
          ELSE IF e = "workqueue" THEN "stopping" ELSE "closed"]
    /\ UNCHANGED <<accepted, completed, failed, rejected>>

Complete(e) ==
    /\ state[e] = "shutting"
    /\ accepted[e] > 0
    /\ accepted' = [accepted EXCEPT ![e] = @ - 1]
    /\ completed' = [completed EXCEPT ![e] = @ + 1]
    /\ UNCHANGED <<state, channel, failed, shutdownRequested, rejected>>

WorkQueueCollectorFails(e) ==
    /\ e = "workqueue"
    /\ state[e] = "shutting"
    /\ accepted[e] > 0
    /\ accepted' = [accepted EXCEPT ![e] = 0]
    /\ failed' = [failed EXCEPT ![e] = @ + accepted[e]]
    /\ channel' = [channel EXCEPT ![e] = "closed"]
    /\ UNCHANGED <<state, completed, shutdownRequested, rejected>>

HtexInterchangeLoss(e) ==
    /\ e = "htex"
    /\ state[e] = "shutting"
    /\ accepted[e] > 0
    /\ accepted' = [accepted EXCEPT ![e] = 0]
    /\ failed' = [failed EXCEPT ![e] = @ + accepted[e]]
    /\ UNCHANGED <<state, channel, completed, shutdownRequested, rejected>>

FinishShutdown(e) ==
    /\ state[e] = "shutting"
    /\ accepted[e] = 0
    /\ state' = [state EXCEPT ![e] = "stopped"]
    /\ channel' = [channel EXCEPT ![e] = "closed"]
    /\ UNCHANGED <<accepted, completed, failed, shutdownRequested, rejected>>

Next ==
    \/ \E e \in EXECUTORS : Start(e)
    \/ \E e \in EXECUTORS : Submit(e)
    \/ \E e \in EXECUTORS : RejectAfterShutdown(e)
    \/ \E e \in EXECUTORS : BeginShutdown(e)
    \/ \E e \in EXECUTORS : Complete(e)
    \/ \E e \in EXECUTORS : WorkQueueCollectorFails(e)
    \/ \E e \in EXECUTORS : HtexInterchangeLoss(e)
    \/ \E e \in EXECUTORS : FinishShutdown(e)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in [EXECUTORS -> States]
    /\ channel \in [EXECUTORS -> Channels]
    /\ accepted \in [EXECUTORS -> 0..MAX_TASKS]
    /\ completed \in [EXECUTORS -> 0..MAX_TASKS]
    /\ failed \in [EXECUTORS -> 0..MAX_TASKS]
    /\ shutdownRequested \in [EXECUTORS -> BOOLEAN]
    /\ rejected \in [EXECUTORS -> 0..MAX_TASKS]

ShutdownAdmissionSafety ==
    \A e \in EXECUTORS : shutdownRequested[e] => state[e] # "running"

NoFalseCompletion ==
    \A e \in EXECUTORS : completed[e] + failed[e] <= MAX_TASKS

ThreadWaitSafety ==
    state["threads"] = "stopped" => accepted["threads"] = 0
                         /\ failed["threads"] = 0

WorkQueueCleanupSafety ==
    state["workqueue"] = "stopped" => accepted["workqueue"] = 0

HtexCleanupSafety ==
    state["htex"] = "stopped" => accepted["htex"] = 0

ChannelSafety ==
    /\ channel["threads"] = "closed" => state["threads"] \in {"down", "stopped"}
    /\ channel["htex"] = "closed" => state["htex"] \in {"down", "shutting", "stopped"}

=============================================================================
