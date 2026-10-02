--------------------------- MODULE ParslHtexLivenessAttempt ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small HTEX communicator lifecycle composition.
 *
 * Result traffic can keep the worker loop busy while contact ages, and a
 * wall-clock rollback can hide both heartbeat expiry and drain deadlines.
 * Once a manager expires, its old physical attempt may report late, but that
 * result must not resolve the retried logical task.
 ***************************************************************************)

CONSTANTS CONTACT_THRESHOLD, MAX_TIME, DRAIN_AT, USE_FIXED

ManagerStates == {"active", "expired"}
ResultStates == {"none", "old", "current", "stale", "old_resolved", "current_resolved"}
FutureStates == {"unresolved", "resolved"}

VARIABLES wallNow, monoNow, lastWallContact, lastMonoContact,
          manager, attempt, result, future, drainSent
vars == <<wallNow, monoNow, lastWallContact, lastMonoContact,
           manager, attempt, result, future, drainSent>>

Init ==
    /\ CONTACT_THRESHOLD > 0
    /\ MAX_TIME >= CONTACT_THRESHOLD
    /\ DRAIN_AT > 0
    /\ USE_FIXED \in BOOLEAN
    /\ wallNow = 100
    /\ monoNow = 0
    /\ lastWallContact = 100
    /\ lastMonoContact = 0
    /\ manager = "active"
    /\ attempt = 0
    /\ result = "none"
    /\ future = "unresolved"
    /\ drainSent = FALSE

AdvanceClock ==
    /\ manager = "active"
    /\ monoNow < MAX_TIME
    /\ monoNow' = monoNow + 1
    /\ wallNow' = wallNow + 1
    /\ manager' = IF USE_FIXED
                     THEN IF monoNow + 1 - lastMonoContact >= CONTACT_THRESHOLD
                          THEN "expired" ELSE "active"
                     ELSE IF wallNow + 1 - lastWallContact >= CONTACT_THRESHOLD
                          THEN "expired" ELSE "active"
    /\ drainSent' = IF USE_FIXED /\ monoNow + 1 >= DRAIN_AT THEN TRUE ELSE drainSent
    /\ UNCHANGED <<lastWallContact, lastMonoContact, attempt, result,
                    future>>

ResultTraffic ==
    /\ manager = "active"
    /\ monoNow < MAX_TIME
    /\ monoNow' = monoNow + 1
    /\ wallNow' = wallNow + 1
    /\ manager' = IF USE_FIXED
                     THEN IF monoNow + 1 - lastMonoContact >= CONTACT_THRESHOLD
                          THEN "expired" ELSE "active"
                     ELSE "active"
    /\ drainSent' = IF USE_FIXED /\ monoNow + 1 >= DRAIN_AT THEN TRUE ELSE drainSent
    /\ UNCHANGED <<lastWallContact, lastMonoContact, attempt, result,
                    future>>

ClockRollback ==
    /\ manager = "active"
    /\ wallNow >= 2
    /\ monoNow < MAX_TIME
    /\ wallNow' = wallNow - 2
    /\ monoNow' = monoNow + 1
    /\ manager' = IF USE_FIXED /\ monoNow + 1 - lastMonoContact >= CONTACT_THRESHOLD
                     THEN "expired" ELSE "active"
    /\ drainSent' = IF USE_FIXED /\ monoNow + 1 >= DRAIN_AT THEN TRUE ELSE drainSent
    /\ UNCHANGED <<lastWallContact, lastMonoContact, attempt, result,
                    future>>

Heartbeat ==
    /\ manager = "active"
    /\ lastWallContact' = wallNow
    /\ lastMonoContact' = monoNow
    /\ UNCHANGED <<wallNow, monoNow, manager, attempt, result, future, drainSent>>

RetryAfterExpiry ==
    /\ manager = "expired"
    /\ attempt = 0
    /\ attempt' = 1
    /\ result' = "none"
    /\ future' = "unresolved"
    /\ UNCHANGED <<wallNow, monoNow, lastWallContact, lastMonoContact,
                    manager, drainSent>>

PublishOldResult ==
    /\ manager = "expired"
    /\ attempt = 1
    /\ result = "none"
    /\ result' = "old"
    /\ UNCHANGED <<wallNow, monoNow, lastWallContact, lastMonoContact,
                    manager, attempt, future, drainSent>>

ResolveOldResult ==
    /\ result = "old"
    /\ result' = IF USE_FIXED THEN "stale" ELSE "old_resolved"
    /\ future' = IF USE_FIXED THEN "unresolved" ELSE "resolved"
    /\ UNCHANGED <<wallNow, monoNow, lastWallContact, lastMonoContact,
                    manager, attempt, drainSent>>

PublishCurrentResult ==
    /\ attempt = 1
    /\ result = "none"
    /\ result' = "current"
    /\ UNCHANGED <<wallNow, monoNow, lastWallContact, lastMonoContact,
                    manager, attempt, future, drainSent>>

ResolveCurrentResult ==
    /\ result = "current"
    /\ result' = "current_resolved"
    /\ future' = "resolved"
    /\ UNCHANGED <<wallNow, monoNow, lastWallContact, lastMonoContact,
                    manager, attempt, drainSent>>

SendDrain ==
    /\ ~drainSent
    /\ monoNow >= DRAIN_AT
    /\ drainSent' = IF USE_FIXED THEN TRUE ELSE wallNow >= 100 + DRAIN_AT
    /\ UNCHANGED <<wallNow, monoNow, lastWallContact, lastMonoContact,
                    manager, attempt, result, future>>

Next ==
    \/ AdvanceClock
    \/ ResultTraffic
    \/ ClockRollback
    \/ Heartbeat
    \/ RetryAfterExpiry
    \/ PublishOldResult
    \/ ResolveOldResult
    \/ PublishCurrentResult
    \/ ResolveCurrentResult
    \/ SendDrain
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wallNow \in Nat
    /\ monoNow \in 0..MAX_TIME
    /\ lastWallContact \in Nat
    /\ lastMonoContact \in 0..MAX_TIME
    /\ manager \in ManagerStates
    /\ attempt \in 0..1
    /\ result \in ResultStates
    /\ future \in FutureStates
    /\ drainSent \in BOOLEAN

HeartbeatExpirySafety ==
    manager = "active" =>
        IF USE_FIXED
        THEN monoNow - lastMonoContact < CONTACT_THRESHOLD
        ELSE wallNow - lastWallContact < CONTACT_THRESHOLD

OldResultSafety == future = "resolved" => result = "current_resolved"

DrainDeadlineSafety == monoNow >= DRAIN_AT => drainSent

=================================================================================
