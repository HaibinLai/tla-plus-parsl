--------------------------- MODULE ParslRadicalPilotUnknownCallback ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Radical Pilot callback after local Future cleanup.
 *
 * task_state_cb indexes future_tasks[task.uid] before validating that the
 * callback still belongs to a live Parsl task.  USE_FIXED models treating an
 * unknown callback as stale and ignoring it.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES callback, state, liveTasks, processed
vars == <<callback, state, liveTasks, processed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ callback = "task-removed"
    /\ state = "received"
    /\ liveTasks = {}
    /\ processed = FALSE

HandleCallback ==
    /\ state = "received"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ processed' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ UNCHANGED <<callback, liveTasks>>

Next == HandleCallback \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ callback = "task-removed"
    /\ state \in {"received", "ignored", "crashed"}
    /\ liveTasks = {}
    /\ processed \in BOOLEAN

UnknownCallbackSafety == state # "crashed"
ProgressSafety == state = "ignored" => processed

=============================================================================
