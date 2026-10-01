--------------------------- MODULE ParslThreadExecutorLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ThreadPoolExecutor start/shutdown lifecycle.
 *
 * A failed construction of the underlying concurrent.futures pool leaves
 * self.executor unset.  The Current branch then exposes a second raw error
 * when cleanup calls shutdown; the Fixed branch makes shutdown idempotent
 * for an executor that never reached started state.
 ***************************************************************************)

CONSTANT USE_FIXED

States == {"constructed", "started", "stopped", "start_failed", "shutdown_error"}

VARIABLES state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "constructed"

StartSuccess ==
    /\ state = "constructed"
    /\ state' = "started"

StartFailure ==
    /\ state = "constructed"
    /\ state' = "start_failed"

Shutdown ==
    /\ state \in {"constructed", "started", "start_failed"}
    /\ state' = IF state = "started" \/ USE_FIXED
                   THEN "stopped" ELSE "shutdown_error"

Next ==
    \/ StartSuccess
    \/ StartFailure
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States

NoRawCleanupError ==
    state # "shutdown_error"

TerminalCleanupStable ==
    state = "stopped" => state' = "stopped" \/ state' = "stopped"

=============================================================================
