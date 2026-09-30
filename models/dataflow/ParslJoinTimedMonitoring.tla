----------------------- MODULE ParslJoinTimedMonitoring -----------------------
EXTENDS Naturals

(***************************************************************************
 * Small timed join boundary.
 *
 * One inner Future feeds an outer join.  The inner physical attempt has a
 * deadline and remains in flight after manager expiry or timeout, allowing a
 * late result to race with join finalization and monitoring persistence.
 *************************************************************************** *)

CONSTANTS MAX_TIME, HEARTBEAT_TIMEOUT, TASK_TIMEOUT, MAX_CHUNK_REPAIRS, USE_FIXED
OuterStates == {"executing", "joining", "succeeded", "failed", "cancelled"}
InnerStates == {"pending", "running", "succeeded", "lost"}
ManagerStates == {"up", "expired"}
Causes == {"none", "timeout", "manager_lost"}
LateStates == {"none", "accepted", "stale"}
MonitorStates == {"none", "queued", "persisted"}
MonitorStatuses == {"none", "succeeded", "failed", "cancelled"}
Chunks == 1..2
ChunkStates == {"missing", "received"}
ChecksumStates == {"missing", "valid", "corrupt"}
Versions == 0..1

VARIABLES now, manager, lastHeartbeat, outer, inner, deadline, inFlight,
          cause, lateResult, chunkState, chunkChecksum, chunkRepairs, dataReady,
          sourceVersion, capturedVersion,
          cancelled,
          monitorState,
          monitorStatus, dbStatus
vars == <<now, manager, lastHeartbeat, outer, inner, deadline, inFlight,
           cause, lateResult, chunkState, chunkChecksum, chunkRepairs, dataReady,
           sourceVersion, capturedVersion,
           cancelled,
           monitorState,
           monitorStatus, dbStatus>>

Init ==
    /\ MAX_TIME >= 3
    /\ HEARTBEAT_TIMEOUT > 0
    /\ TASK_TIMEOUT > 0
    /\ MAX_CHUNK_REPAIRS >= 0
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ manager = "up"
    /\ lastHeartbeat = 0
    /\ outer = "executing"
    /\ inner = "pending"
    /\ deadline = 0
    /\ inFlight = FALSE
    /\ cause = "none"
    /\ lateResult = "none"
    /\ chunkState = [c \in Chunks |-> "missing"]
    /\ chunkChecksum = [c \in Chunks |-> "missing"]
    /\ chunkRepairs = [c \in Chunks |-> 0]
    /\ dataReady = FALSE
    /\ sourceVersion = 0
    /\ capturedVersion = 0
    /\ cancelled = FALSE
    /\ monitorState = "none"
    /\ monitorStatus = "none"
    /\ dbStatus = "none"

Tick ==
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ UNCHANGED <<manager, lastHeartbeat, outer, inner, deadline, inFlight,
                    cause, lateResult, monitorState, monitorStatus, dbStatus>>

Heartbeat ==
    /\ manager = "up"
    /\ lastHeartbeat' = now
    /\ UNCHANGED <<now, manager, outer, inner, deadline, inFlight, cause,
                    lateResult, monitorState, monitorStatus, dbStatus>>

ReturnJoin ==
    /\ outer = "executing"
    /\ outer' = "joining"
    /\ UNCHANGED <<now, manager, lastHeartbeat, inner, deadline, inFlight,
                    cause, lateResult, monitorState, monitorStatus, dbStatus>>

StageChunk(c) ==
    /\ c \in Chunks
    /\ chunkState[c] = "missing"
    /\ chunkState' = [chunkState EXCEPT ![c] = "received"]
    /\ chunkChecksum' = [chunkChecksum EXCEPT ![c] = "valid"]
    /\ capturedVersion' =
          IF \A d \in Chunks: chunkState[d] = "missing"
          THEN sourceVersion
          ELSE capturedVersion
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, inner, deadline,
                    inFlight, cause, lateResult, chunkRepairs, dataReady,
                    sourceVersion,
                    cancelled,
                    monitorState,
                    monitorStatus, dbStatus>>

