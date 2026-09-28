--------------------------- MODULE ParslMonitoringShutdownDrain ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring shutdown drain protocol.
 *
 * DatabaseManager sets a kill event during close, but both the external
 * resource-queue migration thread and the database loop continue while their
 * queues contain messages.  This model tracks that boundary and checks that
 * shutdown does not discard already accepted records.
 ***************************************************************************)

CONSTANT MAX_MESSAGES

VARIABLES killSet, externalQueue, internalQueue, processed
vars == <<killSet, externalQueue, internalQueue, processed>>

Init ==
    /\ MAX_MESSAGES \in Nat
    /\ killSet = FALSE
    /\ externalQueue = MAX_MESSAGES
    /\ internalQueue = 0
    /\ processed = 0

SignalClose ==
    /\ ~killSet
    /\ killSet' = TRUE
    /\ UNCHANGED <<externalQueue, internalQueue, processed>>

MigrateOne ==
    /\ externalQueue > 0
    /\ externalQueue' = externalQueue - 1
    /\ internalQueue' = internalQueue + 1
    /\ UNCHANGED <<killSet, processed>>

ProcessOne ==
    /\ internalQueue > 0
    /\ internalQueue' = internalQueue - 1
    /\ processed' = processed + 1
    /\ UNCHANGED <<killSet, externalQueue>>

Next ==
    \/ SignalClose
    \/ MigrateOne
    \/ ProcessOne
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ killSet \in BOOLEAN
    /\ externalQueue \in 0..MAX_MESSAGES
    /\ internalQueue \in 0..MAX_MESSAGES
    /\ processed \in 0..MAX_MESSAGES

AcceptedMessageConservation ==
    externalQueue + internalQueue + processed = MAX_MESSAGES

ShutdownDrainSafety ==
    killSet /\ externalQueue = 0 => internalQueue + processed = MAX_MESSAGES

=============================================================================
