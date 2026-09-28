--------------------------- MODULE ParslAbstract ---------------------------
EXTENDS Naturals, Integers, FiniteSets, Sequences

(***************************************************************************
 * Small executable abstraction of a Parsl dataflow workflow.
 *
 * The important modeling choice is that a logical task and a physical
 * execution attempt are different objects.  Attempt (t,k) is retry k of task
 * t.  Consequently a late result from an old attempt can be explored without
 * changing the logical Future owned by t.
 ***************************************************************************)

CONSTANTS TASKS, EXECUTORS, WORKERS, DEPS, WORKER_EXECUTOR,
          MEMOIZED, CALLABLE_SERIALIZABLE, PAYLOAD_SERIALIZABLE,
          MAX_RETRIES, MAX_BLOCKS, ALLOW_FAILURES

TaskStates == {"pending", "staging", "ready", "queued", "running",
               "retry_wait", "succeeded", "memoized", "failed"}
FutureStates == {"unresolved", "resolved", "rejected"}
AttemptStates == {"absent", "submitted", "serialized", "sent", "received", "decoded",
                  "dispatched", "running", "result_serialized", "result_sent",
                  "result_received", "result_decoded",
                  "succeeded", "failed", "timed_out", "lost", "stale"}
WorkerStates == {"idle", "busy", "failed"}
ProviderStates == {"none", "requested", "active", "failed", "cancelled"}
DataStates == {"unavailable", "staging", "available"}
AttemptIds == TASKS \X (0..MAX_RETRIES)
NoAttempt == <<"none", -1>>
Deps(t) == {d \in TASKS : d \o "->" \o t \in DEPS}
WorkerExec(w) == CHOOSE e \in EXECUTORS : w \o ":" \o e \in WORKER_EXECUTOR
SerializableTask(t) == t \in CALLABLE_SERIALIZABLE /\ t \in PAYLOAD_SERIALIZABLE

VARIABLES taskState, futureState, retries, currentAttempt, selectedExecutor,
          dataState, attemptState, attemptExecutor, attemptWorker,
          workerState, workerAttempt, executorState,
          providerState, providerTarget, providerBlocks,
          completed, rejected, outputs

vars == <<taskState, futureState, retries, currentAttempt, selectedExecutor,
          dataState, attemptState, attemptExecutor, attemptWorker,
          workerState, workerAttempt, executorState,
          providerState, providerTarget, providerBlocks,
          completed, rejected, outputs>>

Init ==
    /\ TASKS # {} /\ EXECUTORS # {} /\ WORKERS # {}
    /\ CALLABLE_SERIALIZABLE \subseteq TASKS
    /\ PAYLOAD_SERIALIZABLE \subseteq TASKS
    /\ DEPS \subseteq {d \o "->" \o t : d \in TASKS, t \in TASKS}
    /\ WORKER_EXECUTOR \subseteq {w \o ":" \o e : w \in WORKERS, e \in EXECUTORS}
    /\ \A t \in TASKS : t \notin Deps(t)
    /\ \A w \in WORKERS : \E e \in EXECUTORS : w \o ":" \o e \in WORKER_EXECUTOR
    /\ taskState = [t \in TASKS |-> "pending"]
    /\ futureState = [t \in TASKS |-> "unresolved"]
    /\ retries = [t \in TASKS |-> 0]
    /\ currentAttempt = [t \in TASKS |-> -1]
    /\ selectedExecutor = [t \in TASKS |-> "none"]
    /\ dataState = [t \in TASKS |-> IF Deps(t) = {} THEN "available" ELSE "unavailable"]
    /\ attemptState = [a \in AttemptIds |-> "absent"]
    /\ attemptExecutor = [a \in AttemptIds |-> "none"]
    /\ attemptWorker = [a \in AttemptIds |-> "none"]
    /\ workerState = [w \in WORKERS |-> "idle"]
    /\ workerAttempt = [w \in WORKERS |-> NoAttempt]
    /\ executorState = [e \in EXECUTORS |-> "up"]
    /\ providerState = [e \in EXECUTORS |-> "none"]
    /\ providerTarget = [e \in EXECUTORS |-> 0]
    /\ providerBlocks = [e \in EXECUTORS |-> 0]
    /\ completed = {}
    /\ rejected = {}
    /\ outputs = [t \in TASKS |-> "absent"]

