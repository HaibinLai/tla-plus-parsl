---------------------- MODULE ParslConcurrentTimeouts ----------------------
EXTENDS Naturals

(***************************************************************************
 * Independent timeout clocks for concurrent tasks.
 *
 * A and B have different timeout horizons.  A timeout advances only that
 * task's physical attempt; late results are correlated per task and cannot
 * resolve the other task's Future.
 ***************************************************************************)

CONSTANT USE_FIXED
Tasks == {"A", "B"}
Limit(t) == IF t = "A" THEN 1 ELSE 2

VARIABLES age, attempt, physical, future, late, crossResolved
vars == <<age, attempt, physical, future, late, crossResolved>>

Init ==
    /\ age = [t \in Tasks |-> 0]
    /\ attempt = [t \in Tasks |-> 0]
    /\ physical = [t \in Tasks |-> "running"]
    /\ future = [t \in Tasks |-> "unresolved"]
    /\ late = [t \in Tasks |-> FALSE]
    /\ crossResolved = FALSE

Tick(t) ==
    /\ t \in Tasks
    /\ physical[t] = "running"
    /\ age[t] < Limit(t)
    /\ age' = [age EXCEPT ![t] = @ + 1]
    /\ UNCHANGED <<attempt, physical, future, late, crossResolved>>

Timeout(t) ==
    /\ t \in Tasks
    /\ physical[t] = "running"
    /\ age[t] = Limit(t)
    /\ attempt[t] = 0
    /\ age' = [age EXCEPT ![t] = 0]
    /\ attempt' = [attempt EXCEPT ![t] = 1]
    /\ UNCHANGED <<physical, future, late, crossResolved>>

LateResult(t, target) ==
    /\ t \in Tasks
    /\ target \in Tasks
    /\ attempt[t] = 1
    /\ physical[t] = "running"
    /\ late' = [late EXCEPT ![t] = TRUE]
    /\ IF USE_FIXED
          THEN /\ future' = future
               /\ crossResolved' = crossResolved
          ELSE /\ IF target = t
                     THEN /\ future' = [future EXCEPT ![t] = "resolved"]
                          /\ crossResolved' = crossResolved
                     ELSE /\ future' = [future EXCEPT ![target] = "resolved"]
                          /\ crossResolved' = TRUE
    /\ UNCHANGED <<age, attempt, physical>>

Complete(t) ==
    /\ t \in Tasks
    /\ attempt[t] = 1
    /\ physical[t] = "running"
    /\ physical' = [physical EXCEPT ![t] = "succeeded"]
    /\ future' = [future EXCEPT ![t] = "resolved"]
    /\ UNCHANGED <<age, attempt, late, crossResolved>>

Next ==
    \/ \E t \in Tasks : Tick(t) \/ Timeout(t) \/ Complete(t)
    \/ \E t \in Tasks, target \in Tasks : LateResult(t, target)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ age \in [Tasks -> 0..2]
    /\ attempt \in [Tasks -> 0..1]
    /\ physical \in [Tasks -> {"running", "succeeded"}]
    /\ future \in [Tasks -> {"unresolved", "resolved"}]
    /\ late \in [Tasks -> BOOLEAN]
    /\ crossResolved \in BOOLEAN

AttemptBoundSafety == \A t \in Tasks : attempt[t] <= 1

IndependentTimeoutSafety ==
    \A t \in Tasks : future[t] = "resolved" => physical[t] = "succeeded" \/ late[t]

CrossTaskSafety ==
    ~crossResolved

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    AttemptBoundSafety
    IndependentTimeoutSafety
    CrossTaskSafety
