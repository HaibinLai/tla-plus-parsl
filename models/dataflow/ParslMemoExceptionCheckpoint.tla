--------------------------- MODULE ParslMemoExceptionCheckpoint ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BasicMemoizer stores a failed AppFuture in the in-memory memo table, but
 * _checkpoint_these_tasks writes only commands whose exception is None.
 * Consequently a failed call can be reused during one run but is absent
 * after a restart.  USE_FIXED symbolically enables failure checkpointing.
 *************************************************************************** *)

CONSTANTS USE_FIXED

VARIABLES phase, memory, pending, disk, reused, executions

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "fresh"
    /\ memory = "empty"
    /\ pending = FALSE
    /\ disk = "empty"
    /\ reused = FALSE
    /\ executions = 0

RunAndFail ==
    /\ phase = "fresh"
    /\ phase' = "failed"
    /\ memory' = "failed"
    /\ pending' = TRUE
    /\ UNCHANGED <<disk, reused, executions>>

Checkpoint ==
    /\ phase = "failed" /\ pending
    /\ phase' = "checkpointed"
    /\ pending' = FALSE
    /\ disk' = IF USE_FIXED THEN "failed" ELSE disk
    /\ UNCHANGED <<memory, reused, executions>>

Restart ==
    /\ phase = "checkpointed"
    /\ phase' = "restarted"
    /\ memory' = disk
    /\ UNCHANGED <<pending, disk, reused, executions>>

SecondCall ==
    /\ phase = "restarted"
    /\ phase' = IF memory = "failed" THEN "reused" ELSE "rerun"
    /\ reused' = (memory = "failed")
    /\ executions' = executions + (IF memory = "failed" THEN 0 ELSE 1)
    /\ UNCHANGED <<memory, pending, disk>>

vars == <<phase, memory, pending, disk, reused, executions>>

Done ==
    /\ phase \in {"reused", "rerun"}
    /\ UNCHANGED vars

Next == RunAndFail \/ Checkpoint \/ Restart \/ SecondCall \/ Done

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"fresh", "failed", "checkpointed", "restarted", "reused", "rerun"}
    /\ memory \in {"empty", "failed"}
    /\ disk \in {"empty", "failed"}
    /\ pending \in BOOLEAN
    /\ reused \in BOOLEAN
    /\ executions \in Nat

FailureCheckpointRecovery ==
    phase = "restarted" => memory = "failed"

=============================================================================
