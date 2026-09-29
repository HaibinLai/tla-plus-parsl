--------------------------- MODULE ParslExecutorSelection ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Executor selection at DataFlowKernel.submit.
 *
 * The current submit path accepts an empty executor list and then calls
 * random.choice, exposing a raw IndexError.  The fixed branch rejects the
 * request before selection.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"ready", "selected", "rejected", "crashed"}

VARIABLES phase, selected
vars == <<phase, selected>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ selected = "none"

SubmitEmptyCurrent ==
    /\ ~USE_FIXED
    /\ phase = "ready"
    /\ phase' = "crashed"
    /\ selected' = "none"

RejectEmptyFixed ==
    /\ USE_FIXED
    /\ phase = "ready"
    /\ phase' = "rejected"
    /\ selected' = "none"

SubmitAvailable ==
    /\ phase = "ready"
    /\ phase' = "selected"
    /\ selected' = "E1"

Next ==
    \/ SubmitEmptyCurrent
    \/ RejectEmptyFixed
    \/ SubmitAvailable
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ selected \in {"none", "E1"}

NoSelectionCrash == phase # "crashed"

=============================================================================
