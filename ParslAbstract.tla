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
          OBJECTS, TASK_OBJECTS, SERIALIZABLE_OBJECTS, OBJECT_EDGES,
          FILE_OUTPUTS, SUBMITTABLE_EXECUTORS, JOIN_TASKS, JOIN_DEPS, JOIN_INVALID,
          MAX_RETRIES, MAX_BLOCKS, ALLOW_FAILURES,
          MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT, MONITORING_ENABLED

TaskStates == {"pending", "staging", "ready", "queued", "running",
               "retry_wait", "joining", "succeeded", "memoized", "failed"}
FutureStates == {"unresolved", "resolved", "rejected"}
MonitorStates == {"none", "pending", "running", "retry_wait", "succeeded", "failed", "memoized",
                  "write_failed"}
MonitorRecord == [status : MonitorStates, version : Nat]
AttemptStates == {"absent", "submitted", "serialized", "sent", "received", "decoded",
                  "dispatched", "running", "result_serialized", "result_sent",
                  "result_received", "result_decoded",
                  "succeeded", "failed", "timed_out", "lost", "stale"}
WorkerStates == {"unregistered", "idle", "busy", "failed"}
ProviderStates == {"none", "requested", "active", "failed", "cancelled"}
DataStates == {"unavailable", "staging", "available", "stageout",
               "staging_corrupt",
               "stageout_chunk1", "stageout_chunk1_corrupt",
               "stageout_chunk2", "stageout_chunk2_corrupt",
               "transferred", "corrupt"}
WireStates == {"none", "queued", "sent", "received", "duplicate", "acknowledged",
               "consumed", "dropped"}
EnvelopeStates == {"none", "valid", "invalid"}
AttemptIds == TASKS \X (0..MAX_RETRIES)
NoAttempt == <<"none", -1>>
Deps(t) == {d \in TASKS : d \o "->" \o t \in DEPS}
JoinDeps(t) == {d \in TASKS : d \o "=>" \o t \in JOIN_DEPS}
WorkerExec(w) == CHOOSE e \in EXECUTORS : w \o ":" \o e \in WORKER_EXECUTOR
ObjectPayload(t) == {o \in OBJECTS : t \o ":" \o o \in TASK_OBJECTS}
ObjectChildren(o) == {c \in OBJECTS : o \o "->" \o c \in OBJECT_EDGES}
ObjectGrandchildren(o) ==
    {g \in OBJECTS : \E c \in ObjectChildren(o) : g \in ObjectChildren(c)}
ObjectDescendants(o) == ObjectChildren(o) \cup ObjectGrandchildren(o)
ObjectGraphSerializable(t) ==
    /\ ObjectPayload(t) \subseteq SERIALIZABLE_OBJECTS
    /\ \A o \in ObjectPayload(t) :
          ObjectDescendants(o) \subseteq SERIALIZABLE_OBJECTS
ContentToken(t) == t \o ":content"
LocalExecutors == {e \in EXECUTORS : e = "local"}
ResultObject(t) == t \o ":result"
ResultSerializable(t) ==
    ResultObject(t) \notin OBJECTS \/
    (ResultObject(t) \in SERIALIZABLE_OBJECTS /\ ObjectDescendants(ResultObject(t))
        \subseteq SERIALIZABLE_OBJECTS)
SerializableTask(t) ==
    t \in CALLABLE_SERIALIZABLE /\ t \in PAYLOAD_SERIALIZABLE
    /\ ObjectGraphSerializable(t)

VARIABLES taskState, futureState, retries, currentAttempt, selectedExecutor,
          dataState, attemptState, attemptExecutor, attemptWorker,
          workerState, workerAttempt, executorState,
          providerState, providerTarget, providerBlocks,
          completed, rejected, outputs,
          clock, lastHeartbeat, attemptStart, monitoringState, joinObserved,
          taskWireState, resultWireState, taskEnvelope, resultEnvelope

vars == <<taskState, futureState, retries, currentAttempt, selectedExecutor,
          dataState, attemptState, attemptExecutor, attemptWorker,
          workerState, workerAttempt, executorState,
          providerState, providerTarget, providerBlocks,
          completed, rejected, outputs,
          clock, lastHeartbeat, attemptStart, monitoringState, joinObserved,
          taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

timeVars == <<clock, lastHeartbeat, attemptStart>>

Init ==
    /\ TASKS # {} /\ EXECUTORS # {} /\ WORKERS # {}
    /\ CALLABLE_SERIALIZABLE \subseteq TASKS
    /\ PAYLOAD_SERIALIZABLE \subseteq TASKS
    /\ SERIALIZABLE_OBJECTS \subseteq OBJECTS
    /\ TASK_OBJECTS \subseteq {t \o ":" \o o : t \in TASKS, o \in OBJECTS}
    /\ OBJECT_EDGES \subseteq {o \o "->" \o c : o \in OBJECTS, c \in OBJECTS}
    /\ FILE_OUTPUTS \subseteq TASKS
    /\ SUBMITTABLE_EXECUTORS \subseteq EXECUTORS
    /\ DEPS \subseteq {d \o "->" \o t : d \in TASKS, t \in TASKS}
    /\ JOIN_TASKS \subseteq TASKS
    /\ JOIN_DEPS \subseteq {d \o "=>" \o t : d \in TASKS, t \in TASKS}
    /\ JOIN_INVALID \subseteq TASKS
    /\ JOIN_INVALID \cap JOIN_TASKS = {}
    /\ WORKER_EXECUTOR \subseteq {w \o ":" \o e : w \in WORKERS, e \in EXECUTORS}
    /\ \A t \in TASKS : t \notin Deps(t)
    /\ \A t \in JOIN_TASKS : t \notin JoinDeps(t)
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
    /\ workerState = [w \in WORKERS |-> "unregistered"]
    /\ workerAttempt = [w \in WORKERS |-> NoAttempt]
    /\ executorState = [e \in EXECUTORS |-> "up"]
    /\ providerState = [e \in EXECUTORS |-> "none"]
    /\ providerTarget = [e \in EXECUTORS |-> 0]
    /\ providerBlocks = [e \in EXECUTORS |-> 0]
    /\ completed = {}
    /\ rejected = {}
    /\ outputs = [t \in TASKS |-> "absent"]
    /\ clock = 0
    /\ lastHeartbeat = [w \in WORKERS |-> 0]
    /\ attemptStart = [a \in AttemptIds |-> -1]
    /\ monitoringState = [t \in TASKS |-> [status |-> "none", version |-> 0]]
    /\ joinObserved = [t \in TASKS |-> {}]
    /\ taskWireState = [a \in AttemptIds |-> "none"]
    /\ resultWireState = [a \in AttemptIds |-> "none"]
    /\ taskEnvelope = [a \in AttemptIds |-> "none"]
    /\ resultEnvelope = [a \in AttemptIds |-> "none"]

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
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

