--------------------------- MODULE ParslGlobusFailureEvent ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus.transfer_file waits for a terminal task and then reads the first
 * failure event.  A failed transfer can legally have no event records.  The
 * current path exposes an indexing error; USE_FIXED converts that response
 * shape into a normal transfer failure.
 ***************************************************************************)

CONSTANT USE_FIXED, EVENT_COUNT

VARIABLES taskState, eventCount, outcome
vars == <<taskState, eventCount, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ EVENT_COUNT \in Nat
    /\ eventCount = EVENT_COUNT
    /\ taskState = "FAILED"
    /\ outcome = ""

ReportFailure ==
    /\ taskState = "FAILED"
    /\ outcome' = IF USE_FIXED THEN "transfer-failed"
                  ELSE IF eventCount = 0 THEN "raw-index-error" ELSE "transfer-failed"
    /\ UNCHANGED <<taskState, eventCount>>

Next == ReportFailure \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ EVENT_COUNT \in Nat
    /\ taskState = "FAILED"
    /\ eventCount = EVENT_COUNT
    /\ outcome \in {"", "transfer-failed", "raw-index-error"}

FailureOutcomeSafety ==
    outcome = "" \/ outcome = "transfer-failed"

=============================================================================
