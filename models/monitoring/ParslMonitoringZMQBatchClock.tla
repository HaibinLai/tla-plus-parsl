--------------------------- MODULE ParslMonitoringZMQBatchClock ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring ZMQ router receive-batch deadline.
 *
 * MonitoringRouter.start uses time.time() to keep receiving for a one-second
 * batch.  A wall-clock rollback can make the elapsed value negative and keep
 * the inner receive loop alive beyond its deadline.  CLOCK_MODE abstracts the
 * current wall-clock path and a monotonic fixed path.
 *************************************************************************** *)

CONSTANT CLOCK_MODE

VARIABLES clock, start, received, state
vars == <<clock, start, received, state>>

Init ==
    /\ CLOCK_MODE \in {"rollback", "monotonic"}
    /\ start = 100
    /\ clock = start
    /\ received = 0
    /\ state = "receiving"

ReceiveMessage ==
    /\ state = "receiving"
    /\ clock - start < 1
    /\ received' = received + 1
    /\ clock' = IF CLOCK_MODE = "rollback" THEN clock - 1 ELSE start + 1
    /\ UNCHANGED <<start, state>>

EndBatch ==
    /\ state = "receiving"
    /\ clock - start >= 1
    /\ state' = "finished"
    /\ UNCHANGED <<start, clock, received>>

Next ==
    \/ ReceiveMessage
    \/ EndBatch
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ CLOCK_MODE \in {"rollback", "monotonic"}
    /\ clock \in 0..200
    /\ start \in 0..200
    /\ received \in 0..2
    /\ state \in {"receiving", "finished"}

MonotonicDeadlineSafety ==
    state = "receiving" => received <= 1

=============================================================================
