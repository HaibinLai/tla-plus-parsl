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

CONSTANT MAX_RETRIES, MAX_DB_FAILURES, USE_FIXED

INNER == {"I1", "I2"}
POSITIONS == 1..3
Inputs == <<"I1", "I2", "I1">>
Modes == {"none", "single", "list", "empty", "invalid"}
OuterStates == {"executing", "joining", "succeeded", "failed", "cancelled"}
LogicalStates == {"pending", "retry_wait", "succeeded", "failed", "cancelled"}
AttemptStates == {"absent", "serialized", "queued", "received", "decoded",
                  "running", "succeeded", "failed", "cancelled", "stale"}
Values == {"I1:value", "I2:value", "unset"}
ResultValue == Values \cup {"invalid-return", "join-error"} \cup Seq(Values)
MonitorStates == {"none", "queued", "failed", "persisted"}
MonitorStatuses == {"none", "succeeded", "failed", "cancelled"}

VARIABLES outerState, mode, joinSet, observed, joinHandle,
          logicalState, currentAttempt, attemptState, innerValue,
          outerResult, failureCount, monitorState, monitorStatus, dbStatus,
          dbFailures, cancelRequested, cancelError
vars == <<outerState, mode, joinSet, observed, joinHandle,
           logicalState, currentAttempt, attemptState, innerValue,
           outerResult, failureCount, monitorState, monitorStatus, dbStatus,
           dbFailures, cancelRequested, cancelError>>

ExpectedList == [p \in POSITIONS |-> innerValue[Inputs[p]]]
AllJoinedTerminal ==
    \A i \in joinSet : logicalState[i] \in {"succeeded", "failed", "cancelled"}

Init ==
    /\ MAX_RETRIES >= 1
    /\ MAX_DB_FAILURES >= 0
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
    /\ monitorState = "none"
    /\ monitorStatus = "none"
    /\ dbStatus = "none"
    /\ dbFailures = 0
    /\ cancelRequested = FALSE
    /\ cancelError = FALSE

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

QueueAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "serialized"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "queued"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, innerValue,
                    outerResult, failureCount>>

ReceiveAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "queued"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "received"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, innerValue,
                    outerResult, failureCount>>

DecodeAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "received"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "decoded"]
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, innerValue,
                    outerResult, failureCount>>

StartAttempt(i) ==
    /\ i \in INNER
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "decoded"
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
              IF @ \in {"running", "serialized", "queued", "received", "decoded"}
              THEN "cancelled" ELSE @]
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

CancelOuter ==
    /\ outerState \in {"executing", "joining"}
    /\ cancelRequested' = TRUE
    /\ cancelError' = ~USE_FIXED
    /\ IF USE_FIXED
       THEN /\ outerState' = "cancelled"
            /\ joinHandle' = FALSE
            /\ outerResult' = [kind |-> "failure", value |-> "join-error"]
       ELSE /\ UNCHANGED <<outerState, joinHandle, outerResult>>
    /\ UNCHANGED <<mode, joinSet, observed, logicalState, currentAttempt,
                    attemptState, innerValue, failureCount, monitorState,
                    monitorStatus, dbStatus, dbFailures>>

JoinNext ==
    \/ ReturnSingle \/ ReturnList \/ ReturnEmpty \/ ReturnInvalid
    \/ \E i \in INNER : SerializeAttempt(i) \/ QueueAttempt(i)
                             \/ ReceiveAttempt(i) \/ DecodeAttempt(i)
                             \/ StartAttempt(i) \/ CompleteAttempt(i)
                             \/ FailAttempt(i) \/ RetryAttempt(i)
                             \/ CancelInner(i)
    \/ \E i \in INNER : Observe(i)
    \/ \E i \in INNER, a \in 0..MAX_RETRIES : LateAttempt(i, a)
    \/ Finalize
    \/ UNCHANGED vars

EmitOuterStatus ==
    /\ outerState \in {"succeeded", "failed", "cancelled"}
    /\ monitorState = "none"
    /\ monitorState' = "queued"
    /\ monitorStatus' = outerState
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, attemptState, innerValue,
                    outerResult, failureCount, dbStatus, dbFailures,
                    cancelRequested, cancelError>>

PersistOuterStatus ==
    /\ monitorState = "queued"
    /\ monitorState' = "persisted"
    /\ dbStatus' = monitorStatus
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, attemptState, innerValue,
                    outerResult, failureCount, monitorStatus, dbFailures,
                    cancelRequested, cancelError>>

FailDatabaseWrite ==
    /\ monitorState = "queued"
    /\ dbFailures < MAX_DB_FAILURES
    /\ monitorState' = "failed"
    /\ dbFailures' = dbFailures + 1
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, attemptState, innerValue,
                    outerResult, failureCount, monitorStatus, dbStatus,
                    cancelRequested, cancelError>>

RetryDatabaseWrite ==
    /\ monitorState = "failed"
    /\ monitorState' = "queued"
    /\ UNCHANGED <<outerState, mode, joinSet, observed, joinHandle,
                    logicalState, currentAttempt, attemptState, innerValue,
                    outerResult, failureCount, monitorStatus, dbStatus,
                    dbFailures, cancelRequested, cancelError>>

Next ==
    \/ (JoinNext /\ UNCHANGED <<monitorState, monitorStatus, dbStatus,
                                  dbFailures, cancelRequested, cancelError>>)
    \/ CancelOuter
    \/ EmitOuterStatus
    \/ PersistOuterStatus
    \/ FailDatabaseWrite
    \/ RetryDatabaseWrite

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
    /\ monitorState \in MonitorStates
    /\ monitorStatus \in MonitorStatuses
    /\ dbStatus \in MonitorStatuses
    /\ dbFailures \in 0..MAX_DB_FAILURES
    /\ cancelRequested \in BOOLEAN
    /\ cancelError \in BOOLEAN

JoinWaitSafety == outerState = "joining" => joinHandle
TerminalHandleSafety == outerState \in {"succeeded", "failed"} => ~joinHandle
OuterCancellationSafety ==
    outerState = "cancelled" =>
        /\ ~joinHandle
        /\ outerResult["kind"] = "failure"
CancellationSupportSafety == cancelRequested => outerState = "cancelled"
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

DatabaseTerminalSafety ==
    /\ dbStatus = "succeeded" => outerState = "succeeded"
    /\ dbStatus = "failed" => outerState = "failed"
    /\ dbStatus = "cancelled" => outerState = "cancelled"

DatabaseRetryBound ==
    dbFailures <= MAX_DB_FAILURES

=============================================================================
