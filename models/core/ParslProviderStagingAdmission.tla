------------------------- MODULE ParslProviderStagingAdmission -------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Small provider + staging + task-admission abstraction.
 *
 * The model deliberately keeps only the boundaries needed to reason about
 * admission: a provider block must be active, and every file chunk must be
 * copied before the DataFuture becomes ready.  A scale-in can withdraw the
 * only active block while a task is running; the fixed branch makes that
 * physical loss visible as retry_wait instead of leaving a running task with
 * no capacity.
 ***************************************************************************)

CONSTANTS CHUNKS, USE_FIXED, MAX_RETRIES

ProviderStates == {"down", "pending", "active", "failed"}
TransferStates == {"idle", "copying", "published"}
FutureStates == {"unresolved", "ready"}
TaskStates == {"pending", "running", "retry_wait", "done"}
MonitorStates == {"none", "running", "failed", "succeeded"}

VARIABLES blocks, provider, transfer, source, destination, dataFuture,
          task, attempt, monitor
vars == <<blocks, provider, transfer, source, destination, dataFuture,
           task, attempt, monitor>>

Init ==
    /\ CHUNKS # {}
    /\ CHUNKS \subseteq STRING
    /\ MAX_RETRIES >= 0
    /\ blocks = 0
    /\ provider = "down"
    /\ transfer = "idle"
    /\ source = [c \in CHUNKS |-> "payload"]
    /\ destination = [c \in CHUNKS |-> "absent"]
    /\ dataFuture = "unresolved"
    /\ task = "pending"
    /\ attempt = 0
    /\ monitor = "none"

RequestBlock ==
    /\ provider \in {"down", "failed"}
    /\ blocks = 0
    /\ blocks' = 1
    /\ provider' = "pending"
    /\ UNCHANGED <<transfer, source, destination, dataFuture,
                    task, attempt, monitor>>

ProvisionSucceeds ==
    /\ provider = "pending"
    /\ provider' = "active"
    /\ UNCHANGED <<blocks, transfer, source, destination, dataFuture,
                    task, attempt, monitor>>

ProvisionFails ==
    /\ provider = "pending"
    /\ provider' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED <<blocks, transfer, source, destination, dataFuture,
                    task, attempt>>

StartStage ==
    /\ transfer = "idle"
    /\ transfer' = "copying"
    /\ UNCHANGED <<blocks, provider, source, destination, dataFuture,
                    task, attempt, monitor>>

CopyChunk(c) ==
    /\ transfer = "copying"
    /\ c \in CHUNKS
    /\ destination[c] = "absent"
    /\ destination' = [destination EXCEPT ![c] = source[c]]
    /\ UNCHANGED <<blocks, provider, transfer, source, dataFuture,
                    task, attempt, monitor>>

AllCopied == \A c \in CHUNKS : destination[c] = source[c]
SomeCopied == \E c \in CHUNKS : destination[c] = source[c]

PublishStage ==
    /\ transfer = "copying"
    /\ IF USE_FIXED THEN AllCopied ELSE SomeCopied
    /\ transfer' = "published"
    /\ dataFuture' = "ready"
    /\ UNCHANGED <<blocks, provider, source, destination,
                    task, attempt, monitor>>

SubmitTask ==
    /\ task = "pending"
    /\ provider = "active"
    /\ blocks > 0
    /\ IF USE_FIXED THEN dataFuture = "ready" ELSE TRUE
    /\ task' = "running"
    /\ monitor' = "running"
    /\ UNCHANGED <<blocks, provider, transfer, source, destination,
                    dataFuture, attempt>>

ScaleIn ==
    /\ provider = "active"
    /\ blocks > 0
    /\ blocks' = blocks - 1
    /\ provider' = IF blocks' = 0 THEN "down" ELSE "active"
    /\ IF USE_FIXED /\ task = "running"
          THEN /\ task' = "retry_wait"
               /\ monitor' = "failed"
          ELSE /\ UNCHANGED <<task, monitor>>
    /\ UNCHANGED <<transfer, source, destination, dataFuture, attempt>>

RetryTask ==
    /\ task = "retry_wait"
    /\ attempt < MAX_RETRIES
    /\ task' = "pending"
    /\ attempt' = attempt + 1
    /\ UNCHANGED <<blocks, provider, transfer, source, destination,
                    dataFuture, monitor>>

CompleteTask ==
    /\ task = "running"
    /\ provider = "active"
    /\ blocks > 0
    /\ task' = "done"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<blocks, provider, transfer, source, destination,
                    dataFuture, attempt>>

Next ==
    \/ RequestBlock
    \/ ProvisionSucceeds
    \/ ProvisionFails
    \/ StartStage
    \/ \E c \in CHUNKS : CopyChunk(c)
    \/ PublishStage
    \/ SubmitTask
    \/ ScaleIn
    \/ RetryTask
    \/ CompleteTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ CHUNKS \subseteq STRING
    /\ blocks \in 0..1
    /\ provider \in ProviderStates
    /\ transfer \in TransferStates
    /\ source \in [CHUNKS -> STRING]
    /\ destination \in [CHUNKS -> STRING]
    /\ dataFuture \in FutureStates
    /\ task \in TaskStates
    /\ attempt \in 0..MAX_RETRIES
    /\ monitor \in MonitorStates

AdmissionSafety ==
    task = "running"
        => /\ provider = "active"
           /\ blocks > 0
           /\ dataFuture = "ready"

PublicationSafety ==
    dataFuture = "ready"
        => /\ transfer = "published"
           /\ AllCopied

RetryBound == attempt <= MAX_RETRIES

TerminalMonitoring == monitor = "succeeded" => task = "done"

=============================================================================
