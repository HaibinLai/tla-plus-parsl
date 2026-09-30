--------------------------- MODULE ParslMPITaskContextShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MPITaskScheduler.put_task reads task_package["context"] as a mapping.
 * A malformed but pickleable context currently reaches .get and raises a
 * raw AttributeError; the fixed branch rejects it before MPI admission.
 ***************************************************************************)

CONSTANTS CONTEXT_MAPPING, USE_FIXED
VARIABLES state, admitted
vars == <<state, admitted>>

Init ==
    /\ CONTEXT_MAPPING \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ admitted = FALSE

ReadContext ==
    /\ state = "ready"
    /\ IF CONTEXT_MAPPING
          THEN /\ state' = "queued"
               /\ admitted' = TRUE
          ELSE IF USE_FIXED
               THEN /\ state' = "rejected"
                    /\ admitted' = FALSE
               ELSE /\ state' = "crashed"
                    /\ admitted' = FALSE

Next ==
    \/ ReadContext
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ CONTEXT_MAPPING \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"ready", "queued", "rejected", "crashed"}
    /\ admitted \in BOOLEAN

MalformedContextSafety == state = "crashed" => FALSE
AdmissionSafety == admitted => state = "queued"

=============================================================================
