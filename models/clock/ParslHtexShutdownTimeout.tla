--------------------------- MODULE ParslHtexShutdownTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HighThroughputExecutor.shutdown() terminates the interchange, waits for
 * the configured deadline, kills it only after TimeoutExpired, and then
 * closes the outgoing/command pipes.  The result-queue thread is joined
 * after those pipe operations.
 ***************************************************************************)

VARIABLES process, waitResult, pipes, resultThread, shutdown
vars == <<process, waitResult, pipes, resultThread, shutdown>>

ProcessStates == {"running", "terminating", "terminated", "killed"}
WaitResults == {"not_called", "returned", "expired"}
PipeStates == {"open", "closed"}
ThreadStates == {"running", "exited"}

Init ==
    /\ process = "running"
    /\ waitResult = "not_called"
    /\ pipes = "open"
    /\ resultThread = "running"
    /\ shutdown = FALSE

Terminate ==
    /\ ~shutdown
    /\ process = "running"
    /\ process' = "terminating"
    /\ shutdown' = TRUE
    /\ UNCHANGED <<waitResult, pipes, resultThread>>

WaitReturns ==
    /\ process = "terminating"
    /\ waitResult = "not_called"
    /\ process' = "terminated"
    /\ waitResult' = "returned"
    /\ UNCHANGED <<pipes, resultThread, shutdown>>

WaitExpires ==
    /\ process = "terminating"
    /\ waitResult = "not_called"
    /\ waitResult' = "expired"
    /\ UNCHANGED <<process, pipes, resultThread, shutdown>>

KillAfterTimeout ==
    /\ waitResult = "expired"
    /\ process = "terminating"
    /\ process' = "killed"
    /\ UNCHANGED <<waitResult, pipes, resultThread, shutdown>>

ClosePipes ==
    /\ process \in {"terminated", "killed"}
    /\ pipes = "open"
    /\ pipes' = "closed"
    /\ UNCHANGED <<process, waitResult, resultThread, shutdown>>

ResultThreadExit ==
    /\ pipes = "closed"
    /\ resultThread = "running"
    /\ resultThread' = "exited"
    /\ UNCHANGED <<process, waitResult, pipes, shutdown>>

Next ==
    \/ Terminate
    \/ WaitReturns
    \/ WaitExpires
    \/ KillAfterTimeout
    \/ ClosePipes
    \/ ResultThreadExit
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ process \in ProcessStates
    /\ waitResult \in WaitResults
    /\ pipes \in PipeStates
    /\ resultThread \in ThreadStates
    /\ shutdown \in BOOLEAN

KillRequiresTimeout == process = "killed" => waitResult = "expired"
PipesCloseAfterProcess == pipes = "closed" => process \in {"terminated", "killed"}
ThreadJoinOrder == resultThread = "exited" => pipes = "closed"
ShutdownRequested == shutdown => process # "running"

=============================================================================
SPECIFICATION Spec
INVARIANTS TypeOK KillRequiresTimeout PipesCloseAfterProcess
    ThreadJoinOrder ShutdownRequested
