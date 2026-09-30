--------------------------- MODULE ParslHtexScaleInRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Two concurrent HTEX scale_in callers can select the same idle block before
 * either caller publishes cancellation progress.  The current branch sends
 * two remote cancellation requests for one job; USE_FIXED serializes
 * selection/cancellation or reserves the block before the second caller.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, selectedByFirst, selectedBySecond, cancelCalls
vars == <<phase, selectedByFirst, selectedBySecond, cancelCalls>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ selectedByFirst = FALSE
    /\ selectedBySecond = FALSE
    /\ cancelCalls = 0

FirstSelect ==
    /\ phase = "ready"
    /\ selectedByFirst = FALSE
    /\ selectedByFirst' = TRUE
    /\ phase' = "first-selected"
    /\ UNCHANGED <<selectedBySecond, cancelCalls>>

SecondSelect ==
    /\ phase = "first-selected"
    /\ selectedByFirst
    /\ selectedBySecond = FALSE
    /\ IF USE_FIXED
          THEN /\ selectedBySecond' = FALSE
               /\ phase' = "first-selected"
          ELSE /\ selectedBySecond' = TRUE
               /\ phase' = "both-selected"
    /\ UNCHANGED <<selectedByFirst, cancelCalls>>

FirstCancel ==
    /\ selectedByFirst
    /\ cancelCalls = 0
    /\ cancelCalls < 2
    /\ cancelCalls' = cancelCalls + 1
    /\ phase' = IF cancelCalls + 1 = 2 THEN "done" ELSE phase
    /\ UNCHANGED <<selectedByFirst, selectedBySecond>>

SecondCancel ==
    /\ selectedBySecond
    /\ cancelCalls < 2
    /\ cancelCalls' = cancelCalls + 1
    /\ phase' = "done"
    /\ UNCHANGED <<selectedByFirst, selectedBySecond>>

Next == FirstSelect \/ SecondSelect \/ FirstCancel \/ SecondCancel \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"ready", "first-selected", "both-selected", "done"}
    /\ selectedByFirst \in BOOLEAN
    /\ selectedBySecond \in BOOLEAN
    /\ cancelCalls \in 0..2

SingleCancellationSafety ==
    phase = "done" => cancelCalls <= 1

=============================================================================
