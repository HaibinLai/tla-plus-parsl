--------------------------- MODULE ParslZMQMultipartDecodeMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Multipart frame validation composed with two result Futures.
 *
 * A malformed serialized frame arrives before an independent valid result in
 * the same result batch.  The Current collector aborts before completing the
 * bad Future or consuming the peer result.  The Fixed collector rejects the
 * bad frame, publishes its failure, and continues to the valid frame.
 ***************************************************************************)

CONSTANT USE_FIXED

CollectorStates == {"running", "crashed"}
FutureStates == {"pending", "failed", "succeeded"}
MonitorStates == {"none", "failed", "succeeded"}

VARIABLES collector, badSeen, peerAvailable, badFuture, peerFuture,
          badMonitor, peerMonitor
vars == <<collector, badSeen, peerAvailable, badFuture, peerFuture,
          badMonitor, peerMonitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ collector = "running"
    /\ badSeen = FALSE
    /\ peerAvailable = FALSE
    /\ badFuture = "pending"
    /\ peerFuture = "pending"
    /\ badMonitor = "none"
    /\ peerMonitor = "none"

ReceiveMalformed ==
    /\ collector = "running"
    /\ badSeen' = TRUE
    /\ peerAvailable' = TRUE
    /\ IF USE_FIXED
          THEN /\ collector' = "running"
               /\ badFuture' = "failed"
               /\ badMonitor' = "failed"
          ELSE /\ collector' = "crashed"
               /\ UNCHANGED <<badFuture, badMonitor>>
    /\ UNCHANGED <<peerFuture, peerMonitor>>

ReceiveValidPeer ==
    /\ collector = "running"
    /\ peerAvailable
    /\ peerFuture' = "succeeded"
    /\ peerMonitor' = "succeeded"
    /\ UNCHANGED <<collector, badSeen, peerAvailable, badFuture, badMonitor>>

Next ==
    \/ ReceiveMalformed
    \/ ReceiveValidPeer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ collector \in CollectorStates
    /\ badSeen \in BOOLEAN
    /\ peerAvailable \in BOOLEAN
    /\ badFuture \in FutureStates
    /\ peerFuture \in FutureStates
    /\ badMonitor \in MonitorStates
    /\ peerMonitor \in MonitorStates

MalformedFrameIsolation ==
    badSeen =>
        /\ collector = "running"
        /\ badFuture = "failed"
        /\ badMonitor = "failed"

PeerProgress == peerFuture = "succeeded" => peerMonitor = "succeeded"

MonitoringConsistency ==
    /\ badMonitor = "failed" => badFuture = "failed"
    /\ peerMonitor = "succeeded" => peerFuture = "succeeded"

=============================================================================
