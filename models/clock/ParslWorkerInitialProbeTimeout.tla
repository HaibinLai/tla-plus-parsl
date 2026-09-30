--------------------------- MODULE ParslWorkerInitialProbeTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Initial HTEX manager-to-interchange connection probe.
 *
 * The worker polls for a probe reply before registration.  The current
 * implementation logs a timeout and then calls blocking recv() anyway;
 * USE_FIXED terminates the startup path after the timeout instead.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "probing"

ProbeTimeout ==
    /\ state = "probing"
    /\ state' = "timed-out"

BlockingReceive ==
    /\ state = "timed-out"
    /\ state' = IF USE_FIXED THEN "stopped" ELSE "blocked"

Next == ProbeTimeout \/ BlockingReceive \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"probing", "timed-out", "stopped", "blocked"}

ProbeTimeoutSafety ==
    state # "blocked"

=============================================================================
