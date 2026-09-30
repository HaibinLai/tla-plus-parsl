--------------------------- MODULE ParslJoinFull ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Integrated bounded join_app semantics.
 *
 * This model keeps logical inner Futures separate from physical attempts and
 * combines the externally visible join cases: one Future, an ordered list
 * with duplicate references, an empty list, and an invalid return. Inner
 * retries are local to each logical Future. Cancellation and failure are
 * terminal observations that become an outer JoinError; successful list
 * results preserve the original input positions.
 ***************************************************************************)

CONSTANT MAX_RETRIES, USE_FIXED

INNER == {"I1", "I2"}
POSITIONS == 1..3
Inputs == <<"I1", "I2", "I1">>
Modes == {"none", "single", "list", "empty", "invalid"}
OuterStates == {"executing", "joining", "succeeded", "failed"}
LogicalStates == {"pending", "retry_wait", "succeeded", "failed", "cancelled"}
AttemptStates == {"absent", "serialized", "running", "succeeded", "failed", "cancelled", "stale"}
Values == {"I1:value", "I2:value", "unset"}
ResultValue == Values \cup {"invalid-return", "join-error"} \cup Seq(Values)

VARIABLES outerState, mode, joinSet, observed, joinHandle,
          logicalState, currentAttempt, attemptState, innerValue,
          outerResult, failureCount
vars == <<outerState, mode, joinSet, observed, joinHandle,
           logicalState, currentAttempt, attemptState, innerValue,
           outerResult, failureCount>>

ExpectedList == [p \in POSITIONS |-> innerValue[Inputs[p]]]
AllJoinedTerminal ==
    \A i \in joinSet : logicalState[i] \in {"succeeded", "failed", "cancelled"}

Init ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ outerState = "executing"
    /\ mode = "none"
    /\ joinSet = {}
    /\ observed = {}
    /\ joinHandle = FALSE
    /\ logicalState = [i \in INNER |-> "pending"]
    /\ currentAttempt = [i \in INNER |-> 0]
    /\ attemptState = [i \in INNER |->
          [a \in 0..MAX_RETRIES |-> "absent"]]
    /\ innerValue = [i \in INNER |-> "unset"]
    /\ outerResult = [kind |-> "none", value |-> "unset"]
    /\ failureCount = 0

ReturnSingle ==
    /\ outerState = "executing"
    /\ mode' = "single"
    /\ joinSet' = {"I1"}
    /\ outerState' = "joining"
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<logicalState, currentAttempt, attemptState, innerValue,
                    outerResult, failureCount>>

ReturnList ==
    /\ outerState = "executing"
    /\ mode' = "list"
    /\ joinSet' = INNER
    /\ outerState' = "joining"
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<logicalState, currentAttempt, attemptState, innerValue,
                    outerResult, failureCount>>

ReturnEmpty ==
    /\ outerState = "executing"
    /\ mode' = "empty"
    /\ joinSet' = {}
    /\ outerState' = "joining"
    /\ observed' = {}
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<logicalState, currentAttempt, attemptState, innerValue,
                    outerResult, failureCount>>

ReturnInvalid ==
    /\ outerState = "executing"
    /\ mode' = "invalid"
    /\ outerState' = "failed"
    /\ joinSet' = {}
    /\ observed' = {}
    /\ joinHandle' = FALSE
    /\ outerResult' = [kind |-> "failure", value |-> "invalid-return"]
    /\ UNCHANGED <<logicalState, currentAttempt, attemptState, innerValue,
                    failureCount>>

SerializeAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "absent"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "serialized"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, innerValue,
                    outerResult, failureCount>>

StartAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "serialized"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "running"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, innerValue,
                    outerResult, failureCount>>

CompleteAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "succeeded"]
    /\ logicalState' = [logicalState EXCEPT ![i] = "succeeded"]
    /\ innerValue' = [innerValue EXCEPT ![i] = i \o ":value"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    currentAttempt, outerResult, failureCount>>

FailAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "failed"]
    /\ logicalState' = [logicalState EXCEPT ![i] =
          IF currentAttempt[i] = MAX_RETRIES THEN "failed" ELSE "retry_wait"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    currentAttempt, innerValue, outerResult, failureCount>>

RetryAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] = "retry_wait"
    /\ currentAttempt[i] < MAX_RETRIES
    /\ currentAttempt' = [currentAttempt EXCEPT ![i] = @ + 1]
    /\ logicalState' = [logicalState EXCEPT ![i] = "pending"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    attemptState, innerValue, outerResult, failureCount>>