FinishStaging(t) ==
    /\ t \in TASKS /\ taskState[t] = "staging" /\ dataState[t] = "staging"
    /\ dataState' = [dataState EXCEPT ![t] = "available"]
    /\ taskState' = [taskState EXCEPT ![t] = "pending"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

CorruptStaging(t) ==
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ taskState[t] = "staging"
    /\ dataState[t] = "staging"
    /\ dataState' = [dataState EXCEPT ![t] = "staging_corrupt"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt, selectedExecutor,
                    attemptState, attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState, providerState, providerTarget,
                    providerBlocks, completed, rejected, outputs, taskWireState,
                    resultWireState, taskEnvelope, resultEnvelope>>

RepairStaging(t) ==
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ taskState[t] = "staging"
    /\ dataState[t] = "staging_corrupt"
    /\ dataState' = [dataState EXCEPT ![t] = "staging"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt, selectedExecutor,
                    attemptState, attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState, providerState, providerTarget,
                    providerBlocks, completed, rejected, outputs, taskWireState,
                    resultWireState, taskEnvelope, resultEnvelope>>

BeginStageOut(t) ==
    /\ t \in FILE_OUTPUTS
    /\ taskState[t] \in {"succeeded", "memoized"}
    /\ dataState[t] = "available"
    /\ dataState' = [dataState EXCEPT ![t] = "stageout_chunk1"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

FinishStageOut(t) ==
    /\ t \in FILE_OUTPUTS
    /\ taskState[t] \in {"succeeded", "memoized"}
    /\ dataState[t] = "stageout_chunk2"
    /\ dataState' = [dataState EXCEPT ![t] = "transferred"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

TransferOutputChunk(t) ==
    /\ t \in FILE_OUTPUTS
    /\ taskState[t] \in {"succeeded", "memoized"}
    /\ dataState[t] = "stageout_chunk1"
    /\ dataState' = [dataState EXCEPT ![t] = "stageout_chunk2"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

CorruptStageOut(t) ==
    /\ ALLOW_FAILURES
    /\ t \in FILE_OUTPUTS
    /\ taskState[t] \in {"succeeded", "memoized"}
    /\ dataState[t] \in {"stageout", "stageout_chunk1", "stageout_chunk2", "transferred"}
    /\ dataState' = [dataState EXCEPT ![t] =
          IF dataState[t] = "stageout_chunk1" THEN "stageout_chunk1_corrupt"
          ELSE IF dataState[t] = "stageout_chunk2" THEN "stageout_chunk2_corrupt"
          ELSE "corrupt"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

RepairStageOut(t) ==
    /\ ALLOW_FAILURES
    /\ t \in FILE_OUTPUTS
    /\ taskState[t] \in {"succeeded", "memoized"}
    /\ dataState[t] \in {"corrupt", "stageout_chunk1_corrupt", "stageout_chunk2_corrupt"}
    /\ dataState' = [dataState EXCEPT ![t] =
          IF dataState[t] = "stageout_chunk2_corrupt" THEN "stageout_chunk2"
          ELSE "stageout_chunk1"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

DependencyCheck(t) ==
    /\ t \in TASKS /\ taskState[t] = "pending" /\ dataState[t] = "available"
    /\ Deps(t) \subseteq {d \in TASKS : futureState[d] = "resolved"}
    /\ taskState' = [taskState EXCEPT ![t] = "ready"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    dataState, attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

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
                    rejected, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

Enqueue(t) ==
    /\ t \in TASKS /\ taskState[t] = "ready" /\ t \notin MEMOIZED
    /\ taskState' = [taskState EXCEPT ![t] = "queued"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    dataState, attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

SubmitAttempt(t, e) ==
    LET a == <<t, retries[t]>> IN
    /\ t \in TASKS /\ e \in EXECUTORS
    /\ taskState[t] = "queued" /\ executorState[e] = "up"
    /\ providerState[e] = "active" \/ e \in LocalExecutors
    /\ e \in SUBMITTABLE_EXECUTORS
    /\ retries[t] <= MAX_RETRIES /\ attemptState[a] = "absent"
    /\ taskState' = [taskState EXCEPT ![t] = "running"]
    /\ currentAttempt' = [currentAttempt EXCEPT ![t] = retries[t]]
    /\ selectedExecutor' = [selectedExecutor EXCEPT ![t] = e]
    /\ attemptState' = [attemptState EXCEPT ![a] = "submitted"]
    /\ attemptExecutor' = [attemptExecutor EXCEPT ![a] = e]
    /\ UNCHANGED <<futureState, retries, dataState, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

