--------------------------- MODULE ParslGlobusComputeShutdownCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus Compute shutdown cleanup.
 *
 * The current wrapper calls the SDK executor shutdown before obtaining and
 * shutting down its result watcher.  If the first call raises, the watcher
 * remains live.  USE_FIXED models a cleanup path that guarantees watcher
 * shutdown even when the SDK reports an error.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES sdk, watcher, outcome
vars == <<sdk, watcher, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ sdk = "running"
    /\ watcher = "running"
    /\ outcome = "open"

SdkShutdownFailure ==
    /\ sdk = "running"
    /\ sdk' = "failed"
    /\ watcher' = IF USE_FIXED THEN "stopped" ELSE watcher
    /\ outcome' = "failed"

SdkShutdownSuccess ==
    /\ sdk = "running"
    /\ sdk' = "stopped"
    /\ watcher' = "stopped"
    /\ outcome' = "closed"

Next ==
    \/ SdkShutdownFailure
    \/ SdkShutdownSuccess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ sdk \in {"running", "failed", "stopped"}
    /\ watcher \in {"running", "stopped"}
    /\ outcome \in {"open", "failed", "closed"}

ShutdownCleanup ==
    outcome # "open" => watcher = "stopped"

=============================================================================
