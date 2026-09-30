--------------------------- MODULE ParslPbsproStatusShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * PBSProProvider._status assumes every JSON Jobs value is a mapping and
 * calls .get("job_state").  A malformed but valid JSON response can contain
 * a list/scalar instead.  USE_FIXED isolates that record and preserves the
 * polling pass with an UNKNOWN observation.
 ***************************************************************************)

CONSTANT USE_FIXED, JOB_RECORD_VALID

VARIABLES pollAlive, status
vars == <<pollAlive, status>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ JOB_RECORD_VALID \in BOOLEAN
    /\ pollAlive = TRUE
    /\ status = "running"

Poll ==
    /\ IF JOB_RECORD_VALID \/ USE_FIXED
          THEN /\ pollAlive' = TRUE
               /\ status' = IF JOB_RECORD_VALID THEN "completed" ELSE "unknown"
          ELSE /\ pollAlive' = FALSE
               /\ UNCHANGED status

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ JOB_RECORD_VALID \in BOOLEAN
    /\ pollAlive \in BOOLEAN
    /\ status \in {"running", "completed", "unknown"}

MalformedRecordSafety ==
    pollAlive

=============================================================================
