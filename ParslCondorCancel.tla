--------------------------- MODULE ParslCondorCancel ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Bounded model of CondorProvider.cancel.
 *
 * Condor cancellation is chunked, but unlike LSF/Grid Engine it guards each
 * successful job id with `jid in resources`.  An unknown id therefore still
 * receives a successful return value from the scheduler call without causing
 * a local dictionary crash.
 ***************************************************************************)

CONSTANTS API_SUCCESS, JOB_IDS, KNOWN_IDS, CHUNK_SIZE

States == {"running", "cancelled", "absent"}

VARIABLES resourceState, cancelResults, chunksProcessed
vars == <<resourceState, cancelResults, chunksProcessed>>

Init ==
    /\ API_SUCCESS \in BOOLEAN
    /\ JOB_IDS # {}
    /\ KNOWN_IDS \subseteq JOB_IDS
    /\ CHUNK_SIZE \in Nat \ {0}
    /\ resourceState = [j \in JOB_IDS |-> IF j \in KNOWN_IDS THEN "running" ELSE "absent"]
    /\ cancelResults = [j \in JOB_IDS |-> "none"]
    /\ chunksProcessed = 0

CancelChunk ==
    /\ chunksProcessed = 0
    /\ chunksProcessed' = 1
    /\ IF API_SUCCESS THEN
           /\ resourceState' = [j \in JOB_IDS |->
                  IF j \in KNOWN_IDS THEN "cancelled" ELSE resourceState[j]]
           /\ cancelResults' = [j \in JOB_IDS |-> "success"]
       ELSE
           /\ UNCHANGED <<resourceState, cancelResults>>

Next ==
    \/ CancelChunk
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resourceState \in [JOB_IDS -> States]
    /\ cancelResults \in [JOB_IDS -> {"none", "success", "failure"}]
    /\ chunksProcessed \in Nat

UnknownJobSafety ==
    \A j \in JOB_IDS :
        j \notin KNOWN_IDS => resourceState[j] = "absent"

SuccessfulCancellationSafety ==
    (API_SUCCESS /\ chunksProcessed = 1) =>
        /\ \A j \in KNOWN_IDS : resourceState[j] = "cancelled"
        /\ \A j \in JOB_IDS : cancelResults[j] = "success"

=============================================================================
