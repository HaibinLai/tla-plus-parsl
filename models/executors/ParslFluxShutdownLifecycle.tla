--------------------------- MODULE ParslFluxShutdownLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxExecutor shutdown-before-start lifecycle.
 *
 * The executor constructs a submission thread before start() launches it.
 * The Current shutdown path unconditionally joins that unstarted thread;
 * the Fixed branch treats an unstarted executor as already quiescent.
 ***************************************************************************)

CONSTANT USE_FIXED

States == {"constructed", "started", "stopped", "shutdown_error"}

VARIABLES state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "constructed"

Start ==
    /\ state = "constructed"
    /\ state' = "started"

Shutdown ==
    /\ state \in {"constructed", "started"}
    /\ state' = IF state = "started" \/ USE_FIXED
                   THEN "stopped" ELSE "shutdown_error"

Next ==
    \/ Start
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States

NoRawShutdownError ==
    state # "shutdown_error"

=============================================================================
