--------------------------- MODULE ParslWorkQueueResults ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * WorkQueue collector result handling.
 *
 * The WorkQueue collector receives either a result-file report or an error
 * report.  A result file may deserialize to a value, deserialize to an
 * exception produced by the app, or fail to deserialize at all.  When the
 * collector exits, its finally block fails every Future still outstanding.
 ***************************************************************************)

TASKS == {"T1", "T2"}
TaskStates == {"absent", "pending", "reported", "done", "failed"}
FileKinds == {"none", "valid", "corrupt", "exception"}

VARIABLES taskState, fileKind, terminalSnapshot, collectorAlive, cleanupDone
vars == <<taskState, fileKind, terminalSnapshot, collectorAlive, cleanupDone>>

Init ==
    /\ taskState = [t \in TASKS |-> "absent"]
    /\ fileKind = [t \in TASKS |-> "none"]
    /\ terminalSnapshot = [t \in TASKS |-> "none"]
    /\ collectorAlive = TRUE
    /\ cleanupDone = FALSE

Submit(t) ==
    /\ t \in TASKS
    /\ collectorAlive
    /\ taskState[t] = "absent"
    /\ taskState' = [taskState EXCEPT ![t] = "pending"]
    /\ UNCHANGED <<fileKind, terminalSnapshot, collectorAlive, cleanupDone>>

Report(t, kind) ==
    /\ t \in TASKS
    /\ collectorAlive
    /\ taskState[t] = "pending"
    /\ kind \in FileKinds
    /\ taskState' = [taskState EXCEPT ![t] = "reported"]
    /\ fileKind' = [fileKind EXCEPT ![t] = kind]
    /\ UNCHANGED <<terminalSnapshot, collectorAlive, cleanupDone>>

DecodeReport(t) ==
    /\ t \in TASKS
    /\ collectorAlive
    /\ taskState[t] = "reported"
    /\ taskState' = [taskState EXCEPT ![t] =
          IF fileKind[t] = "valid" THEN "done" ELSE "failed"]
    /\ terminalSnapshot' = [terminalSnapshot EXCEPT ![t] =
          IF fileKind[t] = "valid" THEN "done" ELSE "failed"]
    /\ UNCHANGED <<fileKind, collectorAlive, cleanupDone>>

StopCollector ==
    /\ collectorAlive
    /\ collectorAlive' = FALSE
    /\ cleanupDone' = FALSE
    /\ UNCHANGED <<taskState, fileKind, terminalSnapshot>>

CollectorFinallyFailsOutstanding ==
    /\ ~collectorAlive
    /\ ~cleanupDone
    /\ taskState' = [t \in TASKS |->
          IF taskState[t] \in {"absent", "pending", "reported"}
          THEN "failed" ELSE taskState[t]]
    /\ terminalSnapshot' = [t \in TASKS |->
          IF taskState[t] \in {"absent", "pending", "reported"}
          THEN "failed" ELSE terminalSnapshot[t]]
    /\ cleanupDone' = TRUE
    /\ UNCHANGED <<fileKind, collectorAlive>>

Next ==
    \/ \E t \in TASKS : Submit(t)
    \/ \E t \in TASKS, kind \in FileKinds : Report(t, kind)
    \/ \E t \in TASKS : DecodeReport(t)
    \/ StopCollector
    \/ CollectorFinallyFailsOutstanding
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in [TASKS -> TaskStates]
    /\ fileKind \in [TASKS -> FileKinds]
    /\ terminalSnapshot \in [TASKS -> (TaskStates \cup {"none"})]
    /\ collectorAlive \in BOOLEAN
    /\ cleanupDone \in BOOLEAN

ResultSafety ==
    \A t \in TASKS : taskState[t] = "done" => fileKind[t] = "valid"

TerminalStability ==
    \A t \in TASKS : terminalSnapshot[t] # "none"
        => taskState[t] = terminalSnapshot[t]

CollectorCleanupSafety ==
    cleanupDone => \A t \in TASKS : taskState[t] \in {"done", "failed"}

NoDecodeAfterCollectorExit ==
    cleanupDone =>
        \A t \in TASKS : taskState[t] # "reported"

=============================================================================
