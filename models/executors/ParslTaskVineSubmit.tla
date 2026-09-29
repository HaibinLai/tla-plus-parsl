--------------------------- MODULE ParslTaskVineSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVineExecutor.submit registers a Future before serializing the function
 * and before checking that the submit process is alive.  A failure in either
 * step can leave an orphaned task-map entry.  USE_FIXED models removing that
 * entry before returning the submission error.
 *************************************************************************** *)

CONSTANTS PROCESS_ALIVE, SERIALIZE_OK, USE_FIXED

States == {"new", "registered", "serialized", "queued", "failed"}

VARIABLES state, taskMapped, outstanding
vars == <<state, taskMapped, outstanding>>

Init ==
    /\ PROCESS_ALIVE \in BOOLEAN
    /\ SERIALIZE_OK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ taskMapped = FALSE
    /\ outstanding = 0

Register ==
    /\ state = "new"
    /\ state' = "registered"
    /\ taskMapped' = TRUE
    /\ UNCHANGED outstanding

Serialize ==
    /\ state = "registered"
    /\ IF SERIALIZE_OK
          THEN /\ state' = "serialized"
               /\ UNCHANGED taskMapped
          ELSE /\ state' = "failed"
               /\ taskMapped' = IF USE_FIXED THEN FALSE ELSE taskMapped
    /\ UNCHANGED outstanding

CheckProcess ==
    /\ state = "serialized"
    /\ IF PROCESS_ALIVE
          THEN /\ state' = "queued"
               /\ outstanding' = 1
               /\ UNCHANGED taskMapped
          ELSE /\ state' = "failed"
               /\ taskMapped' = IF USE_FIXED THEN FALSE ELSE taskMapped
               /\ UNCHANGED outstanding

Done ==
    /\ state \in {"queued", "failed"}
    /\ UNCHANGED vars

Next == Register \/ Serialize \/ CheckProcess \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ taskMapped \in BOOLEAN
    /\ outstanding \in 0..1

SubmitFailureSafety ==
    state = "failed" => ~taskMapped /\ outstanding = 0

QueueSafety ==
    state = "queued" => taskMapped /\ outstanding = 1

=============================================================================
