------------------------- MODULE ParslJoinMultiOutputMonitoring -------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Positive composition of list-valued join, multi-output stage-out, and
 * monitoring persistence.
 *
 * The outer join may become logically terminal only after both inner Futures
 * complete.  Each output then has an independent stage-out/DataFuture.  The
 * terminal monitoring row is published only after both output Futures are
 * ready and observed.
 ***************************************************************************)

INNER == {"a", "b"}
OUTPUTS == {"o1", "o2"}
InnerStates == {"pending", "done"}
TransferStates == {"idle", "sending", "ready"}
OutputStates == {"unresolved", "ready"}
OuterStates == {"joining", "succeeded"}
MonitorStates == {"none", "queued", "persisted"}

VARIABLES inner, outer, transfer, output, observed, monitor, dbStatus
vars == <<inner, outer, transfer, output, observed, monitor, dbStatus>>

Init ==
    /\ inner = [i \in INNER |-> "pending"]
    /\ outer = "joining"
    /\ transfer = [o \in OUTPUTS |-> "idle"]
    /\ output = [o \in OUTPUTS |-> "unresolved"]
    /\ observed = [o \in OUTPUTS |-> FALSE]
    /\ monitor = "none"
    /\ dbStatus = "none"

CompleteInner(i) ==
    /\ i \in INNER
    /\ inner[i] = "pending"
    /\ inner' = [inner EXCEPT ![i] = "done"]
    /\ UNCHANGED <<outer, transfer, output, observed, monitor, dbStatus>>

FinalizeJoin ==
    /\ outer = "joining"
    /\ \A i \in INNER : inner[i] = "done"
    /\ outer' = "succeeded"
    /\ UNCHANGED <<inner, transfer, output, observed, monitor, dbStatus>>

BeginTransfer(o) ==
    /\ o \in OUTPUTS
    /\ outer = "succeeded"
    /\ transfer[o] = "idle"
    /\ transfer' = [transfer EXCEPT ![o] = "sending"]
    /\ UNCHANGED <<inner, outer, output, observed, monitor, dbStatus>>

CompleteTransfer(o) ==
    /\ o \in OUTPUTS
    /\ transfer[o] = "sending"
    /\ transfer' = [transfer EXCEPT ![o] = "ready"]
    /\ UNCHANGED <<inner, outer, output, observed, monitor, dbStatus>>

PublishOutput(o) ==
    /\ o \in OUTPUTS
    /\ transfer[o] = "ready"
    /\ output' = [output EXCEPT ![o] = "ready"]
    /\ UNCHANGED <<inner, outer, transfer, observed, monitor, dbStatus>>

ObserveOutput(o) ==
    /\ o \in OUTPUTS
    /\ output[o] = "ready"
    /\ observed' = [observed EXCEPT ![o] = TRUE]
    /\ UNCHANGED <<inner, outer, transfer, output, monitor, dbStatus>>

QueueMonitoring ==
    /\ monitor = "none"
    /\ outer = "succeeded"
    /\ (\A o \in OUTPUTS : output[o] = "ready" /\ observed[o])
    /\ monitor' = "queued"
    /\ UNCHANGED <<inner, outer, transfer, output, observed, dbStatus>>

PersistMonitoring ==
    /\ monitor = "queued"
    /\ monitor' = "persisted"
    /\ dbStatus' = "succeeded"
    /\ UNCHANGED <<inner, outer, transfer, output, observed>>

Next ==
    \/ \E i \in INNER : CompleteInner(i)
    \/ FinalizeJoin
    \/ \E o \in OUTPUTS : BeginTransfer(o) \/ CompleteTransfer(o)
    \/ \E o \in OUTPUTS : PublishOutput(o) \/ ObserveOutput(o)
    \/ QueueMonitoring
    \/ PersistMonitoring
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ inner \in [INNER -> InnerStates]
    /\ outer \in OuterStates
    /\ transfer \in [OUTPUTS -> TransferStates]
    /\ output \in [OUTPUTS -> OutputStates]
    /\ observed \in [OUTPUTS -> BOOLEAN]
    /\ monitor \in MonitorStates
    /\ dbStatus \in {"none", "succeeded"}

JoinDependencySafety ==
    outer = "succeeded" => \A i \in INNER : inner[i] = "done"

OutputPublicationSafety ==
    \A o \in OUTPUTS : output[o] = "ready" =>
        /\ outer = "succeeded"
        /\ transfer[o] = "ready"

JoinOutputCompleteness ==
    monitor \in {"queued", "persisted"} =>
        \A o \in OUTPUTS : output[o] = "ready" /\ observed[o]

MonitoringTerminalSafety ==
    monitor = "persisted" =>
        /\ outer = "succeeded"
        /\ dbStatus = "succeeded"

=============================================================================
