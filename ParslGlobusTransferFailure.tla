--------------------------- MODULE ParslGlobusTransferFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus.transfer_file terminal failure reporting.
 *
 * After task_wait returns, the current implementation treats every status
 * other than SUCCEEDED as a failed transfer and reads events.data[0] for the
 * error text. A valid terminal failure with an empty event list therefore
 * raises IndexError instead of returning a transfer exception. The FIXED
 * branch reports failure even when no diagnostic event is available.
 *************************************************************************** *)

CONSTANTS EVENTS_PRESENT, USE_FIXED
VARIABLES state, failureReported, eventRead
vars == <<state, failureReported, eventRead>>

Init ==
    /\ EVENTS_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "submitted"
    /\ failureReported = FALSE
    /\ eventRead = FALSE

WaitReturnsTerminalFailure ==
    /\ state = "submitted"
    /\ state' = "failed-task"
    /\ UNCHANGED <<failureReported, eventRead>>

ReadFailureEvent ==
    /\ state = "failed-task"
    /\ IF USE_FIXED
          THEN /\ state' = "failed-reported"
               /\ failureReported' = TRUE
               /\ eventRead' = EVENTS_PRESENT
          ELSE IF EVENTS_PRESENT
               THEN /\ state' = "failed-reported"
                    /\ failureReported' = TRUE
                    /\ eventRead' = TRUE
               ELSE /\ state' = "crashed"
                    /\ UNCHANGED <<failureReported, eventRead>>

Next ==
    \/ WaitReturnsTerminalFailure
    \/ ReadFailureEvent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"submitted", "failed-task", "failed-reported", "crashed"}
    /\ failureReported \in BOOLEAN
    /\ eventRead \in BOOLEAN

FailureReportingSafety ==
    state = "failed-reported" => failureReported

NoDiagnosticCrash == state # "crashed"

=============================================================================
