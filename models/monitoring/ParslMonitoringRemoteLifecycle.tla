--------------------------- MODULE ParslMonitoringRemoteLifecycle ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Resource-monitor lifecycle and two clock domains.
 *
 * parsl.monitoring.remote.monitor emits periodic intermediate resource
 * messages and emits one final message after the process loop exits.  The
 * current scheduler uses wall time for intermediate deadlines; the fixed
 * scheduler uses monotonic elapsed time while retaining the final-send
 * guarantee.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"active", "rollback", "stopping", "done"}

VARIABLES phase, wallNow, monotonicNow, nextWall, nextMono,
          intermediate, finalSent, stopRequested
vars == <<phase, wallNow, monotonicNow, nextWall, nextMono,
          intermediate, finalSent, stopRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "active"
    /\ wallNow = 100
    /\ monotonicNow = 0
    /\ nextWall = 110
    /\ nextMono = 10
    /\ intermediate = 0
    /\ finalSent = 0
    /\ stopRequested = FALSE

Tick ==
    /\ phase \in {"active", "rollback", "stopping"}
    /\ wallNow' = wallNow + 1
    /\ monotonicNow' = monotonicNow + 1
    /\ UNCHANGED <<phase, nextWall, nextMono, intermediate,
                    finalSent, stopRequested>>

RollbackWallClock ==
    /\ phase = "active"
    /\ wallNow > 0
    /\ wallNow' = 0
    /\ phase' = "rollback"
    /\ UNCHANGED <<monotonicNow, nextWall, nextMono, intermediate,
                    finalSent, stopRequested>>

SendIntermediate ==
    /\ phase \in {"active", "rollback"}
    /\ IF USE_FIXED
          THEN monotonicNow >= nextMono
          ELSE wallNow >= nextWall
    /\ intermediate' = intermediate + 1
    /\ nextWall' = nextWall + 10
    /\ nextMono' = nextMono + 10
    /\ UNCHANGED <<phase, wallNow, monotonicNow, finalSent, stopRequested>>

RequestStop ==
    /\ phase \in {"active", "rollback"}
    /\ stopRequested = FALSE
    /\ stopRequested' = TRUE
    /\ phase' = "stopping"
    /\ UNCHANGED <<wallNow, monotonicNow, nextWall, nextMono,
                    intermediate, finalSent>>

SendFinal ==
    /\ phase = "stopping"
    /\ finalSent = 0
    /\ finalSent' = 1
    /\ phase' = "done"
    /\ UNCHANGED <<wallNow, monotonicNow, nextWall, nextMono,
                    intermediate, stopRequested>>

Next ==
    \/ Tick
    \/ RollbackWallClock
    \/ SendIntermediate
    \/ RequestStop
    \/ SendFinal
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ wallNow \in Int
    /\ monotonicNow \in Nat
    /\ nextWall \in Int
    /\ nextMono \in Nat
    /\ intermediate \in Nat
    /\ finalSent \in 0..1
    /\ stopRequested \in BOOLEAN

FinalDelivery == phase = "done" => finalSent = 1
FinalOnce == finalSent <= 1

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    FinalDelivery
    FinalOnce
