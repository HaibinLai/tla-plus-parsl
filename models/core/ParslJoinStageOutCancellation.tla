--------------------------- MODULE ParslJoinStageOutCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small application-Future/stage-out composition model.
 *
 * The logical application and its physical stage-out Future are separate.
 * Cancellation can race with a stage-out completion that was already in
 * flight.  The Fixed branch rejects that late publication; Current lets it
 * publish after the outer Future became cancelled.
 ***************************************************************************)

CONSTANT USE_FIXED, BOUND_TO_APP

AppStates == {"pending", "running", "succeeded", "failed", "cancelled"}
StageStates == {"blocked", "running", "published", "failed", "cancelled"}
OuterStates == {"running", "succeeded", "failed", "cancelled"}

VARIABLES app, stage, outer, latePublication
vars == <<app, stage, outer, latePublication>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ BOUND_TO_APP \in BOOLEAN
    /\ app = "pending"
    /\ stage = "blocked"
    /\ outer = "running"
    /\ latePublication = FALSE

StartApp ==
    /\ app = "pending"
    /\ app' = "running"
    /\ UNCHANGED <<stage, outer, latePublication>>

CompleteApp ==
    /\ app = "running"
    /\ app' = "succeeded"
    /\ stage' = "running"
    /\ UNCHANGED <<outer, latePublication>>

FailApp ==
    /\ app = "running"
    /\ app' = "failed"
    /\ stage' = "failed"
    /\ outer' = "failed"
    /\ UNCHANGED latePublication

CompleteStage ==
    /\ app = "succeeded"
    /\ stage = "running"
    /\ stage' = "published"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<app, latePublication>>

CancelOuter ==
    /\ outer = "running"
    /\ outer' = "cancelled"
    /\ app' = IF app \in {"pending", "running"} THEN "cancelled" ELSE app
    /\ stage' = IF stage \in {"blocked", "running"} THEN "cancelled" ELSE stage
    /\ UNCHANGED latePublication

LateStagePublication ==
    /\ outer = "cancelled"
    /\ stage = "cancelled"
    /\ latePublication = FALSE
    /\ latePublication' = TRUE
    /\ stage' = IF USE_FIXED \/ BOUND_TO_APP THEN stage ELSE "published"
    /\ UNCHANGED <<app, outer>>

Next ==
    \/ StartApp
    \/ CompleteApp
    \/ FailApp
    \/ CompleteStage
    \/ CancelOuter
    \/ LateStagePublication
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ BOUND_TO_APP \in BOOLEAN
    /\ app \in AppStates
    /\ stage \in StageStates
    /\ outer \in OuterStates
    /\ latePublication \in BOOLEAN

DependencySafety ==
    stage = "running" => app = "succeeded"

JoinOutputSafety ==
    outer = "succeeded" => stage = "published"

CancellationPublicationSafety ==
    outer = "cancelled" => stage # "published"

TerminalStateStability ==
    outer = "cancelled" => app = "cancelled" \/ app = "succeeded" \/ app = "failed"

BoundProviderCancellationSafety ==
    BOUND_TO_APP => (outer = "cancelled" => stage # "published")

================================================================================
