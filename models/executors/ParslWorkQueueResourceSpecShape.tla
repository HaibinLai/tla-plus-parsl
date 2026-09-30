--------------------------- MODULE ParslWorkQueueResourceSpecShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * WorkQueueExecutor.submit creates a per-task directory and Future before a
 * late assertion checks that resource_specification is a dict.  USE_FIXED
 * validates the request before publishing any task-side filesystem state.
 ***************************************************************************)

CONSTANT USE_FIXED, SPEC_IS_MAPPING

VARIABLES taskDirCreated, futureRegistered, outcome
vars == <<taskDirCreated, futureRegistered, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ SPEC_IS_MAPPING \in BOOLEAN
    /\ taskDirCreated = FALSE
    /\ futureRegistered = FALSE
    /\ outcome = "pending"

Submit ==
    /\ IF USE_FIXED /\ ~SPEC_IS_MAPPING
          THEN /\ taskDirCreated' = FALSE
               /\ futureRegistered' = FALSE
               /\ outcome' = "rejected"
          ELSE IF ~SPEC_IS_MAPPING
               THEN /\ taskDirCreated' = TRUE
                    /\ futureRegistered' = TRUE
                    /\ outcome' = "assertion-error"
               ELSE /\ taskDirCreated' = TRUE
                    /\ futureRegistered' = TRUE
                    /\ outcome' = "queued"

Next == Submit \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ SPEC_IS_MAPPING \in BOOLEAN
    /\ taskDirCreated \in BOOLEAN
    /\ futureRegistered \in BOOLEAN
    /\ outcome \in {"pending", "rejected", "assertion-error", "queued"}

InvalidInputSafety ==
    SPEC_IS_MAPPING \/ (outcome = "pending" \/ outcome = "rejected")

=============================================================================
