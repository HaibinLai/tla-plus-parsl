--------------------------- MODULE ParslWorkQueueStartTimeoutCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * WorkQueue startup timeout cleanup.
 *
 * WorkQueueExecutor.start starts its submit process and collector thread,
 * then waits for a port announcement.  If the mailbox timeout expires, the
 * current path raises without stopping either component.  USE_FIXED models
 * terminal cleanup on the startup-failure path.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES process, collector, startup
vars == <<process, collector, startup>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ process = "not_started"
    /\ collector = "not_started"
    /\ startup = "not_started"

StartComponents ==
    /\ process = "not_started" /\ collector = "not_started"
    /\ process' = "running"
    /\ collector' = "running"
    /\ startup' = "waiting_for_port"

PortArrives ==
    /\ startup = "waiting_for_port"
    /\ startup' = "started"
    /\ UNCHANGED <<process, collector>>

PortTimeout ==
    /\ startup = "waiting_for_port"
    /\ startup' = "failed"
    /\ process' = IF USE_FIXED THEN "stopped" ELSE process
    /\ collector' = IF USE_FIXED THEN "stopped" ELSE collector

Next ==
    \/ StartComponents
    \/ PortArrives
    \/ PortTimeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ process \in {"not_started", "running", "stopped"}
    /\ collector \in {"not_started", "running", "stopped"}
    /\ startup \in {"not_started", "waiting_for_port", "started", "failed"}

StartupFailureCleanup ==
    startup = "failed" => process = "stopped" /\ collector = "stopped"

=============================================================================
