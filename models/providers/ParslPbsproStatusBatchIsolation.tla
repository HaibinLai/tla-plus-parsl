--------------------------- MODULE ParslPbsproStatusBatchIsolation ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * PBS Pro status polling with one malformed record and one valid record.
 *
 * PBSProProvider._status iterates over every decoded Jobs entry.  The current
 * implementation calls .get("job_state") before checking that each record is
 * a mapping, so one malformed entry aborts the whole polling pass and hides
 * independent valid observations.  The fixed branch isolates the malformed
 * entry and still records the valid job.
 ***************************************************************************)

CONSTANT USE_FIXED

JOBS == {"bad", "good"}

VARIABLES pollAlive, processed, status
vars == <<pollAlive, processed, status>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollAlive = TRUE
    /\ processed = {}
    /\ status = [j \in JOBS |-> "running"]

PollBatch ==
    /\ pollAlive
    /\ IF USE_FIXED
          THEN /\ pollAlive' = TRUE
               /\ processed' = JOBS
               /\ status' = [status EXCEPT !["bad"] = "unknown",
                                           !["good"] = "running"]
          ELSE /\ pollAlive' = FALSE
               /\ processed' = {"bad"}
               /\ UNCHANGED status

Next == PollBatch \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollAlive \in BOOLEAN
    /\ processed \subseteq JOBS
    /\ status \in [JOBS -> {"running", "unknown", "completed"}]

BatchIsolationSafety ==
    processed # {} => processed = JOBS

ValidRecordPreserved ==
    processed = JOBS => status["good"] = "running"

=============================================================================
