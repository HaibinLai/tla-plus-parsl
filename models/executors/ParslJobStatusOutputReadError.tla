--------------------------- MODULE ParslJobStatusOutputReadError ---------------------------
EXTENDS Naturals

(***************************************************************************
 * JobStatus.stdout catches every read exception, but stdout_summary catches
 * only FileNotFoundError.  A permission/I/O error is therefore represented
 * as no output by one property and escapes from the other.  USE_FIXED models
 * making summary reads use the same defensive policy.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES readState, summaryState
vars == <<readState, summaryState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ readState = "unread"
    /\ summaryState = "unread"

ReadOutput ==
    /\ readState = "unread"
    /\ readState' = "none"
    /\ UNCHANGED summaryState

ReadSummary ==
    /\ summaryState = "unread"
    /\ summaryState' = IF USE_FIXED THEN "none" ELSE "error"
    /\ UNCHANGED readState

Done ==
    /\ readState = "none" /\ summaryState \in {"none", "error"}
    /\ UNCHANGED vars

Next == ReadOutput \/ ReadSummary \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ readState \in {"unread", "none"}
    /\ summaryState \in {"unread", "none", "error"}

ReadErrorConsistency == summaryState = "error" => USE_FIXED

=============================================================================
