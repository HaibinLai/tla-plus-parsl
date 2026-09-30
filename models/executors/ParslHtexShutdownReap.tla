--------------------------- MODULE ParslHtexShutdownReap ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX shutdown timeout boundary.  The current shutdown path sends SIGKILL
 * after a timed wait but does not wait/reap again before closing its pipes and
 * returning.  USE_FIXED adds a reap step, so shutdown completion implies that
 * the interchange process is no longer live.
 ***************************************************************************)

CONSTANT USE_FIXED, TIMED_OUT
VARIABLES process, pipes, phase
vars == <<process, pipes, phase>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ TIMED_OUT \in BOOLEAN
    /\ process = "running"
    /\ pipes = "open"
    /\ phase = "active"

Terminate ==
    /\ phase = "active"
    /\ phase' = IF TIMED_OUT THEN "waiting" ELSE "closing"
    /\ process' = IF TIMED_OUT THEN process ELSE "stopped"
    /\ UNCHANGED pipes

WaitTimeout ==
    /\ phase = "waiting"
    /\ TIMED_OUT
    /\ phase' = "kill-sent"
    /\ UNCHANGED <<process, pipes>>

Kill ==
    /\ phase = "kill-sent"
    /\ process' = "stopping"
    /\ phase' = IF USE_FIXED THEN "reaping" ELSE "closing"
    /\ UNCHANGED pipes

Reap ==
    /\ phase = "reaping"
    /\ process' = "stopped"
    /\ phase' = "closing"
    /\ UNCHANGED pipes

ClosePipes ==
    /\ phase = "closing"
    /\ pipes' = "closed"
    /\ phase' = "done"
    /\ UNCHANGED process

Next == Terminate \/ WaitTimeout \/ Kill \/ Reap \/ ClosePipes \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ process \in {"running", "stopping", "stopped"}
    /\ pipes \in {"open", "closed"}
    /\ phase \in {"active", "waiting", "kill-sent", "reaping", "closing", "done"}

ShutdownQuiescence == phase = "done" => process = "stopped"
=============================================================================
