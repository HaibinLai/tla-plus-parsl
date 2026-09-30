--------------------------- MODULE ParslJoinCallableTransport ---------------------------
EXTENDS Naturals, Integers, Sequences, FiniteSets

(***************************************************************************
 * join_app over serialized, retryable inner applications.
 *
 * The outer join observes logical inner Futures, while each inner Future may
 * have several physical attempts and serialized callable snapshots. A late
 * result from an obsolete attempt is stale and cannot satisfy the join. Once
 * all logical Futures succeed, the outer list is assembled in input order,
 * including duplicate references.
 ***************************************************************************)

CONSTANTS INNER, INPUT_MODE, MAX_RETRIES
Inputs ==
    IF INPUT_MODE = "full"
    THEN <<"I1", "I2", "I1">>
    ELSE LET i == CHOOSE x \in INNER : TRUE IN <<i, i>>
POSITIONS == 1..Len(Inputs)

LogicalStates == {"pending", "retry_wait", "succeeded", "failed"}
AttemptStates == {"absent", "running", "failed", "succeeded", "stale"}
OuterStates == {"joining", "succeeded", "failed"}

Value(i, v) ==
    i \o (IF v = 0 THEN ":v0" ELSE ":v1")

VARIABLES sourceVersion, currentAttempt, logicalState, attemptState,
          capturedVersion, resultWire, resultVersion,
          outerState, outerResult
vars == <<sourceVersion, currentAttempt, logicalState, attemptState,
           capturedVersion, resultWire, resultVersion,
           outerState, outerResult>>

Init ==
    /\ INNER # {}
    /\ INPUT_MODE \in {"full", "duplicate-single"}
    /\ Inputs \in Seq(INNER)
    /\ Len(Inputs) > 0
    /\ sourceVersion = [i \in INNER |-> 0]
    /\ currentAttempt = [i \in INNER |-> 0]
    /\ logicalState = [i \in INNER |-> "pending"]
    /\ attemptState = [i \in INNER |-> [a \in 0..MAX_RETRIES |-> "absent"]]
    /\ capturedVersion = [i \in INNER |-> [a \in 0..MAX_RETRIES |-> -1]]
    /\ resultWire = [i \in INNER |-> [a \in 0..MAX_RETRIES |-> "none"]]
    /\ resultVersion = [i \in INNER |-> [a \in 0..MAX_RETRIES |-> -1]]
    /\ outerState = "joining"
    /\ outerResult = <<>>

Serialize(i) ==
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "absent"
    /\ capturedVersion' = [capturedVersion EXCEPT
          ![i][currentAttempt[i]] = sourceVersion[i]]
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "running"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState,
                    resultWire, resultVersion, outerState, outerResult>>

Mutate(i) ==
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ sourceVersion[i] = 0
    /\ sourceVersion' = [sourceVersion EXCEPT ![i] = 1]
    /\ UNCHANGED <<currentAttempt, logicalState, attemptState,
                    capturedVersion, resultWire, resultVersion,
                    outerState, outerResult>>

Fail(i) ==
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "failed"]
    /\ logicalState' = [logicalState EXCEPT ![i] =
          IF currentAttempt[i] < MAX_RETRIES THEN "retry_wait" ELSE "failed"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, capturedVersion,
                    resultWire, resultVersion, outerState, outerResult>>

Retry(i) ==
    /\ logicalState[i] = "retry_wait"
    /\ currentAttempt[i] < MAX_RETRIES
    /\ currentAttempt' = [currentAttempt EXCEPT ![i] = @ + 1]
    /\ logicalState' = [logicalState EXCEPT ![i] = "pending"]
    /\ UNCHANGED <<sourceVersion, attemptState, capturedVersion,
                    resultWire, resultVersion, outerState, outerResult>>

