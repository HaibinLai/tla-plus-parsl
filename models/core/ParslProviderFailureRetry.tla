--------------------------- MODULE ParslProviderFailureRetry ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Provider/executor failure joined with retry and late-result handling.
 *
 * A provider block can disappear while an attempt is running.  The executor
 * loses that physical attempt and may launch a retry after the provider is
 * recovered.  The old worker can still send a result after the retry starts.
 * The current branch accepts that stale result; the fixed branch only lets
 * the current completed attempt resolve the logical Future.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, USE_FIXED

AttemptIds == 0..MAX_RETRIES
ProviderStates == {"down", "running", "failed"}
ExecutorStates == {"down", "up", "failed"}
AttemptStates == {"absent", "running", "lost", "completed"}
TaskStates == {"pending", "running", "retry_wait", "succeeded", "failed"}
ResultStates == {"none", "queued", "delivered", "stale"}

VARIABLES provider, executor, task, attemptState, currentAttempt,
          resultState, future
vars == <<provider, executor, task, attemptState, currentAttempt,
           resultState, future>>

Init ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ provider = "down"
    /\ executor = "down"
    /\ task = "pending"
    /\ attemptState = [k \in AttemptIds |-> "absent"]
    /\ currentAttempt = 0
    /\ resultState = [k \in AttemptIds |-> "none"]
    /\ future = "unresolved"

StartProvider ==
    /\ provider = "down"
    /\ provider' = "running"
    /\ executor' = "up"
    /\ UNCHANGED <<task, attemptState, currentAttempt, resultState, future>>

SubmitAttempt ==
    /\ provider = "running"
    /\ executor = "up"
    /\ task \in {"pending", "retry_wait"}
    /\ attemptState[currentAttempt] = "absent"
    /\ task' = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "running"]
    /\ UNCHANGED <<provider, executor, currentAttempt, resultState, future>>

ProviderFails ==
    /\ provider = "running"
    /\ provider' = "failed"
    /\ executor' = "failed"
    /\ task' = IF task = "running" THEN "retry_wait" ELSE task
    /\ attemptState' = [attemptState EXCEPT
          ![currentAttempt] = IF @ = "running" THEN "lost" ELSE @]
    /\ UNCHANGED <<currentAttempt, resultState, future>>

RecoverProvider ==
    /\ provider = "failed"
    /\ provider' = "running"
    /\ executor' = "up"
    /\ UNCHANGED <<task, attemptState, currentAttempt, resultState, future>>

Retry ==
    /\ task = "retry_wait"
    /\ currentAttempt < MAX_RETRIES
    /\ currentAttempt' = currentAttempt + 1
    /\ task' = "pending"
    /\ UNCHANGED <<provider, executor, attemptState, resultState, future>>

CompleteCurrent ==
    /\ task = "running"
    /\ attemptState[currentAttempt] = "running"
    /\ attemptState' = [attemptState EXCEPT ![currentAttempt] = "completed"]
    /\ task' = "succeeded"
    /\ future' = "resolved"
    /\ UNCHANGED <<provider, executor, currentAttempt, resultState>>

QueueResult(k) ==
    /\ k \in AttemptIds
    /\ attemptState[k] \in {"lost", "completed"}
    /\ resultState[k] = "none"
    /\ resultState' = [resultState EXCEPT ![k] = "queued"]
    /\ UNCHANGED <<provider, executor, task, attemptState, currentAttempt, future>>

DeliverResult(k) ==
    /\ k \in AttemptIds
    /\ resultState[k] = "queued"
    /\ IF USE_FIXED
       THEN IF k = currentAttempt /\ attemptState[k] = "completed"
            THEN /\ resultState' = [resultState EXCEPT ![k] = "delivered"]
                 /\ future' = "resolved"
            ELSE /\ resultState' = [resultState EXCEPT ![k] = "stale"]
                 /\ UNCHANGED future
       ELSE /\ resultState' = [resultState EXCEPT ![k] = "delivered"]
            /\ future' = "resolved"
    /\ UNCHANGED <<provider, executor, task, attemptState, currentAttempt>>

RejectAfterRetry ==
    /\ task = "retry_wait"
    /\ currentAttempt = MAX_RETRIES
    /\ task' = "failed"
    /\ future' = "rejected"
    /\ UNCHANGED <<provider, executor, attemptState, currentAttempt, resultState>>

Next ==
    \/ StartProvider
    \/ SubmitAttempt
    \/ ProviderFails
    \/ RecoverProvider
    \/ Retry
    \/ CompleteCurrent
    \/ \E k \in AttemptIds : QueueResult(k) \/ DeliverResult(k)
    \/ RejectAfterRetry
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ provider \in ProviderStates
    /\ executor \in ExecutorStates
    /\ task \in TaskStates
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ currentAttempt \in AttemptIds
    /\ resultState \in [AttemptIds -> ResultStates]
    /\ future \in {"unresolved", "resolved", "rejected"}

ProviderExecutorSafety ==
    executor = "up" => provider = "running"

RetryBound ==
    currentAttempt <= MAX_RETRIES

FutureSafety ==
    future = "resolved" => task = "succeeded"

StaleResultSafety ==
    /\ \A k \in AttemptIds : resultState[k] = "stale" =>
          ~(k = currentAttempt /\ attemptState[k] = "completed")
    /\ future = "resolved" => attemptState[currentAttempt] = "completed"

TerminalSafety ==
    task = "succeeded" => future = "resolved"

=============================================================================