BeginStaging(t) ==
    /\ t \in TASKS /\ taskState[t] = "pending"
    /\ dataState[t] = "unavailable"
    /\ Deps(t) \subseteq {d \in TASKS : futureState[d] = "resolved"}
    /\ dataState' = [dataState EXCEPT ![t] = "staging"]
    /\ taskState' = [taskState EXCEPT ![t] = "staging"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

FinishStaging(t) ==
    /\ t \in TASKS /\ taskState[t] = "staging" /\ dataState[t] = "staging"
    /\ dataState' = [dataState EXCEPT ![t] = "available"]
    /\ taskState' = [taskState EXCEPT ![t] = "pending"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

DependencyCheck(t) ==
    /\ t \in TASKS /\ taskState[t] = "pending" /\ dataState[t] = "available"
    /\ Deps(t) \subseteq {d \in TASKS : futureState[d] = "resolved"}
    /\ taskState' = [taskState EXCEPT ![t] = "ready"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    dataState, attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

MemoizationHit(t) ==
    /\ t \in TASKS /\ t \in MEMOIZED /\ taskState[t] = "ready"
    /\ taskState' = [taskState EXCEPT ![t] = "memoized"]
    /\ futureState' = [futureState EXCEPT ![t] = "resolved"]
    /\ completed' = completed \cup {t}
    /\ outputs' = [outputs EXCEPT ![t] = "memoized-output"]
    /\ UNCHANGED <<retries, currentAttempt, selectedExecutor, dataState,
                    attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    rejected>>

Enqueue(t) ==
    /\ t \in TASKS /\ taskState[t] = "ready" /\ t \notin MEMOIZED
    /\ taskState' = [taskState EXCEPT ![t] = "queued"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    dataState, attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

SubmitAttempt(t, e) ==
    LET a == <<t, retries[t]>> IN
    /\ t \in TASKS /\ e \in EXECUTORS
    /\ taskState[t] = "queued" /\ executorState[e] = "up"
    /\ providerState[e] = "active"
    /\ retries[t] <= MAX_RETRIES /\ attemptState[a] = "absent"
    /\ taskState' = [taskState EXCEPT ![t] = "running"]
    /\ currentAttempt' = [currentAttempt EXCEPT ![t] = retries[t]]
    /\ selectedExecutor' = [selectedExecutor EXCEPT ![t] = e]
    /\ attemptState' = [attemptState EXCEPT ![a] = "submitted"]
    /\ attemptExecutor' = [attemptExecutor EXCEPT ![a] = e]
    /\ UNCHANGED <<futureState, retries, dataState, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

SerializeAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "submitted" /\ currentAttempt[t] = k
    /\ SerializableTask(t)
    /\ attemptState' = [attemptState EXCEPT ![a] = "serialized"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

SerializationFailure(t, k) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES
    /\ attemptState[a] = "submitted" /\ currentAttempt[t] = k
    /\ ~SerializableTask(t)
    /\ attemptState' = [attemptState EXCEPT ![a] = "failed"]
    /\ retries' = IF retries[t] < MAX_RETRIES
                    THEN [retries EXCEPT ![t] = @ + 1]
                    ELSE retries
    /\ taskState' = IF retries[t] < MAX_RETRIES
                    THEN [taskState EXCEPT ![t] = "retry_wait"]
                    ELSE [taskState EXCEPT ![t] = "failed"]
    /\ futureState' = IF retries[t] < MAX_RETRIES
                      THEN futureState
                      ELSE [futureState EXCEPT ![t] = "rejected"]
    /\ rejected' = IF retries[t] < MAX_RETRIES THEN rejected ELSE rejected \cup {t}
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, attemptWorker, workerState, workerAttempt,
                    executorState, providerState, providerTarget, providerBlocks,
                    completed, outputs>>

SendAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "serialized"
    /\ attemptState' = [attemptState EXCEPT ![a] = "sent"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

ReceiveAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "sent"
    /\ attemptState' = [attemptState EXCEPT ![a] = "received"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

DecodeAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "received"
    /\ attemptState' = [attemptState EXCEPT ![a] = "decoded"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

DispatchAttempt(t, k, w) ==
    LET a == <<t, k>> IN
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "decoded"
    /\ workerState[w] = "idle" /\ WorkerExec(w) = attemptExecutor[a]
    /\ providerState[attemptExecutor[a]] = "active"
    /\ attemptState' = [attemptState EXCEPT ![a] = "dispatched"]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = w]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = a]
    /\ workerState' = [workerState EXCEPT ![w] = "busy"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    executorState, providerState, providerTarget,
                    providerBlocks, completed, rejected, outputs>>