Complete(i) ==
    /\ logicalState[i] \in {"pending", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "succeeded"]
    /\ resultWire' = [resultWire EXCEPT
          ![i][currentAttempt[i]] = "queued"]
    /\ resultVersion' = [resultVersion EXCEPT
          ![i][currentAttempt[i]] = capturedVersion[i][currentAttempt[i]]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState,
                    capturedVersion, outerState, outerResult>>

LateComplete(i, a) ==
    /\ a < currentAttempt[i]
    /\ attemptState[i][a] = "failed"
    /\ resultWire' = [resultWire EXCEPT ![i][a] = "queued"]
    /\ resultVersion' = [resultVersion EXCEPT ![i][a] = capturedVersion[i][a]]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState,
                    attemptState, capturedVersion, outerState, outerResult>>

Deliver(i, a) ==
    /\ resultWire[i][a] = "queued"
    /\ resultWire' = [resultWire EXCEPT ![i][a] = "consumed"]
    /\ IF a = currentAttempt[i] /\ attemptState[i][a] = "succeeded"
       THEN /\ logicalState' = [logicalState EXCEPT ![i] = "succeeded"]
            /\ attemptState' = attemptState
       ELSE /\ logicalState' = logicalState
            /\ attemptState' = [attemptState EXCEPT ![i][a] = "stale"]
    /\ UNCHANGED <<sourceVersion, currentAttempt, capturedVersion,
                    resultVersion, outerState, outerResult>>

Finalize ==
    /\ outerState = "joining"
    /\ \A i \in INNER : logicalState[i] = "succeeded"
    /\ outerState' = "succeeded"
    /\ outerResult' = [p \in POSITIONS |->
          Value(Inputs[p], capturedVersion[Inputs[p]][currentAttempt[Inputs[p]]])]
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState,
                    attemptState, capturedVersion, resultWire, resultVersion>>

PropagateFailure ==
    /\ outerState = "joining"
    /\ \E i \in INNER : logicalState[i] = "failed"
    /\ outerState' = "failed"
    /\ outerResult' = <<>>
    /\ UNCHANGED <<sourceVersion, currentAttempt, logicalState,
                    attemptState, capturedVersion, resultWire, resultVersion>>

Next ==
    \/ \E i \in INNER : Serialize(i) \/ Mutate(i) \/ Fail(i) \/ Retry(i) \/ Complete(i)
    \/ \E i \in INNER, a \in 0..MAX_RETRIES : Deliver(i, a)
    \/ \E i \in INNER, a \in 0..MAX_RETRIES : LateComplete(i, a)
    \/ Finalize
    \/ PropagateFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ sourceVersion \in [INNER -> 0..1]
    /\ currentAttempt \in [INNER -> 0..MAX_RETRIES]
    /\ logicalState \in [INNER -> LogicalStates]
    /\ attemptState \in [INNER -> [0..MAX_RETRIES -> AttemptStates]]
    /\ capturedVersion \in [INNER -> [0..MAX_RETRIES -> -1..1]]
    /\ resultWire \in [INNER -> [0..MAX_RETRIES -> {"none", "queued", "consumed"}]]
    /\ resultVersion \in [INNER -> [0..MAX_RETRIES -> -1..1]]
    /\ outerState \in OuterStates
    /\ outerResult \in Seq(STRING)

JoinWaitSafety ==
    outerState = "joining" => outerResult = <<>>

FailureTerminalSafety ==
    outerState = "failed" => \E i \in INNER : logicalState[i] = "failed"

RetryBound == \A i \in INNER : currentAttempt[i] <= MAX_RETRIES

OrderedDuplicateResultSafety ==
    outerState = "succeeded" =>
        outerResult = [p \in POSITIONS |->
          Value(Inputs[p], capturedVersion[Inputs[p]][currentAttempt[Inputs[p]]])]

NoStaleRelease ==
    \A i \in INNER, a \in 0..MAX_RETRIES :
        resultWire[i][a] = "consumed" /\ a # currentAttempt[i]
            => attemptState[i][a] = "stale"

=============================================================================
