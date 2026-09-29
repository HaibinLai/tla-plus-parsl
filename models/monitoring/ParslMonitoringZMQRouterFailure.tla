--------------------------- MODULE ParslMonitoringZMQRouterFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Persistent receive failure in the monitoring ZMQ router.
 *
 * The current router catches every receive exception and goes back to its
 * outer loop.  A permanently broken channel therefore remains alive until
 * an external exit event is set.  USE_FIXED models stopping after the first
 * unrecoverable channel failure.
 *************************************************************************** *)

CONSTANT USE_FIXED
MAX_FAILURES == 2
VARIABLES state, failures
vars == <<state, failures>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "listening"
    /\ failures = 0

ReceiveFailure ==
    /\ state = "listening"
    /\ failures < MAX_FAILURES
    /\ failures' = failures + 1
    /\ state' = IF USE_FIXED THEN "stopped" ELSE "listening"

ExternalStop ==
    /\ state = "listening"
    /\ state' = "stopped"
    /\ UNCHANGED failures

Next ==
    \/ ReceiveFailure
    \/ ExternalStop
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"listening", "stopped"}
    /\ failures \in 0..MAX_FAILURES

FailureTerminationSafety ==
    failures > 0 => state = "stopped"

=============================================================================
