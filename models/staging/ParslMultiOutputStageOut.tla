--------------------------- MODULE ParslMultiOutputStageOut ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Two-output stage-out readiness.
 *
 * Each output gets its own staging Future, but both stage-out operations are
 * gated by the same application Future. One output may fail independently;
 * that must not publish the other output or make either dependent consumer
 * run before its own output is ready.
 *************************************************************************** *)

CONSTANT ALLOW_EARLY_PUBLICATION
VARIABLES appState, output1, output2, dependent1, dependent2
vars == <<appState, output1, output2, dependent1, dependent2>>

Init ==
    /\ ALLOW_EARLY_PUBLICATION \in BOOLEAN
    /\ appState = "running"
    /\ output1 = "unready"
    /\ output2 = "unready"
    /\ dependent1 = "waiting"
    /\ dependent2 = "waiting"

CompleteApp ==
    /\ appState = "running"
    /\ appState' = "succeeded"
    /\ UNCHANGED <<output1, output2, dependent1, dependent2>>

PublishOutput1 ==
    /\ output1 = "unready"
    /\ (appState = "succeeded" \/ ALLOW_EARLY_PUBLICATION)
    /\ output1' = "ready"
    /\ UNCHANGED <<appState, output2, dependent1, dependent2>>

PublishOutput2 ==
    /\ output2 = "unready"
    /\ (appState = "succeeded" \/ ALLOW_EARLY_PUBLICATION)
    /\ output2' = "ready"
    /\ UNCHANGED <<appState, output1, dependent1, dependent2>>

FailOutput1 ==
    /\ output1 = "unready"
    /\ appState = "succeeded"
    /\ output1' = "failed"
    /\ UNCHANGED <<appState, output2, dependent1, dependent2>>

FailOutput2 ==
    /\ output2 = "unready"
    /\ appState = "succeeded"
    /\ output2' = "failed"
    /\ UNCHANGED <<appState, output1, dependent1, dependent2>>

RunDependent1 ==
    /\ dependent1 = "waiting"
    /\ output1 = "ready"
    /\ dependent1' = "running"
    /\ UNCHANGED <<appState, output1, output2, dependent2>>

RunDependent2 ==
    /\ dependent2 = "waiting"
    /\ output2 = "ready"
    /\ dependent2' = "running"
    /\ UNCHANGED <<appState, output1, output2, dependent1>>

Next ==
    \/ CompleteApp
    \/ PublishOutput1
    \/ PublishOutput2
    \/ FailOutput1
    \/ FailOutput2
    \/ RunDependent1
    \/ RunDependent2
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ appState \in {"running", "succeeded"}
    /\ output1 \in {"unready", "ready", "failed"}
    /\ output2 \in {"unready", "ready", "failed"}
    /\ dependent1 \in {"waiting", "running"}
    /\ dependent2 \in {"waiting", "running"}

Output1Safety == dependent1 = "running" => output1 = "ready"
Output2Safety == dependent2 = "running" => output2 = "ready"
NoEarlyPublication ==
    (output1 = "ready" \/ output2 = "ready") => appState = "succeeded"

=============================================================================
