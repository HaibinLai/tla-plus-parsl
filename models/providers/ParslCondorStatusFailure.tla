--------------------------- MODULE ParslCondorStatusFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CondorProvider._status currently ignores execute_wait's return code.
 * A failed condor_q command is therefore still parsed: a valid stale line
 * can overwrite a RUNNING resource, while a truncated line can crash while
 * indexing parts[1]. The FIXED branch returns before parsing failed output.
 *************************************************************************** *)

CONSTANTS COMMAND_FAILED, MALFORMED_LINE, USE_FIXED
VARIABLES state, jobStatus, failureIgnored
vars == <<state, jobStatus, failureIgnored>>

Init ==
    /\ COMMAND_FAILED \in BOOLEAN
    /\ MALFORMED_LINE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "idle"
    /\ jobStatus = "running"
    /\ failureIgnored = FALSE

BeginPoll ==
    /\ state = "idle"
    /\ state' = "polling"
    /\ UNCHANGED <<jobStatus, failureIgnored>>

FailedCommandIgnored ==
    /\ state = "polling"
    /\ COMMAND_FAILED
    /\ USE_FIXED
    /\ state' = "preserved"
    /\ failureIgnored' = TRUE
    /\ UNCHANGED jobStatus

FailedCommandCrashes ==
    /\ state = "polling"
    /\ COMMAND_FAILED
    /\ ~USE_FIXED
    /\ MALFORMED_LINE
    /\ state' = "crashed"
    /\ UNCHANGED <<jobStatus, failureIgnored>>

FailedCommandUpdatesStale ==
    /\ state = "polling"
    /\ COMMAND_FAILED
    /\ ~USE_FIXED
    /\ ~MALFORMED_LINE
    /\ state' = "updated"
    /\ jobStatus' = "completed"
    /\ UNCHANGED failureIgnored

SuccessfulCommandUpdates ==
    /\ state = "polling"
    /\ ~COMMAND_FAILED
    /\ state' = "updated"
    /\ jobStatus' = "completed"
    /\ UNCHANGED failureIgnored

Next ==
    \/ BeginPoll
    \/ FailedCommandIgnored
    \/ FailedCommandCrashes
    \/ FailedCommandUpdatesStale
    \/ SuccessfulCommandUpdates
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"idle", "polling", "preserved", "updated", "crashed"}
    /\ jobStatus \in {"running", "completed"}
    /\ failureIgnored \in BOOLEAN

FailurePreservation ==
    COMMAND_FAILED => (state # "updated" /\ jobStatus = "running")

NoParserCrash == state # "crashed"

=============================================================================
