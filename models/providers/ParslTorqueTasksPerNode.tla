--------------------------- MODULE ParslTorqueTasksPerNode ---------------------------
EXTENDS Integers

(***************************************************************************
 * TorqueProvider.submit tasks_per_node admission.
 *
 * The provider documentation says values below one are illegal, but the
 * current submit path forwards them to the launcher and template.  USE_FIXED
 * models rejecting non-positive values before script construction.
 *************************************************************************** *)

CONSTANTS TASKS_KIND, USE_FIXED
Kinds == {"negative", "zero", "positive"}
States == {"unvalidated", "launched", "rejected"}

VARIABLES state
vars == <<state>>

Init ==
    /\ TASKS_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unvalidated"

Submit ==
    /\ state = "unvalidated"
    /\ state' = IF (TASKS_KIND = "negative" \/ TASKS_KIND = "zero") /\ USE_FIXED
                   THEN "rejected" ELSE "launched"

Next ==
    \/ Submit
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ TASKS_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States

TaskAdmissionSafety ==
    state = "launched" => TASKS_KIND = "positive"

=============================================================================
