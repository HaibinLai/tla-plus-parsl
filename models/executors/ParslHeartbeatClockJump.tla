--------------------------- MODULE ParslHeartbeatClockJump ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Wall-clock versus monotonic heartbeat expiry.
 *
 * Interchange.expire_bad_managers stores and compares time.time() values.
 * A forward system-clock adjustment can therefore make a recently healthy
 * manager appear older than heartbeat_threshold. The FIXED branch uses a
 * monotonic elapsed time for expiry while wall time remains diagnostic.
 *************************************************************************** *)

CONSTANTS CLOCK_JUMP, USE_FIXED, HEARTBEAT_THRESHOLD
VARIABLES state, wallAge, monotonicAge, managerActive, expired
vars == <<state, wallAge, monotonicAge, managerActive, expired>>

Init ==
    /\ CLOCK_JUMP \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ HEARTBEAT_THRESHOLD > 1
    /\ state = "healthy"
    /\ wallAge = 0
    /\ monotonicAge = 0
    /\ managerActive = TRUE
    /\ expired = FALSE

AdvanceClock ==
    /\ state = "healthy"
    /\ state' = "checking"
    /\ monotonicAge' = 1
    /\ wallAge' = IF CLOCK_JUMP THEN HEARTBEAT_THRESHOLD + 1 ELSE 1
    /\ UNCHANGED <<managerActive, expired>>

CheckExpiry ==
    /\ state = "checking"
    /\ IF (IF USE_FIXED THEN monotonicAge ELSE wallAge) > HEARTBEAT_THRESHOLD
          THEN /\ state' = "expired"
               /\ managerActive' = FALSE
               /\ expired' = TRUE
          ELSE /\ state' = "retained"
               /\ UNCHANGED <<managerActive, expired>>
    /\ UNCHANGED <<wallAge, monotonicAge>>

Next ==
    \/ AdvanceClock
    \/ CheckExpiry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"healthy", "checking", "expired", "retained"}
    /\ wallAge \in 0..(HEARTBEAT_THRESHOLD + 1)
    /\ monotonicAge \in 0..1
    /\ managerActive \in BOOLEAN
    /\ expired \in BOOLEAN

NoPrematureExpiry ==
    expired => monotonicAge > HEARTBEAT_THRESHOLD

=============================================================================
