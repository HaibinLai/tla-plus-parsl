--------------------------- MODULE ParslHeartbeatProvider ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Provider status versus HTEX manager heartbeat.
 *
 * A scheduler status of UNKNOWN is not itself a manager failure.  The
 * interchange removes a manager only when its heartbeat age crosses the
 * configured threshold; provider terminal states independently revoke the
 * block and lose its in-flight tasks.
 ***************************************************************************)

CONSTANTS HEARTBEAT_THRESHOLD, MAX_TIME, MAX_TASKS

ProviderStates == {"down", "pending", "running", "unknown", "completed", "failed", "timeout"}
ExecutorStates == {"down", "up", "failed"}
LostLimit == MAX_TASKS

VARIABLES providerState, executorState, managerReady, heartbeatAge,
          activeTasks, lost
vars == <<providerState, executorState, managerReady, heartbeatAge,
          activeTasks, lost>>

Init ==
    /\ HEARTBEAT_THRESHOLD > 0
    /\ MAX_TIME >= HEARTBEAT_THRESHOLD
    /\ MAX_TASKS > 0
    /\ providerState = "down"
    /\ executorState = "down"
    /\ managerReady = FALSE
    /\ heartbeatAge = 0
    /\ activeTasks = 0
    /\ lost = 0

StartExecutor ==
    /\ executorState = "down"
    /\ executorState' = "up"
    /\ UNCHANGED <<providerState, managerReady, heartbeatAge,
                    activeTasks, lost>>

RequestBlock ==
    /\ executorState = "up"
    /\ providerState = "down"
    /\ providerState' = "pending"
    /\ UNCHANGED <<executorState, managerReady, heartbeatAge,
                    activeTasks, lost>>

ProviderStarts ==
    /\ providerState = "pending"
    /\ providerState' = "running"
    /\ UNCHANGED <<executorState, managerReady, heartbeatAge,
                    activeTasks, lost>>

RegisterManager ==
    /\ executorState = "up"
    /\ providerState = "running"
    /\ ~managerReady
    /\ managerReady' = TRUE
    /\ heartbeatAge' = 0
    /\ UNCHANGED <<providerState, executorState, activeTasks, lost>>

Heartbeat ==
    /\ managerReady
    /\ heartbeatAge' = 0
    /\ UNCHANGED <<providerState, executorState, managerReady,
                    activeTasks, lost>>

Tick ==
    /\ heartbeatAge < HEARTBEAT_THRESHOLD
    /\ heartbeatAge' = heartbeatAge + 1
    /\ UNCHANGED <<providerState, executorState, managerReady,
                    activeTasks, lost>>

SubmitTask ==
    /\ managerReady
    /\ activeTasks < MAX_TASKS
    /\ activeTasks' = activeTasks + 1
    /\ UNCHANGED <<providerState, executorState, managerReady,
                    heartbeatAge, lost>>

CompleteTask ==
    /\ activeTasks > 0
    /\ activeTasks' = activeTasks - 1
    /\ UNCHANGED <<providerState, executorState, managerReady,
                    heartbeatAge, lost>>

ProviderUnknown ==
    /\ providerState = "running"
    /\ providerState' = "unknown"
    /\ UNCHANGED <<executorState, managerReady, heartbeatAge,
                    activeTasks, lost>>

ProviderRecovers ==
    /\ providerState = "unknown"
    /\ providerState' = "running"
    /\ UNCHANGED <<executorState, managerReady, heartbeatAge,
                    activeTasks, lost>>

ExpireManager ==
    /\ managerReady
    /\ heartbeatAge >= HEARTBEAT_THRESHOLD
    /\ managerReady' = FALSE
    /\ lost' = IF lost + activeTasks > LostLimit
                 THEN LostLimit ELSE lost + activeTasks
    /\ activeTasks' = 0
    /\ UNCHANGED <<providerState, executorState, heartbeatAge>>

ProviderTerminal(kind) ==
    /\ providerState \in {"running", "unknown", "pending"}
    /\ kind \in {"completed", "failed", "timeout"}
    /\ providerState' = kind
    /\ executorState' = "failed"
    /\ managerReady' = FALSE
    /\ lost' = IF lost + activeTasks > LostLimit
                 THEN LostLimit ELSE lost + activeTasks
    /\ activeTasks' = 0
    /\ UNCHANGED heartbeatAge

Next ==
    \/ StartExecutor \/ RequestBlock \/ ProviderStarts
    \/ RegisterManager \/ Heartbeat \/ Tick
    \/ SubmitTask \/ CompleteTask
    \/ ProviderUnknown \/ ProviderRecovers
    \/ ExpireManager
    \/ \E kind \in {"completed", "failed", "timeout"} : ProviderTerminal(kind)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ providerState \in ProviderStates
    /\ executorState \in ExecutorStates
    /\ managerReady \in BOOLEAN
    /\ heartbeatAge \in 0..MAX_TIME
    /\ activeTasks \in 0..MAX_TASKS
    /\ lost \in 0..MAX_TASKS

HeartbeatAdmissionSafety ==
    managerReady => /\ executorState = "up"
                     /\ providerState \in {"running", "unknown"}
                     /\ heartbeatAge <= HEARTBEAT_THRESHOLD

TerminalCleanup ==
    providerState \in {"completed", "failed", "timeout"}
        => /\ ~managerReady
           /\ executorState = "failed"
           /\ activeTasks = 0

ManagerExpiryCleanup ==
    ~managerReady /\ executorState = "up" /\ providerState = "running"
        => activeTasks = 0 \/ heartbeatAge < HEARTBEAT_THRESHOLD

=============================================================================
