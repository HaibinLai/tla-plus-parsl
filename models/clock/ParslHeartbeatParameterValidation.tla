--------------------------- MODULE ParslHeartbeatParameterValidation ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * HTEX heartbeat parameter validation.
 *
 * HighThroughputExecutor stores heartbeat_period and heartbeat_threshold
 * without checking that they are positive.  USE_FIXED represents rejecting a
 * configuration before workers/interchange are launched.
 *************************************************************************** *)

CONSTANTS PERIOD, THRESHOLD, USE_FIXED
VARIABLE state
vars == <<state>>

Init ==
    /\ PERIOD \in -1..1
    /\ THRESHOLD \in -1..1
    /\ USE_FIXED \in BOOLEAN
    /\ state = "configured"

Accept ==
    /\ state = "configured"
    /\ IF USE_FIXED THEN PERIOD > 0 /\ THRESHOLD > 0 ELSE TRUE
    /\ state' = "running"

Reject ==
    /\ state = "configured"
    /\ USE_FIXED
    /\ (PERIOD <= 0 \/ THRESHOLD <= 0)
    /\ state' = "rejected"

Next == Accept \/ Reject \/ UNCHANGED state
Spec == Init /\ [][Next]_vars

TypeOK == state \in {"configured", "running", "rejected"}
ParameterSafety == state = "running" => PERIOD > 0 /\ THRESHOLD > 0
=============================================================================
