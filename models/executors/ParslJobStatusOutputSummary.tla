--------------------------- MODULE ParslJobStatusOutputSummary ---------------------------
EXTENDS Naturals

(***************************************************************************
 * JobStatus.stdout_summary/stderr_summary from parsl/jobs/states.py.
 *
 * A missing output file is reported as no output.  Files at or below the
 * truncation threshold are returned in full; larger files are represented by
 * their head and tail with an ellipsis marker.  This model abstracts bytes to
 * the resulting output classification while retaining the threshold boundary.
 ***************************************************************************)

CONSTANTS FILE_PRESENT, HAS_PATH, FILE_SIZE
THRESHOLD == 2048

VARIABLES state, result
vars == <<state, result>>

Init ==
    /\ FILE_PRESENT \in BOOLEAN
    /\ HAS_PATH \in BOOLEAN
    /\ FILE_SIZE \in Nat
    /\ state = "unread"
    /\ result = "none"

ReadSummary ==
    /\ state = "unread"
    /\ state' = "read"
    /\ result' =
        IF ~HAS_PATH \/ ~FILE_PRESENT THEN "none"
        ELSE IF FILE_SIZE <= THRESHOLD THEN "full"
        ELSE "head-tail"

Next ==
    \/ ReadSummary
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"unread", "read"}
    /\ result \in {"none", "full", "head-tail"}

SummarySafety ==
    state = "read" =>
        result = "none" <=> (~HAS_PATH \/ ~FILE_PRESENT)

ThresholdSafety ==
    state = "read" /\ HAS_PATH /\ FILE_PRESENT =>
        (FILE_SIZE <= THRESHOLD <=> result = "full")

=============================================================================
