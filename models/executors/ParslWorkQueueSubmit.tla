--------------------------- MODULE ParslWorkQueueSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of WorkQueueExecutor.submit around submit-process failure.
 *
 * The current source inserts the executor Future into `_tasks` before checking
 * serialization and submit-process liveness.  Either failure can therefore
 * leave an orphaned entry.  ROLLBACK models the candidate fix which removes
 * that orphaned entry before returning failure.
 ***************************************************************************)

CONSTANTS PROCESS_ALIVE, SERIALIZE_OK, ROLLBACK

States == {"new", "registered", "serialized", "queued", "failed", "rejected"}

VARIABLES state, taskMapped
vars == <<state, taskMapped>>

Init ==
    /\ PROCESS_ALIVE \in BOOLEAN
    /\ SERIALIZE_OK \in BOOLEAN
    /\ ROLLBACK \in BOOLEAN
    /\ state = "new"
    /\ taskMapped = FALSE

Validate ==
    /\ state = "new"
    /\ state' = "registered"
    /\ taskMapped' = TRUE

Serialize ==
    /\ state = "registered"
    /\ IF SERIALIZE_OK THEN
           /\ state' = "serialized"
           /\ UNCHANGED taskMapped
       ELSE
           /\ state' = "failed"
           /\ taskMapped' = IF ROLLBACK THEN FALSE ELSE taskMapped

CheckSubmitProcess ==
    /\ state = "serialized"
    /\ IF PROCESS_ALIVE THEN
           /\ state' = "queued"
           /\ UNCHANGED taskMapped
       ELSE
           /\ state' = "failed"
           /\ taskMapped' = IF ROLLBACK THEN FALSE ELSE taskMapped

Next ==
    \/ Validate
    \/ Serialize
    \/ CheckSubmitProcess
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ taskMapped \in BOOLEAN

SubmitFailureSafety ==
    state = "failed" => ~taskMapped

QueueSafety ==
    state = "queued" => taskMapped

=============================================================================
