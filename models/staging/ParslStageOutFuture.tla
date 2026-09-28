--------------------------- MODULE ParslStageOutFuture ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A focused DataManager/DataFlowKernel stage-out dependency model.
 *
 * DataFlowKernel creates a DataFuture for each output.  If DataManager.stage_out
 * returns a Future, the output DataFuture follows that stage-out Future; if it
 * returns None, it follows the application Future.  In-task staging is modeled
 * as part of application completion, while separate staging has its own
 * completion/failure/retry path.
 ***************************************************************************)

CONSTANT STAGE_MODE

Modes == {"separate", "in_task", "none"}
AppStates == {"pending", "running", "succeeded", "failed"}
StageStates == {"not_started", "waiting", "running", "succeeded", "failed"}
OutputStates == {"unready", "ready", "failed"}
DependentStates == {"waiting", "running", "succeeded", "failed"}

VARIABLES appState, stageState, outputState, dependentState, retries
vars == <<appState, stageState, outputState, dependentState, retries>>

Init ==
    /\ STAGE_MODE \in Modes
    /\ appState = "pending"
    /\ stageState = "not_started"
    /\ outputState = "unready"
    /\ dependentState = "waiting"
    /\ retries = 0

StartApp ==
    /\ appState = "pending"
    /\ appState' = "running"
    /\ UNCHANGED <<stageState, outputState, dependentState, retries>>

CompleteApp ==
    /\ appState = "running"
    /\ appState' = "succeeded"
    /\ IF STAGE_MODE \in {"in_task", "none"}
          THEN outputState' = "ready"
          ELSE outputState' = outputState
    /\ IF STAGE_MODE = "separate"
          THEN stageState' = "waiting"
          ELSE stageState' = "succeeded"
    /\ UNCHANGED <<dependentState, retries>>

FailApp ==
    /\ appState = "running"
    /\ appState' = "failed"
    /\ outputState' = "failed"
    /\ stageState' = "failed"
    /\ UNCHANGED <<dependentState, retries>>

StartStageOut ==
    /\ STAGE_MODE = "separate"
    /\ appState = "succeeded"
    /\ stageState = "waiting"
    /\ stageState' = "running"
    /\ UNCHANGED <<appState, outputState, dependentState, retries>>

CompleteStageOut ==
    /\ STAGE_MODE = "separate"
    /\ stageState = "running"
    /\ stageState' = "succeeded"
    /\ outputState' = "ready"
    /\ UNCHANGED <<appState, dependentState, retries>>

FailStageOut ==
    /\ STAGE_MODE = "separate"
    /\ stageState = "running"
    /\ stageState' = "failed"
    /\ outputState' = "failed"
    /\ UNCHANGED <<appState, dependentState, retries>>

RetryStageOut ==
    /\ STAGE_MODE = "separate"
    /\ stageState = "failed"
    /\ retries < 1
    /\ stageState' = "waiting"
    /\ outputState' = "unready"
    /\ retries' = retries + 1
    /\ UNCHANGED <<appState, dependentState>>

StartDependent ==
    /\ dependentState = "waiting"
    /\ outputState = "ready"
    /\ dependentState' = "running"
    /\ UNCHANGED <<appState, stageState, outputState, retries>>

CompleteDependent ==
    /\ dependentState = "running"
    /\ dependentState' = "succeeded"
    /\ UNCHANGED <<appState, stageState, outputState, retries>>

RejectDependent ==
    /\ dependentState = "waiting"
    /\ outputState = "failed"
    /\ dependentState' = "failed"
    /\ UNCHANGED <<appState, stageState, outputState, retries>>

Next ==
    \/ StartApp
    \/ CompleteApp
    \/ FailApp
    \/ StartStageOut
    \/ CompleteStageOut
    \/ FailStageOut
    \/ RetryStageOut
    \/ StartDependent
    \/ CompleteDependent
    \/ RejectDependent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ appState \in AppStates
    /\ stageState \in StageStates
    /\ outputState \in OutputStates
    /\ dependentState \in DependentStates
    /\ retries \in 0..1

OutputPublicationSafety ==
    outputState = "ready" =>
       /\ appState = "succeeded"
       /\ stageState = "succeeded"

DependencySafety ==
    dependentState = "running" => outputState = "ready"

SeparateStageGate ==
    STAGE_MODE = "separate" =>
       (stageState = "running" => appState = "succeeded")

TerminalStability ==
    dependentState = "succeeded" => dependentState' = "succeeded"

=============================================================================
