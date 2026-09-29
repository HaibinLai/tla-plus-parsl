--------------------------- MODULE ParslMonitoringBatchClock ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring batch deadline and clock source.
 *
 * DatabaseManager._get_messages_in_batch currently measures its batching
 * interval with time.time().  A wall-clock rollback can make elapsed time
 * negative and admit another message after the intended deadline.  CLOCK_MODE
 * abstracts the current wall-clock path and a monotonic fixed path.
 *************************************************************************** *)

CONSTANT CLOCK_MODE

VARIABLES clock, start, pending, drained, state
vars == <<clock, start, pending, drained, state>>

Init ==
    /\ CLOCK_MODE \in {"rollback", "monotonic"}
    /\ start = 100
    /\ clock = start
    /\ pending = 2
    /\ drained = 0
    /\ state = "collecting"

ReadMessage ==
    /\ state = "collecting"
    /\ pending > 0
    /\ clock - start < 1
    /\ pending' = pending - 1
    /\ drained' = drained + 1
    /\ clock' = IF CLOCK_MODE = "rollback" THEN clock - 1 ELSE start + 1
    /\ UNCHANGED <<start, state>>

StopAtDeadline ==
    /\ state = "collecting"
    /\ clock - start >= 1
    /\ state' = "stopped"
    /\ UNCHANGED <<start, clock, pending, drained>>

StopWhenEmpty ==
    /\ state = "collecting"
    /\ pending = 0
    /\ state' = "stopped"
    /\ UNCHANGED <<start, clock, pending, drained>>

Next ==
    \/ ReadMessage
    \/ StopAtDeadline
    \/ StopWhenEmpty
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ CLOCK_MODE \in {"rollback", "monotonic"}
    /\ clock \in 0..200
    /\ start \in 0..200
    /\ pending \in 0..2
    /\ drained \in 0..2
    /\ state \in {"collecting", "stopped"}

NoOverdueBatch ==
    state = "collecting" => drained <= 1

=============================================================================
