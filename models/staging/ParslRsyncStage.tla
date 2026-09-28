--------------------------- MODULE ParslRsyncStage ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RSync in-task staging protocol.
 *
 * Stage-in must complete rsync before the user function runs. Stage-out runs
 * the user function first, then transfers its output; a transfer failure
 * still fails the wrapper even though the user function ran.
 ***************************************************************************)

CONSTANT MODE, TRANSFER_SUCCEEDS

Modes == {"in", "out"}
Phases == {"new", "transfer_in", "app", "transfer_out", "succeeded", "failed"}

VARIABLES phase, appRan, appSucceeded
vars == <<phase, appRan, appSucceeded>>

Init ==
    /\ MODE \in Modes
    /\ TRANSFER_SUCCEEDS \in BOOLEAN
    /\ phase = "new"
    /\ appRan = FALSE
    /\ appSucceeded = FALSE

StartStageIn ==
    /\ MODE = "in"
    /\ phase = "new"
    /\ phase' = "transfer_in"
    /\ UNCHANGED <<appRan, appSucceeded>>

FinishStageIn ==
    /\ MODE = "in"
    /\ phase = "transfer_in"
    /\ phase' = IF TRANSFER_SUCCEEDS THEN "app" ELSE "failed"
    /\ UNCHANGED <<appRan, appSucceeded>>

StartStageOut ==
    /\ MODE = "out"
    /\ phase = "new"
    /\ phase' = "app"
    /\ UNCHANGED <<appRan, appSucceeded>>

RunApp ==
    /\ phase = "app"
    /\ appRan' = TRUE
    /\ appSucceeded' = TRUE
    /\ phase' = IF MODE = "out" THEN "transfer_out" ELSE "succeeded"

FinishStageOut ==
    /\ MODE = "out"
    /\ phase = "transfer_out"
    /\ phase' = IF TRANSFER_SUCCEEDS THEN "succeeded" ELSE "failed"
    /\ UNCHANGED <<appRan, appSucceeded>>

Next ==
    \/ StartStageIn
    \/ FinishStageIn
    \/ StartStageOut
    \/ RunApp
    \/ FinishStageOut
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ appRan \in BOOLEAN
    /\ appSucceeded \in BOOLEAN

StageInGate ==
    MODE = "in" /\ appRan => TRANSFER_SUCCEEDS

FailurePropagation ==
    phase = "failed" =>
        /\ (MODE = "in" => ~appRan)
        /\ (MODE = "out" => appRan)

SuccessSafety ==
    phase = "succeeded" =>
        /\ appRan
        /\ appSucceeded
        /\ TRANSFER_SUCCEEDS

=============================================================================