StartAttempt(t, k, w) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "dispatched" /\ attemptWorker[a] = w
    /\ workerState[w] = "busy"
    /\ attemptState' = [attemptState EXCEPT ![a] = "running"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

SerializeResult(t, k, w) ==
    LET a == <<t, k>> IN
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "running" /\ attemptWorker[a] = w
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_serialized"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

SendResult(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_serialized"
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_sent"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

ReceiveResult(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_sent"
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_received"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

DecodeResult(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_received"
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_decoded"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

AttemptSuccess(t, k, w) ==
    LET a == <<t, k>> IN
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "result_decoded" /\ attemptWorker[a] = w
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState' = [attemptState EXCEPT ![a] = "succeeded"]
    /\ taskState' = [taskState EXCEPT ![t] = "succeeded"]
    /\ futureState' = [futureState EXCEPT ![t] = "resolved"]
    /\ completed' = completed \cup {t}
    /\ outputs' = [outputs EXCEPT ![t] = "result"]
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ UNCHANGED <<retries, currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, executorState,
                    providerState, providerTarget, providerBlocks,
                    rejected>>

AttemptFailure(t, k, w) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "running" /\ attemptWorker[a] = w
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState' = [attemptState EXCEPT ![a] = "failed"]
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ retries' = IF retries[t] < MAX_RETRIES
                    THEN [retries EXCEPT ![t] = @ + 1]
                    ELSE retries
    /\ taskState' = IF retries[t] < MAX_RETRIES
                    THEN [taskState EXCEPT ![t] = "retry_wait"]
                    ELSE [taskState EXCEPT ![t] = "failed"]
    /\ futureState' = IF retries[t] < MAX_RETRIES
                      THEN futureState
                      ELSE [futureState EXCEPT ![t] = "rejected"]
    /\ rejected' = IF retries[t] < MAX_RETRIES THEN rejected ELSE rejected \cup {t}
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, executorState, providerState,
                    providerTarget, providerBlocks, completed, outputs>>

RetryTask(t) ==
    /\ t \in TASKS /\ taskState[t] = "retry_wait" /\ retries[t] <= MAX_RETRIES
    /\ taskState' = [taskState EXCEPT ![t] = "queued"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    dataState, attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

AttemptTimeout(t, k, w) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ attemptState[a] = "running" /\ attemptWorker[a] = w
    /\ currentAttempt[t] = k /\ retries[t] < MAX_RETRIES
    /\ attemptState' = [attemptState EXCEPT ![a] = "timed_out"]
    /\ taskState' = [taskState EXCEPT ![t] = "retry_wait"]
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ retries' = [retries EXCEPT ![t] = @ + 1]
    /\ UNCHANGED <<futureState, currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, executorState, providerState,
                    providerTarget, providerBlocks, completed, rejected, outputs>>

WorkerFailure(w) ==
    /\ ALLOW_FAILURES
    /\ w \in WORKERS /\ workerState[w] = "busy"
    /\ LET a == workerAttempt[w] IN
       /\ attemptState[a] \in {"submitted", "dispatched", "running",
                                "result_serialized", "result_sent",
                                "result_received", "result_decoded"}
       /\ attemptState' = [attemptState EXCEPT ![a] = "lost"]
       /\ workerState' = [workerState EXCEPT ![w] = "failed"]
       /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
       /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
       /\ retries' = IF currentAttempt[a[1]] = a[2] /\ retries[a[1]] < MAX_RETRIES
                     THEN [retries EXCEPT ![a[1]] = @ + 1] ELSE retries
       /\ taskState' = IF currentAttempt[a[1]] = a[2] /\ retries[a[1]] < MAX_RETRIES
                       THEN [taskState EXCEPT ![a[1]] = "retry_wait"]
                       ELSE [taskState EXCEPT ![a[1]] = "failed"]
       /\ futureState' = IF currentAttempt[a[1]] = a[2] /\ retries[a[1]] < MAX_RETRIES
                         THEN futureState
                         ELSE [futureState EXCEPT ![a[1]] = "rejected"]
       /\ rejected' = IF currentAttempt[a[1]] = a[2] /\ retries[a[1]] < MAX_RETRIES
                      THEN rejected ELSE rejected \cup {a[1]}
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, executorState, providerState,
                    providerTarget, providerBlocks, completed, outputs>>

ExecutorFailure(e, t, k) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ t \in TASKS /\ k \in 0..MAX_RETRIES
    /\ executorState[e] = "up" /\ attemptExecutor[a] = e
    /\ attemptState[a] \in {"running", "result_serialized", "result_sent",
                             "result_received", "result_decoded"}
    /\ attemptWorker[a] \in WORKERS
    /\ workerState[attemptWorker[a]] = "busy"
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ Cardinality({x \in AttemptIds : attemptExecutor[x] = e /\
                    attemptState[x] \in {"submitted", "dispatched", "running",
                                         "result_serialized", "result_sent",
                                         "result_received", "result_decoded"}}) = 1
    /\ attemptState' = [attemptState EXCEPT ![a] = "lost"]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ workerState' = [workerState EXCEPT ![attemptWorker[a]] = "failed"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![attemptWorker[a]] = NoAttempt]
    /\ executorState' = [executorState EXCEPT ![e] = "down"]
    /\ providerState' = [providerState EXCEPT ![e] = "failed"]
    /\ providerTarget' = [providerTarget EXCEPT ![e] = 0]
    /\ providerBlocks' = [providerBlocks EXCEPT ![e] = 0]
    /\ retries' = IF retries[t] < MAX_RETRIES
                    THEN [retries EXCEPT ![t] = @ + 1]
                    ELSE retries
    /\ taskState' = IF retries[t] < MAX_RETRIES
                    THEN [taskState EXCEPT ![t] = "retry_wait"]
                    ELSE [taskState EXCEPT ![t] = "failed"]
    /\ futureState' = IF retries[t] < MAX_RETRIES
                      THEN futureState
                      ELSE [futureState EXCEPT ![t] = "rejected"]
    /\ rejected' = IF retries[t] < MAX_RETRIES THEN rejected ELSE rejected \cup {t}
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, completed, outputs>>

LateResult(t, k) ==
    LET a == <<t, k>> IN
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES
    /\ attemptState[a] \in {"failed", "timed_out", "lost"}
    /\ currentAttempt[t] # k
    /\ attemptState' = [attemptState EXCEPT ![a] = "stale"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs>>

RequestAllocation(e) ==
    /\ e \in EXECUTORS
    /\ ((providerState[e] \in {"none", "cancelled"} /\ providerTarget[e] < MAX_BLOCKS)
        \/ providerState[e] = "failed")
    /\ providerTarget' = IF providerState[e] = "failed"
                          THEN providerTarget
                          ELSE [providerTarget EXCEPT ![e] = @ + 1]
    /\ providerState' = [providerState EXCEPT ![e] = "requested"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState, providerBlocks,
                    completed, rejected, outputs>>

AllocationSucceeds(e, w) ==
    /\ e \in EXECUTORS /\ w \in WORKERS
    /\ providerState[e] = "requested" /\ WorkerExec(w) = e
    /\ workerState[w] = "idle"
    /\ providerState' = [providerState EXCEPT ![e] = "active"]
    /\ providerBlocks' = [providerBlocks EXCEPT ![e] = @ + 1]
    /\ executorState' = [executorState EXCEPT ![e] = "up"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState,
                    workerAttempt, providerTarget, completed, rejected, outputs>>

AllocationFails(e) ==
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ providerState[e] = "requested"
    /\ providerState' = [providerState EXCEPT ![e] = "failed"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState, providerTarget,
                    providerBlocks, completed, rejected, outputs>>

CancelAllocation(e) ==
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ providerState[e] = "active" /\ providerBlocks[e] > 0
    /\ \A w \in WORKERS : WorkerExec(w) = e => workerState[w] = "idle"
    /\ \A a \in AttemptIds : attemptExecutor[a] = e =>
          attemptState[a] \notin {"submitted", "serialized", "sent", "received",
                                   "decoded", "dispatched", "running"}
    /\ providerState' = [providerState EXCEPT ![e] = "cancelled"]
    /\ providerBlocks' = [providerBlocks EXCEPT ![e] = @ - 1]
    /\ providerTarget' = [providerTarget EXCEPT ![e] = @ - 1]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState, workerAttempt,
                    executorState, completed, rejected, outputs>>

NextCore ==
    \/ \E t \in TASKS : BeginStaging(t) \/ FinishStaging(t)
    \/ \E t \in TASKS : DependencyCheck(t) \/ MemoizationHit(t) \/ Enqueue(t)
    \/ \E t \in TASKS, e \in EXECUTORS : SubmitAttempt(t, e)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : SerializationFailure(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES :
          SerializeAttempt(t, k) \/ SendAttempt(t, k)
          \/ ReceiveAttempt(t, k) \/ DecodeAttempt(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES, w \in WORKERS :
          DispatchAttempt(t, k, w) \/ StartAttempt(t, k, w)
          \/ SerializeResult(t, k, w)
          \/ AttemptSuccess(t, k, w) \/ AttemptFailure(t, k, w)
          \/ AttemptTimeout(t, k, w)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES :
          SendResult(t, k) \/ ReceiveResult(t, k) \/ DecodeResult(t, k)
    \/ \E t \in TASKS : RetryTask(t)
    \/ \E w \in WORKERS : WorkerFailure(w)
    \/ \E e \in EXECUTORS, t \in TASKS, k \in 0..MAX_RETRIES :
          ExecutorFailure(e, t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : LateResult(t, k)
    \/ \E e \in EXECUTORS : RequestAllocation(e) \/ AllocationFails(e)
    \/ \E e \in EXECUTORS, w \in WORKERS : AllocationSucceeds(e, w)
    \/ \E e \in EXECUTORS : CancelAllocation(e)

Next == NextCore \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars
SpecFair == Init /\ [][Next]_vars /\ WF_vars(NextCore)

TypeOK ==
    /\ taskState \in [TASKS -> TaskStates]
    /\ futureState \in [TASKS -> FutureStates]
    /\ retries \in [TASKS -> 0..MAX_RETRIES]
    /\ currentAttempt \in [TASKS -> -1..MAX_RETRIES]
    /\ selectedExecutor \in [TASKS -> (EXECUTORS \cup {"none"})]
    /\ dataState \in [TASKS -> DataStates]
    /\ attemptState \in [AttemptIds -> AttemptStates]
    /\ attemptExecutor \in [AttemptIds -> (EXECUTORS \cup {"none"})]
    /\ attemptWorker \in [AttemptIds -> (WORKERS \cup {"none"})]
    /\ workerState \in [WORKERS -> WorkerStates]
    /\ workerAttempt \in [WORKERS -> (AttemptIds \cup {NoAttempt})]
    /\ executorState \in [EXECUTORS -> {"up", "down"}]
    /\ providerState \in [EXECUTORS -> ProviderStates]
    /\ providerTarget \in [EXECUTORS -> 0..MAX_BLOCKS]
    /\ providerBlocks \in [EXECUTORS -> 0..MAX_BLOCKS]
    /\ completed \subseteq TASKS /\ rejected \subseteq TASKS
    /\ outputs \in [TASKS -> {"absent", "memoized-output", "result"}]

DependencySafety ==
    \A t \in TASKS : taskState[t] = "running" =>
        Deps(t) \subseteq {d \in TASKS : futureState[d] = "resolved"}

TerminalStability ==
    \A t \in TASKS : taskState[t] \in {"succeeded", "memoized"} =>
        futureState[t] = "resolved" /\ t \in completed

RetryBound == \A t \in TASKS : retries[t] <= MAX_RETRIES

WorkerCapacity ==
    \A w \in WORKERS : workerState[w] = "busy" => workerAttempt[w] # NoAttempt

WorkerBinding ==
    /\ \A w \in WORKERS : workerAttempt[w] # NoAttempt =>
          attemptWorker[workerAttempt[w]] = w
    /\ \A a \in AttemptIds : attemptWorker[a] # "none" =>
          workerAttempt[attemptWorker[a]] = a

ValidRunningAttempt ==
    \A a \in AttemptIds : attemptState[a] = "running" =>
        attemptExecutor[a] \in EXECUTORS /\ attemptWorker[a] \in WORKERS

NoRunningOnDownExecutor ==
    \A a \in AttemptIds : attemptState[a] = "running" =>
        executorState[attemptExecutor[a]] = "up"

AttemptIdentity ==
    \A t \in TASKS : currentAttempt[t] # -1 =>
        attemptState[<<t, currentAttempt[t]>>] # "absent"

ResultConsistency ==
    /\ completed \cap rejected = {}
    /\ \A t \in TASKS : futureState[t] = "resolved" => t \in completed

StaleResultSafety ==
    \A t \in TASKS, k \in 0..MAX_RETRIES :
      attemptState[<<t, k>>] = "stale" => currentAttempt[t] # k

SerializationSafety ==
    \A a \in AttemptIds :
      attemptState[a] \in {"serialized", "sent", "received", "decoded",
                            "dispatched", "running", "result_serialized",
                            "result_sent", "result_received", "result_decoded",
                            "succeeded"} => SerializableTask(a[1])

EventuallySettled ==
    \A t \in TASKS : <> (taskState[t] \in {"succeeded", "memoized", "failed"})

=============================================================================
