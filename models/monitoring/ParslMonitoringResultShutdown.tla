--------------------------- MODULE ParslMonitoringResultShutdown ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Monitoring result persistence across retry and database-manager shutdown.
 *
 * A result event is queued before DatabaseManager processes it.  The logical
 * task may already have retried, so an attempt-0 event is stale.  Shutdown may
 * race with that queue.  The unsafe branch can either persist the stale event
 * or stop with queued work still present; the fixed branch rejects old
 * attempts and drains the queue before stopping.
 ***************************************************************************)

CONSTANT USE_FIXED

LoopStates == {"running", "stopped"}
QueueStates == {-1, 0, 1}
DbStates == {"empty", "stale", "succeeded"}

VARIABLES currentAttempt, queueAttempt, loopState, killSet, producerClosed,
          future, db, dbAttempt
vars == <<currentAttempt, queueAttempt, loopState, killSet, producerClosed,
           future, db, dbAttempt>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ currentAttempt = 0
    /\ queueAttempt = -1
    /\ loopState = "running"
    /\ killSet = FALSE
    /\ producerClosed = FALSE
    /\ future = "unresolved"
    /\ db = "empty"
    /\ dbAttempt = -1

Retry ==
    /\ currentAttempt = 0
    /\ loopState = "running"
    /\ future = "unresolved"
    /\ currentAttempt' = 1
    /\ UNCHANGED <<queueAttempt, loopState, killSet, producerClosed,
                    future, db, dbAttempt>>

EnqueueResult(a) ==
    /\ loopState = "running"
    /\ a \in 0..1
    /\ queueAttempt = -1
    /\ queueAttempt' = a
    /\ UNCHANGED <<currentAttempt, loopState, killSet, producerClosed,
                    future, db, dbAttempt>>

ProcessQueued ==
    /\ loopState = "running"
    /\ queueAttempt # -1
    /\ IF queueAttempt # currentAttempt
          THEN IF USE_FIXED
               THEN /\ queueAttempt' = -1
                    /\ UNCHANGED <<future, db, dbAttempt>>
               ELSE /\ queueAttempt' = -1
                    /\ db' = "succeeded"
                    /\ future' = "resolved"
                    /\ dbAttempt' = queueAttempt
          ELSE /\ queueAttempt' = -1
               /\ db' = "succeeded"
               /\ future' = "resolved"
               /\ dbAttempt' = queueAttempt
    /\ UNCHANGED <<currentAttempt, loopState, killSet, producerClosed>>

SignalShutdown ==
    /\ loopState = "running"
    /\ killSet' = TRUE
    /\ producerClosed' = TRUE
    /\ UNCHANGED <<currentAttempt, queueAttempt, loopState, future, db, dbAttempt>>

StopLoop ==
    /\ loopState = "running"
    /\ killSet
    /\ IF USE_FIXED
          THEN queueAttempt = -1 /\ producerClosed
          ELSE TRUE
    /\ loopState' = "stopped"
    /\ UNCHANGED <<currentAttempt, queueAttempt, killSet, producerClosed,
                    future, db, dbAttempt>>

Next ==
    \/ Retry
    \/ \E a \in 0..1 : EnqueueResult(a)
    \/ ProcessQueued
    \/ SignalShutdown
    \/ StopLoop
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in 0..1
    /\ queueAttempt \in QueueStates
    /\ loopState \in LoopStates
    /\ killSet \in BOOLEAN
    /\ producerClosed \in BOOLEAN
    /\ future \in {"unresolved", "resolved"}
    /\ db \in DbStates
    /\ dbAttempt \in QueueStates

FutureDatabaseConsistency ==
    future = "resolved" => db = "succeeded" /\ dbAttempt = currentAttempt

TerminalResultStability == db = "succeeded" => future = "resolved"

ShutdownDrainSafety == loopState = "stopped" => queueAttempt = -1

=================================================================================
