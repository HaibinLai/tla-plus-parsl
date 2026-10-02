--------------------------- MODULE ParslWorkQueueCancelledMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Work Queue stale-result isolation with peer Future and monitoring.
 *
 * A cancelled Future can still have a result report in the collector queue.
 * The concrete collector currently removes that Future and calls set_result,
 * which raises InvalidStateError and enters global failure cleanup.  This
 * composition tracks the unrelated peer Future and monitoring terminal state.
 * USE_FIXED discards the stale report and continues collecting the peer.
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

ConsumeStaleCancelledReport ==
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
    \/ ConsumeStaleCancelledReport
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
