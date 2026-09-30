--------------------------- MODULE ParslMemoCheckpointResultFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFlowKernel completion with task-exit checkpointing.
 *
 * A successful result is checkpointed before the task record and AppFuture
 * are made terminal.  If serializing the result for the checkpoint fails,
 * the current callback escapes and leaves the logical task/Future pending.
 * USE_FIXED represents converting that checkpoint failure into an explicit
 * terminal outcome rather than abandoning completion.
 ***************************************************************************)

CONSTANTS USE_FIXED, CHECKPOINT_FAILS

VARIABLES taskState, futureState, checkpointState
vars == <<taskState, futureState, checkpointState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ CHECKPOINT_FAILS \in BOOLEAN
    /\ taskState = "running"
    /\ futureState = "unresolved"
    /\ checkpointState = "not_started"

CompleteResult ==
    /\ taskState = "running"
    /\ CHECKPOINT_FAILS
    /\ checkpointState' = "error"
    /\ IF USE_FIXED
          THEN /\ taskState' = "failed"
               /\ futureState' = "rejected"
          ELSE /\ taskState' = "running"
               /\ futureState' = "unresolved"

CompleteResultNormally ==
    /\ taskState = "running"
    /\ ~CHECKPOINT_FAILS
    /\ checkpointState' = "written"
    /\ taskState' = "succeeded"
    /\ futureState' = "resolved"

Next == CompleteResult \/ CompleteResultNormally \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in {"running", "succeeded", "failed"}
    /\ futureState \in {"unresolved", "resolved", "rejected"}
    /\ checkpointState \in {"not_started", "written", "error"}

CheckpointFailureTerminality ==
    checkpointState = "error" => futureState # "unresolved"

ResultCompletionConsistency ==
    futureState = "resolved" => taskState = "succeeded"

=============================================================================
