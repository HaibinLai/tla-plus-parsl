--------------------------- MODULE ParslLSFMissingJob ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LSFProvider._status asks bjobs for active job IDs.  LSF omits jobs which
 * are no longer reported, so the current provider fills those holes with
 * COMPLETED even when the job may have failed.  USE_FIXED keeps the result
 * UNKNOWN until an explicit terminal state is observed.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES pollState, jobState
vars == <<pollState, jobState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollState = "waiting"
    /\ jobState = "running"

MissingJob ==
    /\ pollState = "waiting"
    /\ pollState' = "complete"
    /\ jobState' = IF USE_FIXED THEN "unknown" ELSE "completed"

KnownFailure ==
    /\ pollState = "waiting"
    /\ pollState' = "complete"
    /\ jobState' = "failed"

KnownRunning ==
    /\ pollState = "waiting"
    /\ pollState' = "running"
    /\ jobState' = "running"

Done ==
    /\ pollState \in {"complete", "running"}
    /\ UNCHANGED vars

Next == MissingJob \/ KnownFailure \/ KnownRunning \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ pollState \in {"waiting", "running", "complete"}
    /\ jobState \in {"running", "failed", "completed", "unknown"}

MissingJobSafety ==
    jobState # "completed"

TerminalStateStability ==
    pollState = "complete" => jobState \in {"failed", "completed", "unknown"}

=============================================================================
