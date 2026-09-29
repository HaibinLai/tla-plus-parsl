--------------------------- MODULE ParslHtexDuplicateResult ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Focused HTEX duplicate-result protocol.
 *
 * The first result removes the task from the executor task map.  A duplicate
 * frame then either crashes the current worker (KeyError) or is classified as
 * stale by the candidate fixed behavior.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES phase, futureState, taskPresent, workerAlive
vars == <<phase, futureState, taskPresent, workerAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "first"
    /\ futureState = "pending"
    /\ taskPresent = TRUE
    /\ workerAlive = TRUE

FirstResult ==
    /\ phase = "first"
    /\ taskPresent
    /\ futureState' = "done"
    /\ taskPresent' = FALSE
    /\ phase' = "duplicate"
    /\ UNCHANGED workerAlive

DuplicateResult ==
    /\ phase = "duplicate"
    /\ ~taskPresent
    /\ futureState = "done"
    /\ taskPresent' = FALSE
    /\ phase' = "handled"
    /\ workerAlive' = USE_FIXED
    /\ UNCHANGED futureState

Next ==
    \/ FirstResult
    \/ DuplicateResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"first", "duplicate", "handled"}
    /\ futureState \in {"pending", "done"}
    /\ taskPresent \in BOOLEAN
    /\ workerAlive \in BOOLEAN

DuplicateSafety ==
    phase = "handled" => workerAlive

=============================================================================