CorruptChunk(c) ==
    /\ ~dataReady
    /\ c \in Chunks
    /\ chunkState[c] = "received"
    /\ chunkChecksum[c] = "valid"
    /\ chunkChecksum' = [chunkChecksum EXCEPT ![c] = "corrupt"]
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, inner, deadline,
                    inFlight, cause, lateResult, chunkState, chunkRepairs,
                    dataReady,
                    sourceVersion, capturedVersion,
                    cancelled,
                    monitorState, monitorStatus, dbStatus>>

RepairChunk(c) ==
    /\ c \in Chunks
    /\ chunkState[c] = "received"
    /\ chunkChecksum[c] = "corrupt"
    /\ chunkRepairs[c] < MAX_CHUNK_REPAIRS
    /\ chunkChecksum' = [chunkChecksum EXCEPT ![c] = "valid"]
    /\ chunkRepairs' = [chunkRepairs EXCEPT ![c] = @ + 1]
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, inner, deadline,
                    inFlight, cause, lateResult, chunkState, dataReady,
                    sourceVersion, capturedVersion,
                    cancelled,
                    monitorState, monitorStatus, dbStatus>>

ChangeSource ==
    /\ ~dataReady
    /\ sourceVersion' = 1 - sourceVersion
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, inner, deadline,
                    inFlight, cause, lateResult, chunkState, chunkChecksum,
                    chunkRepairs, dataReady, capturedVersion,
                    cancelled,
                    monitorState, monitorStatus, dbStatus>>

PublishData ==
    /\ ~dataReady
    /\ \A c \in Chunks: chunkState[c] = "received"
    /\ IF USE_FIXED
          THEN \A c \in Chunks: chunkChecksum[c] = "valid"
          ELSE TRUE
    /\ IF USE_FIXED THEN capturedVersion = sourceVersion ELSE TRUE
    /\ dataReady' = TRUE
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, inner, deadline,
                    inFlight, cause, lateResult, chunkState, chunkChecksum,
                    chunkRepairs,
                    sourceVersion, capturedVersion,
                    cancelled,
                    monitorState,
                    monitorStatus, dbStatus>>

StartInner ==
    /\ outer = "joining"
    /\ inner = "pending"
    /\ dataReady
    /\ manager = "up"
    /\ inner' = "running"
    /\ deadline' = now + TASK_TIMEOUT
    /\ inFlight' = TRUE
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, cause, lateResult,
                    monitorState, monitorStatus, dbStatus>>

CancelOuter ==
    /\ outer \in {"executing", "joining"}
    /\ outer' = "cancelled"
    /\ cancelled' = TRUE
    /\ inner' = IF inner = "running" THEN "lost" ELSE inner
    /\ inFlight' = FALSE
    /\ UNCHANGED <<now, manager, lastHeartbeat, deadline, cause, lateResult,
                    chunkState, chunkChecksum, chunkRepairs, dataReady,
                    sourceVersion, capturedVersion, monitorState,
                    monitorStatus, dbStatus>>

CompleteInner ==
    /\ inner = "running"
    /\ inFlight
    /\ manager = "up"
    /\ now < deadline
    /\ inner' = "succeeded"
    /\ inFlight' = FALSE
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, deadline, cause,
                    lateResult, monitorState, monitorStatus, dbStatus>>

TimeoutInner ==
    /\ inner = "running"
    /\ inFlight
    /\ now >= deadline
    /\ inner' = "lost"
    /\ cause' = "timeout"
    /\ inFlight' = FALSE
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, deadline, lateResult,
                    monitorState, monitorStatus, dbStatus>>

ExpireManager ==
    /\ manager = "up"
    /\ now - lastHeartbeat >= HEARTBEAT_TIMEOUT
    /\ manager' = "expired"
    /\ inner' = IF inner = "running" THEN "lost" ELSE inner
    /\ cause' = IF inner = "running" THEN "manager_lost" ELSE cause
    /\ inFlight' = IF inner = "running" THEN FALSE ELSE inFlight
    /\ UNCHANGED <<now, lastHeartbeat, outer, deadline, lateResult,
                    monitorState, monitorStatus, dbStatus>>

