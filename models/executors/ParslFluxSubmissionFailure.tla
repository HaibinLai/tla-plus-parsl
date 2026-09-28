--------------------------- MODULE ParslFluxSubmissionFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxExecutor submission-thread failure cleanup.
 *
 * _submit_wrapper routes an exception through _error_out_jobs.  The cleanup
 * loop keeps draining the submission queue after stop_event is set and fails
 * every queued Future rather than leaving it pending.
 ***************************************************************************)

CONSTANT MAX_JOBS

VARIABLES stopSet, queued, failed, state
vars == <<stopSet, queued, failed, state>>

Init ==
    /\ MAX_JOBS \in Nat
    /\ stopSet = FALSE
    /\ queued = MAX_JOBS
    /\ failed = 0
    /\ state = "running"

SubmissionFailure ==
    /\ state = "running"
    /\ stopSet' = TRUE
    /\ state' = "draining"
    /\ UNCHANGED <<queued, failed>>

FailQueuedJob ==
    /\ state = "draining"
    /\ queued > 0
    /\ queued' = queued - 1
    /\ failed' = failed + 1
    /\ UNCHANGED <<stopSet, state>>

FinishDrain ==
    /\ state = "draining"
    /\ queued = 0
    /\ state' = "stopped"
    /\ UNCHANGED <<stopSet, queued, failed>>

Next ==
    \/ SubmissionFailure
    \/ FailQueuedJob
    \/ FinishDrain
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MAX_JOBS \in Nat
    /\ stopSet \in BOOLEAN
    /\ queued \in 0..MAX_JOBS
    /\ failed \in 0..MAX_JOBS
    /\ state \in {"running", "draining", "stopped"}

FailureDrainSafety ==
    state = "stopped" => queued = 0 /\ failed = MAX_JOBS

=============================================================================
