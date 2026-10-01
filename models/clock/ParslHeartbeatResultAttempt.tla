--------------------------- MODULE ParslHeartbeatResultAttempt ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Heartbeat expiry, retry generation, and result acceptance.
 *
 * A manager that misses its heartbeat threshold loses attempt 0 and makes
 * attempt 1 current.  A late heartbeat from the expired manager must not
 * revive it, and a result from attempt 0 must not resolve the retry Future.
 ***************************************************************************)

CONSTANT USE_FIXED

Managers == {"up", "expired"}
Results == {"none", "old", "current", "stale", "old_resolved", "current_resolved"}

VARIABLES clock, lastHeartbeat, manager, attempt, retryReady, result,
          future, heartbeatAccepted

vars == <<clock, lastHeartbeat, manager, attempt, retryReady, result,
           future, heartbeatAccepted>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ clock = 0
    /\ lastHeartbeat = 0
    /\ manager = "up"
    /\ attempt = 0
    /\ retryReady = FALSE
    /\ result = "none"
    /\ future = "unresolved"
    /\ heartbeatAccepted = FALSE

Tick ==
    /\ clock < 4
    /\ clock' = clock + 1
    /\ UNCHANGED <<lastHeartbeat, manager, attempt, retryReady, result,
                    future, heartbeatAccepted>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = clock
    /\ heartbeatAccepted' = TRUE
    /\ UNCHANGED <<clock, manager, attempt, retryReady, result, future>>

ExpireManager ==
    /\ manager = "up"
    /\ clock - lastHeartbeat >= 2
    /\ manager' = "expired"
    /\ attempt' = 1
    /\ retryReady' = TRUE
    /\ heartbeatAccepted' = FALSE
    /\ UNCHANGED <<clock, lastHeartbeat, result, future>>

LateHeartbeatFixed ==
    /\ manager = "expired"
    /\ USE_FIXED
    /\ manager' = "expired"
    /\ heartbeatAccepted' = FALSE
    /\ UNCHANGED <<clock, lastHeartbeat, attempt, retryReady, result, future>>

LateHeartbeatCurrent ==
    /\ manager = "expired"
    /\ ~USE_FIXED
    /\ manager' = "up"
    /\ lastHeartbeat' = clock
    /\ heartbeatAccepted' = TRUE
    /\ UNCHANGED <<clock, attempt, retryReady, result, future>>

PublishOldResult ==
    /\ manager = "expired"
    /\ result = "none"
    /\ result' = "old"
    /\ UNCHANGED <<clock, lastHeartbeat, manager, attempt, retryReady,
                    future, heartbeatAccepted>>

PublishCurrentResult ==
    /\ retryReady
    /\ result = "none"
    /\ result' = "current"
    /\ UNCHANGED <<clock, lastHeartbeat, manager, attempt, retryReady,
                    future, heartbeatAccepted>>

ResolveOldResultFixed ==
    /\ result = "old"
    /\ USE_FIXED
    /\ result' = "stale"
    /\ future' = "unresolved"
    /\ UNCHANGED <<clock, lastHeartbeat, manager, attempt, retryReady,
                    heartbeatAccepted>>

ResolveOldResultCurrent ==
    /\ result = "old"
    /\ ~USE_FIXED
    /\ result' = "old_resolved"
    /\ future' = "resolved"
    /\ UNCHANGED <<clock, lastHeartbeat, manager, attempt, retryReady,
                    heartbeatAccepted>>

ResolveCurrentResult ==
    /\ result = "current"
    /\ result' = "current_resolved"
    /\ future' = "resolved"
    /\ UNCHANGED <<clock, lastHeartbeat, manager, attempt, retryReady,
                    heartbeatAccepted>>

Next ==
    \/ Tick
    \/ Heartbeat
    \/ ExpireManager
    \/ LateHeartbeatFixed
    \/ LateHeartbeatCurrent
    \/ PublishOldResult
    \/ PublishCurrentResult
    \/ ResolveOldResultFixed
    \/ ResolveOldResultCurrent
    \/ ResolveCurrentResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ clock \in 0..4
    /\ lastHeartbeat \in 0..4
    /\ manager \in Managers
    /\ attempt \in 0..1
    /\ retryReady \in BOOLEAN
    /\ result \in Results
    /\ future \in {"unresolved", "resolved"}
    /\ heartbeatAccepted \in BOOLEAN

ExpiredHeartbeatSafety == manager = "expired" => ~heartbeatAccepted
CurrentResultSafety == future = "resolved" => result = "current_resolved" /\ attempt = 1
OldResultSafety == result = "stale" => attempt = 1
TerminalManagerSafety == retryReady => manager = "expired"

=============================================================================
