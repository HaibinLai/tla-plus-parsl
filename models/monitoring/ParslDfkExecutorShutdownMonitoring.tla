--------------------------- MODULE ParslDfkExecutorShutdownMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFlowKernel.cleanup and executor shutdown failure.
 *
 * DFK cleanup shuts down each executor before sending the final WORKFLOW_INFO
 * monitoring message and closing the monitoring hub.  A shutdown exception
 * can therefore abort cleanup before the workflow terminal record exists.
 * USE_FIXED models isolating executor shutdown failures and continuing to the
 * final monitoring path.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"idle", "executors", "finalizing", "closed", "aborted"}
ExecutorStates == {"running", "stopped", "failed"}
WorkflowStates == {"none", "sent"}
MonitorStates == {"open", "closed"}

VARIABLES phase, executor, workflow, monitor
vars == <<phase, executor, workflow, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "idle"
    /\ executor = "running"
    /\ workflow = "none"
    /\ monitor = "open"

BeginCleanup ==
    /\ phase = "idle"
    /\ phase' = "executors"
    /\ UNCHANGED <<executor, workflow, monitor>>

ExecutorShutdownSucceeds ==
    /\ phase = "executors"
    /\ executor = "running"
    /\ executor' = "stopped"
    /\ phase' = "finalizing"
    /\ UNCHANGED <<workflow, monitor>>

ExecutorShutdownFails ==
    /\ phase = "executors"
    /\ executor = "running"
    /\ executor' = "failed"
    /\ phase' = IF USE_FIXED THEN "finalizing" ELSE "aborted"
    /\ UNCHANGED <<workflow, monitor>>

SendWorkflowInfo ==
    /\ phase = "finalizing"
    /\ workflow = "none"
    /\ workflow' = "sent"
    /\ UNCHANGED <<phase, executor, monitor>>

CloseMonitoring ==
    /\ phase = "finalizing"
    /\ workflow = "sent"
    /\ monitor' = "closed"
    /\ phase' = "closed"
    /\ UNCHANGED <<executor, workflow>>

Next ==
    \/ BeginCleanup
    \/ ExecutorShutdownSucceeds
    \/ ExecutorShutdownFails
    \/ SendWorkflowInfo
    \/ CloseMonitoring
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ executor \in ExecutorStates
    /\ workflow \in WorkflowStates
    /\ monitor \in MonitorStates

NoAbortOnExecutorFailure ==
    executor = "failed" => phase # "aborted"

TerminalWorkflowSafety ==
    phase = "closed" => workflow = "sent" /\ monitor = "closed"

WorkflowBeforeMonitorClose ==
    monitor = "closed" => workflow = "sent"

=============================================================================
