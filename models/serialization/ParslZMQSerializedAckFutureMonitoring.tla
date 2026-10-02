--------------------------- MODULE ParslZMQSerializedAckFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Serialized ZMQ retransmission composed with Future and monitoring.
 *
 * A lost ACK can deliver the same task/attempt envelope twice.  The source
 * snapshot is immutable after encoding, and the fixed collector deduplicates
 * the envelope before dispatch.  The Current branch executes the duplicate,
 * producing an inconsistent dispatch/monitoring history even though the
 * logical Future eventually resolves.
 ***************************************************************************)

CONSTANT USE_FIXED

WireStates == {"none", "encoded", "delivered", "decoded"}
TaskStates == {"pending", "running", "succeeded"}
MonitorStates == {"none", "running", "succeeded", "duplicate"}

VARIABLES sourceVersion, capturedVersion, wire, delivered, seen,
          dispatchCount, task, future, monitor
vars == <<sourceVersion, capturedVersion, wire, delivered, seen,
          dispatchCount, task, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion = 0
    /\ capturedVersion = 0
    /\ wire = "none"
    /\ delivered = 0
    /\ seen = FALSE
    /\ dispatchCount = 0
    /\ task = "pending"
    /\ future = "unresolved"
    /\ monitor = "none"

MutateSource ==
    /\ sourceVersion = 0
    /\ sourceVersion' = 1
    /\ UNCHANGED <<capturedVersion, wire, delivered, seen, dispatchCount,
                    task, future, monitor>>

Encode ==
    /\ wire = "none"
    /\ sourceVersion = 0
    /\ capturedVersion = sourceVersion
    /\ capturedVersion' = capturedVersion
    /\ wire' = "encoded"
    /\ UNCHANGED <<sourceVersion, delivered, seen, dispatchCount,
                    task, future, monitor>>

Deliver ==
    /\ wire = "encoded"
    /\ delivered < 2
    /\ wire' = "delivered"
    /\ delivered' = delivered + 1
    /\ UNCHANGED <<sourceVersion, capturedVersion, seen, dispatchCount,
                    task, future, monitor>>

LoseAck ==
    /\ wire = "delivered"
    /\ delivered = 1
    /\ wire' = "none"
    /\ UNCHANGED <<sourceVersion, capturedVersion, delivered, seen,
                    dispatchCount, task, future, monitor>>

Decode ==
    /\ wire = "delivered"
    /\ wire' = "decoded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, delivered, seen,
                    dispatchCount, task, future, monitor>>

Dispatch ==
    /\ wire = "decoded"
    /\ wire' = "none"
    /\ dispatchCount' = IF seen /\ USE_FIXED THEN dispatchCount
                        ELSE dispatchCount + 1
    /\ seen' = TRUE
    /\ task' = IF seen /\ USE_FIXED THEN task ELSE "running"
    /\ monitor' = IF seen THEN IF USE_FIXED THEN monitor ELSE "duplicate"
                  ELSE "running"
    /\ UNCHANGED <<sourceVersion, capturedVersion, delivered, future>>

Complete ==
    /\ task = "running"
    /\ dispatchCount > 0
    /\ task' = "succeeded"
    /\ future' = "resolved"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<sourceVersion, capturedVersion, wire, delivered, seen,
                    dispatchCount>>

Next ==
    \/ MutateSource
    \/ Encode
    \/ Deliver
    \/ LoseAck
    \/ Decode
    \/ Dispatch
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ sourceVersion \in 0..1
    /\ capturedVersion \in 0..1
    /\ wire \in WireStates
    /\ delivered \in 0..2
    /\ seen \in BOOLEAN
    /\ dispatchCount \in 0..2
    /\ task \in TaskStates
    /\ future \in {"unresolved", "resolved"}
    /\ monitor \in MonitorStates

SnapshotSafety == capturedVersion = 0

SingleDispatch == dispatchCount <= 1

FutureMonitoringConsistency ==
    future = "resolved" =>
        /\ task = "succeeded"
        /\ monitor = "succeeded"

NoDuplicatePublication == monitor # "duplicate"

=============================================================================
