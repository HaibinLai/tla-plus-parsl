--------------------------- MODULE ParslLocalProviderExitStatus ---------------------------
EXTENDS Integers

(***************************************************************************
 * Compact model of LocalProvider.status().  The provider uses a temporary
 * .ec file: '-' means the launcher is still in flight, a numeric value is
 * the command exit code, and malformed contents are a failed observation.
 * A numeric exit code takes precedence over process liveness and a prior
 * cancellation request.
 ***************************************************************************)

VARIABLES marker, alive, cancelled, status
vars == <<marker, alive, cancelled, status>>

Markers == {"-", "0", "3", "bad"}
Statuses == {"unknown", "running", "completed", "failed", "cancelled"}

Init ==
    /\ marker = "-"
    /\ alive = TRUE
    /\ cancelled = FALSE
    /\ status = "unknown"

WriteSuccess ==
    /\ status = "unknown"
    /\ marker' = "0"
    /\ UNCHANGED <<alive, cancelled, status>>

WriteFailure ==
    /\ status = "unknown"
    /\ marker' = "3"
    /\ UNCHANGED <<alive, cancelled, status>>

WriteMalformed ==
    /\ status = "unknown"
    /\ marker' = "bad"
    /\ UNCHANGED <<alive, cancelled, status>>

ProcessDies ==
    /\ alive
    /\ alive' = FALSE
    /\ UNCHANGED <<marker, cancelled, status>>

RequestCancel ==
    /\ ~cancelled
    /\ cancelled' = TRUE
    /\ UNCHANGED <<marker, alive, status>>

PollRunning ==
    /\ status = "unknown"
    /\ marker = "-"
    /\ alive
    /\ status' = "running"
    /\ UNCHANGED <<marker, alive, cancelled>>

PollKilled ==
    /\ status = "unknown"
    /\ marker = "-"
    /\ ~alive
    /\ status' = "cancelled"
    /\ UNCHANGED <<marker, alive, cancelled>>

PollCompleted ==
    /\ status = "unknown"
    /\ marker = "0"
    /\ status' = "completed"
    /\ UNCHANGED <<marker, alive, cancelled>>

PollFailed ==
    /\ status = "unknown"
    /\ marker \in {"3", "bad"}
    /\ status' = "failed"
    /\ UNCHANGED <<marker, alive, cancelled>>

Next ==
    \/ WriteSuccess
    \/ WriteFailure
    \/ WriteMalformed
    \/ ProcessDies
    \/ RequestCancel
    \/ PollRunning
    \/ PollKilled
    \/ PollCompleted
    \/ PollFailed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ marker \in Markers
    /\ alive \in BOOLEAN
    /\ cancelled \in BOOLEAN
    /\ status \in Statuses

RunningRequiresMarker == status = "running" => marker = "-"
CompletedRequiresZero == status = "completed" => marker = "0"
FailedRequiresFailureEvidence == status = "failed" => marker \in {"3", "bad"}
KilledRequiresNoExit == status = "cancelled" => marker = "-" /\ ~alive
TerminalStatusIsKnown == status # "unknown" => status \in {"running", "completed", "failed", "cancelled"}

=============================================================================
SPECIFICATION Spec
INVARIANTS TypeOK RunningRequiresMarker CompletedRequiresZero
    FailedRequiresFailureEvidence KilledRequiresNoExit TerminalStatusIsKnown
