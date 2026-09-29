--------------------------- MODULE ParslHtexSubmitCounterRace ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Two concurrent HTEX submit_payload calls update _task_counter in Python
 * as a read/modify/write sequence. Without serialization both calls can
 * observe the same counter value and overwrite one entry in tasks.
 ***************************************************************************)

CONSTANT USE_FIXED
Threads == {"A", "B"}
Phases == {"ready", "read", "committed"}
Other(t) == IF t = "A" THEN "B" ELSE "A"

VARIABLES phase, seen, counter, taskKeys
vars == <<phase, seen, counter, taskKeys>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = [t \in Threads |-> "ready"]
    /\ seen = [t \in Threads |-> 0]
    /\ counter = 0
    /\ taskKeys = {}

BeginRead(t) ==
    /\ t \in Threads
    /\ phase[t] = "ready"
    /\ (USE_FIXED => phase[Other(t)] # "read")
    /\ phase' = [phase EXCEPT ![t] = "read"]
    /\ seen' = [seen EXCEPT ![t] = counter]
    /\ UNCHANGED <<counter, taskKeys>>

Commit(t) ==
    /\ t \in Threads
    /\ phase[t] = "read"
    /\ (USE_FIXED => phase[Other(t)] # "read")
    /\ phase' = [phase EXCEPT ![t] = "committed"]
    /\ counter' = counter + 1
    /\ taskKeys' = taskKeys \cup {seen[t] + 1}
    /\ UNCHANGED seen

Next ==
    \/ \E t \in Threads : BeginRead(t)
    \/ \E t \in Threads : Commit(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in [Threads -> Phases]
    /\ seen \in [Threads -> Nat]
    /\ counter \in Nat
    /\ taskKeys \subseteq Nat

NoDuplicateTaskIds == Cardinality(taskKeys) = counter

=============================================================================
