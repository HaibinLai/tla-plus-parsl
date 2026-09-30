--------------------------- MODULE ParslTaskVineStartFailureCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVine startup failure cleanup.
 *
 * TaskVineExecutor.start launches the manager process (and optionally the
 * factory) before provider scaling.  A scaling exception escapes before the
 * collector starts, leaving already-launched processes alive.  USE_FIXED
 * models stopping those components before returning startup failure.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES manager, factory, collector, startup
vars == <<manager, factory, collector, startup>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ manager = "not_started"
    /\ factory = "not_started"
    /\ collector = "not_started"
    /\ startup = "not_started"

LaunchManager ==
    /\ manager = "not_started"
    /\ manager' = "running"
    /\ UNCHANGED <<factory, collector, startup>>

ScalingFailure ==
    /\ manager = "running"
    /\ startup = "not_started"
    /\ startup' = "failed"
    /\ manager' = IF USE_FIXED THEN "stopped" ELSE manager
    /\ UNCHANGED <<factory, collector>>

StartCollector ==
    /\ manager = "running"
    /\ startup = "not_started"
    /\ collector' = "running"
    /\ startup' = "started"
    /\ UNCHANGED <<manager, factory>>

Next ==
    \/ LaunchManager
    \/ ScalingFailure
    \/ StartCollector
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ manager \in {"not_started", "running", "stopped"}
    /\ factory \in {"not_started", "running", "stopped"}
    /\ collector \in {"not_started", "running"}
    /\ startup \in {"not_started", "started", "failed"}

StartupFailureCleanup ==
    startup = "failed" =>
        /\ manager = "stopped"
        /\ factory = "stopped" \/ factory = "not_started"
        /\ collector = "not_started"

=============================================================================
