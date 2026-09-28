--------------------------- MODULE ParslHeartbeatClockRollback ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Backward system-clock adjustment during heartbeat expiry.
 *
 * The current HTEX interchange compares time.time() values.  If the system
 * clock moves backward, wall-clock age can remain below the threshold even
 * though enough monotonic time has elapsed.  The fixed branch uses elapsed
 * monotonic time for the expiry decision.
 **************************************************************************)

CONSTANTS HEARTBEAT_THRESHOLD, MAX_TICKS, CLOCK_ROLLBACK, USE_FIXED

ManagerStates == {"ready", "expired"}

VARIABLES ticks, wallClock, monotonicAge, lastWallHeartbeat, managerState
vars == <<ticks, wallClock, monotonicAge, lastWallHeartbeat, managerState>>

Init ==
    /\ HEARTBEAT_THRESHOLD > 0
    /\ MAX_TICKS > HEARTBEAT_THRESHOLD
    /\ CLOCK_ROLLBACK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ ticks = 0
    /\ wallClock = 0
    /\ monotonicAge = 0
    /\ lastWallHeartbeat = 0
    /\ managerState = "ready"

Tick ==
    /\ managerState = "ready"
    /\ ticks < MAX_TICKS
    /\ IF USE_FIXED THEN monotonicAge < HEARTBEAT_THRESHOLD ELSE TRUE
    /\ ticks' = ticks + 1
    /\ monotonicAge' = monotonicAge + 1
    /\ wallClock' = IF CLOCK_ROLLBACK /\ ticks = 1
                    THEN -2 ELSE wallClock + 1
    /\ UNCHANGED <<lastWallHeartbeat, managerState>>

ExpireManager ==
    /\ managerState = "ready"
    /\ IF USE_FIXED
          THEN monotonicAge >= HEARTBEAT_THRESHOLD
          ELSE wallClock - lastWallHeartbeat >= HEARTBEAT_THRESHOLD
    /\ managerState' = "expired"
    /\ UNCHANGED <<ticks, wallClock, monotonicAge, lastWallHeartbeat>>

Next ==
    \/ Tick
    \/ ExpireManager
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ ticks \in 0..MAX_TICKS
    /\ wallClock \in -2..(MAX_TICKS + 1)
    /\ monotonicAge \in 0..MAX_TICKS
    /\ lastWallHeartbeat \in -2..(MAX_TICKS + 1)
    /\ managerState \in ManagerStates

NoFalseExpiry ==
    managerState = "expired" =>
        IF USE_FIXED
           THEN monotonicAge >= HEARTBEAT_THRESHOLD
           ELSE wallClock - lastWallHeartbeat >= HEARTBEAT_THRESHOLD

HorizonRequiresExpiry ==
    ticks = MAX_TICKS => managerState = "expired"

=============================================================================
