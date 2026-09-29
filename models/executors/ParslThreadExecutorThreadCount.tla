--------------------------- MODULE ParslThreadExecutorThreadCount ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ThreadPoolExecutor thread-count validation.
 *
 * The current wrapper stores max_threads without validating it; a zero value
 * reaches the underlying concurrent.futures constructor during start().
 * USE_FIXED represents rejecting non-positive counts at executor creation.
 *************************************************************************** *)

CONSTANTS MAX_THREADS, USE_FIXED
VARIABLE state
vars == <<state>>

Init ==
    /\ MAX_THREADS \in 0..2
    /\ USE_FIXED \in BOOLEAN
    /\ state = "constructed"

Start ==
    /\ state = "constructed"
    /\ IF USE_FIXED THEN MAX_THREADS > 0 ELSE TRUE
    /\ state' = IF MAX_THREADS > 0 THEN "running" ELSE "start_error"

RejectAtConstruction ==
    /\ state = "constructed"
    /\ USE_FIXED
    /\ MAX_THREADS = 0
    /\ state' = "rejected"

Next == Start \/ RejectAtConstruction \/ UNCHANGED state
Spec == Init /\ [][Next]_vars

TypeOK == state \in {"constructed", "running", "start_error", "rejected"}
ThreadCountSafety == state = "running" => MAX_THREADS > 0
NoDelayedStartError == state # "start_error"
=============================================================================
