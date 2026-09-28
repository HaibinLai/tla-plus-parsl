--------------------------- MODULE ParslEndToEnd ---------------------------
EXTENDS Naturals, FiniteSets, Sequences

(***************************************************************************
 * A compact end-to-end Parsl protocol.
 *
 * This model intentionally connects the boundaries that are separate in the
 * larger focused models: dependency release, physical attempts, task/result
 * wire messages, worker execution, retry, timeout, and late results.  The
 * current branch deliberately accepts a late result for an old attempt; the
 * fixed branch rejects it as stale.
 ***************************************************************************)

CONSTANTS TASKS, DEPS, MAX_RETRIES, USE_FIXED

TaskStates == {"pending", "ready", "queued", "running", "retry_wait", "succeeded", "failed"}
FutureStates == {"unresolved", "resolved", "rejected"}
AttemptStates == {"absent", "submitted", "serialized", "sent", "running",
                  "succeeded", "failed", "timed_out", "stale"}
WireStates == {"none", "queued", "sent", "received", "consumed"}
AttemptIds == TASKS \X (0..MAX_RETRIES)
NoAttempt == <<"none", 0>>

DepsOf(t) == {d \in TASKS : d \o "->" \o t \in DEPS}
Id(t, k) == <<t, k>>

VARIABLES taskState, futureState, currentAttempt, attemptState,
          taskWire, resultWire, attemptResult, workerState, workerAttempt

vars == <<taskState, futureState, currentAttempt, attemptState,
          taskWire, resultWire, attemptResult, workerState, workerAttempt>>

Init ==
    /\ TASKS # {}
    /\ DEPS \subseteq {a \o "->" \o b : a \in TASKS, b \in TASKS}
    /\ MAX_RETRIES >= 0
    /\ taskState = [t \in TASKS |-> IF t = CHOOSE x \in TASKS : TRUE THEN "ready" ELSE "pending"]
    /\ futureState = [t \in TASKS |-> "unresolved"]
    /\ currentAttempt = [t \in TASKS |-> 0]
    /\ attemptState = [x \in AttemptIds |-> "absent"]
    /\ taskWire = [x \in AttemptIds |-> "none"]
    /\ resultWire = [x \in AttemptIds |-> "none"]
    /\ attemptResult = [x \in AttemptIds |-> "none"]
    /\ workerState = "idle"
    /\ workerAttempt = NoAttempt

Submit(t) ==
    /\ taskState[t] = "ready"
    /\ DepsOf(t) \subseteq {d \in TASKS : taskState[d] = "succeeded"}
    /\ LET k == currentAttempt[t]
           x == Id(t, k)
       IN
           /\ currentAttempt' = [currentAttempt EXCEPT ![t] = k]
           /\ taskState' = [taskState EXCEPT ![t] = "queued"]
           /\ attemptState' = [attemptState EXCEPT ![x] = "submitted"]
           /\ UNCHANGED <<futureState, taskWire, resultWire, attemptResult,
                          workerState, workerAttempt>>

Serialize(t, k) ==
    /\ Id(t, k) \in AttemptIds
    /\ attemptState[Id(t, k)] = "submitted"
    /\ taskWire' = [taskWire EXCEPT ![Id(t, k)] = "queued"]
    /\ attemptState' = [attemptState EXCEPT ![Id(t, k)] = "serialized"]
    /\ UNCHANGED <<taskState, futureState, currentAttempt, resultWire,
                   attemptResult, workerState, workerAttempt>>

SendTask(t, k) ==
    /\ taskWire[Id(t, k)] = "queued"
    /\ taskWire' = [taskWire EXCEPT ![Id(t, k)] = "sent"]
    /\ attemptState' = [attemptState EXCEPT ![Id(t, k)] = "sent"]
    /\ UNCHANGED <<taskState, futureState, currentAttempt, resultWire,
                   attemptResult, workerState, workerAttempt>>

StartWorker(t, k) ==
    /\ taskWire[Id(t, k)] = "sent"
    /\ workerState = "idle"
    /\ taskWire' = [taskWire EXCEPT ![Id(t, k)] = "received"]
    /\ attemptState' = [attemptState EXCEPT ![Id(t, k)] = "running"]
    /\ taskState' = [taskState EXCEPT ![t] = "running"]
    /\ workerState' = "busy"
    /\ workerAttempt' = Id(t, k)
    /\ UNCHANGED <<futureState, currentAttempt, resultWire, attemptResult>>

Complete(t, k) ==
    /\ attemptState[Id(t, k)] = "running"
    /\ workerAttempt = Id(t, k)
    /\ resultWire' = [resultWire EXCEPT ![Id(t, k)] = "queued"]
    /\ attemptResult' = [attemptResult EXCEPT ![Id(t, k)] = "ok"]
    /\ attemptState' = [attemptState EXCEPT ![Id(t, k)] = "succeeded"]
    /\ workerState' = "idle"
    /\ workerAttempt' = NoAttempt
    /\ UNCHANGED <<taskState, futureState, currentAttempt, taskWire>>

