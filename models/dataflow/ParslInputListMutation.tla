--------------------------- MODULE ParslInputListMutation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFlowKernel._add_input_deps mutates the caller-owned ``inputs`` list
 * while replacing files with staged values.  The fixed branch snapshots the
 * list before rewriting task arguments.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES taskInput, callerInput
vars == <<taskInput, callerInput>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskInput = "file:/input"
    /\ callerInput = "file:/input"

StageInput ==
    /\ taskInput = "file:/input"
    /\ taskInput' = "staged:/worker/input"
    /\ callerInput' = IF USE_FIXED THEN callerInput ELSE taskInput'

Next ==
    \/ StageInput
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskInput \in {"file:/input", "staged:/worker/input"}
    /\ callerInput \in {"file:/input", "staged:/worker/input"}

CallerListPreserved == USE_FIXED \/ callerInput = "file:/input"

=============================================================================
