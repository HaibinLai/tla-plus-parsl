--------------------------- MODULE ParslMonitoringHubRepeatedStart ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Repeated MonitoringHub.start calls.
 *
 * A started hub owns one DB process and one resource queue. The current
 * implementation starts a second pair when start is called again and
 * overwrites the first handles. The fixed path rejects/reuses an active hub
 * without allocating another process.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES active, processCount, queueCount, orphaned, closeCount
vars == <<active, processCount, queueCount, orphaned, closeCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ active = FALSE
    /\ processCount = 0
    /\ queueCount = 0
    /\ orphaned = 0
    /\ closeCount = 0

Start ==
    /\ processCount < 2
    /\ IF USE_FIXED /\ active
          THEN /\ UNCHANGED vars
          ELSE /\ active' = TRUE
               /\ processCount' = processCount + 1
               /\ queueCount' = queueCount + 1
               /\ orphaned' = orphaned + IF active THEN 1 ELSE 0
               /\ UNCHANGED closeCount

Close ==
    /\ active
    /\ active' = FALSE
    /\ closeCount' = closeCount + 1
    /\ UNCHANGED <<processCount, queueCount, orphaned>>

Next == Start \/ Close \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ active \in BOOLEAN
    /\ processCount \in 0..2
    /\ queueCount \in 0..2
    /\ orphaned \in 0..1
    /\ closeCount \in 0..2

SingleOwnerSafety ==
    /\ processCount - closeCount <= 1
    /\ queueCount - closeCount <= 1
    /\ orphaned = 0

=============================================================================