SubmitFailure(t, e) ==
    LET a == <<t, retries[t]>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ e \in EXECUTORS
    /\ taskState[t] = "queued" /\ executorState[e] = "up"
    /\ providerState[e] = "active" /\ e \notin SUBMITTABLE_EXECUTORS
    /\ retries[t] <= MAX_RETRIES /\ attemptState[a] = "absent"
    /\ taskState' = IF retries[t] < MAX_RETRIES
                    THEN [taskState EXCEPT ![t] = "retry_wait"]
                    ELSE [taskState EXCEPT ![t] = "failed"]
    /\ currentAttempt' = [currentAttempt EXCEPT ![t] = retries[t]]
    /\ selectedExecutor' = [selectedExecutor EXCEPT ![t] = e]
    /\ attemptState' = [attemptState EXCEPT ![a] = "failed"]
    /\ attemptExecutor' = [attemptExecutor EXCEPT ![a] = e]
    /\ retries' = IF retries[t] < MAX_RETRIES
                    THEN [retries EXCEPT ![t] = @ + 1]
                    ELSE retries
    /\ futureState' = IF retries[t] < MAX_RETRIES
                      THEN futureState
                      ELSE [futureState EXCEPT ![t] = "rejected"]
    /\ rejected' = IF retries[t] < MAX_RETRIES THEN rejected ELSE rejected \cup {t}
    /\ UNCHANGED <<dataState, attemptWorker, workerState, workerAttempt,
                    executorState, providerState, providerTarget, providerBlocks,
                    completed, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

SerializeAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "submitted" /\ currentAttempt[t] = k
    /\ SerializableTask(t)
    /\ attemptState' = [attemptState EXCEPT ![a] = "serialized"]
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "queued"]
    /\ taskEnvelope' = [taskEnvelope EXCEPT ![a] = "valid"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, resultWireState, resultEnvelope>>

SerializationFailure(t, k) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES
    /\ attemptState[a] = "submitted" /\ currentAttempt[t] = k
    /\ ~SerializableTask(t)
    /\ attemptState' = [attemptState EXCEPT ![a] = "failed"]
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "dropped"]
    /\ taskEnvelope' = [taskEnvelope EXCEPT ![a] = "invalid"]
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
                    completed, outputs, resultWireState, resultEnvelope>>

DropTaskMessage(t, k) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState[a] \in {"serialized", "sent", "received"}
    /\ taskWireState[a] \in {"queued", "sent", "received"}
    /\ attemptState' = [attemptState EXCEPT ![a] = "lost"]
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "dropped"]
    /\ taskEnvelope' = [taskEnvelope EXCEPT ![a] = "invalid"]
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
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks, completed,
                    outputs, resultWireState, resultEnvelope>>

SendAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "serialized" /\ taskWireState[a] = "queued"
    /\ attemptState' = [attemptState EXCEPT ![a] = "sent"]
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "sent"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, resultWireState,
                    taskEnvelope, resultEnvelope>>

ReceiveAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "sent" /\ taskWireState[a] = "sent"
    /\ attemptState' = [attemptState EXCEPT ![a] = "received"]
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "received"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, resultWireState,
                    taskEnvelope, resultEnvelope>>

