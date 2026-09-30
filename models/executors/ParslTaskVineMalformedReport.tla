--------------------------- MODULE ParslTaskVineMalformedReport ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVineExecutor._collect_taskvine_results accesses executor_id before
 * validating a completion report.  A malformed report can terminate the
 * collector and prevent later valid reports from being processed.
 * USE_FIXED discards malformed reports and continues.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES phase, valid_future, outcome
vars == <<phase, valid_future, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "malformed_report"
    /\ valid_future = "pending"
    /\ outcome = "waiting"

HandleMalformed ==
    /\ phase = "malformed_report"
    /\ phase' = IF USE_FIXED THEN "valid_report" ELSE "stopped"
    /\ valid_future' = "pending"
    /\ outcome' = IF USE_FIXED THEN "continue" ELSE "collector_crash"

HandleValid ==
    /\ phase = "valid_report"
    /\ phase' = "complete"
    /\ valid_future' = "resolved"
    /\ outcome' = "complete"

Next == HandleMalformed \/ HandleValid \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"malformed_report", "valid_report", "stopped", "complete"}
    /\ valid_future \in {"pending", "resolved"}
    /\ outcome \in {"waiting", "continue", "collector_crash", "complete"}

MalformedReportSafety == phase = "stopped" => valid_future # "pending"
=============================================================================
