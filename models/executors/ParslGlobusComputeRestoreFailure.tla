--------------------------- MODULE ParslGlobusComputeRestoreFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus Compute submit failure followed by configuration-restore failure.
 *
 * The SDK submit operation can fail, and the ``finally`` restoration of the
 * shared executor configuration can fail independently.  The Current branch
 * exposes the restoration error; the Fixed branch preserves the original
 * submit failure while still making cleanup terminal.
 ***************************************************************************)

CONSTANTS USE_FIXED, RESTORE_FAILURE

VARIABLES phase, submitError, restoreError, observedError, future
vars == <<phase, submitError, restoreError, observedError, future>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESTORE_FAILURE \in BOOLEAN
    /\ phase = "idle"
    /\ submitError = FALSE
    /\ restoreError = FALSE
    /\ observedError = "none"
    /\ future = "pending"

BeginSubmit ==
    /\ phase = "idle"
    /\ phase' = "submitting"
    /\ UNCHANGED <<submitError, restoreError, observedError, future>>

SdkSubmitFails ==
    /\ phase = "submitting"
    /\ phase' = "restoring"
    /\ submitError' = TRUE
    /\ UNCHANGED <<restoreError, observedError, future>>

RestoreSucceeds ==
    /\ phase = "restoring"
    /\ ~RESTORE_FAILURE
    /\ phase' = "terminal"
    /\ observedError' = "submit"
    /\ future' = "failed"
    /\ UNCHANGED <<submitError, restoreError>>

RestoreFailsFixed ==
    /\ phase = "restoring"
    /\ RESTORE_FAILURE
    /\ USE_FIXED
    /\ phase' = "terminal"
    /\ restoreError' = TRUE
    /\ observedError' = "submit"
    /\ future' = "failed"
    /\ UNCHANGED submitError

RestoreFailsCurrent ==
    /\ phase = "restoring"
    /\ RESTORE_FAILURE
    /\ ~USE_FIXED
    /\ phase' = "terminal"
    /\ restoreError' = TRUE
    /\ observedError' = "restore"
    /\ future' = "failed"
    /\ UNCHANGED submitError

Next ==
    \/ BeginSubmit
    \/ SdkSubmitFails
    \/ RestoreSucceeds
    \/ RestoreFailsFixed
    \/ RestoreFailsCurrent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"idle", "submitting", "restoring", "terminal"}
    /\ submitError \in BOOLEAN
    /\ restoreError \in BOOLEAN
    /\ observedError \in {"none", "submit", "restore"}
    /\ future \in {"pending", "failed"}

CleanupTerminality == phase = "terminal" => future = "failed"
OriginalErrorPreserved ==
    (phase = "terminal" /\ submitError) => observedError = "submit"
NoPendingAfterFailure ==
    (phase = "terminal" /\ submitError) => future = "failed"

=============================================================================
