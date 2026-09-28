--------------------------- MODULE ParslBashTimeoutCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bash app timeout boundary.  remote_side_bash_executor calls
 * proc.wait(timeout=walltime), but its TimeoutExpired handler raises
 * AppTimeout without terminating the shell/process group.  USE_FIXED models
 * killing the process group before reporting the timeout.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES phase, processAlive, killIssued
vars == <<phase, processAlive, killIssued>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "running"
    /\ processAlive = TRUE
    /\ killIssued = FALSE

Timeout ==
    /\ phase = "running"
    /\ phase' = "timed-out"
    /\ processAlive' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ killIssued' = USE_FIXED

Done ==
    /\ phase = "timed-out"
    /\ UNCHANGED vars

Next == Timeout \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"running", "timed-out"}
    /\ processAlive \in BOOLEAN
    /\ killIssued \in BOOLEAN

TimeoutCleanupSafety ==
    phase = "timed-out" => /\ ~processAlive /\ killIssued

=============================================================================