DuplicateTaskMessage(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "received" /\ taskWireState[a] = "received"
    /\ taskEnvelope[a] = "valid"
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "duplicate"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, resultWireState,
                    taskEnvelope, resultEnvelope>>

DiscardTaskDuplicate(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "received" /\ taskWireState[a] = "duplicate"
    /\ taskEnvelope[a] = "valid"
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "received"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, resultWireState,
                    taskEnvelope, resultEnvelope>>

AcknowledgeTask(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "received"
    /\ taskWireState[a] = "received"
    /\ taskEnvelope[a] = "valid"
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "acknowledged"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, resultWireState,
                    taskEnvelope, resultEnvelope>>

DecodeAttempt(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "received" /\ taskWireState[a] = "acknowledged"
    /\ attemptState' = [attemptState EXCEPT ![a] = "decoded"]
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "consumed"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, resultWireState,
                    taskEnvelope, resultEnvelope>>

RegisterWorker(w) ==
    /\ w \in WORKERS /\ workerState[w] = "unregistered"
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, clock, lastHeartbeat,
                    attemptStart, monitoringState, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

RegistrationFailure(w) ==
    /\ ALLOW_FAILURES
    /\ w \in WORKERS /\ workerState[w] = "unregistered"
    /\ workerState' = [workerState EXCEPT ![w] = "failed"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, clock, lastHeartbeat,
                    attemptStart, monitoringState, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

DispatchAttempt(t, k, w) ==
    LET a == <<t, k>> IN
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "decoded"
    /\ workerState[w] = "idle" /\ WorkerExec(w) = attemptExecutor[a]
    /\ (providerState[attemptExecutor[a]] = "active"
        \/ attemptExecutor[a] \in LocalExecutors)
    /\ attemptState' = [attemptState EXCEPT ![a] = "dispatched"]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = w]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = a]
    /\ workerState' = [workerState EXCEPT ![w] = "busy"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    executorState, providerState, providerTarget,
                    providerBlocks, completed, rejected, outputs, taskWireState,
                    resultWireState, taskEnvelope, resultEnvelope>>

MisrouteAttempt(t, k, w) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "decoded"
    /\ workerState[w] = "idle" /\ WorkerExec(w) # attemptExecutor[a]
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState' = [attemptState EXCEPT ![a] = "lost"]
    /\ taskState' = IF retries[t] < MAX_RETRIES
                    THEN [taskState EXCEPT ![t] = "retry_wait"]
                    ELSE [taskState EXCEPT ![t] = "failed"]
    /\ futureState' = IF retries[t] < MAX_RETRIES
                      THEN futureState
                      ELSE [futureState EXCEPT ![t] = "rejected"]
    /\ retries' = IF retries[t] < MAX_RETRIES
                    THEN [retries EXCEPT ![t] = @ + 1]
                    ELSE retries
    /\ rejected' = IF retries[t] < MAX_RETRIES THEN rejected ELSE rejected \cup {t}
    /\ taskWireState' = [taskWireState EXCEPT ![a] = "dropped"]
    /\ taskEnvelope' = [taskEnvelope EXCEPT ![a] = "invalid"]
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, attemptWorker, workerState, workerAttempt,
                    executorState, providerState, providerTarget, providerBlocks,
                    completed, outputs, resultWireState, resultEnvelope>>

StartAttempt(t, k, w) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "dispatched" /\ attemptWorker[a] = w
    /\ workerState[w] = "busy"
    /\ attemptState' = [attemptState EXCEPT ![a] = "running"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

SerializeResult(t, k, w) ==
    LET a == <<t, k>> IN
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "running" /\ attemptWorker[a] = w
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ ResultSerializable(t)
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_serialized"]
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "queued"]
    /\ resultEnvelope' = [resultEnvelope EXCEPT ![a] = "valid"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState,
                    taskEnvelope>>

SendResult(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_serialized" /\ resultWireState[a] = "queued"
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_sent"]
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "sent"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState,
                    taskEnvelope, resultEnvelope>>

ResultSerializationFailure(t, k, w) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "running" /\ attemptWorker[a] = w
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ ~ResultSerializable(t)
    /\ attemptState' = [attemptState EXCEPT ![a] = "failed"]
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "dropped"]
    /\ resultEnvelope' = [resultEnvelope EXCEPT ![a] = "invalid"]
    /\ retries' = IF retries[t] < MAX_RETRIES
                    THEN [retries EXCEPT ![t] = @ + 1]
                    ELSE retries
    /\ taskState' = IF retries[t] < MAX_RETRIES
                    THEN [taskState EXCEPT ![t] = "retry_wait"]
                    ELSE [taskState EXCEPT ![t] = "failed"]
    /\ futureState' = IF retries[t] < MAX_RETRIES
                      THEN futureState
                      ELSE [futureState EXCEPT ![t] = "rejected"]
    /\ rejected' = IF retries[t] < MAX_RETRIES
                   THEN rejected ELSE rejected \cup {t}
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, executorState, providerState,
                    providerTarget, providerBlocks, completed, outputs,
                    taskWireState, taskEnvelope>>

ReceiveResult(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_sent" /\ resultWireState[a] = "sent"
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_received"]
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "received"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState,
                    taskEnvelope, resultEnvelope>>

DuplicateResultMessage(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_received" /\ resultWireState[a] = "received"
    /\ resultEnvelope[a] = "valid"
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "duplicate"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState,
                    taskEnvelope, resultEnvelope>>

DiscardResultDuplicate(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_received" /\ resultWireState[a] = "duplicate"
    /\ resultEnvelope[a] = "valid"
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "received"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState,
                    taskEnvelope, resultEnvelope>>

AcknowledgeResult(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_received"
    /\ resultWireState[a] = "received"
    /\ resultEnvelope[a] = "valid"
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "acknowledged"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, taskEnvelope,
                    resultEnvelope>>

DecodeResult(t, k) ==
    LET a == <<t, k>> IN
    /\ attemptState[a] = "result_received" /\ resultWireState[a] = "acknowledged"
    /\ attemptState' = [attemptState EXCEPT ![a] = "result_decoded"]
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "consumed"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState,
                    taskEnvelope, resultEnvelope>>

DropResultMessage(t, k, w) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState[a] \in {"result_serialized", "result_sent", "result_received"}
    /\ resultWireState[a] \in {"queued", "sent", "received"}
    /\ attemptWorker[a] = w /\ workerState[w] = "busy"
    /\ attemptState' = [attemptState EXCEPT ![a] = "lost"]
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "dropped"]
    /\ resultEnvelope' = [resultEnvelope EXCEPT ![a] = "invalid"]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
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
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState, attemptExecutor,
                    executorState, providerState, providerTarget, providerBlocks,
                    completed, outputs, taskWireState, taskEnvelope>>

MisrouteResult(t, k, w, e) ==
    LET a == <<t, k>> IN
    /\ ALLOW_FAILURES
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS /\ e \in EXECUTORS
    /\ e # attemptExecutor[a]
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState[a] = "result_decoded" /\ attemptWorker[a] = w
    /\ workerState[w] = "busy"
    /\ resultWireState[a] = "consumed" /\ resultEnvelope[a] = "valid"
    /\ attemptState' = [attemptState EXCEPT ![a] = "lost"]
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "dropped"]
    /\ resultEnvelope' = [resultEnvelope EXCEPT ![a] = "invalid"]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
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
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState, attemptExecutor,
                    executorState, providerState, providerTarget, providerBlocks,
                    completed, outputs, taskWireState, taskEnvelope>>

AttemptSuccess(t, k, w) ==
    LET a == <<t, k>> IN
    /\ t \in TASKS /\ k \in 0..MAX_RETRIES /\ w \in WORKERS
    /\ attemptState[a] = "result_decoded" /\ attemptWorker[a] = w
    /\ currentAttempt[t] = k /\ taskState[t] = "running"
    /\ attemptState' = [attemptState EXCEPT ![a] = "succeeded"]
    /\ taskState' = IF t \in JOIN_INVALID
                    THEN [taskState EXCEPT ![t] = "failed"]
                    ELSE IF t \in JOIN_TASKS
                         THEN [taskState EXCEPT ![t] = "joining"]
                         ELSE [taskState EXCEPT ![t] = "succeeded"]
    /\ futureState' = IF t \in JOIN_INVALID
                      THEN [futureState EXCEPT ![t] = "rejected"]
                      ELSE IF t \in JOIN_TASKS
                           THEN futureState
                           ELSE [futureState EXCEPT ![t] = "resolved"]
    /\ completed' = IF t \in JOIN_INVALID \/ t \in JOIN_TASKS
                    THEN completed ELSE completed \cup {t}
    /\ rejected' = IF t \in JOIN_INVALID THEN rejected \cup {t} ELSE rejected
    /\ outputs' = [outputs EXCEPT ![t] = IF t \in JOIN_INVALID
                                      THEN "absent"
                                      ELSE IF t \in JOIN_TASKS
                                           THEN "join-handle" ELSE "result"]
    /\ workerState' = [workerState EXCEPT ![w] = "idle"]
    /\ workerAttempt' = [workerAttempt EXCEPT ![w] = NoAttempt]
    /\ attemptWorker' = [attemptWorker EXCEPT ![a] = "none"]
    /\ UNCHANGED <<retries, currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, executorState,
                    providerState, providerTarget, providerBlocks,
                    taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

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
                    providerTarget, providerBlocks, completed, outputs,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

JoinObserve(t, i) ==
    /\ t \in JOIN_TASKS /\ i \in JoinDeps(t)
    /\ taskState[t] = "joining"
    /\ futureState[i] \in {"resolved", "rejected"}
    /\ i \notin joinObserved[t]
    /\ joinObserved' = [joinObserved EXCEPT ![t] = @ \cup {i}]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, clock, lastHeartbeat,
                    attemptStart, monitoringState, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

JoinComplete(t) ==
    /\ t \in JOIN_TASKS /\ taskState[t] = "joining"
    /\ joinObserved[t] = JoinDeps(t)
    /\ \A i \in JoinDeps(t) : futureState[i] = "resolved"
    /\ taskState' = [taskState EXCEPT ![t] = "succeeded"]
    /\ futureState' = [futureState EXCEPT ![t] = "resolved"]
    /\ completed' = completed \cup {t}
    /\ outputs' = [outputs EXCEPT ![t] = "join-result"]
    /\ UNCHANGED <<retries, currentAttempt, selectedExecutor, dataState,
                    attemptState, attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState, providerState, providerTarget,
                    providerBlocks, rejected, clock, lastHeartbeat, attemptStart,
                    monitoringState, joinObserved, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

JoinFailure(t) ==
    /\ ALLOW_FAILURES
    /\ t \in JOIN_TASKS /\ taskState[t] = "joining"
    /\ joinObserved[t] = JoinDeps(t)
    /\ \E i \in JoinDeps(t) : futureState[i] = "rejected"
    /\ taskState' = [taskState EXCEPT ![t] = "failed"]
    /\ futureState' = [futureState EXCEPT ![t] = "rejected"]
    /\ rejected' = rejected \cup {t}
    /\ UNCHANGED <<retries, currentAttempt, selectedExecutor, dataState,
                    attemptState, attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState, providerState, providerTarget,
                    providerBlocks, completed, outputs, clock, lastHeartbeat,
                    attemptStart, monitoringState, joinObserved, taskWireState,
                    resultWireState, taskEnvelope, resultEnvelope>>

RetryTask(t) ==
    /\ t \in TASKS /\ taskState[t] = "retry_wait" /\ retries[t] <= MAX_RETRIES
    /\ taskState' = [taskState EXCEPT ![t] = "queued"]
    /\ UNCHANGED <<futureState, retries, currentAttempt, selectedExecutor,
                    dataState, attemptState, attemptExecutor, attemptWorker,
                    workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

AttemptTimeout(t, k, w) ==
    LET a == <<t, k>> IN
    /\ (ALLOW_FAILURES \/ clock - attemptStart[a] >= TASK_TIMEOUT)
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
                    providerTarget, providerBlocks, completed, rejected, outputs,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

WorkerFailure(w) ==
    /\ (ALLOW_FAILURES \/ clock - lastHeartbeat[w] >= HEARTBEAT_TIMEOUT)
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
       /\ resultWireState' = [resultWireState EXCEPT ![a] = "dropped"]
       /\ resultEnvelope' = [resultEnvelope EXCEPT ![a] = "invalid"]
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, executorState, providerState,
                    providerTarget, providerBlocks, completed, outputs,
                    taskWireState, taskEnvelope>>

IdleManagerTimeout(w) ==
    LET e == WorkerExec(w) IN
    /\ ALLOW_FAILURES
    /\ w \in WORKERS /\ workerState[w] = "idle"
    /\ clock - lastHeartbeat[w] >= HEARTBEAT_TIMEOUT
    /\ providerState[e] = "active" /\ executorState[e] = "up"
    /\ workerState' = [workerState EXCEPT ![w] = "failed"]
    /\ providerState' = [providerState EXCEPT ![e] = "failed"]
    /\ executorState' = [executorState EXCEPT ![e] = "down"]
    /\ providerTarget' = [providerTarget EXCEPT ![e] = 0]
    /\ providerBlocks' = [providerBlocks EXCEPT ![e] = 0]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerAttempt, completed, rejected, outputs,
                    clock, lastHeartbeat, attemptStart, monitoringState,
                    joinObserved, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

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
    /\ resultWireState' = [resultWireState EXCEPT ![a] = "dropped"]
    /\ resultEnvelope' = [resultEnvelope EXCEPT ![a] = "invalid"]
    /\ UNCHANGED <<currentAttempt, selectedExecutor, dataState,
                    attemptExecutor, completed, outputs, taskWireState, taskEnvelope>>

ExecutorDrain(e) ==
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ executorState[e] = "up"
    /\ executorState' = [executorState EXCEPT ![e] = "draining"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState, workerAttempt,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, clock, lastHeartbeat,
                    attemptStart, monitoringState, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

ExecutorRecover(e) ==
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ executorState[e] = "draining"
    /\ executorState' = [executorState EXCEPT ![e] = "up"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState, workerAttempt,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, clock, lastHeartbeat,
                    attemptStart, monitoringState, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

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
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

RequestAllocation(e) ==
    /\ e \in EXECUTORS \ LocalExecutors
    /\ ((providerState[e] \in {"none", "cancelled"} /\ providerTarget[e] < MAX_BLOCKS)
        \/ providerState[e] = "failed")
    /\ providerTarget' = [providerTarget EXCEPT ![e] = @ + 1]
    /\ providerState' = [providerState EXCEPT ![e] = "requested"]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState, providerBlocks,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

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
                    workerAttempt, providerTarget, completed, rejected, outputs,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

AllocationFails(e) ==
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ providerState[e] = "requested"
    /\ providerState' = [providerState EXCEPT ![e] = "failed"]
    /\ providerTarget' = [providerTarget EXCEPT ![e] = 0]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState,
                    workerAttempt, executorState,
                    providerBlocks, completed, rejected, outputs,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

ProviderFailure(e) ==
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ providerState[e] = "active"
    /\ executorState[e] = "up"
    /\ \A w \in WORKERS : WorkerExec(w) = e => workerState[w] = "idle"
    /\ \A a \in AttemptIds : attemptExecutor[a] = e =>
          attemptState[a] \notin {"submitted", "serialized", "sent", "received",
                                   "decoded", "dispatched", "running",
                                   "result_serialized", "result_sent",
                                   "result_received", "result_decoded"}
    /\ providerState' = [providerState EXCEPT ![e] = "failed"]
    /\ executorState' = [executorState EXCEPT ![e] = "down"]
    /\ providerTarget' = [providerTarget EXCEPT ![e] = 0]
    /\ providerBlocks' = [providerBlocks EXCEPT ![e] = 0]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState, workerAttempt,
                    completed, rejected, outputs, taskWireState, resultWireState,
                    taskEnvelope, resultEnvelope>>

CancelAllocation(e) ==
    /\ ALLOW_FAILURES
    /\ e \in EXECUTORS /\ providerState[e] = "active" /\ providerBlocks[e] > 0
    /\ \A w \in WORKERS : WorkerExec(w) = e => workerState[w] = "idle"
    /\ \A a \in AttemptIds : attemptExecutor[a] = e =>
          attemptState[a] \notin {"submitted", "serialized", "sent", "received",
                                   "decoded", "dispatched", "running"}
    /\ providerState' = [providerState EXCEPT ![e] =
          IF providerBlocks[e] = 1 THEN "cancelled" ELSE "active"]
    /\ providerBlocks' = [providerBlocks EXCEPT ![e] = @ - 1]
    /\ providerTarget' = [providerTarget EXCEPT ![e] = @ - 1]
    /\ UNCHANGED <<taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState,
                    attemptExecutor, attemptWorker, workerState, workerAttempt,
                    executorState, completed, rejected, outputs,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

CoreActions ==
    \/ \E w \in WORKERS : RegisterWorker(w) \/ RegistrationFailure(w)
    \/ \E t \in TASKS : BeginStaging(t) \/ FinishStaging(t)
          \/ CorruptStaging(t) \/ RepairStaging(t)
    \/ \E t \in TASKS : BeginStageOut(t) \/ TransferOutputChunk(t)
          \/ FinishStageOut(t) \/ CorruptStageOut(t) \/ RepairStageOut(t)
    \/ \E t \in TASKS : DependencyCheck(t) \/ MemoizationHit(t) \/ Enqueue(t)
    \/ \E t \in TASKS, e \in EXECUTORS : SubmitAttempt(t, e)
    \/ \E t \in TASKS, e \in EXECUTORS : SubmitFailure(t, e)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : SerializationFailure(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : DropTaskMessage(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES :
          SerializeAttempt(t, k) \/ SendAttempt(t, k)
          \/ ReceiveAttempt(t, k) \/ DuplicateTaskMessage(t, k)
          \/ DiscardTaskDuplicate(t, k) \/ AcknowledgeTask(t, k)
          \/ DecodeAttempt(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES, w \in WORKERS :
          DispatchAttempt(t, k, w)
          \/ MisrouteAttempt(t, k, w)
          \/ SerializeResult(t, k, w)
          \/ ResultSerializationFailure(t, k, w)
          \/ AttemptSuccess(t, k, w) \/ AttemptFailure(t, k, w)
          \/ AttemptTimeout(t, k, w)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES :
          SendResult(t, k) \/ ReceiveResult(t, k)
          \/ DuplicateResultMessage(t, k) \/ DiscardResultDuplicate(t, k)
          \/ AcknowledgeResult(t, k) \/ DecodeResult(t, k)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES, w \in WORKERS :
          DropResultMessage(t, k, w)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES, w \in WORKERS, e \in EXECUTORS :
          MisrouteResult(t, k, w, e)
    \/ \E t \in TASKS : RetryTask(t)
    \/ \E w \in WORKERS : WorkerFailure(w)
    \/ \E w \in WORKERS : IdleManagerTimeout(w)
    \/ \E e \in EXECUTORS, t \in TASKS, k \in 0..MAX_RETRIES :
          ExecutorFailure(e, t, k)
    \/ \E e \in EXECUTORS : ExecutorDrain(e) \/ ExecutorRecover(e)
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES : LateResult(t, k)
    \/ \E e \in EXECUTORS : RequestAllocation(e) \/ AllocationFails(e)
    \/ \E e \in EXECUTORS : ProviderFailure(e)
    \/ \E e \in EXECUTORS, w \in WORKERS : AllocationSucceeds(e, w)
    \/ \E e \in EXECUTORS : CancelAllocation(e)

StartAttemptTimed(t, k, w) ==
    /\ StartAttempt(t, k, w)
    /\ attemptStart' = [attemptStart EXCEPT ![<<t, k>>] = clock]
    /\ UNCHANGED <<clock, lastHeartbeat, monitoringState, joinObserved>>

Tick ==
    /\ clock < MAX_TIME
    /\ clock' = clock + 1
    /\ UNCHANGED <<lastHeartbeat, attemptStart,
                    taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, monitoringState, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

Heartbeat(w) ==
    /\ w \in WORKERS /\ workerState[w] \in {"idle", "busy"}
    /\ lastHeartbeat' = [lastHeartbeat EXCEPT ![w] = clock]
    /\ UNCHANGED <<clock, attemptStart,
                    taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, monitoringState, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

MonitorView(t) ==
    CASE taskState[t] = "memoized"  -> "memoized"
      [] taskState[t] = "succeeded" -> "succeeded"
      [] taskState[t] = "failed"    -> "failed"
      [] taskState[t] = "running"   -> "running"
      [] taskState[t] = "retry_wait" -> "retry_wait"
      [] OTHER -> "pending"

PublishMonitor(t) ==
    /\ MONITORING_ENABLED
    /\ t \in TASKS
    /\ monitoringState[t].status # MonitorView(t)
    /\ monitoringState' = [monitoringState EXCEPT ![t] =
          [status |-> MonitorView(t), version |-> monitoringState[t].version + 1]]
    /\ UNCHANGED <<clock, lastHeartbeat, attemptStart,
                    taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

MonitoringWriteFailure(t) ==
    /\ ALLOW_FAILURES
    /\ MONITORING_ENABLED
    /\ t \in TASKS
    /\ monitoringState[t].status \notin {"write_failed", MonitorView(t)}
    /\ monitoringState' = [monitoringState EXCEPT ![t] =
          [status |-> "write_failed", version |-> monitoringState[t].version]]
    /\ UNCHANGED <<clock, lastHeartbeat, attemptStart,
                    taskState, futureState, retries, currentAttempt,
                    selectedExecutor, dataState, attemptState, attemptExecutor,
                    attemptWorker, workerState, workerAttempt, executorState,
                    providerState, providerTarget, providerBlocks,
                    completed, rejected, outputs, joinObserved,
                    taskWireState, resultWireState, taskEnvelope, resultEnvelope>>

NextCore ==
    \/ CoreActions /\ UNCHANGED <<timeVars, monitoringState, joinObserved>>
    \/ \E t \in TASKS, k \in 0..MAX_RETRIES, w \in WORKERS :
          StartAttemptTimed(t, k, w)
    \/ Tick
    \/ \E w \in WORKERS : Heartbeat(w)
    \/ \E t \in TASKS : PublishMonitor(t) \/ MonitoringWriteFailure(t)
    \/ \E t \in JOIN_TASKS, i \in TASKS : JoinObserve(t, i)
    \/ \E t \in JOIN_TASKS : JoinComplete(t) \/ JoinFailure(t)

Next == NextCore \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars
ProgressNext == NextCore /\
    (taskState' # taskState \/ futureState' # futureState \/
     attemptState' # attemptState \/ completed' # completed \/ rejected' # rejected)
ProtocolProgress == NextCore /\
    (\E a \in AttemptIds : taskWireState'[a] = "acknowledged" \/
                             resultWireState'[a] = "acknowledged")
SpecFair == Init /\ [][Next]_vars /\ WF_vars(NextCore) /\
           SF_vars(ProgressNext) /\ SF_vars(ProtocolProgress)

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
    /\ executorState \in [EXECUTORS -> {"up", "draining", "down"}]
    /\ providerState \in [EXECUTORS -> ProviderStates]
    /\ providerTarget \in [EXECUTORS -> 0..MAX_BLOCKS]
    /\ providerBlocks \in [EXECUTORS -> 0..MAX_BLOCKS]
    /\ completed \subseteq TASKS /\ rejected \subseteq TASKS
    /\ outputs \in [TASKS -> {"absent", "memoized-output", "join-handle", "result",
                               "join-result"}]
    /\ clock \in 0..MAX_TIME
    /\ lastHeartbeat \in [WORKERS -> 0..MAX_TIME]
    /\ attemptStart \in [AttemptIds -> -1..MAX_TIME]
    /\ monitoringState \in [TASKS -> MonitorRecord]
    /\ joinObserved \in [TASKS -> SUBSET TASKS]
    /\ taskWireState \in [AttemptIds -> WireStates]
    /\ resultWireState \in [AttemptIds -> WireStates]
    /\ taskEnvelope \in [AttemptIds -> EnvelopeStates]
    /\ resultEnvelope \in [AttemptIds -> EnvelopeStates]

MessageSafety ==
    /\ \A a \in AttemptIds :
          taskWireState[a] = "none" => taskEnvelope[a] = "none"
    /\ \A a \in AttemptIds :
          taskWireState[a] = "queued" =>
              taskEnvelope[a] = "valid" /\ attemptState[a] = "serialized"
    /\ \A a \in AttemptIds :
          taskWireState[a] = "sent" =>
              taskEnvelope[a] = "valid" /\ attemptState[a] = "sent"
    /\ \A a \in AttemptIds :
          taskWireState[a] = "received" =>
              taskEnvelope[a] = "valid" /\ attemptState[a] = "received"
    /\ \A a \in AttemptIds :
          taskWireState[a] = "duplicate" =>
              taskEnvelope[a] = "valid" /\ attemptState[a] = "received"
    /\ \A a \in AttemptIds :
          taskWireState[a] = "acknowledged" =>
              taskEnvelope[a] = "valid" /\ attemptState[a] = "received"
    /\ \A a \in AttemptIds :
          taskWireState[a] = "consumed" =>
              taskEnvelope[a] = "valid" /\
              attemptState[a] \in {"decoded", "dispatched", "running",
                                   "result_serialized", "result_sent",
                                   "result_received", "result_decoded", "succeeded",
                                   "lost", "timed_out", "failed", "stale"}
    /\ \A a \in AttemptIds :
          resultWireState[a] = "none" => resultEnvelope[a] = "none"
    /\ \A a \in AttemptIds :
          resultWireState[a] = "queued" =>
              resultEnvelope[a] = "valid" /\ attemptState[a] = "result_serialized"
    /\ \A a \in AttemptIds :
          resultWireState[a] = "sent" =>
              resultEnvelope[a] = "valid" /\ attemptState[a] = "result_sent"
    /\ \A a \in AttemptIds :
          resultWireState[a] = "received" =>
              resultEnvelope[a] = "valid" /\ attemptState[a] = "result_received"
    /\ \A a \in AttemptIds :
          resultWireState[a] = "duplicate" =>
              resultEnvelope[a] = "valid" /\ attemptState[a] = "result_received"
    /\ \A a \in AttemptIds :
          resultWireState[a] = "acknowledged" =>
              resultEnvelope[a] = "valid" /\ attemptState[a] = "result_received"
    /\ \A a \in AttemptIds :
          resultWireState[a] = "consumed" =>
              resultEnvelope[a] = "valid" /\
              attemptState[a] \in {"result_decoded", "succeeded", "lost", "stale"}

MessageCorrelationSafety ==
    /\ \A a \in AttemptIds : taskWireState[a] \in
          {"queued", "sent", "received", "duplicate", "acknowledged", "consumed"} =>
          currentAttempt[a[1]] = a[2] \/
          attemptState[a] \in {"succeeded", "failed", "timed_out", "lost", "stale"}
    /\ \A a \in AttemptIds : resultWireState[a] \in
          {"queued", "sent", "received", "duplicate", "acknowledged", "consumed"} =>
          currentAttempt[a[1]] = a[2] \/
          attemptState[a] \in {"succeeded", "failed", "timed_out", "lost", "stale"}

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

RegistrationSafety ==
    \A w \in WORKERS : workerState[w] = "unregistered" =>
        workerAttempt[w] = NoAttempt

ValidRunningAttempt ==
    \A a \in AttemptIds : attemptState[a] = "running" =>
        attemptExecutor[a] \in EXECUTORS /\ attemptWorker[a] \in WORKERS

NoRunningOnDownExecutor ==
    \A a \in AttemptIds : attemptState[a] = "running" =>
        executorState[attemptExecutor[a]] \in {"up", "draining"}

ExecutorDrainSafety ==
    \A a \in AttemptIds : attemptState[a] = "submitted" =>
        executorState[attemptExecutor[a]] \in {"up", "draining"}

AttemptIdentity ==
    \A t \in TASKS : currentAttempt[t] # -1 =>
        attemptState[<<t, currentAttempt[t]>>] # "absent"

SubmitSafety ==
    \A a \in AttemptIds :
      attemptState[a] \in {"submitted", "serialized", "sent", "received", "decoded",
                            "dispatched", "running", "result_serialized", "result_sent",
                            "result_received", "result_decoded", "succeeded"} =>
          attemptExecutor[a] \in SUBMITTABLE_EXECUTORS

ProviderExecutorConsistency ==
    /\ \A e \in EXECUTORS : providerState[e] = "active" =>
          executorState[e] \in {"up", "draining"} /\ providerBlocks[e] > 0
    /\ \A e \in EXECUTORS : providerState[e] = "failed" =>
          providerBlocks[e] = 0 /\ providerTarget[e] = 0
    /\ \A e \in EXECUTORS : providerState[e] = "cancelled" =>
          providerBlocks[e] = 0 /\ providerTarget[e] = 0

JoinSafety ==
    /\ \A t \in JOIN_TASKS : taskState[t] = "joining" =>
          futureState[t] = "unresolved" /\ outputs[t] = "join-handle"
    /\ \A t \in JOIN_TASKS : joinObserved[t] \subseteq JoinDeps(t)
    /\ \A t \in JOIN_TASKS : taskState[t] = "succeeded" =>
          JoinDeps(t) \subseteq {i \in TASKS : futureState[i] = "resolved"}
          /\ outputs[t] = "join-result"
    /\ \A t \in JOIN_INVALID : taskState[t] = "failed" =>
          futureState[t] = "rejected" /\ t \in rejected

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

ResultSerializationSafety ==
    \A a \in AttemptIds :
      attemptState[a] \in {"result_serialized", "result_sent", "result_received",
                            "result_decoded", "succeeded"} => ResultSerializable(a[1])

ObjectGraphSafety ==
    /\ \A a \in AttemptIds : taskEnvelope[a] = "valid" =>
          ObjectGraphSerializable(a[1])
    /\ \A t \in TASKS : ObjectPayload(t) \subseteq OBJECTS

DataReadinessSafety ==
    \A t \in TASKS : taskState[t] \in {"ready", "queued", "running"} =>
        dataState[t] \in {"available", "transferred"}

FileTransferSafety ==
    \A t \in TASKS : dataState[t] \in {"stageout", "stageout_chunk1",
                                         "stageout_chunk2", "transferred"} =>
        t \in FILE_OUTPUTS /\ taskState[t] \in {"succeeded", "memoized"}

FileStagingSafety ==
    \A t \in TASKS : dataState[t] = "staging_corrupt" =>
        taskState[t] = "staging" /\ futureState[t] = "unresolved"

FileContentSafety ==
    /\ \A t \in TASKS : dataState[t] = "transferred" =>
          (IF dataState[t] = "transferred" THEN ContentToken(t) ELSE "none") = ContentToken(t)
    /\ \A t \in TASKS : dataState[t] \in {"stageout", "stageout_chunk1",
                                             "stageout_chunk2"} =>
          t \in FILE_OUTPUTS /\ outputs[t] \in {"result", "join-result", "memoized-output"}

FileChunkSafety ==
    /\ \A t \in TASKS : dataState[t] \in {"stageout_chunk1", "stageout_chunk2"} =>
          t \in FILE_OUTPUTS /\ taskState[t] \in {"succeeded", "memoized"}
    /\ \A t \in TASKS : dataState[t] \in {"stageout_chunk1_corrupt",
                                             "stageout_chunk2_corrupt", "corrupt"} =>
          t \in FILE_OUTPUTS /\ taskState[t] \in {"succeeded", "memoized"}

FileCorruptionSafety ==
    \A t \in TASKS : dataState[t] \in {"corrupt", "stageout_chunk1_corrupt",
                                         "stageout_chunk2_corrupt"} =>
        t \in FILE_OUTPUTS /\ taskState[t] \in {"succeeded", "memoized"}

TimeSafety ==
    /\ \A a \in AttemptIds : attemptState[a] = "running" =>
          attemptStart[a] \in 0..clock
    /\ \A w \in WORKERS : lastHeartbeat[w] <= clock

MonitoringConsistency ==
    /\ \A t \in TASKS : monitoringState[t].status = "succeeded" =>
          taskState[t] \in {"succeeded", "memoized"}
    /\ \A t \in TASKS : monitoringState[t].status = "memoized" =>
          taskState[t] = "memoized"
    /\ \A t \in TASKS : monitoringState[t].status = "failed" =>
          taskState[t] = "failed"
MonitoringDatabaseSafety ==
    /\ \A t \in TASKS : monitoringState[t].version = 0 =>
          monitoringState[t].status \in {"none", "write_failed"}
    /\ \A t \in TASKS : monitoringState[t].status = "none" =>
          monitoringState[t].version = 0

EventuallySettled ==
    \A t \in TASKS : <> (taskState[t] \in {"succeeded", "memoized", "failed"})

=============================================================================
