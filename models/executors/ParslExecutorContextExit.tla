--------------------------- MODULE ParslExecutorContextExit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ParslExecutor context-manager exception preservation.
 *
 * ParslExecutor.__exit__ calls shutdown() and then returns False.  If the
 * context body already raised and shutdown raises too, the cleanup exception
 * replaces the original body exception.  USE_FIXED models preserving the
 * primary body failure while still propagating a shutdown failure when there
 * was no earlier exception.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES body, shutdown, observed
vars == <<body, shutdown, observed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ body = "body-error"
    /\ shutdown = "shutdown-error"
    /\ observed = "none"

Exit ==
    /\ observed = "none"
    /\ observed' = IF USE_FIXED THEN body ELSE shutdown
    /\ UNCHANGED <<body, shutdown>>

Next == Exit \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ body = "body-error"
    /\ shutdown = "shutdown-error"
    /\ observed \in {"none", "body-error", "shutdown-error"}

PrimaryExceptionPreserved == observed # "shutdown-error"

================================================================================
