--------------------------- MODULE ParslOutputListMutation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFlowKernel._add_output_deps rewrites the caller-owned ``outputs``
 * list while creating clean File copies for stage-out.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES taskOutput, callerOutput
vars == <<taskOutput, callerOutput>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskOutput = "file:/output"
    /\ callerOutput = "file:/output"

PrepareOutput ==
    /\ taskOutput = "file:/output"
    /\ taskOutput' = "clean-copy:/output"
    /\ callerOutput' = IF USE_FIXED THEN callerOutput ELSE taskOutput'

Next ==
    \/ PrepareOutput
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskOutput \in {"file:/output", "clean-copy:/output"}
    /\ callerOutput \in {"file:/output", "clean-copy:/output"}

CallerListPreserved == USE_FIXED \/ callerOutput = "file:/output"

=============================================================================
