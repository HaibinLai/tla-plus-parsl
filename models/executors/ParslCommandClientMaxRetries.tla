--------------------------- MODULE ParslCommandClientMaxRetries ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CommandClient.run exposes max_retries, but the current implementation
 * never reads it: send_pyobj is attempted once and a send exception escapes.
 * USE_FIXED is an executable candidate contract in which a transient send
 * failure consumes one retry and the same request can complete.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES phase, attempts, maxRetries, result
vars == <<phase, attempts, maxRetries, result>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ attempts = 0
    /\ maxRetries = 2
    /\ result = "none"

SendFails ==
    /\ phase = "ready"
    /\ attempts' = attempts + 1
    /\ IF USE_FIXED /\ maxRetries > 0
          THEN phase' = "ready" /\ result' = "none" /\ maxRetries' = maxRetries - 1
          ELSE phase' = "failed" /\ result' = "send-error" /\ maxRetries' = maxRetries
SendSucceeds ==
    /\ phase = "ready"
    /\ phase' = "done"
    /\ attempts' = attempts + 1
    /\ result' = "reply"
    /\ UNCHANGED maxRetries

Done ==
    /\ phase \in {"done", "failed"}
    /\ UNCHANGED vars

Next == SendFails \/ SendSucceeds \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"ready", "done", "failed"}
    /\ attempts \in Nat
    /\ maxRetries \in Nat
    /\ result \in {"none", "reply", "send-error"}

RetryBudgetHonored ==
    result = "send-error" => maxRetries = 0

=============================================================================
