--------------------------- MODULE ParslTaskVineCancelledMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVine stale cancelled-result isolation across peer Future and monitoring.
 *
 * The collector receives a report for a cancelled task before an unrelated
 * live task.  USE_FIXED discards the stale report; the Current branch lets
 * InvalidStateError terminate collection and globally fail the peer.
 ***************************************************************************)

CONSTANT USE_FIXED

CollectorStates == {"running", "failed", "done"}
PeerStates == {"pending", "done", "failed"}
MonitorStates == {"none", "failure", "success"}

VARIABLES reportIndex, collector, peer, monitor
vars == <<reportIndex, collector, peer, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ reportIndex = 0
    /\ collector = "running"
    /\ peer = "pending"
    /\ monitor = "none"

ConsumeCancelledReport ==
    /\ reportIndex = 0
    /\ collector = "running"
    /\ reportIndex' = 1
    /\ IF USE_FIXED
          THEN /\ collector' = "running"
               /\ monitor' = "none"
          ELSE /\ collector' = "failed"
               /\ monitor' = "failure"
    /\ UNCHANGED peer

ConsumePeerReport ==
    /\ reportIndex = 1
    /\ collector = "running"
    /\ reportIndex' = 2
    /\ collector' = "done"
    /\ peer' = "done"
    /\ monitor' = "success"

GlobalFailureCleanup ==
    /\ collector = "failed"
    /\ peer' = "failed"
    /\ UNCHANGED <<reportIndex, collector, monitor>>

Next ==
    \/ ConsumeCancelledReport
    \/ ConsumePeerReport
    \/ GlobalFailureCleanup
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ reportIndex \in 0..2
    /\ collector \in CollectorStates
    /\ peer \in PeerStates
    /\ monitor \in MonitorStates

PeerProgressSafety ==
    reportIndex = 1 => peer = "done" \/ USE_FIXED

MonitoringTerminalSafety ==
    peer = "done" => monitor = "success"

NoPeerFailureFromStale ==
    reportIndex = 1 => peer # "failed"

=============================================================================
