--------------------------- MODULE ParslHtexWorkerDrainClock ---------------------------
EXTENDS Naturals

(***************************************************************************
 * The HTEX worker communicator stores drain_time from time.time() and later
 * compares another wall-clock reading against it.  A backward clock step can
 * postpone the drain message even though monotonic elapsed time is past the
 * configured deadline.  USE_FIXED models a monotonic deadline check.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES wallNow, monoNow, drainDeadline, drainSent
vars == <<wallNow, monoNow, drainDeadline, drainSent>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ wallNow = 90
    /\ monoNow = 0
    /\ drainDeadline = 102
    /\ drainSent = FALSE

AdvanceElapsed ==
    /\ monoNow = 0
    /\ monoNow' = 3
    /\ drainSent' = USE_FIXED
    /\ UNCHANGED <<wallNow, drainDeadline>>

CheckDrain ==
    /\ ~drainSent
    /\ monoNow >= 2
    /\ drainSent' = IF USE_FIXED
                         THEN monoNow >= 2
                         ELSE wallNow >= drainDeadline
    /\ UNCHANGED <<wallNow, monoNow, drainDeadline>>

Next == AdvanceElapsed \/ CheckDrain \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wallNow \in Nat
    /\ monoNow \in Nat
    /\ drainDeadline \in Nat
    /\ drainSent \in BOOLEAN

DrainDeadlineSafety == monoNow >= 2 => drainSent
=============================================================================
