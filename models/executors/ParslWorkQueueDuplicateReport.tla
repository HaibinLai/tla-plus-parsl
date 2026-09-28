--------------------------- MODULE ParslWorkQueueDuplicateReport ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A stale/duplicate WorkQueue collector report model.
 *
 * The collector removes a Future from ``tasks`` before decoding a report.
 * A duplicate or late report for the same executor id therefore reaches
 * ``tasks.pop`` with no entry.  The current implementation lets KeyError
 * escape, exits the collector, and fails unrelated outstanding Futures in
 * its finally block.  USE_FIXED models the candidate stale-report guard.
 ***************************************************************************)

CONSTANT USE_FIXED
TASKS == {"T1", "T2"}
States == {"pending", "done", "failed"}

VARIABLES active, state, collectorAlive, staleSeen
vars == <<active, state, collectorAlive, staleSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ active = TASKS
    /\ state = [t \in TASKS |-> "pending"]
    /\ collectorAlive = TRUE
    /\ staleSeen = FALSE

Report(t) ==
    /\ t \in TASKS
    /\ collectorAlive
    /\ IF t \in active
          THEN /\ active' = active \ {t}
               /\ state' = [state EXCEPT ![t] = "done"]
               /\ UNCHANGED <<collectorAlive, staleSeen>>
          ELSE IF USE_FIXED
               THEN /\ UNCHANGED <<active, state, collectorAlive>>
                    /\ staleSeen' = TRUE
               ELSE /\ collectorAlive' = FALSE
                    /\ staleSeen' = TRUE
                    /\ UNCHANGED <<active, state>>

Cleanup ==
    /\ ~collectorAlive
    /\ state' = [t \in TASKS |-> IF t \in active THEN "failed" ELSE state[t]]
    /\ active' = {}
    /\ UNCHANGED <<collectorAlive, staleSeen>>

Next ==
    \/ \E t \in TASKS : Report(t)
    \/ Cleanup
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ active \subseteq TASKS
    /\ state \in [TASKS -> States]
    /\ collectorAlive \in BOOLEAN
    /\ staleSeen \in BOOLEAN

StaleReportSafety ==
    staleSeen => collectorAlive

UnrelatedTaskSafety ==
    staleSeen => \A t \in active : state[t] = "pending"

TerminalStability ==
    \A t \in TASKS : state[t] = "done" => t \notin active

=============================================================================