LateResult(t, k) ==
    /\ attemptState[Id(t, k)] \in {"failed", "timed_out"}
    /\ resultWire[Id(t, k)] = "none"
    /\ resultWire' = [resultWire EXCEPT ![Id(t, k)] = "queued"]
    /\ attemptResult' = [attemptResult EXCEPT ![Id(t, k)] = "ok"]
    /\ UNCHANGED <<taskState, futureState, currentAttempt, attemptState,
                   taskWire, workerState, workerAttempt>>

DeliverResult(t, k) ==
    /\ resultWire[Id(t, k)] = "queued"
    /\ resultWire' = [resultWire EXCEPT ![Id(t, k)] = "consumed"]
    /\ IF k = currentAttempt[t]
          THEN /\ taskState' = [taskState EXCEPT ![t] = "succeeded"]
               /\ futureState' = [futureState EXCEPT ![t] = "resolved"]
          ELSE IF USE_FIXED
               THEN /\ taskState' = taskState
                    /\ futureState' = futureState
                    /\ attemptState' = [attemptState EXCEPT ![Id(t, k)] = "stale"]
               ELSE /\ taskState' = [taskState EXCEPT ![t] = "succeeded"]
                    /\ futureState' = [futureState EXCEPT ![t] = "resolved"]
                    /\ attemptState' = attemptState
    /\ IF k = currentAttempt[t] THEN attemptState' = attemptState ELSE TRUE
    /\ UNCHANGED <<currentAttempt, taskWire, attemptResult, workerState, workerAttempt>>

FailAttempt(t, k) ==
    /\ attemptState[Id(t, k)] = "running"
    /\ workerAttempt = Id(t, k)
    /\ attemptState' = [attemptState EXCEPT ![Id(t, k)] = "failed"]
    /\ taskState' = [taskState EXCEPT ![t] = IF k < MAX_RETRIES THEN "retry_wait" ELSE "failed"]
    /\ futureState' = [futureState EXCEPT ![t] = IF k < MAX_RETRIES THEN "unresolved" ELSE "rejected"]
    /\ workerState' = "idle"
    /\ workerAttempt' = NoAttempt
    /\ UNCHANGED <<currentAttempt, taskWire, resultWire, attemptResult>>

TimeoutAttempt(t, k) ==
    /\ attemptState[Id(t, k)] = "running"
    /\ workerAttempt = Id(t, k)
    /\ attemptState' = [attemptState EXCEPT ![Id(t, k)] = "timed_out"]
    /\ taskState' = [taskState EXCEPT ![t] = IF k < MAX_RETRIES THEN "retry_wait" ELSE "failed"]
    /\ futureState' = [futureState EXCEPT ![t] = IF k < MAX_RETRIES THEN "unresolved" ELSE "rejected"]
    /\ workerState' = "idle"
    /\ workerAttempt' = NoAttempt
    /\ UNCHANGED <<currentAttempt, taskWire, resultWire, attemptResult>>

Retry(t) ==
    /\ taskState[t] = "retry_wait"
    /\ currentAttempt[t] < MAX_RETRIES
    /\ taskState' = [taskState EXCEPT ![t] = "ready"]
    /\ currentAttempt' = [currentAttempt EXCEPT ![t] = @ + 1]
    /\ UNCHANGED <<futureState, attemptState, taskWire,
                   resultWire, attemptResult, workerState, workerAttempt>>

Next ==
    \/ \E t \in TASKS : Submit(t)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : Serialize(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : SendTask(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : StartWorker(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : Complete(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : LateResult(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : DeliverResult(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : FailAttempt(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : TimeoutAttempt(t, k)
    \/ \E t \in TASKS : Retry(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in [TASKS -> TaskStates]
    /\ futureState \in [TASKS -> FutureStates]
    /\ currentAttempt \in [TASKS -> 0..MAX_RETRIES]
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ taskWire \in [AttemptIds -> WireStates]
    /\ resultWire \in [AttemptIds -> WireStates]
    /\ attemptResult \in [AttemptIds -> {"none", "ok", "error"}]
    /\ workerState \in {"idle", "busy"}
    /\ workerAttempt \in AttemptIds \cup {NoAttempt}

DependencySafety ==
    \A t \in TASKS : taskState[t] \in {"queued", "running", "succeeded"}
        => DepsOf(t) \subseteq {d \in TASKS : taskState[d] = "succeeded"}

RetryBound ==
    \A t \in TASKS : currentAttempt[t] <= MAX_RETRIES

ResultConsistency ==
    \A t \in TASKS : futureState[t] = "resolved" => taskState[t] = "succeeded"

StaleResultSafety ==
    \A t \in TASKS, k \in 0..MAX_RETRIES :
        resultWire[Id(t, k)] = "consumed" /\ k # currentAttempt[t]
        => attemptState[Id(t, k)] = "stale"

TerminalStability ==
    \A t \in TASKS : futureState[t] = "rejected" => taskState[t] = "failed"

=============================================================================
