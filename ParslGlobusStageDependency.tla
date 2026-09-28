--------------------------- MODULE ParslGlobusStageDependency ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus staging dependency wiring.
 *
 * Stage-in must retain the parent DataFuture as an input dependency. Stage-out
 * must retain the application Future as an input dependency so the transfer
 * cannot start before the application has produced its file.
 ***************************************************************************)

CONSTANT MODE

Modes == {"in", "out"}
ParentStates == {"pending", "ready"}
AppStates == {"running", "done"}
Stages == {"not_started", "started", "succeeded"}

VARIABLES parentState, appState, stageState
vars == <<parentState, appState, stageState>>

Init ==
    /\ MODE \in Modes
    /\ parentState = "pending"
    /\ appState = "running"
    /\ stageState = "not_started"

ParentReady ==
    /\ parentState = "pending"
    /\ parentState' = "ready"
    /\ UNCHANGED <<appState, stageState>>

AppDone ==
    /\ appState = "running"
    /\ appState' = "done"
    /\ UNCHANGED <<parentState, stageState>>

StartStageIn ==
    /\ MODE = "in"
    /\ parentState = "ready"
    /\ stageState = "not_started"
    /\ stageState' = "started"
    /\ UNCHANGED <<parentState, appState>>

StartStageOut ==
    /\ MODE = "out"
    /\ appState = "done"
    /\ stageState = "not_started"
    /\ stageState' = "started"
    /\ UNCHANGED <<parentState, appState>>

CompleteStage ==
    /\ stageState = "started"
    /\ stageState' = "succeeded"
    /\ UNCHANGED <<parentState, appState>>

Next ==
    \/ ParentReady
    \/ AppDone
    \/ StartStageIn
    \/ StartStageOut
    \/ CompleteStage
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ parentState \in ParentStates
    /\ appState \in AppStates
    /\ stageState \in Stages

DependencyGate ==
    stageState = "started" =>
        IF MODE = "in" THEN parentState = "ready" ELSE appState = "done"

StageCompletionSafety ==
    stageState = "succeeded" =>
        IF MODE = "in" THEN parentState = "ready" ELSE appState = "done"

=============================================================================
