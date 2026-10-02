--------------------------- MODULE ParslGlobusComputeLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Compact composition model for GlobusComputeExecutor.
 *
 * The Parsl Future is the SDK Future, while executor configuration and the
 * result watcher have independent cleanup lifetimes.  This model combines
 * submit/restore error ordering, SDK result propagation, and shutdown cleanup.
 ***************************************************************************)

CONSTANTS USE_FIXED, RESTORE_FAILURE, SHUTDOWN_FAILURE

Phases == {"idle", "submitting", "restoring", "submitted", "terminal"}
FutureStates == {"none", "pending", "success", "failed", "cancelled"}
ExecutorStates == {"running", "stopped"}

VARIABLES phase, submitError, restoreError, observedError, future,
          sdk, watcher, executorState
vars == <<phase, submitError, restoreError, observedError, future,
          sdk, watcher, executorState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESTORE_FAILURE \in BOOLEAN
    /\ SHUTDOWN_FAILURE \in BOOLEAN
    /\ phase = "idle"
    /\ submitError = FALSE
    /\ restoreError = FALSE
    /\ observedError = "none"
    /\ future = "none"
    /\ sdk = "running"
    /\ watcher = "running"
    /\ executorState = "running"

BeginSubmit ==
    /\ phase = "idle"
    /\ phase' = "submitting"
    /\ future' = "pending"
    /\ UNCHANGED <<submitError, restoreError, observedError, sdk, watcher, executorState>>

SdkSubmitSucceeds ==
    /\ phase = "submitting"
    /\ phase' = "submitted"
    /\ UNCHANGED <<submitError, restoreError, observedError, future,
                    sdk, watcher, executorState>>

SdkSubmitFails ==
    /\ phase = "submitting"
    /\ phase' = "restoring"
    /\ submitError' = TRUE
    /\ UNCHANGED <<restoreError, observedError, future, sdk, watcher, executorState>>

Restore ==
    /\ phase = "restoring"
    /\ RESTORE_FAILURE
    /\ phase' = "terminal"
    /\ restoreError' = TRUE
    /\ observedError' = IF USE_FIXED THEN "submit" ELSE "restore"
    /\ future' = "failed"
    /\ UNCHANGED <<submitError, sdk, watcher, executorState>>

RestoreWithoutFailure ==
    /\ phase = "restoring"
    /\ ~RESTORE_FAILURE
    /\ phase' = "terminal"
    /\ observedError' = "submit"
    /\ future' = "failed"
    /\ UNCHANGED <<submitError, restoreError, sdk, watcher, executorState>>

Complete(kind) ==
    /\ phase = "submitted"
    /\ kind \in {"success", "failed", "cancelled"}
    /\ phase' = "terminal"
    /\ future' = kind
    /\ UNCHANGED <<submitError, restoreError, observedError, sdk, watcher, executorState>>

Shutdown ==
    /\ phase = "terminal"
    /\ executorState = "running"
    /\ executorState' = "stopped"
    /\ sdk' = IF SHUTDOWN_FAILURE THEN "failed" ELSE "stopped"
    /\ watcher' = IF USE_FIXED THEN "stopped" ELSE IF SHUTDOWN_FAILURE THEN "running" ELSE "stopped"
    /\ UNCHANGED <<phase, submitError, restoreError, observedError, future>>

Next ==
    \/ BeginSubmit
    \/ SdkSubmitSucceeds
    \/ SdkSubmitFails
    \/ Restore
    \/ RestoreWithoutFailure
    \/ \E kind \in {"success", "failed", "cancelled"} : Complete(kind)
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ submitError \in BOOLEAN
    /\ restoreError \in BOOLEAN
    /\ observedError \in {"none", "submit", "restore"}
    /\ future \in FutureStates
    /\ sdk \in {"running", "stopped", "failed"}
    /\ watcher \in {"running", "stopped"}
    /\ executorState \in ExecutorStates

ErrorPreserved == (phase = "terminal" /\ submitError) => observedError = "submit"
ShutdownCleanup == executorState = "stopped" => watcher = "stopped"
ResultTerminal == phase = "terminal" => future \in {"success", "failed", "cancelled"}
TerminalStability == phase = "terminal" => future # "none"

=============================================================================
