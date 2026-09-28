--------------------------- MODULE ParslGoogleCloudSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GoogleCloudProvider.create_instance allocation bookkeeping.
 *
 * The current implementation increments num_instances before the first GCE
 * API call.  A failed image/API request therefore consumes an instance name
 * even though no cloud resource was created.  USE_FIXED models incrementing
 * only after successful creation.
 ***************************************************************************)

CONSTANT CREATE_SUCCEEDS, USE_FIXED

States == {"new", "created", "failed"}

VARIABLES state, numInstances
vars == <<state, numInstances>>

Init ==
    /\ CREATE_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ numInstances = 0

CreateInstance ==
    /\ state = "new"
    /\ IF CREATE_SUCCEEDS
          THEN /\ state' = "created"
               /\ numInstances' = numInstances + 1
          ELSE /\ state' = "failed"
               /\ numInstances' = IF USE_FIXED THEN numInstances ELSE numInstances + 1

Next ==
    \/ CreateInstance
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ numInstances \in Nat

FailedCreateBookkeeping ==
    state = "failed" => numInstances = 0

=============================================================================
