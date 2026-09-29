--------------------------- MODULE ParslJoinRetryDuplicates ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * join_app ordered duplicate inputs with inner physical retries.
 *
 * The outer join receives <<I1, I2, I1>>.  Each logical inner Future owns
 * physical attempts; a non-final failure leaves it unresolved.  The current
 * branch aggregates the completed logical Futures as a set and loses the
 * duplicate position.  The fixed branch reconstructs the original sequence.
 ***************************************************************************)

CONSTANTS MAX_RETRIES, USE_FIXED

INNER == {"I1", "I2"}
Inputs == <<"I1", "I2", "I1">>
OuterStates == {"new", "joining", "succeeded", "failed"}
InnerStates == {"unresolved", "retry_wait", "succeeded", "failed"}
AttemptStates == {"absent", "running", "failed", "succeeded"}

VARIABLES outer, inner, currentAttempt, attemptState, observed,
          innerValue, resultList, failure
vars == <<outer, inner, currentAttempt, attemptState, observed,
           innerValue, resultList, failure>>

Expected == <<innerValue["I1"], innerValue["I2"], innerValue["I1"]>>

Init ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ outer = "new"
    /\ inner = [i \in INNER |-> "unresolved"]
    /\ currentAttempt = [i \in INNER |-> 0]
    /\ attemptState = [i \in INNER |->
          [k \in 0..MAX_RETRIES |-> "absent"]]
    /\ observed = {}
    /\ innerValue = [i \in INNER |-> "unset"]
    /\ resultList = <<>>
    /\ failure = FALSE

StartJoin ==
    /\ outer = "new"
    /\ outer' = "joining"
    /\ UNCHANGED <<inner, currentAttempt, attemptState, observed,
                    innerValue, resultList, failure>>

StartAttempt(i) ==
    /\ i \in INNER
    /\ outer = "joining"
    /\ inner[i] \in {"unresolved", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "absent"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "running"]
    /\ UNCHANGED <<outer, inner, currentAttempt, observed,
                    innerValue, resultList, failure>>

FailAttempt(i) ==
    /\ i \in INNER
    /\ inner[i] \in {"unresolved", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "failed"]
    /\ inner' = [inner EXCEPT ![i] =
          IF currentAttempt[i] = MAX_RETRIES THEN "failed" ELSE "retry_wait"]
    /\ failure' = IF currentAttempt[i] = MAX_RETRIES THEN TRUE ELSE failure
    /\ UNCHANGED <<outer, currentAttempt, observed, innerValue, resultList>>

RetryAttempt(i) ==
    /\ i \in INNER
    /\ inner[i] = "retry_wait"
    /\ currentAttempt[i] < MAX_RETRIES
    /\ currentAttempt' = [currentAttempt EXCEPT ![i] = @ + 1]
    /\ inner' = [inner EXCEPT ![i] = "unresolved"]
    /\ UNCHANGED <<outer, attemptState, observed, innerValue,
                    resultList, failure>>

CompleteAttempt(i) ==
    /\ i \in INNER
    /\ inner[i] \in {"unresolved", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "succeeded"]
    /\ inner' = [inner EXCEPT ![i] = "succeeded"]
    /\ innerValue' = [innerValue EXCEPT ![i] = i \o ":value"]
    /\ UNCHANGED <<outer, currentAttempt, observed, resultList, failure>>

Observe(i) ==
    /\ outer = "joining"
    /\ i \in INNER
    /\ inner[i] \in {"succeeded", "failed"}
    /\ i \notin observed
    /\ observed' = observed \cup {i}
    /\ UNCHANGED <<outer, inner, currentAttempt, attemptState,
                    innerValue, resultList, failure>>

Finalize ==
    /\ outer = "joining"
    /\ observed = INNER
    /\ outer' = IF failure THEN "failed" ELSE "succeeded"
    /\ resultList' = IF ~failure
                     THEN IF USE_FIXED THEN Expected
                          ELSE <<innerValue["I1"], innerValue["I2"]>>
                     ELSE resultList
    /\ UNCHANGED <<inner, currentAttempt, attemptState, observed,
                    innerValue, failure>>

Next ==
    \/ StartJoin
    \/ \E i \in INNER : StartAttempt(i)
    \/ \E i \in INNER : FailAttempt(i) \/ RetryAttempt(i) \/ CompleteAttempt(i)
    \/ \E i \in INNER : Observe(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outer \in OuterStates
    /\ inner \in [INNER -> InnerStates]
    /\ currentAttempt \in [INNER -> 0..MAX_RETRIES]
    /\ attemptState \in [INNER -> [0..MAX_RETRIES -> AttemptStates]]
    /\ observed \subseteq INNER
    /\ innerValue \in [INNER -> STRING]
    /\ resultList \in Seq(STRING)
    /\ failure \in BOOLEAN

RetryBound == \A i \in INNER : currentAttempt[i] <= MAX_RETRIES

JoinWaitSafety ==
    outer = "joining" => observed # INNER \/
        \A i \in INNER : inner[i] \in {"succeeded", "failed"}

ResultOrderSafety ==
    outer = "succeeded" => resultList = Expected

FailureSafety ==
    outer = "failed" => failure /\ \E i \in INNER : inner[i] = "failed"

=============================================================================
