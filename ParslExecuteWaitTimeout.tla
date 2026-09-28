--------------------------- MODULE ParslExecuteWaitTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ClusterProvider.execute_wait delegates to utils.execute_wait.  The
 * current execute_wait path re-raises communicate(timeout=...) failures but
 * does not terminate the process group.  The FIXED branch performs cleanup
 * before reporting the timeout.
 *************************************************************************** *)

CONSTANTS COMMAND_TIMES_OUT, USE_FIXED
VARIABLES state, processAlive
vars == <<state, processAlive>>

Init ==
    /\ COMMAND_TIMES_OUT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "running"
    /\ processAlive = TRUE

Complete ==
    /\ state = "running"
    /\ ~COMMAND_TIMES_OUT
    /\ state' = "returned"
    /\ processAlive' = FALSE

Timeout ==
    /\ state = "running"
    /\ COMMAND_TIMES_OUT
    /\ state' = "raised"
    /\ processAlive' = IF USE_FIXED THEN FALSE ELSE TRUE

Next ==
    \/ Complete
    \/ Timeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"running", "returned", "raised"}
    /\ processAlive \in BOOLEAN

TimeoutCleanupSafety ==
    state = "raised" => ~processAlive

=============================================================================
