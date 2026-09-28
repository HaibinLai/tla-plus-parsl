--------------------------- MODULE ParslRadicalPilotResults ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A focused RadicalPilotExecutor callback/shutdown model.
 *
 * The executor maps RADICAL-Pilot task callbacks to a Parsl Future.  DONE
 * callbacks produce either an exit code (bash/executable) or a deserialized
 * return value (Python; MPI uses the raw return value), CANCELED callbacks
 * cancel the Future, and FAILED callbacks set an exception.  A master failure
 * fails all outstanding tasks.  USE_FIXED probes explicit Future cleanup at
 * shutdown; the current shutdown path closes the RP session but does not
 * explicitly fail pending Futures.
 ***************************************************************************)

CONSTANT USE_FIXED

Modes == {"bash", "python", "mpi"}
RPStates == {"not_submitted", "running", "done", "canceled", "failed"}
ExecutorStates == {"up", "stopped"}
FutureStates == {"none", "pending", "succeeded", "failed", "cancelled"}
ResultKinds == {"none", "exit_code", "deserialized", "raw_mpi", "exception"}

VARIABLES executorState, rpState, futureState, mode, resultKind
vars == <<executorState, rpState, futureState, mode, resultKind>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ executorState = "up"
    /\ rpState = "not_submitted"
    /\ futureState = "none"
    /\ mode = "none"
    /\ resultKind = "none"

Submit(m) ==
    /\ executorState = "up"
    /\ rpState = "not_submitted"
    /\ futureState = "none"
    /\ m \in Modes
    /\ rpState' = "running"
    /\ futureState' = "pending"
    /\ mode' = m
    /\ UNCHANGED <<executorState, resultKind>>

TaskDone(kind) ==
    /\ executorState = "up"
    /\ rpState = "running"
    /\ kind \in {"exit_code", "deserialized", "raw_mpi"}
    /\ IF (mode = "bash" /\ kind = "exit_code")
          \/ (mode = "python" /\ kind = "deserialized")
          \/ (mode = "mpi" /\ kind = "raw_mpi")
          THEN futureState' = "succeeded"
          ELSE futureState' = "failed"
    /\ rpState' = "done"
    /\ resultKind' = kind
    /\ UNCHANGED <<executorState, mode>>

TaskCanceled ==
    /\ executorState = "up"
    /\ rpState = "running"
    /\ rpState' = "canceled"
    /\ futureState' = "cancelled"
    /\ UNCHANGED <<executorState, mode, resultKind>>

TaskFailed ==
    /\ executorState = "up"
    /\ rpState = "running"
    /\ rpState' = "failed"
    /\ futureState' = "failed"
    /\ resultKind' = "exception"
    /\ UNCHANGED <<executorState, mode>>

MasterFailed ==
    /\ executorState = "up"
    /\ rpState = "running"
    /\ executorState' = "stopped"
    /\ rpState' = "failed"
    /\ futureState' = "failed"
    /\ resultKind' = "exception"
    /\ UNCHANGED mode

Shutdown ==
    /\ executorState = "up"
    /\ executorState' = "stopped"
    /\ IF USE_FIXED /\ futureState = "pending"
          THEN futureState' = "failed"
          ELSE futureState' = futureState
    /\ UNCHANGED <<rpState, mode, resultKind>>

Next ==
    \/ \E m \in Modes : Submit(m)
    \/ \E kind \in {"exit_code", "deserialized", "raw_mpi"} : TaskDone(kind)
    \/ TaskCanceled
    \/ TaskFailed
    \/ MasterFailed
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ executorState \in ExecutorStates
    /\ rpState \in RPStates
    /\ futureState \in FutureStates
    /\ mode \in (Modes \cup {"none"})
    /\ resultKind \in ResultKinds

CallbackMappingSafety ==
    futureState = "succeeded" => rpState = "done"

TerminalConsistency ==
    rpState \in {"done", "canceled", "failed"}
      => futureState \in {"succeeded", "failed", "cancelled"}

ShutdownFutureSafety ==
    executorState = "stopped" => futureState \in {"succeeded", "failed", "cancelled", "none"}

=============================================================================
