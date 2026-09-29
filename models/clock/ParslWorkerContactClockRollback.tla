--------------------------- MODULE ParslWorkerContactClockRollback ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Worker-side interchange contact expiry under a backward wall-clock step.
 *
 * process_worker_pool.Manager.interchange_communicator stores the last
 * contact with time.time() and compares another time.time() reading against
 * heartbeat_threshold.  `monotonicAge` is the elapsed-time reference for a
 * candidate fix; `wallClock` is the current implementation.
 ***************************************************************************)

CONSTANTS HEARTBEAT_THRESHOLD, MAX_TICKS, CLOCK_ROLLBACK, USE_FIXED

WorkerStates == {"running", "stopped"}

VARIABLES ticks, wallClock, monotonicAge, lastContact, workerState
vars == <<ticks, wallClock, monotonicAge, lastContact, workerState>>

Init ==
    /\ HEARTBEAT_THRESHOLD > 0
    /\ MAX_TICKS > HEARTBEAT_THRESHOLD
    /\ CLOCK_ROLLBACK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ ticks = 0
    /\ wallClock = 100
    /\ monotonicAge = 0
    /\ lastContact = 100
    /\ workerState = "running"

Tick ==
    /\ workerState = "running"
    /\ ticks < MAX_TICKS
    /\ IF USE_FIXED THEN monotonicAge < HEARTBEAT_THRESHOLD ELSE TRUE
    /\ ticks' = ticks + 1
    /\ monotonicAge' = monotonicAge + 1
    /\ wallClock' = IF CLOCK_ROLLBACK /\ ticks = 0
                    THEN wallClock - 10
                    ELSE wallClock + 1
    /\ UNCHANGED <<lastContact, workerState>>

ExpireWorker ==
    /\ workerState = "running"
    /\ IF USE_FIXED
          THEN monotonicAge >= HEARTBEAT_THRESHOLD
          ELSE wallClock - lastContact >= HEARTBEAT_THRESHOLD
    /\ workerState' = "stopped"
    /\ UNCHANGED <<ticks, wallClock, monotonicAge, lastContact>>

Next ==
    \/ Tick
    \/ ExpireWorker
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ ticks \in 0..MAX_TICKS
    /\ wallClock \in 80..(100 + MAX_TICKS)
    /\ monotonicAge \in 0..MAX_TICKS
    /\ lastContact \in 80..(100 + MAX_TICKS)
    /\ workerState \in WorkerStates

ExpirySafety ==
    workerState = "stopped" =>
        IF USE_FIXED
           THEN monotonicAge >= HEARTBEAT_THRESHOLD
           ELSE wallClock - lastContact >= HEARTBEAT_THRESHOLD

HorizonRequiresStop ==
    ticks = MAX_TICKS => workerState = "stopped"

=============================================================================