LateComplete ==
    /\ inner = "lost"
    /\ IF USE_FIXED
          THEN /\ lateResult' = "stale"
               /\ UNCHANGED <<inner, outer>>
          ELSE /\ inner' = "succeeded"
               /\ outer' = IF cancelled THEN "succeeded" ELSE outer
               /\ lateResult' = "accepted"
    /\ UNCHANGED <<now, manager, lastHeartbeat, deadline, inFlight,
                    cause, monitorState, monitorStatus, dbStatus,
                    cancelled, chunkState, chunkChecksum, chunkRepairs,
                    dataReady, sourceVersion, capturedVersion>>

FinalizeJoin ==
    /\ outer = "joining"
    /\ inner \in {"succeeded", "lost"}
    /\ outer' = IF inner = "succeeded" THEN "succeeded" ELSE "failed"
    /\ UNCHANGED <<now, manager, lastHeartbeat, inner, deadline, inFlight,
                    cause, lateResult, monitorState, monitorStatus, dbStatus>>

EmitStatus ==
    /\ outer \in {"succeeded", "failed", "cancelled"}
    /\ monitorState = "none"
    /\ monitorState' = "queued"
    /\ monitorStatus' = outer
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, inner, deadline,
                    inFlight, cause, lateResult, dbStatus>>

PersistStatus ==
    /\ monitorState = "queued"
    /\ monitorState' = "persisted"
    /\ dbStatus' = monitorStatus
    /\ UNCHANGED <<now, manager, lastHeartbeat, outer, inner, deadline,
                    inFlight, cause, lateResult, monitorStatus>>

CoreNext ==
    \/ Tick \/ Heartbeat \/ ReturnJoin \/ StartInner \/ CompleteInner
    \/ TimeoutInner \/ ExpireManager \/ LateComplete \/ FinalizeJoin
    \/ EmitStatus \/ PersistStatus
    \/ UNCHANGED vars

Next ==
    \/ (CoreNext /\ UNCHANGED <<chunkState, chunkChecksum, chunkRepairs,
                                  dataReady, sourceVersion, capturedVersion,
                                  cancelled>>)
    \/ CancelOuter
    \/ \E c \in Chunks: StageChunk(c)
    \/ \E c \in Chunks: CorruptChunk(c) \/ RepairChunk(c)
    \/ ChangeSource
    \/ PublishData

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ manager \in ManagerStates
    /\ lastHeartbeat \in 0..MAX_TIME
    /\ outer \in OuterStates
    /\ inner \in InnerStates
    /\ deadline \in 0..(MAX_TIME + TASK_TIMEOUT)
    /\ inFlight \in BOOLEAN
    /\ cause \in Causes
    /\ lateResult \in LateStates
    /\ chunkState \in [Chunks -> ChunkStates]
    /\ chunkChecksum \in [Chunks -> ChecksumStates]
    /\ chunkRepairs \in [Chunks -> 0..MAX_CHUNK_REPAIRS]
    /\ dataReady \in BOOLEAN
    /\ sourceVersion \in Versions
    /\ capturedVersion \in Versions
    /\ cancelled \in BOOLEAN
    /\ monitorState \in MonitorStates
    /\ monitorStatus \in MonitorStatuses
    /\ dbStatus \in MonitorStatuses

JoinSafety == outer = "succeeded" => inner = "succeeded"
DataReadinessSafety == inner \in {"running", "succeeded"} => dataReady
ContentSafety == dataReady => \A c \in Chunks: chunkChecksum[c] = "valid"
StaleDataSafety == dataReady => capturedVersion = sourceVersion
ChunkRepairBound == \A c \in Chunks: chunkRepairs[c] <= MAX_CHUNK_REPAIRS
TerminalCauseSafety == cause # "none" => inner # "succeeded"
StaleResultSafety == lateResult = "accepted" => ~USE_FIXED
DatabaseSafety ==
    /\ dbStatus = "succeeded" => outer = "succeeded"
    /\ dbStatus = "failed" => outer = "failed"
    /\ dbStatus = "cancelled" => outer = "cancelled"

CancellationSafety == cancelled => outer = "cancelled"

=============================================================================
