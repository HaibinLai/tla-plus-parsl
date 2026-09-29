--------------------------- MODULE ParslResourceMonitorClock ---------------------------
EXTENDS Integers, Naturals

(***************************************************************************
 * Remote resource-monitor scheduling.
 *
 * parsl.monitoring.remote.monitor schedules samples with time.time().  A
 * backward wall-clock step can make an already-due sample appear overdue in
 * the future.  The fixed branch uses an elapsed monotonic clock for the
 * scheduling decision while retaining wall time only for timestamps.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"scheduled", "rollback", "sent", "suppressed"}

VARIABLES phase, wallNow, monotonicNow, nextSend, sent
vars == <<phase, wallNow, monotonicNow, nextSend, sent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "scheduled"
    /\ wallNow = 10
    /\ monotonicNow = 0
    /\ nextSend = 20
    /\ sent = 0

ClockRollback ==
    /\ phase = "scheduled"
    /\ phase' = "rollback"
    /\ wallNow' = 0
    /\ monotonicNow' = 10
    /\ UNCHANGED <<nextSend, sent>>

ObserveCurrent ==
    /\ ~USE_FIXED
    /\ phase = "rollback"
    /\ wallNow < nextSend
    /\ phase' = "suppressed"
    /\ UNCHANGED <<wallNow, monotonicNow, nextSend, sent>>

ObserveFixed ==
    /\ USE_FIXED
    /\ phase = "rollback"
    /\ monotonicNow >= nextSend - 10
    /\ phase' = "sent"
    /\ sent' = sent + 1
    /\ UNCHANGED <<wallNow, monotonicNow, nextSend>>

Next ==
    \/ ClockRollback
    \/ ObserveCurrent
    \/ ObserveFixed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in Phases
    /\ wallNow \in Int
    /\ monotonicNow \in Nat
    /\ nextSend \in Int
    /\ sent \in Nat

NoDueSuppression == phase # "suppressed"

=============================================================================
