--------------------------- MODULE ParslMonitoringWrapperCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Resource-monitor wrapper cleanup and primary application exception.
 *
 * monitor_wrapper sends a final WORKER_TASK_INFO message in a finally block.
 * If the wrapped user function already failed and that final send also raises,
 * the cleanup exception replaces the primary application exception.  USE_FIXED
 * models preserving the body failure while retaining cleanup diagnostics.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES body, finalSend, observed
vars == <<body, finalSend, observed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ body = "body-error"
    /\ finalSend = "monitor-error"
    /\ observed = "none"

Cleanup ==
    /\ observed = "none"
    /\ observed' = IF USE_FIXED THEN body ELSE finalSend
    /\ UNCHANGED <<body, finalSend>>

Next == Cleanup \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ body = "body-error"
    /\ finalSend = "monitor-error"
    /\ observed \in {"none", "body-error", "monitor-error"}

PrimaryExceptionPreserved == observed # "monitor-error"

================================================================================
