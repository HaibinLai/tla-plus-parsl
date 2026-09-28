--------------------------- MODULE ParslHeartbeatLateAck ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A stale HTEX heartbeat acknowledgement race.
 *
 * A manager can have a heartbeat in flight when the interchange expires it.
 * The acknowledgement may arrive after the manager record has been removed.
 * The current branch models an unsafe path which accepts that old heartbeat
 * and resurrects the manager; the fixed branch ignores it as stale.
 ***************************************************************************)

CONSTANTS HEARTBEAT_THRESHOLD, MAX_TIME, USE_FIXED

ManagerStates == {"ready", "expired"}
HeartbeatStates == {"none", "inflight", "accepted", "stale"}

VARIABLES now, managerState, lastHeartbeat, heartbeatState, expiredOnce
vars == <<now, managerState, lastHeartbeat, heartbeatState, expiredOnce>>

Init ==
    /\ HEARTBEAT_THRESHOLD > 0
    /\ MAX_TIME > HEARTBEAT_THRESHOLD
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ managerState = "ready"
    /\ lastHeartbeat = 0
    /\ heartbeatState = "none"
    /\ expiredOnce = FALSE

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<managerState, lastHeartbeat, heartbeatState, expiredOnce>>

SendHeartbeat ==
    /\ managerState = "ready"
    /\ heartbeatState = "none"
    /\ heartbeatState' = "inflight"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, expiredOnce>>

ExpireManager ==
    /\ managerState = "ready"
    /\ now - lastHeartbeat > HEARTBEAT_THRESHOLD
    /\ managerState' = "expired"
    /\ expiredOnce' = TRUE
    /\ UNCHANGED <<now, lastHeartbeat, heartbeatState>>

DeliverFreshHeartbeat ==
    /\ heartbeatState = "inflight"
    /\ managerState = "ready"
    /\ heartbeatState' = "accepted"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, managerState, expiredOnce>>

DeliverLateHeartbeatFixed ==
    /\ heartbeatState = "inflight"
    /\ managerState = "expired"
    /\ USE_FIXED
    /\ heartbeatState' = "stale"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, expiredOnce>>

DeliverLateHeartbeatCurrent ==
    /\ heartbeatState = "inflight"
    /\ managerState = "expired"
    /\ ~USE_FIXED
    /\ heartbeatState' = "accepted"
    /\ managerState' = "ready"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, expiredOnce>>

ResetHeartbeat ==
    /\ heartbeatState \in {"accepted", "stale"}
    /\ heartbeatState' = "none"
    /\ UNCHANGED <<now, managerState, lastHeartbeat, expiredOnce>>

Next ==
    \/ Tick
    \/ SendHeartbeat
    \/ ExpireManager
    \/ DeliverFreshHeartbeat
    \/ DeliverLateHeartbeatFixed
    \/ DeliverLateHeartbeatCurrent
    \/ ResetHeartbeat
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ managerState \in ManagerStates
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ heartbeatState \in HeartbeatStates
    /\ expiredOnce \in BOOLEAN

ExpiryTerminal ==
    expiredOnce => managerState = "expired"

NoResurrection ==
    expiredOnce => lastHeartbeat < now

StaleAckSafety ==
    heartbeatState = "stale" => managerState = "expired"

=============================================================================
