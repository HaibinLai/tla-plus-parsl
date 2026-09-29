--------------------------- MODULE ParslJoinEndToEnd ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * End-to-end bounded join_app semantics.
 *
 * Logical inner Futures are separate from their physical attempts. The outer
 * join observes each logical Future once, but reconstructs the result from
 * the original sequence, so duplicate references remain duplicate positions.
 ***************************************************************************)

CONSTANT MAX_RETRIES

INNER == {"I1", "I2"}
Inputs == <<"I1", "I2", "I1">>
OuterStates == {"joining", "succeeded", "failed"}
LogicalStates == {"pending", "retry_wait", "succeeded", "failed", "cancelled"}
AttemptStates == {"absent", "running", "succeeded", "failed", "cancelled"}

VARIABLES outerState, logicalState, currentAttempt, attemptState,
          innerValue, observed, resultList
vars == <<outerState, logicalState, currentAttempt, attemptState,
           innerValue, observed, resultList>>

ExpectedResult == <<innerValue["I1"], innerValue["I2"], innerValue["I1"]>>
AllLogicalTerminal ==
    \A i \in INNER : logicalState[i] \in {"succeeded", "failed", "cancelled"}

Init ==
    /\ MAX_RETRIES >= 1
    /\ outerState = "joining"
    /\ logicalState = [i \in INNER |-> "pending"]
    /\ currentAttempt = [i \in INNER |-> 0]
    /\ attemptState = [i \in INNER |->
          [a \in 0..MAX_RETRIES |-> "absent"]]
    /\ innerValue = [i \in INNER |-> "unset"]
    /\ observed = {}
    /\ resultList = <<>>

StartAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "absent"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "running"]
    /\ UNCHANGED <<outerState, logicalState, currentAttempt,
                    innerValue, observed, resultList>>

CompleteAttempt(i, value) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "succeeded"]
    /\ logicalState' = [logicalState EXCEPT ![i] = "succeeded"]
    /\ innerValue' = [innerValue EXCEPT ![i] = value]
    /\ UNCHANGED <<outerState, currentAttempt, observed, resultList>>

FailAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "failed"]
    /\ logicalState' = [logicalState EXCEPT ![i] =
          IF currentAttempt[i] = MAX_RETRIES THEN "failed" ELSE "retry_wait"]
    /\ UNCHANGED <<outerState, currentAttempt, innerValue,
                    observed, resultList>>

RetryAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] = "retry_wait"
    /\ currentAttempt[i] < MAX_RETRIES
    /\ currentAttempt' = [currentAttempt EXCEPT ![i] = @ + 1]
    /\ logicalState' = [logicalState EXCEPT ![i] = "pending"]
    /\ UNCHANGED <<outerState, attemptState, innerValue, observed, resultList>>

CancelAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "cancelled"]
    /\ logicalState' = [logicalState EXCEPT ![i] = "cancelled"]
    /\ UNCHANGED <<outerState, currentAttempt, innerValue,
                    observed, resultList>>

Observe(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"succeeded", "failed", "cancelled"}
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, logicalState, currentAttempt,
                    attemptState, innerValue, resultList>>

Finalize ==
    /\ observed = INNER
    /\ AllLogicalTerminal
    /\ outerState' = IF \E i \in INNER :
                          logicalState[i] \in {"failed", "cancelled"}
                     THEN "failed" ELSE "succeeded"
    /\ resultList' = IF outerState' = "succeeded" THEN ExpectedResult ELSE resultList
    /\ UNCHANGED <<logicalState, currentAttempt, attemptState,
                    innerValue, observed>>

Next ==
    \/ \E i \in INNER : StartAttempt(i)
    \/ \E i \in INNER, v \in {"I1:value", "I2:value"} : CompleteAttempt(i, v)
    \/ \E i \in INNER : FailAttempt(i) \/ RetryAttempt(i) \/ CancelAttempt(i)
    \/ \E i \in INNER : Observe(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ logicalState \in [INNER -> LogicalStates]
    /\ currentAttempt \in [INNER -> 0..MAX_RETRIES]
    /\ attemptState \in [INNER -> [0..MAX_RETRIES -> AttemptStates]]
    /\ innerValue \in [INNER -> {"I1:value", "I2:value", "unset"}]
    /\ observed \subseteq INNER
    /\ resultList \in Seq({"I1:value", "I2:value", "unset"})

RetryBound ==
    \A i \in INNER : currentAttempt[i] <= MAX_RETRIES

PhysicalLogicalSafety ==
    \A i \in INNER :
        IF logicalState[i] = "succeeded"
           THEN attemptState[i][currentAttempt[i]] = "succeeded"
           ELSE IF logicalState[i] = "failed"
                THEN attemptState[i][currentAttempt[i]] = "failed"
                ELSE IF logicalState[i] = "cancelled"
                     THEN attemptState[i][currentAttempt[i]] = "cancelled"
                     ELSE TRUE

ObservedTerminalSafety ==
    \A i \in observed : logicalState[i] \in {"succeeded", "failed", "cancelled"}

JoinWaitSafety ==
    outerState = "succeeded" => observed = INNER /\ AllLogicalTerminal

JoinResultShapeSafety ==
    outerState = "succeeded" => resultList = ExpectedResult

FailureSafety ==
    outerState = "failed" =>
        \E i \in INNER : logicalState[i] \in {"failed", "cancelled"}

TerminalOuterSafety ==
    outerState \in {"succeeded", "failed"} =>
        observed = INNER /\ AllLogicalTerminal

=============================================================================
