--------------------------- MODULE ParslPluginRetryMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Dynamic deserializer failure across a physical retry.
 *
 * facade.deserialize caches a dynamically loaded plugin before invoking it.
 * If decode fails, a retry of the logical task can reuse that poisoned
 * instance.  This composition connects plugin-cache state to retry attempts,
 * Future terminal state, and monitoring status.  USE_FIXED evicts the failed
 * plugin so the second attempt can reload it.
 ***************************************************************************)

CONSTANT USE_FIXED

TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
MonitorStates == {"none", "failed", "succeeded"}

VARIABLES cachePresent, attempt, task, decodeAttempts, monitor
vars == <<cachePresent, attempt, task, decodeAttempts, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ cachePresent = FALSE
    /\ attempt = 0
    /\ task = "pending"
    /\ decodeAttempts = 0
    /\ monitor = "none"

SubmitAttempt ==
    /\ task = "pending"
    /\ task' = "running"
    /\ UNCHANGED <<cachePresent, attempt, decodeAttempts, monitor>>

FirstDecodeFails ==
    /\ task = "running"
    /\ attempt = 0
    /\ task' = "retry_wait"
    /\ cachePresent' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ decodeAttempts' = 1
    /\ monitor' = "failed"
    /\ UNCHANGED attempt

Retry ==
    /\ task = "retry_wait"
    /\ attempt' = 1
    /\ task' = "pending"
    /\ UNCHANGED <<cachePresent, decodeAttempts, monitor>>

SecondDecode ==
    /\ task = "running"
    /\ attempt = 1
    /\ decodeAttempts = 1
    /\ decodeAttempts' = 2
    /\ IF USE_FIXED /\ ~cachePresent
          THEN /\ task' = "succeeded"
               /\ cachePresent' = TRUE
               /\ monitor' = "succeeded"
          ELSE /\ task' = "failed"
               /\ UNCHANGED <<cachePresent, monitor>>
    /\ UNCHANGED attempt

Next ==
    \/ SubmitAttempt
    \/ FirstDecodeFails
    \/ Retry
    \/ SecondDecode
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ cachePresent \in BOOLEAN
    /\ attempt \in 0..1
    /\ task \in TaskStates
    /\ decodeAttempts \in 0..2
    /\ monitor \in MonitorStates

RetryRecoverySafety ==
    attempt = 1 /\ task = "failed" => USE_FIXED

TerminalMonitoringConsistency ==
    task = "succeeded" => monitor = "succeeded"

FailureEventVisible ==
    decodeAttempts >= 1 => monitor = "failed" \/ monitor = "succeeded"

=============================================================================