LateAttempt(i, a) ==
    /\ i \in INNER
    /\ a \in 0..MAX_RETRIES
    /\ a < currentAttempt[i]
    /\ attemptState[i][a] = "failed"
    /\ IF USE_FIXED
          THEN /\ attemptState' = [attemptState EXCEPT ![i][a] = "stale"]
               /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                               logicalState, currentAttempt, innerValue,
                               outerResult, failureCount>>
          ELSE /\ logicalState' = [logicalState EXCEPT ![i] = "succeeded"]
               /\ innerValue' = [innerValue EXCEPT ![i] = i \o ":value"]
               /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                               currentAttempt, attemptState, outerResult,
                               failureCount>>

CancelInner(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait", "running"}
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] =
              IF @ \in {"running", "serialized"} THEN "cancelled" ELSE @]
    /\ logicalState' = [logicalState EXCEPT ![i] = "cancelled"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    currentAttempt, innerValue, outerResult, failureCount>>

Observe(i) ==
    /\ outerState = "joining"
    /\ i \in joinSet
    /\ logicalState[i] \in {"succeeded", "failed", "cancelled"}
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outerState, mode, joinSet, joinHandle, logicalState,
                    currentAttempt, attemptState, innerValue, outerResult,
                    failureCount>>

Finalize ==
    /\ outerState = "joining"
    /\ observed = joinSet
    /\ AllJoinedTerminal
    /\ LET failed == {i \in joinSet : logicalState[i] \in {"failed", "cancelled"}} IN
        /\ outerState' = IF failed # {} THEN "failed" ELSE "succeeded"
        /\ failureCount' = Cardinality(failed)
        /\ outerResult' =
              IF failed # {}
              THEN [kind |-> "failure", value |-> "join-error"]
              ELSE IF mode = "single"
                   THEN [kind |-> "single", value |-> innerValue["I1"]]
                   ELSE IF mode = "empty"
                        THEN [kind |-> "empty", value |-> <<>>]
                        ELSE [kind |-> "list", value |-> ExpectedList]
        /\ joinHandle' = FALSE
    /\ UNCHANGED <<mode, joinSet, observed, logicalState, currentAttempt,
                    attemptState, innerValue>>

Next ==
    \/ ReturnSingle \/ ReturnList \/ ReturnEmpty \/ ReturnInvalid
    \/ \E i \in INNER : SerializeAttempt(i) \/ StartAttempt(i)
                             \/ CompleteAttempt(i)
                             \/ FailAttempt(i) \/ RetryAttempt(i)
                             \/ CancelInner(i)
    \/ \E i \in INNER : Observe(i)
    \/ \E i \in INNER, a \in 0..MAX_RETRIES : LateAttempt(i, a)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ mode \in Modes
    /\ joinSet \subseteq INNER
    /\ observed \subseteq joinSet
    /\ joinHandle \in BOOLEAN
    /\ logicalState \in [INNER -> LogicalStates]
    /\ currentAttempt \in [INNER -> 0..MAX_RETRIES]
    /\ attemptState \in [INNER -> [0..MAX_RETRIES -> AttemptStates]]
    /\ innerValue \in [INNER -> Values]
    /\ outerResult["kind"] \in {"none", "single", "list", "empty", "failure"}
    /\ IF outerResult["kind"] = "list"
       THEN outerResult["value"] \in [POSITIONS -> Values]
       ELSE outerResult["value"] \in ResultValue
    /\ failureCount \in 0..Cardinality(INNER)

JoinWaitSafety == outerState = "joining" => joinHandle
TerminalHandleSafety == outerState \in {"succeeded", "failed"} => ~joinHandle
RetryBound == \A i \in INNER : currentAttempt[i] <= MAX_RETRIES
FailureAggregationSafety ==
    outerState = "failed" /\ mode # "invalid"
        => failureCount > 0 /\ outerResult["kind"] = "failure"
OrderedResultSafety ==
    outerState = "succeeded" /\ mode = "list"
        => outerResult["value"] = ExpectedList
EmptyJoinSafety ==
    outerState = "succeeded" /\ mode = "empty"
        => outerResult["value"] = <<>>
AttemptLogicalSafety ==
    \A i \in INNER :
      logicalState[i] = "succeeded" => attemptState[i][currentAttempt[i]] = "succeeded"

CancellationSafety ==
    \A i \in INNER :
      logicalState[i] = "cancelled"
        => attemptState[i][currentAttempt[i]] \in
             {"absent", "failed", "cancelled"}

LateResultSafety ==
    \A i \in INNER :
      logicalState[i] = "succeeded" =>
        attemptState[i][currentAttempt[i]] = "succeeded"

=============================================================================
