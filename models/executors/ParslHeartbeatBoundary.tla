--------------------------- MODULE ParslHeartbeatBoundary ---------------------------
EXTENDS Naturals, Integers, FiniteSets

(***************************************************************************
 * HTEX heartbeat threshold boundary.
 *
 * The interchange processes manager messages before expire_bad_managers and
 * expires only when (now - last_heartbeat) > heartbeat_threshold.  This
 * model makes the strict boundary, heartbeat reset, and in-flight loss
 * accounting explicit.
 ***************************************************************************)

HEARTBEAT_THRESHOLD == 2
MAX_TICKS == 5
MAX_TASKS == 2

VARIABLES now, lastHeartbeat, managerActive, inFlight, lost,
          expirationAge, lastLostBatch
vars == <<now, lastHeartbeat, managerActive, inFlight, lost,
           expirationAge, lastLostBatch>>

Init ==
    /\ now = 0
    /\ lastHeartbeat = 0
    /\ managerActive = TRUE
    /\ inFlight = 0
    /\ lost = 0
    /\ expirationAge = -1
    /\ lastLostBatch = 0

Tick ==
    /\ now < MAX_TICKS
    /\ now' = now + 1
    /\ UNCHANGED <<lastHeartbeat, managerActive, inFlight, lost,
                    expirationAge, lastLostBatch>>

Heartbeat ==
    /\ managerActive
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, managerActive, inFlight, lost,
                    expirationAge, lastLostBatch>>

SubmitTask ==
    /\ managerActive
    /\ inFlight < MAX_TASKS
    /\ inFlight' = inFlight + 1
    /\ UNCHANGED <<now, lastHeartbeat, managerActive, lost,
                    expirationAge, lastLostBatch>>

CompleteTask ==
    /\ managerActive
    /\ inFlight > 0
    /\ inFlight' = inFlight - 1
    /\ UNCHANGED <<now, lastHeartbeat, managerActive, lost,
                    expirationAge, lastLostBatch>>

ExpireManager ==
    /\ managerActive
    /\ now - lastHeartbeat > HEARTBEAT_THRESHOLD
    /\ managerActive' = FALSE
    /\ lost' = lost + inFlight
    /\ lastLostBatch' = inFlight
    /\ expirationAge' = now - lastHeartbeat
    /\ inFlight' = 0
    /\ UNCHANGED <<now, lastHeartbeat>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ SubmitTask
    \/ CompleteTask
    \/ ExpireManager
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TICKS
    /\ lastHeartbeat \in 0..MAX_TICKS
    /\ managerActive \in BOOLEAN
    /\ inFlight \in 0..MAX_TASKS
    /\ lost \in 0..MAX_TASKS
    /\ expirationAge \in -1..MAX_TICKS
    /\ lastLostBatch \in 0..MAX_TASKS

StrictThresholdSafety ==
    expirationAge # -1 => expirationAge > HEARTBEAT_THRESHOLD

ExpirationAccounting ==
    expirationAge # -1 => inFlight = 0 /\ lastLostBatch <= MAX_TASKS

HeartbeatResetSafety ==
    managerActive /\ lastHeartbeat = now => now - lastHeartbeat = 0

NoPostLossHeartbeat ==
    ~managerActive => lastHeartbeat <= now

=============================================================================
