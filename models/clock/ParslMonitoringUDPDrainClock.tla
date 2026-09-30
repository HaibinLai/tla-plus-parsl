--------------------------- MODULE ParslMonitoringUDPDrainClock ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * UDP monitoring-router drain deadline.
 *
 * The current drain loop compares time.time() against a wall-clock baseline.
 * A rollback can make elapsed wall time negative even though monotonic time
 * has passed the configured atexit timeout.  The fixed branch uses elapsed
 * monotonic time for the shutdown deadline.
 ***************************************************************************)

CONSTANTS USE_FIXED, TIMEOUT, MAX_STEPS

VARIABLES state, wall, monotonic, start, steps
vars == <<state, wall, monotonic, start, steps>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ TIMEOUT >= 1
    /\ MAX_STEPS >= 1
    /\ state = "draining"
    /\ wall = 0
    /\ monotonic = 0
    /\ start = 0
    /\ steps = 0

Advance ==
    /\ state = "draining"
    /\ steps < MAX_STEPS
    /\ wall' = wall + 1
    /\ monotonic' = monotonic + 1
    /\ steps' = steps + 1
    /\ state' = IF USE_FIXED /\ monotonic + 1 - start >= TIMEOUT
                THEN "finished" ELSE state
    /\ UNCHANGED start

Rollback ==
    /\ state = "draining"
    /\ steps < MAX_STEPS
    /\ wall' = wall - 2
    /\ monotonic' = monotonic + 1
    /\ steps' = steps + 1
    /\ state' = IF USE_FIXED /\ monotonic + 1 - start >= TIMEOUT
                THEN "finished" ELSE state
    /\ UNCHANGED start

CheckDeadline ==
    /\ state = "draining"
    /\ IF USE_FIXED
          THEN monotonic - start >= TIMEOUT
          ELSE wall - start >= TIMEOUT
    /\ state' = "finished"
    /\ UNCHANGED <<wall, monotonic, start, steps>>

Next ==
    \/ Advance
    \/ Rollback
    \/ CheckDeadline
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ TIMEOUT >= 1
    /\ MAX_STEPS >= 1
    /\ state \in {"draining", "finished"}
    /\ wall \in Int
    /\ monotonic \in Nat
    /\ start \in Int
    /\ steps \in 0..MAX_STEPS

MonotonicDeadlineSafety ==
    monotonic - start >= TIMEOUT => state = "finished"

=============================================================================
